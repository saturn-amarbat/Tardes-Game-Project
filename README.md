# Tardes (Cabin Bunker Horror)

A replayable 1–4 player cooperative procedural psychological horror experience on Roblox.

Players begin stranded on the edge of the dense, fog-drenched Blackpine Forest. After investigating a dilapidated warden's cottage, they uncover a hidden cellar hatch that descends into a subterranean industrial bunker complex—a space impossibly larger than the cottage above (a "bigger on the inside" anomaly). Beyond the bunker's survey galleries, players operate an industrial lift to enter a modular, procedurally shifting maze of dark, rusty wood cabins and concrete corridors. To escape, players must survive hunting entities, manage a failing flashlight battery, decipher environmental clues, collect required keys and fuses, and coordinate a dual-lever extraction gate.

---

## Quickstart Guide

### Prerequisites & Toolchain Setup
The project uses **[Rokit](https://github.com/rojo-rbx/rokit)** to manage Roblox development toolchains consistently across platforms (Windows & macOS).

Tools configured in [rokit.toml](file:///c:/Users/sanch/Projects/horror-game/rokit.toml):
- **Rojo** (`7.7.1`) – Filesystem-to-Roblox synchronizer
- **Wally** (`0.3.2`) – Package manager
- **StyLua** (`2.6.0`) – Luau code formatter
- **Selene** (`0.32.0`) – Luau linter
- **Luau-LSP** (`1.70.1`) – Language server protocol

### Installation & Launch

#### 1. Install Toolchain
Run in your terminal (macOS / Linux / Windows PowerShell):
```bash
# If Rokit is not yet installed:
# cargo install rokit --locked
# or download binary from https://github.com/rojo-rbx/rokit/releases

# Inside the project root:
rokit install
```

#### 2. Start the Rojo Sync Server
```bash
# Serve the main place project
rojo serve default.project.json
```
The server will bind to `http://localhost:34872`.

#### 3. Connect Roblox Studio
1. Open the project place in **Roblox Studio**.
2. Open the **Rojo Plugin** tab and click **Connect**.
3. Confirm that scripts sync live from `src/` to their respective DataModel containers (`ServerScriptService`, `StarterPlayerScripts`, `ReplicatedStorage`).

*(Optional: To test the forest cabin opening in isolation, run `rojo build forest-preview.project.json -o Blackpine-Survey-Cottage.rbxl` and open the generated file in Studio.)*

---

## Critical Team Create & Sync Rules

To prevent data loss, conflicts, and sync desynchronization:
1. **Disable Collaborative Editing / Script Drafts**: In Roblox Studio Game Settings, Collaborative Editing / Drafts mode must be **OFF**. Rojo expects script changes to apply directly without draft conflicts.
2. **Partially Managed Tree (`$ignoreUnknownInstances: true`)**:
   [default.project.json](file:///c:/Users/sanch/Projects/horror-game/default.project.json) specifies `"$ignoreUnknownInstances": true` on `Workspace`, `ReplicatedStorage`, `Lighting`, and `StarterGui`. This ensures Rojo only manages files present in `src/` and **never deletes** 3D maps, room templates, models, lighting configurations, or raw UI created in Studio Team Create.
3. **No In-Studio Script Edits**: Never edit `.luau` scripts inside Roblox Studio via MCP (`multi_edit`) or the Studio script editor. All script modifications must happen on disk inside `src/` to guarantee clean Git version tracking and automated linting.

---

## Current Baseline & Team Split

- **Current Baseline:** `main` at `fa845b6` (Roblox Studio Team Create **version `46`**). Create short-lived feature branches from `origin/main`.
- **Opening flow.** Follow the amber survey stakes past the roadside deer omen (`DeerIntroRig`) to the Warden's Cottage. Find the brass kitchen key, unlock the hinged cellar hatch, and follow the pipe rail down to the concourse. At the survey lift, the first pull restores power for the whole squad (`SurveyRelay`); the next interaction boards each player individually.
- **Dungeon Loop & Extraction.** Survive `10` procedurally snapped rooms (including a mid-run `ToadMakerSafeRoom` breather), gather clues/objectives + Run Scrap, and coordinate `ExitLever_A` / `ExitLever_B` (with 1 survivor fallback) to open the steel extraction bulkhead.
- **Team Create.** Use the shared Project Horror place for authored room templates, NPC rigs, and `Realistic` lighting. Git tracks the opening model (`Opening.rbxmx`) and all Luau scripts under `src/`.
- **Team Responsibilities**:
  - **Technical Lead**: Owns `src/` (Luau codebase) via Rojo + Git, enforcing `--!strict`, modular services/controllers, and CI checks (`stylua`, `selene`).
  - **Creative Lead**: Owns 3D geometry, environment art, [src/server/ForestCabin/Opening.rbxmx](file:///c:/Users/sanch/Projects/horror-game/src/server/ForestCabin/Opening.rbxmx), `ReplicatedStorage/RoomTemplates`, `ReplicatedStorage/NPCModels`, `Lighting`, audio instances, and raw UI layout in Team Create.

### Modular Grid Bunker (`src/server/BunkerGrid/`, Checkpoints 1–3)
- **Active Roster (`15` modular prefabs):** `5` hallways (`HallDeadEnd`, `HallCorner`, `HallStraight`, `HallT`, `HallCross`) + `10` single-door rooms (`4` special: `Room_Mirror`, `Room_ModelSlot`, `Room_Safe`, `Room_Exit`; `6` standard: `Room_Storage`, `Room_Fuse`, `Room_Flooded`, `Room_Study`, `Room_Generator`, `Room_Archive`). `Room_Abandoned` was consolidated into `Room_Mirror`.
- **Single Source of Truth (`src/server/BunkerGrid/Config.luau`):** Locks `CELL = 32`, `WALL_H = 12`, `WALL_T = 1`, `DOOR_W = 8`, `DOOR_H = 9`, `HALL_W = 16`, `ROOM_COUNT = 10`, Stalker Pathfinding (`AGENT_RADIUS = 2.0`, `AGENT_HEIGHT = 7.0`, `AGENT_CAN_JUMP = false`, `REPATH_INTERVAL = 0.35`), and chase-loop constraints (`1–2` loops, `3×3` minimum).
- **Checkpoint 3 (`HallwaySpineV1.luau` & `RoomAssignment.luau`):** Deterministic 12-cell hallway spine with a `3×3` chase loop, BFS structural validation, and `Random.new(seed)` room assignment (`rooms[1]` standard, `rooms[10]` `Room_Exit`). *(Not yet wired into live `RoomGenerator`; Checkpoints 4–7 remain upcoming.)*

---

## Documentation Index

Detailed specifications, design documentation, and architectural guidelines are maintained in the repository:

- [GAME_SPEC.md](file:///c:/Users/sanch/Projects/horror-game/GAME_SPEC.md) – **Canonical Single Source of Truth** (core loop, multiplayer/revive rules, Toad-Maker safe room, NPC contracts, and v1 launch scope).
- [AGENTS.md](file:///c:/Users/sanch/Projects/horror-game/AGENTS.md) – Strict tool boundaries, role splits, and development constraints.
- [docs/DECISIONS_AND_CHANGELOG.md](file:///c:/Users/sanch/Projects/horror-game/docs/DECISIONS_AND_CHANGELOG.md) – **Architectural Decision Records & Engineering Log** (what changed and *why* each decision was made).
- [docs/MILESTONES_AND_CHECKINS.md](file:///c:/Users/sanch/Projects/horror-game/docs/MILESTONES_AND_CHECKINS.md) – Milestone gates, check-in protocol, and current progress tracker.
- [docs/GAME_DESIGN_AND_RESEARCH.md](file:///c:/Users/sanch/Projects/horror-game/docs/GAME_DESIGN_AND_RESEARCH.md) – Core gameplay loop, story beats, horror research, co-op scaling, monetization/retention, and proposed roadmap.
- [docs/ARCHITECTURE_AND_WORKFLOW.md](file:///c:/Users/sanch/Projects/horror-game/docs/ARCHITECTURE_AND_WORKFLOW.md) – Client/Server/Shared module map, Rojo sync rules, `StreamingEnabled` safety, input contracts, and Git branch workflows.
- [docs/STUDIO_ASSET_SPEC.md](file:///c:/Users/sanch/Projects/horror-game/docs/STUDIO_ASSET_SPEC.md) – Studio instance names, anchor contracts, streaming configurations, audio hooks, and UI button hierarchy.
- [docs/blackpine-survey-works.md](file:///c:/Users/sanch/Projects/horror-game/docs/blackpine-survey-works.md) – Bunker survey gallery environment art pass & `SurveyMount` handoff.
- [docs/milestone-3-release.md](file:///c:/Users/sanch/Projects/horror-game/docs/milestone-3-release.md) – Milestone 3 test record & extraction notes.
- [docs/forest-cabin-handoff.md](file:///c:/Users/sanch/Projects/horror-game/docs/forest-cabin-handoff.md) – Historical environment handoff document for the Blackpine Forest and cabin opening.
