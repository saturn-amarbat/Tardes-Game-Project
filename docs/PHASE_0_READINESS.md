# Phase 0 — Development readiness and recovery

Status as of 2026-11-26: open. This record is a documentation proposal for lead review, not authorization to modify a shared place.

## Evidence baseline

- GitHub main inspected at `3878e6d3c49917c08233b13354a171ecc3c4ab2c`.
- Repository tree contains 15 grid prefabs, BunkerGrid Checkpoints 3–5 test modules and StalkerNavigator. Server bootstrap still calls `RoomGenerator.generate(10)`; `BunkerEntry.server.luau` requires `BunkerHallways.SquadFall`. Presence is not proof of runtime activation or acceptance.
- PR #5 records historical isolated solo and two-player hallway descent tests; these are not evidence of current shared-place recovery.
- Engineering Lead reports ENG-002 complete. Underlying local evidence and exact task acceptance record have not been inspected here.
- Latest shared Studio version, local working-tree status, and current runtime readiness remain unverified.

## Next gates (Engineering Lead)

1. Isolated Rojo recovery validation: record branch/commit, clean or explained working tree, tool versions, exact project mapping and target local place. Preserve gameplay-critical instances. Inspect proposed sync changes before connecting; stop on unexpected deletes or replacements. Record build, formatting and lint results, before/after instance inventory and Studio output.
2. Shared-place recovery: only after isolated validation and explicit joint authorization. Record target place/version, recovery point, expected instance changes, responsible operator and rollback procedure. Do not publish production.
3. Runtime verification: exercise opening/hatch transition, lobby, procedural layout, objective collection, extraction and multiplayer recovery as applicable. Record solo and co-op evidence, errors, seed, player count and tested commit/place version. Run Checkpoint 5 in isolation with the required Stalker rig; do not infer grid activation from test modules.
4. Both leads review evidence and approve readiness exit. Keep Checkpoints 6–7 and new gameplay implementation outside this gate unless separately approved.

## Toolchain

Manifest: `rokit.toml` (Rojo 7.7.1, Wally 0.3.2, StyLua 2.6.0, Selene 0.32.0, Luau-LSP 1.70.1). Engineering setup report records Rokit 1.2.0 and GitHub CLI 2.106.0 on Windows, with the project tools installed. Local verification was reported, not independently repeated. Use `rokit install`, `stylua --check src`, `selene src`, and an isolated `rojo build` for the selected project. Never treat a successful build as a Studio playtest.

See [team workflow](TEAM_WORKFLOW.md) and [engineering handoff](TARDES_Engineering_Handoff_Report.md).
