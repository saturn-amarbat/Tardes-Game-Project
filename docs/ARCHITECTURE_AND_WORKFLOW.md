# Technical Architecture & Workflow Specification

## 1. Repository Structure & Module Architecture

The project follows a modular `--!strict` Luau architecture managed via Rojo and Git. Code is separated into server-authoritative services, client controllers/renderers, and replicated shared registries.

```
c:/Users/sanch/Projects/horror-game/
├── GAME_SPEC.md                        # Canonical Single Source of Truth
├── AGENTS.md                           # Strict agent boundaries & ownership rules
├── README.md                           # Quickstart, baseline status & doc index
├── default.project.json                # Rojo DataModel configuration ($ignoreUnknownInstances)
├── rokit.toml                          # Rokit toolchain manifest (Rojo, Wally, StyLua, Selene)
├── forest-preview.project.json         # Standalone preview project for Forest Cabin
├── docs/
│   ├── DECISIONS_AND_CHANGELOG.md      # ADRs (why decisions were made) & commit log
│   ├── MILESTONES_AND_CHECKINS.md      # Milestone gates & recurring 4-point check-ins
│   ├── GAME_DESIGN_AND_RESEARCH.md     # Core loop, story beats, scaling & monetization
│   ├── ARCHITECTURE_AND_WORKFLOW.md    # Module map, Rojo rules, streaming & Git flow
│   ├── STUDIO_ASSET_SPEC.md            # Creative Lead instance contracts & anchors
│   ├── blackpine-survey-works.md       # Bunker survey galleries & SurveyMount guide
│   ├── milestone-3-release.md          # Milestone 3 extraction & test record
│   └── forest-cabin-handoff.md         # Historical opening handoff notes
└── src/
    ├── client/                         # StarterPlayerScripts/Client
    │   ├── init.client.luau            # Client bootstrap & controller startup
    │   ├── FieldJournal.luau           # [J] Lore archive, flashlight tints & squad support UI
    │   ├── FlashlightController.luau   # Detached damped flashlight, sway, raycast clip, battery
    │   ├── FlashlightOptics.luau       # Dual-cone SpotLights, mobile FillPointLight & dust Beam
    │   ├── FlashlightReplicaClient.luau# Teammate flashlight SpotLight replication renderer
    │   ├── ForestWeather.client.luau   # Overcast dusk fog/sky/exposure above cellar threshold
    │   ├── HorrorFeedback.luau         # Stalker proximity heartbeat vignette, grade & safe badge
    │   ├── ObjectiveHUD.luau           # Keys/fuses/scrap, battery/HP/stamina bars, CluePanel
    │   ├── PrologueController.luau     # Blackpine location card, guidance & omen skip UI
    │   ├── SpectatorController.luau    # Spectator camera cycling & earned Revive Token UI
    │   └── SprintController.luau       # Horror stamina/sprint (LeftShift/L3/touch) + FOV kick
    ├── server/                         # ServerScriptService/Server
    │   ├── init.server.luau            # Server bootstrap & expedition generation loop
    │   ├── InteractionRouter.luau      # Centralized ProximityPromptService validator & hold cleanup
    │   ├── RoomGenerator.luau          # Flush anchor snapping, turn-tracking & SafeRoom insertion
    │   ├── TeleportManager.luau        # Streaming-safe player & squad teleports
    │   ├── MatchScaleManager.luau      # 1–4 player scaling, run lifecycle, mid-run revives
    │   ├── ObjectivePickups.luau       # Server-locked key & ceramic fuse spawns
    │   ├── ObjectiveProps.luau         # Physical brass key & ceramic fuse prop meshes
    │   ├── ExitGate.luau               # Steel bulkhead tween, dual-lever holds & locked feedback
    │   ├── ClueSystem.luau             # Surface-raycasted clue placement & squad lore credit
    │   ├── NPCManager.luau             # Spatial toads, jumpscares & pathfinding Stalker AI
    │   ├── SafeRoomService.luau        # Mid-run Toad-Maker Sanctuary, RunScrap & vendor booth
    │   ├── MaintenanceBay.luau         # Lift-arrival maintenance desk & fuse socket dressing
    │   ├── SurveyGallery.luau          # Procedural bunker survey bays & lintels
    │   ├── SurveyInstruments.luau      # Enamel cases, increment cores, recorders & plumb bobs
    │   ├── PrologueManager.luau        # Roadside DeerIntroRig sequence & BunkerLight trigger
    │   ├── FlashlightReplicator.luau   # Co-op flashlight broadcast & server FlashlightOn state
    │   ├── FunnelAnalytics.luau        # 9-stage AnalyticsService expedition funnel logger
    │   ├── MonetizationService.luau    # Cosmetic tints & idempotent ProcessReceipt revives/gifts
    │   └── ForestCabin/                # Authored opening integration
    │       ├── init.server.luau        # Forest spawn, CellarKey/Hatch & SurveyLift arrival
    │       ├── CottageHardware.luau    # Hinged hatch & key hardware dressing
    │       ├── Fittings.luau           # Shared metal/enamel part & light helpers
    │       ├── SurveyRelay.luau        # Shared lift power & load recorder sequence
    │       ├── TrailMarkers.luau       # Rain-hooded amber stake lenses & cottage signplate
    │       └── Opening.rbxmx           # 3D Blackpine forest, cottage, cellar & concourse
    └── shared/                         # ReplicatedStorage/Shared
        ├── .gitkeep
        ├── ClueData.luau               # Central lore & wall-scribble registry (7 entries)
        └── ShopCatalog.luau            # Flashlight tint presets & Developer Product stubs
```

---

## 2. Server-Side Systems (`src/server/`)

### `init.server.luau`
- **Role**: Server master entry point.
- **Workflow**: Initializes `InteractionRouter`, `FlashlightReplicator`, `PrologueManager`, `FunnelAnalytics`, `SafeRoomService`, and `MonetizationService`, then binds `MatchScaleManager.init(...)` to rebuild `RoomGenerator.generate(10)`, `NPCManager.init(rooms)`, `ClueSystem.init(rooms)`, `MaintenanceBay.install(...)`, `SurveyGallery.install(rooms)`, and `SafeRoomService.install(rooms)` on each expedition.

### `InteractionRouter.luau`
- **Role**: Centralized `ProximityPromptService` dispatcher (`PromptTriggered`, `PromptButtonHoldBegan`, `PromptButtonHoldEnded`, `TriggerEnded`).
- **Why**: Prevents scattered per-part listeners, validates `DungeonEntered == true`, living `HumanoidRootPart`, and `(root.Position - targetPart.Position).Magnitude <= MaxActivationDistance + 4`, and automatically releases lever holds on `PlayerRemoving` or `Humanoid.Died`.

### `RoomGenerator.luau`
- **Role**: Procedural room generation using flush front-face anchor snapping and turn-direction tracking.
- **Snapping & Anti-Looping Rules**:
  - Aligns `targetEntranceCF = currentExitCF * CFrame.Angles(0, math.pi, 0)` and pivots rooms into `Workspace.GeneratedDungeon` with `ModelStreamingMode = Enum.ModelStreamingMode.Atomic`.
  - Computes `getRoomTurnSign(entrance, exit)` and forbids two consecutive left or right turns (`turnSign == lastTurnSign`) alongside `GetPartBoundsInBox` overlap checks.
  - Inserts `ToadMakerSafeRoom` at slot `ceil(numRooms / 2)` (Room `5` of `10`), using a Studio template if present or a built-in `Atomic` fallback.

### `TeleportManager.luau`
- **Role**: Server-authoritative teleportation with `StreamingEnabled` safety (`Player:RequestStreamAroundAsync`, post-yield character revalidation, and `2.5`-stud squad lateral offsets).

### `ForestCabin/` (`init.server.luau`, `CottageHardware`, `SurveyRelay`, `TrailMarkers`, `Fittings`)
- **Role**: Coordinates `Workspace.ForestCabinOpening` (`ForestStart`, rain-hooded amber `TrailMarkers`, shared `CellarKey` / hinged `CellarHatch`, `SurveyRelay` shared lift power sequence, and floor-raycasted `SurveyLift` arrival setting `DungeonEntered = true`).

### `MatchScaleManager.luau` & `ObjectivePickups.luau` & `ExitGate.luau`
- **Role**: Party scaling (1–4 players), server-locked physical pickups (`Collected = true` before crediting totals, skipping `SafeRoom`), and objective-gated extraction (`ExitLever_A`, `ExitLever_B`, `ExitDoor` steel bulkhead with `BlastLeaf` smooth `TweenService` slide-open and `"Locked — Missing Keys/Fuses"` feedback when incomplete).
- **Mid-Run Revives**: `MatchScaleManager.revivePlayer(target)` handles both `ClaimReviveToken` (1 earned token per run) and `MonetizationService` `GiftFieldRevive` receipts, reloading the character and teleporting beside a living survivor.

### `SafeRoomService.luau`
- **Role**: Awards `RunScrap` (`15` start, `+10` per clue, `+15` per objective), tracks `InSafeRoom`, and dresses the mid-run `ToadMakerSafeRoom` booth (raycast-grounded `floorY`) with Emergency Battery (`15`), Field Medkit (`20`), and Revive Token (`35`) vendors.

### `NPCManager.luau`
- **Entities**:
  - `ToadPassiveNPC`: Spread `2–3` across distinct early hazard rooms; clones `ToadCroak` onto `PrimaryPart` with 3D spatial rolloff (`4–24` studs) gated to nearby `DungeonEntered` players.
  - `RoomInstanceNPC`: Non-lethal proximity scare firing `FlickerRequest(1.5, 0.7, 12)` (flicker + `12%` battery drain).
  - `MainNPC_Stalker`: Uses `Humanoid` + welded limbs with `SetNetworkOwner(nil)`, `Workspace:Raycast` line-of-sight + throttled `PathfindingService` (`0.35s`, skipping waypoint `1`), `1.75x` stealth bonus when `FlashlightOn ~= true`, `InSafeRoom` immunity, `38`-stud proximity flicker, and `StalkerTelegraph` cue.

### `ClueSystem.luau`, `FlashlightReplicator.luau`, `PrologueManager.luau`, `FunnelAnalytics.luau`, `MonetizationService.luau`
- `ClueSystem` raycasts room surfaces for clue placement (`PromptMount` `Attachment`s, `RequiresLineOfSight = true`).
- `FlashlightReplicator` tracks `FlashlightOn` and broadcasts `ToggleStateReply`.
- `PrologueManager` runs the `DeerIntroRig` omen sequence (`LeafRustle` $\to$ dialogue $\to$ `DeerScreech` $\to$ bolt tween $\to$ `BunkerLight`).
- `FunnelAnalytics` logs all 9 progression funnel steps via `AnalyticsService:LogFunnelStepEvent`.
- `MonetizationService` manages cosmetic beam tints (`ShopCatalog`) and idempotent `ProcessReceipt` battery/revive gifts.

---

## 3. Client-Side Systems (`src/client/`)

### `FlashlightController.luau` & `FlashlightOptics.luau`
- **Tracking & Anti-Clipping**: Drives a detached `FlashlightEmitter` inside `Workspace.CurrentCamera` with exponential damping (`1 - math.exp(-LagStiffness * dt)`), layered idle/walk sway, and a wall-clip `Workspace:Raycast`. In 3rd-person (`camDist >= 2.4` studs), originates `1.45` studs ahead of `Head` and disables `VolumetricDustBeam` to prevent character starburst shadows and clipping triangles; reserves the subtle dust `Beam` (`0.965 -> 1`) for 1st-person zoom.
- **Optics**: Shadow-casting `CoreSpotLight` (`42°`, `3.5` brightness, `45` range), non-shadow `SpillSpotLight` (`95°`, `0.75` brightness, `26` range), and non-shadow `FillPointLight` (`10` range, `0.25` brightness) for mobile readability.
- **Input & Feedback**: `UserInputService.InputBegan` (`F` / `ButtonY`, Shift-Lock safe), `StarterGui/GameHUD/FlashlightButton` (with touch fallback), `HapticService`, randomized `ClickSound` speed (`0.95–1.05`), and `triggerFlicker(duration, intensity)`.

### `ObjectiveHUD.luau`, `PrologueController.luau`, `SpectatorController.luau`, `ForestWeather.client.luau`
- `ObjectiveHUD`: Top-left `CounterFrame` (`Keys`, `Fuses`, `Scrap`), slim `BatteryFrame` and `HealthFrame`, fullscreen `DamageFlash` vignette on HP drop, centered `CluePanel` field-notebook reader, and top-center `FlashLabel` (`"Locked — Missing Keys/Fuses"` / `"Exit open"`).
- `SpectatorController`: Auto-engages when `SittingOut == true` during an `Active` run (`Q`/`E` or tap to cycle survivors) and shows `"Use Revive Token"` when `ReviveTokens >= 1`.
- `ForestWeather`: Swaps overcast dusk `BlackpineMist` / `BlackpineOvercast` / `BlackpineCloudDeck` / `BlackpineDuskGrade` inside forest bounds (`Y > 78`) and restores place lighting below the cellar.

---

## 4. Partially Managed Rojo & Team Create Rules

[default.project.json](file:///c:/Users/sanch/Projects/horror-game/default.project.json) uses `"$ignoreUnknownInstances": true` on `Workspace`, `ReplicatedStorage`, `Lighting`, and `StarterGui`. Rojo never deletes Team Create assets, Collaborative Editing / Drafts stays **OFF**, and all `.luau` edits happen strictly on disk in `src/`.

---

## 5. Multi-Branch & Quality Workflow

1. Branch from freshly fetched `origin/main` (`feat/<name>`, `fix/<name>`, `docs/<name>`).
2. Format & lint before every commit: `stylua src && stylua --check src && selene src`.
3. Merge via `--no-ff` and keep Team Create saved cleanly (`File > Save to Roblox`) alongside pushed Git history.
