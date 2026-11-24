# Project Rules: Cabin Bunker Horror (Rojo + Studio MCP)

## Team Roles & File Ownership
- `src/` (Luau scripts) is owned by the Technical Lead via Rojo + Git.
- 3D Maps, `ReplicatedStorage/RoomTemplates`, Lighting, and raw UI instances in Team Create are owned by the Creative Lead.

## Strict Tool Boundaries
1. NEVER edit `.luau` scripts inside Roblox Studio via MCP (`multi_edit`). All script edits MUST happen on disk inside `src/` so Git tracks diffs cleanly.
2. Keep `"$ignoreUnknownInstances": true` in `default.project.json` so Rojo never deletes builder-created Workspace or ReplicatedStorage models.
3. Code Standards: Every `.luau` file uses `--!strict`, modular Services/Controllers, and passes `stylua` + `selene`.
4. Streaming & Teleport Safety: All procedural room models require `ModelStreamingMode = Atomic`. Always call `Player:RequestStreamAroundAsync()` before CFrame teleports.

## Repository Documentation
Consult project specifications and architectural guides before making structural changes:
- `README.md`: Project overview, toolchain quickstart, Team Create sync rules, and baseline status.
- `docs/GAME_DESIGN_AND_RESEARCH.md`: Core gameplay loop, story beats, horror atmosphere, 1–4 player scaling, and roadmap.
- `docs/ARCHITECTURE_AND_WORKFLOW.md`: Server/Client/Shared module architecture, Rojo sync boundaries, streaming safety, and Git workflow.
- `docs/STUDIO_ASSET_SPEC.md`: Exact instance hierarchies, room anchors, NPC rigs, sounds, and UI contracts for the Creative Lead.
- `docs/forest-cabin-handoff.md`: Historical environment handoff document for the Blackpine Forest and cabin opening.

