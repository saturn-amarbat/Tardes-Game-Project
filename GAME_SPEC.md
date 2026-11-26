# TARDES — Canonical Game Specification (Single Source of Truth)

## 1. Vision & Core Loop
- **Genre:** 1–4 player co-op procedural room-escape horror on Roblox.
- **Tone & Aesthetic:** Dark, suspenseful horror blending a grounded forest/cottage descent into an abandoned 50-year Cold War bunker with a *Doctor Who* "bigger on the inside" spatial paradox leading into dark rusty wood cabin rooms and complex spaces.
- **Core Gameplay Loop:**
  0. **Lobby-First Entry:** Players joining Tardes normally enter the Dark Forest Lobby (`Workspace.LobbyMap`, Frog Merchant shop, campfire social area, and 1P–4P matchmaking circles). Entry into the horror expedition is initiated voluntarily through the matchmaking queue and countdown.
  1. **Opening & Descent:** Start in the dark forest (`ForestStart`) → pass `Wardens Cottage` (`CellarKey` → `CellarHatch`) → descend through the bunker/galleries to `SurveyLift` → transition via `TeleportManager` (`RequestStreamAroundAsync`) into procedurally generated rooms (`DungeonEntered`).
  2. **Exploration & Survival:** Navigate rooms generated on demand (`ModelStreamingMode.Atomic`, snapped via `Entrance`/`Exit` anchors with overlap checks) using a *Slender Man*-style layered flashlight (`SpotLight` cone + `PointLight` fill for mobile/low-graphics legibility), collect *The Forest* / Timmy-style lore clues/scribbles (shared squad credit), and gather required run objectives (keys/fuses).
  3. **Mid-Run Safe Room:** Reach the Toad-Maker safe area to catch your breath, interact with passive toads, and spend run currency on supplies/tools.
  4. **Extraction or Wipe:** Once required party objectives are complete, activate the exit levers (`ExitLever_A` and `ExitLever_B` for 2+ living players; single-lever fallback only when 1 player remains and objectives are met) to escape with run rewards—or fail if the squad is wiped out.

## 2. Multiplayer, Death, Revive & Session Rules
- **Party Size:** Solo (1 player) up to 4 players per run; objective totals and dual-lever requirements scale by active party state before dungeon entry.
- **Late Joins:** Locked once the squad enters the bunker/dungeon (`DungeonEntered`) so late joiners cannot corrupt active objective counts or spawn into active chases.
- **Death & Revives:** Downed/eliminated players enter Spectator Mode. Players can claim **1 free earned Revive Token per run** or be revived mid-run via a **Robux Gift Revive** from a living teammate.
- **Run Reset:** Escaping or squad wipe triggers clear run outcome state and clean reset/return-to-lobby or replay flow.

## 3. Threats, NPCs & Audio/Visual Contracts
- **Deer Omen (`DeerIntroRig`):** Forest road encounter (leaf rustle → brief relief → eerie face reveal, screech, and bolt into the dark) guiding players toward shelter.
- **Toads & Toad-Maker (`ToadPassiveNPC` + Safe Room):** Passive/disgusting toads in the complex tied to a side-character/shopkeeper room.
- **Room Jumpscare Entity (`RoomInstanceNPC`):** Brief non-lethal cabin room scares that trigger flashlight flicker and drain battery rather than cheap instant run-ends.
- **Main Stalker (`MainNPC_Stalker`):** Patrol → Stalk → Chase loop with clear audio telegraphing (`StalkerTelegraph`) so encounters feel fair.
- **Key Studio Contracts:** Preserve `ReplicatedStorage/RoomTemplates` (`Entrance`/`Exit` parts, `Atomic` streaming), `ReplicatedStorage/NPCModels` (`ToadPassiveNPC`, `RoomInstanceNPC`, `MainNPC_Stalker` with `PrimaryPart`), `Workspace/Sounds` (`LeafRustle`, `DeerScreech`, `ToadCroak`, `StalkerTelegraph`), and `StarterGui/GameHUD/FlashlightButton` (`GuiButton`).

## 4. Monetization & Launch Scope (v1)
- **Access:** Free-to-play entry.
- **v1 Launch Monetization (Non-Pay-to-Win):**
  - **Flashlight Skins & Toad Keycharms:** Purely cosmetic items that look great in co-op and preserve fair gameplay balance.
  - **In-Run Gift Revive:** Social/convenience developer product alongside the free per-run earned token.
  - **Private Servers / Optional Chaos or Admin Pass:** For friend groups and custom play.
- **Post-Launch Expansions:** Additional sectors/floors, new monsters/rooms, class/progression expansions, and steady updates using ethical, transparent pricing (no fake timers or false scarcity).

## 5. Engineering & Agent Boundaries
- `AGENTS.md` governs repository and AI tool rules: edit `.luau` scripts **only** on disk in `src/` (`--!strict`), pass `stylua --check src` and `selene src`, keep `"$ignoreUnknownInstances": true` in `default.project.json`, never edit Rojo-synced scripts inside Studio via MCP, and branch from a freshly fetched `origin/main`.
- **Gameplay Preservation:** The `BunkerGrid` redesign is strictly a scoped replacement of the bunker dungeon generation subsystem. Existing lobby entry, player movement, stamina/sprinting, flashlight optics/battery, HUD, audio, progression, and multiplayer systems must be preserved.