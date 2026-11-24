# Milestones & Progress Check-In Plan

This document defines the milestone gates, deliverable owners, and recurring progress check-in cadence for **Tardes** before starting graphic asset upgrades and feature implementation.

---

## Check-In Cadence & 4-Point Gate

A formal **Progress Check-In** runs at each sub-milestone (`Gate 0`, `4A`, `4B`, `5A`, `5B`, `6A`, `6B`) and before any merge into `main`. Every check-in must pass four checks:

1. **Git & Code Hygiene:** Clean branch state, `stylua --check src` and `selene src` pass with `0` errors/warnings, and Team Create place saved to cloud.
2. **Runtime Console:** `0` script errors in Roblox Studio Output during Play mode.
3. **Visual Crispness Review:** Viewport captures (`screen_capture`) in Play mode verifying lighting contrast, flashlight beam readability, HUD layout, and asset silhouettes.
4. **Playability Verification:** Live route test confirming the milestone's end-to-end player flow works without soft-locks.

---

## Gate 0: Pre-Implementation Baseline Sync

**Goal:** Unify `main` (`f5a8c1e`), `codex/flashlight-beam` (`47a8fae`), and the `codex/blackpine-opening` WIP edits into one clean starting point before upgrading graphics and systems.

| Owner | Deliverable | Exit Criteria |
| --- | --- | --- |
| **Technical Lead** | Commit/finalize `codex/blackpine-opening` and merge both `codex/flashlight-beam` and `codex/blackpine-opening` into `main` | Single unified `main` branch; `stylua` & `selene` pass |
| **Creative Lead** | Resolve Team Create cloud publish (`PublishService`) and place `Workspace.ExitLever_A`, `Workspace.ExitLever_B`, and `Workspace.ExitDoor` | `ExitGate` no longer logs runtime placeholder warnings |

---

## Milestone 4: Visual & Audio Crispness (Art, Lighting & Atmosphere)

**Goal:** Replace all remaining graybox primitives and silent audio hooks with authored, horror-grade visuals and spatial sound.

### Check-In 4A — Room Templates & NPC Rigs
- **Creative Lead:**
  - Upgrade `ReplicatedStorage/RoomTemplates` (`BunkerAirlock`, `RustyWoodHallway`, `LShapedCabinStudy`) from plain box parts to detailed, `Atomic`-streaming 3D architecture with `Entrance`/`Exit` anchors and optional `SurveyMount` attachments.
  - Replace single-part graybox models in `ReplicatedStorage/NPCModels` (`ToadPassiveNPC`, `RoomInstanceNPC`, `MainNPC_Stalker`) with rigged, animated models with distinct silhouettes.
- **Technical Lead:**
  - Wire animation controllers / state transitions in `NPCManager.luau` to the new rigs and verify `SurveyGallery.luau` mounts cleanly against authored walls.

### Check-In 4B — Lighting, Audio & Lore UI
- **Creative Lead:**
  - Populate `Workspace/Sounds` (`LeafRustle`, `DeerScreech`, `ToadCroak`, `StalkerTelegraph`) plus ambient bunker/forest audio.
  - Review lighting balance across Blackpine Forest, Warden's Cottage, and generated bunker rooms in Play mode.
- **Technical Lead:**
  - Tune `FlashlightOptics.luau` + `ForestWeather.client.luau` + Studio `Lighting` together so shadows, fog, and beam hotspot read crisply without crushing dark areas.
  - Upgrade `ObjectiveHUD.luau` clue display into a tactile field-notebook/scrap reader.
- **Milestone 4 Exit Gate:** Full solo Playtest capture review with authored rooms, animated NPCs, working spatial audio, and `0` console errors.

---

## Milestone 5: Replayability, Co-op Depth & Monetization

**Goal:** Expand run-to-run variety, social co-op moments, and non-pay-to-win monetization hooks.

### Check-In 5A — Room Variety & Co-op Engagement
- Add 2–3 new room templates to `ReplicatedStorage/RoomTemplates` (e.g., flooded sub-level, generator room, catwalk).
- Add distinct entity counter-play behaviors in `NPCManager.luau` and a **Spectator Camera** for eliminated teammates.

### Check-In 5B — Lobby & Ethical Monetization
- Build pre-run lobby/queue (1–4 players) with difficulty or seeded-run options.
- Implement cosmetic shop (flashlight skins/beam tints, explorer outfits) and altruistic Developer Products (capped self-revive, gift revive / gift battery to teammate).
- **Milestone 5 Exit Gate:** 2–4 player co-op playtest covering lobby $\to$ forest $\to$ bunker $\to$ extraction/wipe, spectator mode, and purchase/gift flows.

---

## Milestone 6: Mobile Optimization, Telemetry & Release Candidate

**Goal:** Ensure smooth mobile performance, instrument player drop-off funnels, and lock a release candidate.

### Check-In 6A — Mobile & Performance Profiling
- Profile Blackpine Forest (290 pines), `SurveyGallery`, and `StreamingEnabled` (`Atomic`) on low-graphics / mobile emulation and real phone hardware.
- Verify `StarterGui/GameHUD/FlashlightButton` and `ProximityPrompt` touch ergonomics.

### Check-In 6B — Funnel Telemetry & Launch Readiness
- Wire the 9 progression funnel events (`funnel_forest_spawn` through `funnel_gate_escaped` / `funnel_squad_wipe`).
- Complete full regression pass, tag release candidate, and verify rollback steps.
- **Milestone 6 Exit Gate:** Owner sign-off on performance, funnel telemetry, and public release readiness.
