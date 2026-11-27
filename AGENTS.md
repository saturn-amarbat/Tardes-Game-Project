# Project Rules: Cabin Bunker Horror (Rojo + Studio MCP)

## Team Roles & File Ownership
- **Engineering Lead**: Owns `src/` (Luau scripts) via Rojo + Git, gameplay systems, procedural generation (`BunkerGrid` / `RoomGenerator`), multiplayer, NPC AI, technical QA, and Studio recovery.
- **Creative Lead**: Owns 3D maps, environment art, Blender sources, `ReplicatedStorage/RoomTemplates`, `ReplicatedStorage/NPCModels`, `Lighting`, audio, animations, and raw UI instances in Team Create.
- **AI Agents (Antigravity, Codex, ChatGPT)**: Operate strictly within the assigning lead's scope and these repository boundaries; see [docs/TEAM_WORKFLOW.md](docs/TEAM_WORKFLOW.md).

## Strict Tool & Approval Boundaries
1. NEVER edit `.luau` scripts inside Roblox Studio via MCP (`multi_edit`) or Studio's script editor. All script edits MUST happen on disk inside `src/` so Git tracks diffs cleanly.
2. Keep `"$ignoreUnknownInstances": true` in `default.project.json` on `Workspace`, `ReplicatedStorage`, `ServerStorage`, `Lighting`, and `StarterGui`, and do not assume it protects descendants of tracked models or unignored script trees. Never connect Rojo to the shared Team Create place during active recovery until isolated validation passes (see [docs/PHASE_0_READINESS.md](docs/PHASE_0_READINESS.md)).
3. Code Standards: Every `.luau` file uses `--!strict`, modular Services/Controllers, and passes `stylua --check src` + `selene src`.
4. Streaming & Teleport Safety: All procedural room models require `ModelStreamingMode = Atomic`. Always call `Player:RequestStreamAroundAsync()` before CFrame teleports.
5. Approval & Isolation Gate: Validate Rojo recovery and tracked asset replacements in an isolated local Studio copy before touching the shared Team Create place. Structural changes, shared-place recovery, asset replacement, milestone exit, and publishing require explicit approval from both leads.
6. Evidence Discipline: Distinguish source-verified, runtime-verified, reported, proposed, and jointly approved states. Never cite a conversation, chat summary, or static `rojo build` as proof of Studio runtime readiness.

## Repository Documentation
Consult project specifications and architectural guides before making structural changes:
- [GAME_SPEC.md](GAME_SPEC.md): Canonical Single Source of Truth for vision, core loop, death/revive rules, NPCs, and v1 launch scope.
- [README.md](README.md): Project overview, toolchain quickstart, Team Create sync rules, and audited source baseline.
- [docs/PHASE_0_READINESS.md](docs/PHASE_0_READINESS.md): Open Phase 0 recovery sequence, verification gates, and readiness exit criteria.
- [docs/TEAM_WORKFLOW.md](docs/TEAM_WORKFLOW.md): Proposed Engineering/Creative ownership, AI agent boundaries, and handoff protocol.
- [docs/TARDES_Engineering_Handoff_Report.md](docs/TARDES_Engineering_Handoff_Report.md): Reconstructed engineering handoff summary and open verification evidence.
- [docs/DECISIONS_AND_CHANGELOG.md](docs/DECISIONS_AND_CHANGELOG.md): Architectural Decision Records (why choices were made) and chronological implementation log.
- [docs/MILESTONES_AND_CHECKINS.md](docs/MILESTONES_AND_CHECKINS.md): Milestone gates, check-in protocol, and open verification tasks.
- [docs/GAME_DESIGN_AND_RESEARCH.md](docs/GAME_DESIGN_AND_RESEARCH.md): Core gameplay loop, story beats, horror atmosphere, 1–4 player scaling, and roadmap.
- [docs/ARCHITECTURE_AND_WORKFLOW.md](docs/ARCHITECTURE_AND_WORKFLOW.md): Server/Client/Shared module architecture, Rojo sync boundaries, streaming safety, and Git workflow.
- [docs/STUDIO_ASSET_SPEC.md](docs/STUDIO_ASSET_SPEC.md): Exact instance hierarchies, room anchors, NPC rigs, sounds, and UI contracts for the Creative Lead.
- [docs/forest-cabin-handoff.md](docs/forest-cabin-handoff.md): Historical environment handoff document for the Blackpine Forest and cabin opening.

