# PLANCK VR Stability Patch 1.3.2

## Independent patch configuration

Release 1.3.2 moves the downstream weapon-node controls out of PLANCK's
`activeragdoll.ini`. The patch now owns and reloads
`Data\SKSE\Plugins\PLANCK-VR-Stability-Patch.ini`, so installing or updating
the stability patch cannot replace a user's PLANCK settings.

## Fail-closed weapon-node rebinding

This release narrows the 1.3.0 animation-binding correction to the exact
`SHIELD` node demonstrated by retained crash dumps. Other converted weapon
nodes keep PLANCK 0.8.1 behavior unless the user explicitly enables the wider
diagnostic mode.

Two settings live in the patch-owned
`Data\SKSE\Plugins\PLANCK-VR-Stability-Patch.ini`, keeping them independent
from PLANCK's existing configuration:

```ini
[Settings]
enableWeaponNodeRebinding=true
rebindUnobservedWeaponNodes=false
```

The release archive includes this file with the safe defaults shown above.
Set `enableWeaponNodeRebinding=false` to disable the 1.3.x animation-table update
without disabling PLANCK's original fade-node conversion. Set
`rebindUnobservedWeaponNodes=true` to restore 1.3.0's wider `WEAPON`, weapon-type,
`SHIELD`, and `WeaponBack` coverage for diagnosis.

Before replacing an observed node, the patch now verifies the parent slot,
flattened-bone identity, animation-table ranges, current manager, and exact
replacement state. The animation and flattened-bone pointers are committed
together under the graph update lock. An unexpected post-replacement failure
retains the displaced node and disables further affected conversions rather
than allowing an unidentified reader to observe freed storage. Each committed
update writes one bounded result line to `activeragdoll.log`.

## Preserve animation bindings during node conversion

This release updates animation graph bone
pointers when PLANCK replaces a third-person weapon node with a BSFadeNode.
Every pointer-equal entry in every graph of the retained current manager is
updated; flattened-bone offsets and other entry metadata remain unchanged.
This applies to all converted weapon nodes, including SHIELD.

Both old and replacement nodes remain strongly referenced through the update.
Scene replacement runs outside the animation lock; the old reference keeps
any intervening animation access valid. Rebinding occurs under updateLock and
finishes before the old reference is released. If no animation manager can be
retained, conversion is skipped rather than leaving untracked replacements.

Two full dumps show a Shield animation binding pointing to a lighting property
whose contents match the Shield pose. Exact symbols establish that the
conversion hook was installed and enabled in the later dump. This is strong
evidence for a stale binding, not a historical recording of the free/reuse.
The exact crash trigger passed an attended runtime stress test with many rapid
Argonian preset changes and additional race changes. PLANCK logged repeated
successful WEAPON and SHIELD rebinds. This was a qualitative targeted test,
not exhaustive validation of every model-load timing case.

`tests/bone_node_rebinding.cpp` exercises exact-match replacement, duplicate
bindings, multiple graph tables, preserved metadata, unrelated/null entries,
empty ranges, and repeat calls. `tools/Build-Planck.ps1` builds with managed
scratch and disables all legacy deployment post-build events. The local
SKSE VR SDK and Havok headers must be supplied separately; neither is copied
into the corresponding-source directory.

## Released baseline

This downstream build is based on PLANCK 0.8.1 and contains the reviewed
changes from:

- [PR 3](https://github.com/adamhynek/activeragdoll/pull/3): retain the
  animation graph manager for the complete access lifetime;
- [PR 5](https://github.com/adamhynek/activeragdoll/pull/5): prevent stale
  ease-constraint actions from restoring replaced ragdoll constraints;
- [PR 6](https://github.com/adamhynek/activeragdoll/pull/6): validate HIGGS
  body ownership and use the Havok world write lock during filter refresh.

It deliberately does **not** contain
[PR 4](https://github.com/adamhynek/activeragdoll/pull/4). Exact release PDB
and disassembly evidence established that NPC Spell Variance 2.7.0 installs
its `UpdateCombat` hook over Skyrim VR's `Character::GetAlpha`. PLANCK consumes
the undefined value but does not produce it.

The earlier downstream PLANCK alpha change was literally a compatibility
patch: it contained the visible symptom after another plugin violated the
`GetAlpha` contract. It was not the producer fix. Broad validation inside
PLANCK may still be worthwhile as defence in depth, but it can also conceal
other producer faults and make their source harder to identify.

Use the separate
[NPC Spell Variance VR Patch](https://github.com/Treatid2/NPC-Spell-Variance-VR-Patch)
until NPC Spell Variance ships an upstream release with the runtime-correct VR
vtable slot. Existing 1.1.x files remain historical artifacts and are not
withdrawn.

This package is GPL-3.0 and includes its exact corresponding source. PLANCK's
upstream source is available at
[adamhynek/activeragdoll](https://github.com/adamhynek/activeragdoll).
