# PLANCK VR Stability Patch 1.2.0

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
