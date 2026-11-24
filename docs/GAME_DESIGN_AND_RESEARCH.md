# Game Design & Research Specification

## 1. Executive Summary & Core Game Concept

**Tardes** is a replayable 1–4 player cooperative psychological horror game built in Roblox. It merges atmospheric slow-burn dread, physical environmental exploration, and escalating tactical tension.

### Key Pillars
1. **The Impossible Architecture ("Bigger on the Inside")**: Inspired by *Doctor Who*'s TARDIS phenomenon and claustrophobic bunker fiction. Players enter a modest, rustic, 32 × 24 stud wooden forest cottage, only to descend into a vast subterranean Cold War-era concrete bunker system and an infinite procedural labyrinth of rusted wooden cabins and industrial halls.
2. **Tactical Illumination (*Slender Man* Psychological Lighting)**: Complete darkness is fatal. The player's flashlight provides a narrow cone of certainty with simulated battery degradation, flickering anomalies, and dynamic shadows, forcing squads to huddle or budget their light.
3. **Environmental Cryptography (*The Forest* / Timmy-Style Clues)**: Narrative exposition is entirely non-intrusive. Scrap notes, maintenance logs, and desperate bloody wall scribbles tell the tragic story of previous survey teams and offer contextual clues for puzzle mechanics.
4. **Cooperative Interdependence**: While playable solo, party play requires communication: callouts for stalker entities, shared key handling, cooperative battery management, and synchronized dual-lever gate escapes.

---

## 2. Replayable 1–4 Player Core Game Loop

```
┌────────────────────────────────────────────────────────┐
│ 1. FOREST INFILTRATION & PROLOGUE                      │
│    • Spawn at fog-drenched road edge                   │
│    • Deer omen encounter & guiding light trigger       │
│    • Follow survey stakes through Blackpine Forest     │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ 2. WARDEN'S COTTAGE INVESTIGATION                      │
│    • Explore living quarters, hearth & bedroom         │
│    • Locate shared brass Cellar Key in kitchen         │
│    • Unlock cellar hatch & descend intermediate stairs │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ 3. THE BUNKER CONCOURSE & DESCENT                      │
│    • Traverse concrete inspection galleries            │
│    • Board the survey lift                             │
│    • Safe atomic streaming arrival into procedural maze│
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ 4. PROCEDURAL MAZE NAVIGATION & SURVIVAL               │
│    • Explore shifting cabin & bunker modules           │
│    • Evade ambient toads, jumpscares & Stalker NPC     │
│    • Manage flashlight battery & survive flicker events│
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ 5. OBJECTIVE COLLECTION                                │
│    • Locate scaled Fuses (electrical lockers)          │
│    • Locate scaled Keys (cabinet / desk stashes)       │
│    • Decipher lore clues (ClueSystem & ClueData)       │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│ 6. SYNCHRONIZED ESCAPE & OUTCOME                       │
│    • Reach the reinforced exit bulkhead                │
│    • Coordinate simultaneous dual-lever activation     │
│    • Escape into extraction or succumb to the Stalker  │
└────────────────────────────────────────────────────────┘
```

---

## 3. Narrative Beats & Atmosphere Flow

### Beat 1: The Roadside Omen
- **Setting**: Nighttime, dense pine trees, volumetric fog, abandoned vehicle.
- **The Deer Omen**: As players advance along the road, they spot `DeerIntroRig`. Approaching within 14 studs or casting a flashlight beam triggers `Workspace.Sounds.LeafRustle`. The deer abruptly snaps its neck 180° toward the players, emits an unnatural audio screech (`Workspace.Sounds.DeerScreech`), and bolts into the impenetrable woods before vanishing.
- **The Guiding Beacon**: A dim, sickly green PointLight (`BunkerLight`) illuminates near the forest trail path, nudging players toward shelter.

### Beat 2: Blackpine Trail & Warden's Cottage
- **Trail**: Over 290 towering pine trees frame a winding pathway marked by survey stakes. Fog density and dim exposure create deep isolation.
- **Cottage Exterior & Interior**: The 32 × 24 stud wooden structure appears weathered and domestic. Inside, players discover an extinguished hearth, an unmade bed, a small bathroom, and an unsettling family portrait where the faces have become distorted and obscured.
- **The Cellar Key**: In the kitchen, resting on a counter, lies the brass `CellarKey`. Any player can pick it up with ProximityPrompt; the key becomes shared for the expedition and remains unlocked even if the original finder disconnects.
- **The Hatch Drop**: Unlocking `CellarHatch` opens a trapdoor leading to a steep vertical drop onto an intermediate landing, transitioning from domestic wood to cold, reinforced concrete.

### Beat 3: The Subterranean Concourse ("Bigger on the Inside")
- **Scale Anomaly**: Directly beneath the tiny 32-stud footprint lies an expansive Cold War bunker complex featuring high-vaulted concrete concourses, heavy conduits, and two inspection galleries.
- **The Survey Lift**: At the terminal concourse, players interact with `SurveyLift`. Interacting validates proximity, requests server-authoritative geometry streaming around the destination, checks safe floor collision, and transports the player into the generated labyrinth.

### Beat 4: Procedural Cabin-Bunker Labyrinth
- **Environment**: A surreal hybrid of rusted metal bulkhead corridors and decaying 1970s wood cabin interiors (`BunkerAirlock`, `RustyWoodHallway`, `LShapedCabinStudy`).
- **Ambient Life & Horrors**:
  - `ToadPassiveNPC`: Ambient mutant toads lurking in wet corners, emitting periodic croaks (`Workspace.Sounds.ToadCroak`) to build paranoia.
  - `RoomInstanceNPC`: Environmental jumpscare entities triggered by proximity; cause abrupt light flickering and battery siphoning.
  - `MainNPC_Stalker`: An apex threat governed by a three-phase state machine:
    1. *Patrol*: Roams between room pivots.
    2. *Stalk*: Silently tails player squads from shadows when line-of-sight is broken.
    3. *Chase*: Preceded by a terrifying audio telegraph (`Workspace.Sounds.StalkerTelegraph`) giving players 1.5 seconds to sprint, break line of sight, or regroup.

### Beat 5: *The Forest* / Timmy-Style Environmental Clues
Scattered across room furniture, notice boards, and concrete walls are 7 environmental clues ([src/shared/ClueData.luau](file:///c:/Users/sanch/Projects/horror-game/src/shared/ClueData.luau)):
- **Torn Notebook Page (`CLUE_NOTE_01`)**: Notes detailing generator failure at 2 AM and movements outside the treeline.
- **Maintenance Log (`CLUE_NOTE_02`)**: Clues to fuse box locations in storage lockers ("GREEN panel, NOT red").
- **Wall Scribble (`CLUE_WALL_01`)**: Scrawled in dark pigment: *"IT COMES WHEN THE LIGHT DIES"*.
- **Radio Transcript (`CLUE_NOTE_03`)**: Lost transmissions warning: *"Don't go into the cabin..."*
- **Scratched Door (`CLUE_WALL_02`)**: Tragic count: *"3 of us left. then 2. then"*.
- **Keyring Label (`CLUE_NOTE_04`)**: Identifies the master generator key.
- **Basement Wall (`CLUE_WALL_03`)**: Ominous lore link: *"THE DEER WAS JUST THE BEGINNING"*.

---

## 4. 1–4 Player Dynamic Party Scaling

The game dynamically calibrates challenge based on player headcount ([src/server/MatchScaleManager.luau](file:///c:/Users/sanch/Projects/horror-game/src/server/MatchScaleManager.luau)):

| Player Count | Required Keys | Required Fuses | Co-op Exit Mechanic | Squad Teleport Spread |
| :---: | :---: | :---: | :---: | :---: |
| **1 Player (Solo)** | 1 Key | 1 Fuse | Single lever interaction | Single pivot (center) |
| **2 Players** | 2 Keys | 2 Fuses | Dual simultaneous levers | 2.5 studs lateral offset |
| **3 Players** | 3 Keys | 2 Fuses | Dual simultaneous levers | 5.0 studs total spread |
| **4 Players** | 4 Keys | 3 Fuses | Dual simultaneous levers | 7.5 studs total spread |

### Squad Teleport Safety
When moving 1–4 players via `TeleportManager.teleportSquad`, characters are staggered laterally along the target orientation vector (`RightVector * offset`) to prevent physics clipping, character stacking, or launching.

---

## 5. Monetization, Retention & Accessibility Direction

### Ethical, Non-Pay-to-Win Monetization
Horror immersion relies on genuine vulnerability. Monetization must **never** sell invulnerability, speed boosts, or instant objective unlocks:
1. **Flashlight Cosmetics**: Custom beam colors (warm incandescent, cold halogen, UV blacklight), vintage brass flashlight casings, or taped tactical housings.
2. **Character Customization**: Period-appropriate 1970s field explorer jackets, park ranger beanies, and backpack trinkets.
3. **Altruistic Gifting & Revives**: Players can purchase emergency battery packs or revive kits that can only be gifted to fallen or struggling teammates.

### Retention Loops & Session Pacing
- **Run Length**: 12–18 minutes per successful escape run, ideal for Roblox session intervals.
- **Variable Room Seeds & Threat Intensity**: Algorithmic layout variation and randomized objective placements keep runs unpredictable.
- **Badge & Lore Compendium**: Players collect and unlock persistent lore entries in a notebook, encouraging repeat runs to discover all 7 clue documents.

### Mobile Playability & Readability
- Over 60% of Roblox horror audiences play on mobile devices.
- **Lighting Readability**: Flashlights combine a focused high-intensity spot beam (`SPOT_BRIGHTNESS = 2.8`, `RANGE = 60`) with a subtle ambient fill sphere (`AMBIENT_BRIGHTNESS = 0.45`, `RANGE = 14`) so mobile screens with high glare remain navigable without losing horror contrast.
- **Touch Ergonomics**: High-contrast, large touch button for the flashlight placed comfortably within right-thumb reach (`StarterGui/GameHUD/FlashlightButton`), backed by a fallback runtime injector.
- **Haptic Feedback**: Subtle vibration pulses on mobile devices via `HapticService` when switching the flashlight or experiencing stalker anomaly flickers.

### Funnel Telemetry & Analytics Hooks
Track critical player progression events to diagnose drop-off points:
1. `funnel_forest_spawn`: Player loaded into forest.
2. `funnel_deer_omen`: Player triggered roadside deer sequence.
3. `funnel_cottage_enter`: Player entered warden's cottage.
4. `funnel_cellar_key_found`: Player picked up brass key.
5. `funnel_bunker_descent`: Player dropped through cellar hatch.
6. `funnel_lift_use`: Player rode survey lift to procedural dungeon.
7. `funnel_objective_complete`: Squad gathered required keys/fuses.
8. `funnel_gate_escaped`: Squad successfully escaped (Victory).
9. `funnel_squad_wipe`: All players eliminated by Stalker (Defeat).

---

## 6. Proposed Post-Integration Roadmap (Milestones 3–6)

*Note: The following milestones are proposed architectural targets subject to project owner approval and sprint scheduling.*

### [PROPOSED] Milestone 3: Complete Authoritative Playable Run
- **Goal**: Full authoritative loop from forest spawn to functional escape door.
- **Key Deliverables**:
  - Authoritative physical item pickups for Keys and Fuses with distance checks, inventory replication, and anti-cheat validation.
  - Interactive dual-lever exit door: Physical levers (`ExitLever_A`, `ExitLever_B`) requiring two distinct living players to hold simultaneously for 3 seconds to unbolt the exit bulkhead.
  - Defined game-over states: Spectator camera on death, squad wipe summary screen, and automated place reset/re-generation.

### [PROPOSED] Milestone 4: Horror & Environment Polish
- **Goal**: Audiovisual cohesion, pacing refinement, and dread escalation.
- **Key Deliverables**:
  - Final 3D NPC rigs to replace graybox placeholders (`MainNPC_Stalker`, `RoomInstanceNPC`, `ToadPassiveNPC`).
  - Spatial 3D soundscapes: Footstep material detection (wet mud, hollow floorboards, echoing concrete), distant metallic groans, and spatial creature breathing.
  - Interactive lore viewer: High-resolution notebook interface for reading collected clues.

### [PROPOSED] Milestone 5: Multiplayer Resilience & Mobile Alpha
- **Goal**: 4-player edge case handling, performance optimization, and mobile tuning.
- **Key Deliverables**:
  - Late-join and reconnection handling: Allow players connecting mid-game to spawn at the survey lift or spectate active runners.
  - Mobile memory & thermal profiling: Ensuring stable 60 FPS on low-end mobile devices (iPhone 11 / Android 4GB RAM) with heavy atmospheric fog.
  - Full touch HUD layout with thumbstick-friendly prompt interactions.

### [PROPOSED] Milestone 6: Release Candidate & Launch
- **Goal**: Hardening, telemetry validation, and deployment.
- **Key Deliverables**:
  - Live analytics integration with funnel telemetry and error logging.
  - Game icon, thumbnails, badges, and store gamepass configuration.
  - Automated deployment pipeline and rollback verification.
