[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$SdkSource = 'L:\Codex\shared\dependencies\sksevr_2_00_12\src',
    [string]$HavokSource = 'L:\Codex\shared\sdk\Havok\hk2010_2_0_r1\Source',
    [string]$VisualStudio = 'C:\Program Files\Microsoft Visual Studio\18\Community',
    [string]$Destination = 'L:\Codex\artifacts\PLANCK\diagnostics\20260914-bone-node-lifetime',
    [switch]$AcknowledgeLowSpace,
    [string]$LowSpaceReason
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = Split-Path $PSScriptRoot -Parent }
$sourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$scratchTool = $env:CODEX_SCRATCH_TOOL
$runner = 'L:\Codex\shared\tools\managed-process\Invoke-CodexManagedProcess.ps1'
$msbuild = Join-Path $VisualStudio 'MSBuild\Current\Bin\amd64\MSBuild.exe'
foreach ($required in @($SdkSource, $HavokSource, $msbuild, $runner, $scratchTool)) {
    if (!(Test-Path -LiteralPath $required)) { throw "Missing build input: $required" }
}
if (Test-Path -LiteralPath $Destination) { throw "Refusing to overwrite artifact directory: $Destination" }
$acquireParameters = @{
    Kind = 'build'
    ProjectPath = $sourceRoot
    ExpectedGiB = 3
    Compact = $true
}
if ($AcknowledgeLowSpace) {
    if ([string]::IsNullOrWhiteSpace($LowSpaceReason)) {
        throw 'LowSpaceReason is required with AcknowledgeLowSpace'
    }
    $acquireParameters.AcknowledgeLowSpace = $true
    $acquireParameters.LowSpaceReason = $LowSpaceReason
}
$allocation = & $scratchTool acquire @acquireParameters | ConvertFrom-Json
if (!$allocation.ok -or $allocation.state -ne 'active') { throw 'Scratch acquisition failed' }
$work = $allocation.data.workPath
$receipts = @()
try {
    $out = Join-Path $work 'bin'
    $logs = Join-Path $work 'logs'
    New-Item -ItemType Directory -Path $out, $logs | Out-Null
    $projects = @(
        @('common', (Join-Path $SdkSource 'common\common_vc14.vcxproj'), 'Release'),
        @('skse64_common', (Join-Path $SdkSource 'sksevr\skse64_common\skse64_common.vcxproj'), 'Release'),
        @('skse64', (Join-Path $SdkSource 'sksevr\skse64\skse64.vcxproj'), 'Release_Lib'),
        @('activeragdoll', (Join-Path $sourceRoot 'activeragdoll.vcxproj'), 'Release')
    )
    foreach ($project in $projects) {
        $args = @($project[1], '/nologo', '/m:2', '/t:Build',
            "/p:Configuration=$($project[2])", '/p:Platform=x64', '/p:PlatformToolset=v145',
            '/p:WindowsTargetPlatformVersion=10.0', '/p:BuildProjectReferences=false',
            '/p:PostBuildEventUseInBuild=false', '/p:PreBuildEventUseInBuild=false',
            '/p:PreLinkEventUseInBuild=false', "/p:OutDir=$out\",
            "/p:IntDir=$work\obj\$($project[0])\", "/p:SolutionDir=$SdkSource\sksevr\",
            "/p:HavokSource=$HavokSource", "/p:ForceImportBeforeCppTargets=$PSScriptRoot\managed-build.props")
        $receipt = & $runner -FilePath $msbuild -ArgumentList $args -WorkingDirectory $work `
            -OperationName "planck-$($project[0])" -TimeoutSeconds 600 -LogDirectory $logs -PassThru
        $receipts += $receipt
        if (!$receipt.success) { throw "Build failed at $($project[0]): $($receipt.first_actionable_failure)" }
    }
    foreach ($file in @('activeragdoll.dll', 'activeragdoll.pdb')) {
        if (!(Test-Path -LiteralPath (Join-Path $out $file))) { throw "Missing output: $file" }
    }
    New-Item -ItemType Directory -Path $Destination | Out-Null
    $promotedBuild = Join-Path $Destination 'build'
    New-Item -ItemType Directory -Path $promotedBuild | Out-Null
    Copy-Item -LiteralPath (Join-Path $out 'activeragdoll.dll'), (Join-Path $out 'activeragdoll.pdb') -Destination $promotedBuild
    Copy-Item -LiteralPath $logs -Destination (Join-Path $Destination 'logs') -Recurse
    $sourceDestination = Join-Path $Destination 'Source'
    New-Item -ItemType Directory -Path $sourceDestination | Out-Null
    foreach ($item in @('src', 'include', 'tools', 'tests', 'LICENSE', 'README.md', 'DOWNSTREAM_PATCH.md', 'activeragdoll.vcxproj', 'exports.def')) {
        $sourceItem = Join-Path $sourceRoot $item
        if (Test-Path -LiteralPath $sourceItem) {
            Copy-Item -LiteralPath $sourceItem -Destination $sourceDestination -Recurse
        }
    }
    $identity = [ordered]@{
        sourceRoot = $sourceRoot; baseCommit = (& git -C $sourceRoot rev-parse HEAD)
        dirty = @(& git -C $sourceRoot status --short); scratchId = $allocation.data.id
        sdkSource = $SdkSource; havokSource = $HavokSource; visualStudio = $VisualStudio
        builtAtUtc = [DateTime]::UtcNow.ToString('o'); runtimeTested = $false; receipts = $receipts
        outputs = @(Get-FileHash -LiteralPath (Join-Path $Destination 'build\activeragdoll.dll'), (Join-Path $Destination 'build\activeragdoll.pdb'))
    }
    $identity | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $Destination 'build-receipt.json') -Encoding utf8
    $identity | ConvertTo-Json -Depth 12
}
catch {
    $failureDestination = "$Destination-failed-$($allocation.data.id)"
    New-Item -ItemType Directory -Path $failureDestination | Out-Null
    if (Test-Path -LiteralPath $logs) {
        Copy-Item -LiteralPath $logs -Destination (Join-Path $failureDestination 'logs') -Recurse
    }
    @{ error = $_.ToString(); scratchId = $allocation.data.id; success = $false } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $failureDestination 'failure.json') -Encoding utf8
    throw
}
finally {
    & $scratchTool release -Id $allocation.data.id -Disposition discarded `
        -Reason 'Promoted DLL, PDB, source, receipts, and logs; remaining build intermediates are reconstructible.' -Compact
}
