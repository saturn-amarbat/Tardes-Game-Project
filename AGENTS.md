# Project Rules: Cabin Bunker Horror (Rojo + Studio MCP)

## Team Roles & File Ownership
- `src/` (Luau scripts) is owned by the Technical Lead via Rojo + Git.
- 3D Maps, `ReplicatedStorage/RoomTemplates`, Lighting, and raw UI instances in Team Create are owned by the Creative Lead.

## Strict Tool Boundaries
1. NEVER edit `.luau` scripts inside Roblox Studio via MCP (`multi_edit`). All script edits MUST happen on disk inside `src/` so Git tracks diffs cleanly.
2. Keep `"$ignoreUnknownInstances": true` in `default.project.json` so Rojo never deletes builder-created Workspace or ReplicatedStorage models.
3. Code Standards: Every `.luau` file uses `--!strict`, modular Services/Controllers, and passes `stylua` + `selene`.
4. Streaming & Teleport Safety: All procedural room models require `ModelStreamingMode = Atomic`. Always call `Player:RequestStreamAroundAsync()` before CFrame teleports.
