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

- **Start from `origin/main`.** It contains the playable co-op run, the Blackpine survey galleries, and the cottage reveal. Create short-lived feature branches from this shared baseline.
- **Opening flow.** Find the brass kitchen key, unlock the hinged cellar hatch, and follow the pipe rail down to the concourse. At the lift, the first pull restores power for the whole squad and starts the load recorder. The next interaction boards each player individually.
- **Team Create.** Use the shared Project Horror place for the authored room templates, NPC rigs, and lighting. Git tracks the opening model and the scripts that dress it at runtime.
- **Team Responsibilities**:
  - **Technical Lead**: Owns `src/` (Luau codebase) via Rojo + Git, enforcing `--!strict`, modular services/controllers, and CI checks (`stylua`, `selene`).
  - **Creative Lead**: Owns 3D geometry, environment art, [src/server/ForestCabin/Opening.rbxmx](file:///c:/Users/sanch/Projects/horror-game/src/server/ForestCabin/Opening.rbxmx), `ReplicatedStorage/RoomTemplates`, `ReplicatedStorage/NPCModels`, `Lighting`, audio instances, and raw UI layout in Team Create.

---

## Documentation Index

Detailed specifications, design documentation, and architectural guidelines are maintained in the repository:

- [AGENTS.md](file:///c:/Users/sanch/Projects/horror-game/AGENTS.md) – Strict tool boundaries, role splits, and development constraints.
- [docs/GAME_DESIGN_AND_RESEARCH.md](file:///c:/Users/sanch/Projects/horror-game/docs/GAME_DESIGN_AND_RESEARCH.md) – Core gameplay loop, story beats, horror research, co-op scaling, monetization/retention, and proposed roadmap.
- [docs/ARCHITECTURE_AND_WORKFLOW.md](file:///c:/Users/sanch/Projects/horror-game/docs/ARCHITECTURE_AND_WORKFLOW.md) – Client/Server/Shared module map, Rojo sync rules, `StreamingEnabled` safety, input contracts, and Git branch workflows.
- [docs/STUDIO_ASSET_SPEC.md](file:///c:/Users/sanch/Projects/horror-game/docs/STUDIO_ASSET_SPEC.md) – Studio instance names, anchor contracts, streaming configurations, audio hooks, and UI button hierarchy.
- [docs/forest-cabin-handoff.md](file:///c:/Users/sanch/Projects/horror-game/docs/forest-cabin-handoff.md) – Historical environment handoff document for the Blackpine Forest and cabin opening.
