# Milestones & Progress Check-In Plan

This document tracks milestone gates, completed check-ins, and remaining work for **Tardes**. For the architectural rationale behind completed steps, see [docs/DECISIONS_AND_CHANGELOG.md](DECISIONS_AND_CHANGELOG.md).

---

## Check-In Cadence & 4-Point Gate

Every milestone gate (`Gate 0`, `4A`, `4B`, `5A`, `5B`, `6A`, `6B`) verifies:
1. **Git & Code Hygiene:** Clean branch state, `stylua --check src` and `selene src` pass (`0` errors/warnings), and Team Create saved to cloud.
2. **Runtime Console:** `0` script errors in Studio Output during Play mode.
3. **Visual Crispness Review:** Play-mode review verifying lighting contrast, flashlight aim/readability, HUD layout, and silhouettes.
4. **Playability Verification:** End-to-end route check confirming no soft-locks or progression blockers.

---

## Phase 0: Development Readiness & Recovery — OPEN
- **Status (`2026-11-26`):** Source baseline audited at `main` (`3878e6d3`); shared-place Rojo recovery and live Studio verification remain open.
- **Required Gates (see [PHASE_0_READINESS.md](PHASE_0_READINESS.md) & [TEAM_WORKFLOW.md](TEAM_WORKFLOW.md)):**
  - [ ] Isolated Rojo recovery validation on a local `.rbxl` copy (`0` duplicate Rojo-managed paths, creative assets preserved, smoke test output recorded).
  - [ ] Jointly authorized shared-place recovery on `Project Horror` (`122077989749573`) with local backup and rollback plan.
  - [ ] Solo and co-op runtime verification + isolated Checkpoint 5 `StalkerNavigator` run, reviewed by both leads before Phase 0 exit.

---

## Gate 0: Pre-Implementation Baseline Sync — COMPLETED (`06a8608`, `80cde45`)
- Merged `codex/flashlight-beam` (`47a8fae`) and `codex/blackpine-opening` (`e530a0f`) into `main`, deleted obsolete branches, and synced canonical [GAME_SPEC.md](../GAME_SPEC.md).
- Confirmed `ExitGate` builds dynamic bulkhead/levers at `lastRoom.Exit` when static Studio exit instances are absent.

---

## Milestone 4: Visual & Audio Crispness — COMPLETED (`8186199`, `6fd5f9c`, `b505b1e`, `7b2e060`, Team Create `v46`)
- **Check-In 4A (Templates & Rigs):**
  - Dressed `BunkerAirlock`, `RustyWoodHallway`, and `LShapedCabinStudy` with non-shadow static lighting and architectural props.
  - Upgraded `ToadPassiveNPC`, `RoomInstanceNPC`, and `MainNPC_Stalker` (`Humanoid` + welded `Massless` limbs + `SetNetworkOwner(nil)`).
  - Positioned `DeerIntroRig` beside the Blackpine trail (`4.2, 82.0, -221.0`) with welded `PrimaryPart` and `BunkerEntrance` at the cottage threshold.
- **Check-In 4B (Lighting, Audio, Flashlight & Clue UI):**
  - Populated `Workspace/Sounds` (`LeafRustle`, `DeerScreech`, `ToadCroak`, `StalkerTelegraph`) with verified Creator Store audio IDs and converted `ToadCroak` to 3D spatial rolloff per toad.
  - Reworked `FlashlightController` + `FlashlightOptics` (exponentially damped camera/head-forward emitter, wall-clip raycast, `UserInputService.InputBegan`, dual-cone + mobile `FillPointLight`, 1st-person volumetric `Beam`, `Realistic` lighting single-shadow rule).
  - Upgraded `ObjectiveHUD` (`CluePanel` field-notebook styling, `BatteryFrame`, `HealthFrame`, red `DamageFlash`, non-overlapping `FlashLabel`).

---

## Milestone 5: Replayability, Co-op Depth & Monetization — IN PROGRESS (`a25ec17`, `23b8a80`, `fa845b6`)
- **Check-In 5A (Room Variety, Safe Room, Interactions & Co-op) — Implemented in Code / Needs 2–4 Player Live Test:**
  - Added `FloodedSublevel` and `GeneratorSwitchRoom` templates in Studio (`10/10` room placement verified with consecutive turn-direction tracking in `RoomGenerator`).
  - Added mid-run `ToadMakerSafeRoom` (`SafeRoomService`, `RunScrap`, Battery/Medkit/Revive Token vendor, `InSafeRoom` Stalker immunity).
  - Centralized `ProximityPromptService` validation via `InteractionRouter`, raycasted `ClueSystem` surface placement, `BlastLeaf` smooth tween + `"Locked — Missing Keys/Fuses"` feedback in `ExitGate`.
  - Added `SpectatorController` + `MatchScaleManager.revivePlayer` (`ClaimReviveToken` + `GiftFieldRevive`).
- **Check-In 5B (Lobby & Monetization) — Code Complete on `feature/lobby` / Needs Multi-Place Live Test:**
  - [x] Build pre-run Dark Forest lobby (`lobby.project.json`, `LobbyScene`, animated Frog Merchant stall, campfire clearing, 3 play circles w/ Friends-Only support & reserved server teleport) and responsive `ViewportFrame` Shop UI (`ShopCatalog` character/weapon skins + DataStore persistence in `PlayerData_v1`).
  - [ ] Publish dedicated Lobby Place inside the `Project Horror` universe (`122077989749573` destination) and execute [docs/LOBBY_TEST_CHECKLIST.md](LOBBY_TEST_CHECKLIST.md).
  - [ ] Populate Creator Dashboard numeric `productId` values in [src/shared/ShopCatalog.luau](../src/shared/ShopCatalog.luau) and add Private Server / Chaos pass support if scoped for v1.
  - [ ] **Open Polish Item:** Raise the concrete concourse ceiling lip above the cellar stairs inside [src/server/ForestCabin/Opening.rbxmx](../src/server/ForestCabin/Opening.rbxmx) to eliminate the brief 3rd-person camera floor clip seen at `00:44` of `playtest_fixed.mp4`.
  - [ ] **Exit Gate:** Complete a 2–4 player live co-op test verifying simultaneous `ExitLever_A`/`B`, disconnect hold release, Stalker pathfinding across L-rooms, Deer Omen trigger on the trail, and mid-run revive flow.

---

## Milestone 6: Mobile Optimization, Telemetry & Release Candidate — FOUNDATIONS LANDED (`a25ec17`)
- **Check-In 6B Telemetry Ready:** `FunnelAnalytics.luau` passively logs all 9 `CoreExpedition` funnel stages (`forest_spawn` through `gate_escaped`/`squad_wipe`).
- **Remaining:**
  - [ ] **Check-In 6A:** Profile Blackpine Forest (290 pines), `SurveyGallery`, and `StreamingEnabled` (`Atomic`) on real low-end mobile devices and verify touch prompt/button ergonomics.
  - [ ] **Check-In 6B:** Verify live Creator Dashboard funnel data, complete final regression pass, and tag v1 release candidate.

---

## BunkerGrid Redesign — Checkpoints 1–4 Verified / Checkpoint 5 Merged on `main` (Runtime Pending)
- [x] **Checkpoints 1–4:** Preserved `Config.luau`, `DoorResolver.luau`, `PrefabLibrary.luau`, `PrefabValidator.luau`, `HallwaySpineV1.luau`, `RoomAssignment.luau`, `ReachabilityValidator.luau`, and 15 active `.rbxm` prefabs alongside full Dark Forest Lobby and original gameplay (`RoomGenerator.generate(10)`).
- [ ] **Checkpoint 5 (`StalkerNavigator.luau` & `Checkpoint5Test.luau`):** Source merged on `main` (`3878e6d3`, PR `#6`), inactive in live gameplay (`NPCManager.luau` untouched). Physical runtime verification remains pending an isolated local Studio run containing `ReplicatedStorage/NPCModels/MainNPC_Stalker` (see [PHASE_0_READINESS.md](PHASE_0_READINESS.md)).
- [ ] **Checkpoints 6–7 (Upcoming):** Side-monster scares and live `RoomGenerator` compatibility adapter (outside the Phase 0 readiness gate unless separately approved).
