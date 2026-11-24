# Technical Architecture & Workflow Specification

## 1. Repository Structure & Module Architecture

The project follows a modular Luau architecture managed via Rojo and Git. Code is separated into server-authoritative services, client controllers/renderers, and replicated shared state.

```
c:/Users/sanch/Projects/horror-game/
├── default.project.json             # Rojo DataModel configuration
├── rokit.toml                       # Rokit toolchain manifest (Rojo, Wally, StyLua, Selene)
├── forest-preview.project.json      # Isolated standalone preview project for Forest Cabin
├── AGENTS.md                        # Strict agent boundaries & ownership rules
├── README.md                        # Quickstart, project overview & documentation index
├── docs/
│   ├── GAME_DESIGN_AND_RESEARCH.md  # Core loop, story beats, scaling & monetization
│   ├── ARCHITECTURE_AND_WORKFLOW.md # Module map, Rojo rules, streaming & Git flow
│   ├── STUDIO_ASSET_SPEC.md         # Creative Lead instance contracts & anchors
│   └── forest-cabin-handoff.md      # Historical opening handoff notes
└── src/
    ├── client/                      # StarterPlayerScripts/Client
    │   ├── init.client.luau         # Client bootstrap & controller initialization
    │   ├── FlashlightController.luau# Slender Man flashlight, battery, flicker, touch input
    │   ├── FlashlightReplicaClient.luau # Teammate flashlight replication renderer
    │   ├── ForestWeather.client.luau# Regional atmospheric fog & exposure transitions
    │   ├── ObjectiveHUD.luau        # Objective counter UI, clue reader, exit alert
    │   └── PrologueController.luau  # Dialogue display & skip-prologue voting UI
    ├── server/                      # ServerScriptService/Server
    │   ├── init.server.luau         # Server bootstrap, room generation & system init
    │   ├── ClueSystem.luau          # Clue distribution, ProximityPrompts & replication
    │   ├── FlashlightReplicator.luau# Server-side flashlight state broadcasting
    │   ├── MatchScaleManager.luau   # 1–4 player co-op objective scaling & lever logic
    │   ├── NPCManager.luau          # Toad, jumpscare & Stalker NPC AI state machines
    │   ├── PrologueManager.luau     # Roadside deer omen sequence & bunker light
    │   ├── RoomGenerator.luau       # Procedural room snapping, anchors & atomic streaming
    │   ├── TeleportManager.luau     # Streaming-safe player & squad teleports
    │   └── ForestCabin/             # Authored opening integration
    │       ├── init.server.luau     # Forest spawn, cellar key/hatch & lift transition
    │       └── Opening.rbxmx        # 3D forest, cottage, cellar, and concourse model
    └── shared/                      # ReplicatedStorage/Shared
        ├── .gitkeep
        └── ClueData.luau            # Central clue definitions & lore registry
```

---

## 2. Server-Side Systems (`src/server/`)

### `init.server.luau`
- **Role**: Server master entry point.
- **Workflow**: Generates 10 procedural rooms via `RoomGenerator.generate(10)`, then initializes `FlashlightReplicator`, `PrologueManager`, `NPCManager`, `MatchScaleManager`, and `ClueSystem`.

### `RoomGenerator.luau`
- **Role**: Procedural room generation using strict front-face anchor snapping.
- **Snapping Algorithm**:
  - Each room model in `ReplicatedStorage/RoomTemplates` has two transparent `BasePart` anchors: `Entrance` and `Exit`.
  - The previous room's `Exit.CFrame` faces outward into the corridor.
  - The new room's `Entrance` is aligned back-to-back by rotating 180° around the Y-axis:
    $$\text{targetEntranceCF} = \text{prevExitCF} \times \text{CFrame.Angles}(0, \pi, 0)$$
  - Pivot calculation: $\text{newPivot} = \text{targetEntranceCF} \times \text{entranceLocal}^{-1}$.
- **Streaming Setting**: Sets `model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic` on every generated room instance.
- **Dungeon Root**: Clones rooms into `Workspace.GeneratedDungeon`.

### `TeleportManager.luau`
- **Role**: Server-authoritative teleportation with `StreamingEnabled` safety guarantees.
- **Safety Sequence**:
  1. Verifies player character and `HumanoidRootPart` exist.
  2. Calls `player:RequestStreamAroundAsync(targetPosition)` inside a `pcall` to ensure destination geometry is fully loaded on the client before positioning.
  3. Re-validates that the character survived the async yield and that an optional floor validation check passes.
  4. Teleports via `character:PivotTo(targetCF)`.
- **Squad Staggering**: `TeleportManager.teleportSquad(players, targetCF)` applies a lateral spread offset ($2.5\text{ studs} \times i$) along `targetCF.RightVector` so co-op players do not spawn inside one another.

### `ForestCabin/init.server.luau`
- **Role**: Coordinates the authored opening level (`Workspace.ForestCabinOpening`).
- **Features**:
  - Overrides player respawn location to `ForestStart`.
  - Manages the shared `CellarKey` and `CellarHatch` interaction state.
  - Handles `SurveyLift` interaction: validates proximity (within 12 studs), requests streaming around `Room_01` entrance, performs a downward raycast floor check, sets `player:SetAttribute("DungeonEntered", true)`, and teleports the player safely.

### `MatchScaleManager.luau`
- **Role**: Co-op party scaling and objective management.
- **Objective Scaling**:
  - Solo: 1 Key, 1 Fuse.
  - 2 Players: 2 Keys, 2 Fuses.
  - 3 Players: 3 Keys, 2 Fuses.
  - 4 Players: 4 Keys, 3 Fuses.
- **Remotes**: `ReplicatedStorage.MatchRemotes`: `ObjectiveProgress`, `ClueCollected`, `DoorUnlocked`, `CollectObjective`, `LeverStateChange`.
- **Dual-Lever Escape**: Listens for lever pulls from `Workspace.ExitLever_A` and `Workspace.ExitLever_B`.

### `NPCManager.luau`
- **Role**: Modular server-authoritative NPC manager pulling rigs from `ReplicatedStorage.NPCModels`.
- **Entities**:
  - `ToadPassiveNPC`: Spawns ambient toads in rooms with periodic audio croaks.
  - `RoomInstanceNPC`: Proximity-based jumpscare entity that triggers light flicker and drains battery via `FlickerRequest` remote.
  - `MainNPC_Stalker`: Stalker AI with `Patrol`, `Stalk`, and `Chase` states, featuring an audible telegraph hook (`Workspace.Sounds.StalkerTelegraph`) prior to initiating pursuit.

### `ClueSystem.luau`
- **Role**: Spawns physical clue documents or wall scribbles from `src/shared/ClueData.luau` into procedural rooms using `ProximityPrompt` interaction.

### `FlashlightReplicator.luau`
- **Role**: Receives client toggle requests via `ReplicatedStorage.FlashlightRemotes.ToggleState` and replicates flashlight states to all other clients to render external SpotLights on character torsos.

### `PrologueManager.luau`
- **Role**: Controls the opening road deer sequence (`Workspace.DeerIntroRig`). Listens for flashlight proximity, triggers audio (`LeafRustle`, `DeerScreech`), runs dialogue broadcast, fades out the deer, and activates `Workspace.BunkerLight`.

---

## 3. Client-Side Systems (`src/client/`)

### `init.client.luau`
- **Role**: Client bootstrap. Initializes `FlashlightReplicaClient`, `PrologueController`, `ObjectiveHUD`, and `FlashlightController`. Automatically toggles the flashlight on after a 1-second spawn delay.

### `FlashlightController.luau`
- **Role**: Layered *Slender Man* camera-following flashlight system.
- **Lighting Rig**:
  - Primary `SpotLight`: Narrow high-intensity cone (`Brightness = 2.8`, `Range = 60`, `Angle = 48°`).
  - Ambient `PointLight`: Subtle local sphere (`Brightness = 0.45`, `Range = 14`).
  - Root Part: Transparent part welded to camera, updated smoothly via `RunService.RenderStepped` with rotation tweening.
- **Battery & Pacing**:
  - 100 max battery, drains at 0.5/sec (~200 seconds continuous runtime).
  - Anomaly flicker events temporarily suspend normal drain while destabilizing the light.
- **Input Binding Hierarchy**:
  1. `ContextActionService` action `"ToggleFlashlight"` bound to `Enum.KeyCode.F` (Keyboard) and `Enum.KeyCode.ButtonY` (Gamepad).
  2. Touch / GUI button binding: Binds to `StarterGui.GameHUD.FlashlightButton` if authored; otherwise generates an automatic fallback ScreenGui button for mobile.
  3. `HapticService`: Fires haptic vibration pulses on toggle and anomaly flicker start.

### `ObjectiveHUD.luau`
- **Role**: Clean, minimal horror HUD.
- **Behavior**: Remains disabled until `player:GetAttribute("DungeonEntered") == true` (set upon descending the survey lift).
- **Components**:
  - `CounterFrame`: Displays active key and fuse collection tallies (e.g., `🔑 0/2  🔧 0/2`).
  - `CluePanel`: Modal display showing full lore text when clues are examined.
  - `ExitBanner`: Full-screen notification when the bunker escape bulkhead unlocks.

### `ForestWeather.client.luau`
- **Role**: Local atmospheric and lighting transitions.
- **Behavior**: Monitors local player Y-elevation. While above the cellar threshold in the forest, applies custom heavy volumetric fog (`Atmosphere`) and lowered exposure. When descending into the bunker concourse, restores default interior lighting.

---

## 4. Partially Managed Rojo & Team Create Rules

The repository operates under a **Partially Managed Tree** architecture:

```json
{
  "name": "horror-game",
  "tree": {
    "$className": "DataModel",
    "Workspace": {
      "$className": "Workspace",
      "$ignoreUnknownInstances": true
    },
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "$ignoreUnknownInstances": true,
      "Shared": { "$path": "src/shared" }
    },
    "Lighting": {
      "$className": "Lighting",
      "$ignoreUnknownInstances": true
    },
    "StarterGui": {
      "$className": "StarterGui",
      "$ignoreUnknownInstances": true
    }
  }
}
```

### Core Principles
1. **`$ignoreUnknownInstances: true`**: Rojo will only synchronize files defined in its directory mapping. Instances created directly in Roblox Studio Team Create (terrain, parts, sounds, folders, UI elements) are preserved and never deleted on sync.
2. **Strict Tool Boundaries**:
   - Luau source code lives exclusively on disk in `src/`.
   - Never edit scripts inside Studio via MCP (`multi_edit`).
   - Disabling Studio Collaborative Editing / Drafts ensures instant live syncing without draft conflicts.
3. **Environment Asset Exports**:
   - Large authored environment models like `src/server/ForestCabin/Opening.rbxmx` are exported directly from Studio into the repository to ensure both Git tracking and Rojo synchronization.

---

## 5. StreamingEnabled Safety Guidelines

With `Workspace.StreamingEnabled = true`, instances outside a client's streaming radius are not loaded in memory. This requires strict safety protocols:

1. **`ModelStreamingMode = Atomic`**:
   - Every procedural room model in `ReplicatedStorage.RoomTemplates` must have its streaming mode set to `Atomic`.
   - `RoomGenerator.luau` automatically enforces `room.ModelStreamingMode = Enum.ModelStreamingMode.Atomic` during generation. This guarantees that all room geometry (walls, floors, anchors, props) streams in as a single complete unit, preventing players from falling through partially loaded floors.
2. **Pre-Streaming Teleport Handshake**:
   - Never set `character:PivotTo()` immediately on the server.
   - Always invoke `player:RequestStreamAroundAsync(targetPosition)` to force the client to load target chunks before the character is repositioned.
   - Check character validity and perform a raycast floor validation immediately after the async yield.

---

## 6. Multi-Branch & Worktree Git Workflow

To coordinate engineering and avoid workspace conflicts:

### Branch Naming Conventions
- `feat/<system-name>` – New features or system expansions.
- `docs/<topic>` – Documentation and architecture updates.
- `fix/<issue-description>` – Bug fixes and stability patches.

### Isolated Agent Worktrees
When multiple autonomous agents or developers work on the repository concurrently, use Git worktrees to isolate working directories:
```bash
# Add an isolated worktree for a feature branch
git worktree add ../horror-game-feature feat/my-feature

# Navigate and work without interfering with the primary Rojo server
cd ../horror-game-feature
```

### Quality & Linting Gates
Before any commit or merge into `main`:
```bash
# Verify formatting
stylua --check src

# Run linter
selene src
```

### Merge Protocol
All integration into `main` must use non-fast-forward merge commits (`git merge --no-ff <branch>`) to maintain clear milestone audit trails.
