# Roblox Studio Asset Specification

This document defines the exact instance names, hierarchy paths, property contracts, and lighting rules for assets authored in **Roblox Studio Team Create** (`Project Horror`, historical verified save reference: **version `46`**; current shared Studio state is unverified pending Phase 0 recovery).

> [!IMPORTANT]
> See [TEAM_WORKFLOW.md](TEAM_WORKFLOW.md) and [PHASE_0_READINESS.md](PHASE_0_READINESS.md) for asset ownership and integration workflow. Do not alter rig, anchor, marker, audio, or UI contracts without engineering verification and joint lead coordination, and retain existing gameplay-critical assets until replacements are verified in isolation.

---

## 1. Lighting & Atmosphere (`Lighting`)

- **`LightingStyle`**: `Enum.LightingStyle.Realistic` (Unified Lighting equivalent of `Future`).
- **Base Ambient / Exposure**: `Ambient = Color3.fromRGB(8, 8, 12)`, `OutdoorAmbient = Color3.fromRGB(4, 4, 6)`, `ExposureCompensation = -0.35`, `Atmosphere.Density = 0.3`.
- **Single-Shadow Rule**: Under `Realistic` lighting, **only** the player's `CoreSpotLight` should have `Shadows = true`. Keep `Shadows = false` on all static room ceiling/lamp/lantern lights to prevent shadow-map flicker and light culling.

---

## 2. Procedural Room Templates (`ReplicatedStorage/RoomTemplates`)

[src/server/RoomGenerator.luau](../src/server/RoomGenerator.luau) clones templates from `ReplicatedStorage.RoomTemplates`.

### Current Templates
```
ReplicatedStorage
└── RoomTemplates (Folder)
    ├── BunkerAirlock        (18 × 12 × 24, straight, Atomic)
    ├── RustyWoodHallway     (14 × 12 × 32, straight, Atomic)
    ├── LShapedCabinStudy    (37.5 × 12 × 30, 90° turn, Atomic)
    ├── FloodedSublevel      (18 × 12 × 28, catwalk + standing water, Atomic)
    ├── GeneratorSwitchRoom  (24 × 12 × 26, dual diesel generators, Atomic)
    └── ToadMakerSafeRoom    (Optional authored override; runtime fallback built-in)
```

### Mandatory Contracts
1. **`ModelStreamingMode`**: Must be `Enum.ModelStreamingMode.Atomic`.
2. **Flush Bounds & Pivot**:
   - `PrimaryPart = nil`, `WorldPivot = CFrame.new(0, -0.5, 0)`.
   - Floor, wall, and ceiling solids must end **flush** at `Entrance` and `Exit` (`Z = ±length/2`). Extending parts past `Entrance`/`Exit` causes `GetPartBoundsInBox` overlap halts in `RoomGenerator`.
3. **Anchors (`Entrance` & `Exit`)**:
   - Transparent, non-collidable, anchored `Part`s (`Size = Vector3.new(4, 7, 1)`, centered at `Y = 3.5` when floor top is `0`).
   - Straight rooms use `Entrance.LookVector = (0, 0, +1)` and `Exit.LookVector = (0, 0, -1)` so `targetEntranceCF = prevExitCF * CFrame.Angles(0, math.pi, 0)` chains smoothly.
   - Doorways must stay `>= 6` studs wide and `>= 9` studs tall so players and `MainNPC_Stalker` never snag.
4. **Optional Survey Dressing Attributes**:
   - Add `SurveyMount` `Attachment` (`4` studs above floor, `-Z` toward walkway) to explicitly position `SurveyGallery` cabinets, or set boolean attribute `SurveyDressing = false` to opt a template out.
   - Set `SafeRoom = true` on `ToadMakerSafeRoom` templates.

### 2B. Modular Grid Prefabs (`ServerStorage/BunkerPrefabs` ↔ `assets/BunkerPrefabs/*.rbxm`)
Verified Checkpoints 1–4 grid prefabs live in `ServerStorage/BunkerPrefabs` (synced from `assets/BunkerPrefabs/` via Rojo) and are enforced on load by `src/server/BunkerGrid/PrefabValidator.luau`:
- **Dimensions (`BunkerGrid/Config.luau`):** `CELL = 32`, `WALL_H = 12`, `WALL_T = 1`, `DOOR_W = 8`, `DOOR_H = 9`, `HALL_W = 16`, `ROOM_COUNT = 10`.
- **Mandatory Hierarchy per Model (`ModelStreamingMode = Atomic`):**
  - `PrimaryPart = Floor` (`BasePart`, `Size = (32, 1, 32)` at `(0, -0.5, 0)`, walkable top `Y = 0`).
  - All collidable structural parts strictly inside `[-16, +16]` with zero intra-tile wall overlap.
  - **5 Hallways:** `HallDeadEnd` (`N`, `PlayerSpawn` on start tile only), `HallCorner` (`N+E`), `HallStraight` (`N+S`, `MonsterSpawn`), `HallT` (`N+E+W`, `MonsterSpawn`), `HallCross` (`N+E+S+W`, `MonsterSpawn`); hallways never contain `ScareSpawn`.
  - **10 Active Single-Door Rooms (North `-Z` opening):** `Room_Mirror` (retains abandoned chair/table/mirror atmosphere), `Room_ModelSlot` (`ModelSlot` marker), `Room_Exit` (`Exit` marker `-Z` facing into room + clear lever zone), `Room_Safe` (`SafeRoom = true`, `SurveyDressing = false`, no `ScareSpawn`), `Room_Storage`, `Room_Fuse`, `Room_Flooded`, `Room_Study`, `Room_Generator`, `Room_Archive`. Non-safe rooms each contain interior `ScareSpawn`.

---

## 3. NPC Character Models (`ReplicatedStorage/NPCModels`)

```
ReplicatedStorage
└── NPCModels (Folder)
    ├── ToadPassiveNPC    (Sculpted mossy toad, PrimaryPart = HumanoidRootPart, Anchored = true)
    ├── RoomInstanceNPC   (Gaunt shadow entity, PrimaryPart = HumanoidRootPart, Anchored = true)
    └── MainNPC_Stalker   (Antlered skull stalker rig with Humanoid)
```

### `MainNPC_Stalker` Rig Contract
- Must include a `Humanoid` (`WalkSpeed = 12`, `AutoRotate = true`, `DisplayDistanceType = None`).
- `PrimaryPart = HumanoidRootPart` (`Anchored = false`, `CanCollide = true`, `Transparency = 1`).
- All decorative limbs/head/antler parts must be `Anchored = false`, `CanCollide = false`, `Massless = true`, and welded to `HumanoidRootPart` via `WeldConstraint`s so `NPCManager` can enforce `SetNetworkOwner(nil)` and drive smooth `PathfindingService` + `Humanoid:MoveTo` chases.

---

## 4. Authored Workspace Instances (`Workspace`)

```
Workspace
├── ForestCabinOpening (Model — synced from src/server/ForestCabin/Opening.rbxmx)
│   ├── ForestStart (SpawnLocation at 0, 79.9, -254)
│   ├── Blackpine Wood (Folder with Survey stake parts)
│   ├── Wardens Cottage (CellarKey + CellarHatch with Prompt)
│   └── Survey Vault (SurveyLift with Prompt)
├── DeerIntroRig (Model at 4.2, 82.0, -221.0 beside Blackpine trail)
├── BunkerEntrance (BasePart at -6, 88.5, -172.5; optional child PointLight "BunkerLight")
├── ExitLever_A / ExitLever_B (Optional authored levers; runtime industrial pedestals built if absent)
└── ExitDoor (Optional authored door with BlastLeaf BasePart; runtime steel bulkhead built if absent)
```

### `DeerIntroRig` Rig Contract
- `PrimaryPart = HumanoidRootPart` (`Anchored = true`, `CanCollide = false`, `Transparency = 1`).
- Child parts must be `Anchored = false`, `Massless = true`, welded to `HumanoidRootPart` via `WeldConstraint`s so `PrologueManager`'s `TweenService` bolt moves the entire deer model smoothly.

### `ExitDoor`, `ExitLever_A` & `ExitLever_B` Contracts
- If authored in `Workspace`, `ExitLever_A` and `ExitLever_B` must be anchored `BasePart`s with child `ProximityPrompt` named `Prompt` (`RequiresLineOfSight = true`, `MaxActivationDistance = 7`).
- `ExitDoor` should contain a child `BasePart` named `BlastLeaf` (or be a single `BasePart`), which `ExitGate` tweens upward `7.2` studs on unlock. *(If absent, `ExitGate.luau` constructs a steel bulkhead and twin lever pedestals dynamically at `lastRoom.Exit`.)*

---

## 5. Audio Hook Specifications (`Workspace/Sounds`)

```
Workspace
└── Sounds (Folder)
    ├── LeafRustle        (rbxassetid://9116146300 | Volume = 0.75 | Speed = 1.00)
    ├── DeerScreech       (rbxassetid://320108415  | Volume = 0.90 | Speed = 0.85)
    ├── ToadCroak         (rbxassetid://6276863875 | Volume = 0.50 | Speed = 1.05 — cloned per toad 3D)
    └── StalkerTelegraph  (rbxassetid://9044407584 | Volume = 0.95 | Speed = 0.90)
```

> [!NOTE]
> `NPCManager` clones `ToadCroak` onto each spawned `ToadPassiveNPC.PrimaryPart` with `RollOffMode = InverseTapered` (`4–24` studs) rather than playing it globally from `Workspace.Sounds`.

---

## 6. User Interface Contracts (`StarterGui`)

```
StarterGui
└── GameHUD (ScreenGui)
    └── FlashlightButton (TextButton | Pos: 1, -110, 1, -96 | Size: 0, 100, 0, 52)
```

- `FlashlightController` binds `GameHUD.FlashlightButton.Activated` directly; on touch devices when absent, it creates a `FlashlightHUD_Fallback` (`ResetOnSpawn = true`).
- `ObjectiveHUD`, `PrologueUI`, and `SpectatorHUD` are instantiated cleanly on `PlayerGui` (with prior-instance cleanup on init so overlays never stack).

---

## 7. Pre-Game Dark Forest Lobby Place (`lobby.project.json`)

- **Runtime Container (`Workspace.LobbyMap`, `ModelStreamingMode = Persistent`):** Built procedurally by `src/server/Lobby/LobbyScene.luau` with zero shadow-casting decorative lights (`Shadows = false`), double boundary tree rings (`R = 85..98`), perimeter cliff mounds, and invisible collision walls (`R = 90`).
- **Zone A (`FrogShopkeeper`):** Animated `HeadRig` (`Head`, `EyeOrb_L/R`, `Pupil_L/R`, `Eyelid_L/R`, `Tongue`), `Throat`, `ShopStall/Counter/BrowseShopPrompt` (`ButtonX` / tap), and spatial `FrogCroak` (`rbxassetid://6276863875`).
- **Zone B (`QueuePad_1..3`):** `PadBase`, `PadGlow` (state-tinted: dim idle, amber filling, green full, red launch countdown), and `PadBillboard` (`CountLabel`, `NamesLabel`).
- **Remotes (`ReplicatedStorage/LobbyRemotes`) & DataStore (`PlayerData_v1`):**
  - `RequestPurchase` (`RemoteFunction`), `RequestEquip` (`RemoteEvent`), `ShopDataReply`, `PurchaseResult`, `QueueUpdate`, `QueueNotice`.
  - Key `"Player_<userId>"` stores `{ Coins, OwnedCharacterSkins, OwnedWeaponSkins, EquippedCharacterSkin, EquippedWeaponSkin }`.
