# Roblox Studio Asset Specification

This document defines the exact instance names, hierarchy paths, properties, and contract requirements for assets owned and authored by the **Creative Lead** in Roblox Studio Team Create.

Adherence to these exact paths and property values ensures seamless integration with server and client Luau scripts synchronized via Rojo.

---

## 1. Procedural Room Templates (`ReplicatedStorage/RoomTemplates`)

Procedural generation ([src/server/RoomGenerator.luau](file:///c:/Users/sanch/Projects/horror-game/src/server/RoomGenerator.luau)) selects room models from `ReplicatedStorage.RoomTemplates`.

### Required Directory Structure
```
ReplicatedStorage
└── RoomTemplates (Folder)
    ├── BunkerAirlock (Model)
    ├── RustyWoodHallway (Model)
    └── LShapedCabinStudy (Model)
```

### Model Property Contracts
- **`ModelStreamingMode`**: Must be set to `Enum.ModelStreamingMode.Atomic`. This ensures all room geometry streams to clients simultaneously.
- **Anchoring**: Every `BasePart` within the room must have `Anchored = true`.

### Required Anchor BaseParts
Every room template **must** contain two transparent marker parts named exactly `Entrance` and `Exit`:

| Part Name | Class | Properties | Orientation Contract |
| :--- | :--- | :--- | :--- |
| `Entrance` | `Part` | `Transparency = 1`<br>`CanCollide = false`<br>`Anchored = true`<br>`Size = Vector3.new(4, 8, 1)` | Centered in the doorway. **LookVector must point OUTWARD** (away from the room interior, i.e., $-Z$ in model space). |
| `Exit` | `Part` | `Transparency = 1`<br>`CanCollide = false`<br>`Anchored = true`<br>`Size = Vector3.new(4, 8, 1)` | Centered in the doorway. **LookVector must point OUTWARD** (into the forward corridor, i.e., $+Z$ in straight rooms, rotated $90^\circ$ for L-turns). |

> [!IMPORTANT]
> The procedural snapping algorithm matches `prevExitCF` to `targetEntranceCF` by rotating $180^\circ$ around the Y-axis. If LookVectors do not point outward, rooms will connect backwards or intersect.

---

## 2. NPC Character Models (`ReplicatedStorage/NPCModels`)

The server-side NPC manager ([src/server/NPCManager.luau](file:///c:/Users/sanch/Projects/horror-game/src/server/NPCManager.luau)) loads models by exact name from `ReplicatedStorage.NPCModels`.

### Required Directory Structure
```
ReplicatedStorage
└── NPCModels (Folder)
    ├── ToadPassiveNPC (Model)
    ├── RoomInstanceNPC (Model)
    └── MainNPC_Stalker (Model)
```

### Specification by Entity

#### 1. `ToadPassiveNPC` (Ambient Creature)
- **Role**: Harmless ambient swamp toad found in wet bunker corners.
- **Required Properties**:
  - `PrimaryPart`: Set to `HumanoidRootPart` or main body `Part`.
  - `Anchored`: `true` (stationary or hopped via script).
  - Optional: Child `Sound` named `Croak` attached to `PrimaryPart`.

#### 2. `RoomInstanceNPC` (Jumpscare Entity)
- **Role**: Non-lethal scare entity spawned in specific cabin rooms.
- **Required Properties**:
  - `PrimaryPart`: Set to `HumanoidRootPart` or chest `Part`.
  - `Anchored`: `true`.
  - Child `BasePart` named `Head` or `Torso` for proximity detection.

#### 3. `MainNPC_Stalker` (Apex Monster)
- **Role**: Roaming, stalking, and chasing entity.
- **Required Properties**:
  - `PrimaryPart`: Must be `HumanoidRootPart`.
  - `Humanoid`: Standard `Humanoid` instance with `WalkSpeed = 12` (Patrol) to `24` (Chase).
  - Collision: `CanCollide = true` on `HumanoidRootPart`, `CanTouch = true`.
  - Sound Hook: An `Attachment` inside `HumanoidRootPart` containing a `Sound` named `Footstep`.

---

## 3. Authored Workspace Instances (`Workspace`)

The following instances must exist in `Workspace` for opening progression, prologue events, and exit gates:

### Hierarchy Overview
```
Workspace
├── ForestCabinOpening (Model)
│   ├── ForestStart (SpawnLocation)
│   ├── Wardens Cottage (Model)
│   │   ├── CellarKey (BasePart + ProximityPrompt)
│   │   └── CellarHatch (BasePart + ProximityPrompt)
│   └── Survey Vault (Model)
│       └── SurveyLift (BasePart + ProximityPrompt)
├── DeerIntroRig (Model)
├── BunkerEntrance (BasePart)
├── BunkerLight (PointLight, optional fallback)
├── ExitLever_A (BasePart + ProximityPrompt)     [TO BE PLACED]
├── ExitLever_B (BasePart + ProximityPrompt)     [TO BE PLACED]
└── ExitDoor (Model / Bulkhead)                  [TO BE PLACED]
```

### Details & Contracts

#### `ForestCabinOpening`
- Authored opening level containing the Blackpine Forest, cottage, and bunker concourse. Synchronized with `src/server/ForestCabin/Opening.rbxmx`.
- **`ForestStart`**: `SpawnLocation` where players spawn on game start.
- **`Wardens Cottage/CellarKey`**: A brass key `BasePart` with child `ProximityPrompt` (`ActionText = "Take Cellar Key"`, `HoldDuration = 0.5`).
- **`Wardens Cottage/CellarHatch`**: Trapdoor `BasePart` covering the basement drop with child `ProximityPrompt` (`ActionText = "Unlock Hatch"`, `RequiresLineOfSight = false`).
- **`Survey Vault/SurveyLift`**: Industrial elevator platform `BasePart` with child `ProximityPrompt` (`ActionText = "Descend to Lower Complex"`).

#### `DeerIntroRig` & Guiding Anchor
- **`DeerIntroRig`**: Deer model positioned along the forest road. Must have `PrimaryPart` assigned. Handled by `PrologueManager.luau`.
- **`BunkerEntrance`**: Marker `BasePart` indicating the bunker exterior entrance.
- **`BunkerLight`**: PointLight (`Color = Color3.fromRGB(80, 255, 120)`, `Range = 30`) that activates to guide players forward.

#### Exit Gate Levers (`ExitLever_A` & `ExitLever_B`)
- Two distinct physical switch/lever `BasePart` instances positioned on either side of the bunker extraction door.
- Each must contain a child `ProximityPrompt` named `Prompt`:
  - `ActionText = "Hold Lever"`
  - `HoldDuration = 3.0`
  - `RequiresLineOfSight = true`

---

## 4. Audio Hook Specifications (`Workspace/Sounds`)

Audio effects triggered by game logic are looked up directly in `Workspace.Sounds`.

### Required Directory Structure
```
Workspace
└── Sounds (Folder)
    ├── LeafRustle (Sound)
    ├── DeerScreech (Sound)
    ├── ToadCroak (Sound)
    └── StalkerTelegraph (Sound)
```

### Sound Property Configurations

| Sound Name | Volume | PlaybackSpeed | RollOffMode | MaxDistance | Description |
| :--- | :---: | :---: | :--- | :---: | :--- |
| `LeafRustle` | 0.8 | 1.0 | InverseTapered | 40 | Ambient rustle before the deer omen triggers. |
| `DeerScreech` | 1.0 | 0.9 | Inverse | 80 | Terrifying unnatural screech when the deer snaps its neck. |
| `ToadCroak` | 0.5 | 1.1 | InverseTapered | 30 | Ambient croaking sound emitted near toads. |
| `StalkerTelegraph`| 1.0 | 0.85 | LinearSquare | 120 | Distinct audio sting/warning 1.5 seconds before Stalker initiates chase. |

---

## 5. User Interface Contracts (`StarterGui`)

The client HUD expects specific UI instances in `StarterGui`.

### Hierarchy Overview
```
StarterGui
└── GameHUD (ScreenGui)
    └── FlashlightButton (ImageButton or TextButton)
```

### Mobile Flashlight Button Contract
- **Instance Name**: `FlashlightButton`
- **Class**: `ImageButton` or `TextButton`
- **Parent**: `StarterGui.GameHUD`
- **Properties**:
  - `Size = UDim2.fromOffset(64, 64)`
  - `Position = UDim2.new(1, -90, 1, -170)` (lower right quadrant, accessible by right thumb)
  - `Visible = true`
  - `Active = true`
- **Controller Binding**: [src/client/FlashlightController.luau](file:///c:/Users/sanch/Projects/horror-game/src/client/FlashlightController.luau) checks `playerGui:WaitForChild("GameHUD"):FindFirstChild("FlashlightButton")`. If present, it binds touch activations directly to `toggle()`. If absent, a fallback button is automatically created.
