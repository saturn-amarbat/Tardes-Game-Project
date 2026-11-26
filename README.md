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
- [docs/LOBBY_TEST_CHECKLIST.md](file:///c:/Users/sanch/Projects/horror-game/docs/LOBBY_TEST_CHECKLIST.md) – Pre-game Dark Forest Lobby QA checklist.

---

## Dark Forest Lobby (`feature/lobby`)

The pre-game hub uses a standalone Rojo project (`lobby.project.json`) with a Dark Forest night aesthetic, a giant animated Frog Merchant stall (Zone A), a central campfire clearing with sit-able logs, and glowing matchmaking play circles (Zone B). Guard checks in `src/server/Lobby/init.server.luau` and `src/client/Lobby/init.client.luau` ensure lobby scripts do not interfere when `default.project.json` runs inside the main road/bunker place (`122077989749573`).

### Running the Lobby Place
```bash
rojo serve lobby.project.json
# Or build a standalone .rbxl file:
rojo build lobby.project.json -o DarkForestLobby.rbxl
```
> Enable **Game Settings -> Security -> Enable Studio Access to API Services** in Roblox Studio when testing `DataStoreService` persistence.

### How to Add Shop Items
All Character Skins and Weapon Skins are data-driven inside `src/shared/ShopCatalog.luau`. No UI code edits are required.
1. Open `src/shared/ShopCatalog.luau`.
2. Append a new `SkinEntry` table inside `characterSkins` or `weaponSkins`:
   ```luau
   {
       id = "char_ranger_alt", -- unique key stored in DataStore
       category = "Character", -- "Character" or "Weapon"
       name = "Moss Cloak",
       rarity = "Rare", -- Common | Uncommon | Rare | Epic | Legendary
       price = 450, -- Coins (0 = free)
       description = "Damp wool woven with forest moss.",
       preview = {
           primaryColor = Color3.fromRGB(48, 66, 44),
           secondaryColor = Color3.fromRGB(32, 38, 32),
           accentColor = Color3.fromRGB(168, 210, 134),
           style = "cultist", -- ranger | miner | warden | cultist | spectre | antler | torch | blade | cleaver | shard
       },
   }
   ```
3. The server (`ShopService.luau`) and client `ViewportFrame` shop UI (`ShopGuiController.luau`) automatically load and validate the new entry.

### How to Change Queue Size & Countdown
All queue settings live at the top of `src/shared/LobbyConfig.luau`:
- `LobbyConfig.QUEUE_SIZE`: Maximum players per play circle (default `4`).
- `LobbyConfig.COUNTDOWN_SECONDS`: Launch countdown seconds once triggered (default `5`).
- `LobbyConfig.AUTO_START_TIMEOUT`: Seconds before 1–3 waiting players launch automatically (`45`; set `0` for strict full-circle `4/4` only).
- `LobbyConfig.NUM_PADS` / `LobbyConfig.PAD_POSITIONS`: Number and world positions of play circles.
- `LobbyConfig.FRIENDS_PAD_INDEX`: Which circle requires Roblox friendship with the host (`3`).

### How to Set the Destination Place ID
Open `src/shared/LobbyConfig.luau` and update line 14:
```luau
LobbyConfig.GAME_PLACE_ID = 122077989749573 -- Destination Place ID for Project Horror
```
Make sure both the Lobby place and destination place belong to the same Roblox Universe (Experience) so `TeleportService:ReserveServer` and `TeleportAsync` succeed in live servers.
