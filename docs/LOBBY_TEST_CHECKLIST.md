# Dark Forest Lobby — QA & Verification Checklist

Pre-deployment test plan for `feature/lobby` (`lobby.project.json`).
Enable **Game Settings -> Security -> Enable Studio Access to API Services** before running DataStore tests, and publish both the Lobby place and Destination place (`LobbyConfig.GAME_PLACE_ID = 122077989749573`) inside the same Experience for live Teleport tests.

---

## 1. Solo Purchase & Equip Flow
- [ ] Spawn in Lobby; verify top-left persistent HUD displays `Coins: 100` (`LobbyConfig.STARTING_COINS`).
- [ ] Walk up to Zone A (`Frog Merchant` counter) and trigger `"Browse Shop"` (`ProximityPrompt` / `ButtonX` / tap).
- [ ] Confirm Frog turns its head toward the player and displays a greeting line.
- [ ] Verify `ShopGui` opens with **Character Skins** and **Weapon Skins** tabs, 3D `ViewportFrame` rotating previews, and `FREE` / `EQUIPPED` on starter items (`Forest Ranger`, `Standard Issue`).
- [ ] Select `Rusty Machete` (`100` Coins) -> click `BUY (100)` -> verify Confirm Popup shows item name, price, and current balance -> click `CONFIRM`.
- [ ] Verify server deducts `100` Coins (`Coins: 0` updates in both top-left HUD and shop header), shows `"Purchased Rusty Machete!"`, button changes to `EQUIP`, and clicking `EQUIP` updates button to `EQUIPPED` and attaches the hip prop.
- [ ] Rejoin the server and verify `Coins: 0`, `Rusty Machete` remains owned and `EQUIPPED` from `DataStoreService` (`PlayerData_v1`).

## 2. Insufficient Coins, Already-Owned & DataStore Failure
- [ ] With `0` Coins, click `BUY` on `Abandoned Miner` (`150` Coins); verify clear error toast `"Insufficient coins (need 150, have 0)."` and balance stays `0`.
- [ ] Fire `RequestPurchase` manually via exploit/test script for an already-owned `skinId` (e.g., `"wpn_rusty"`); verify server rejects with `"Already owned."` without deducting coins.
- [ ] Fire `RequestPurchase` with a modified/unknown ID or rapid-fire spam; verify server rejects invalid IDs and enforces `PURCHASE_COOLDOWN` (`1.0s`).
- [ ] Disable **Studio Access to API Services** (simulating DataStore failure) and rejoin:
  - Verify red warning banner `"Database unavailable — purchases disabled to protect your save."` appears in `ShopGui`.
  - Attempt a purchase -> verify purchase is blocked / rolled back with clear UI message and existing cloud save is never overwritten.

## 3. Two Players Joining & Leaving a Play Circle
- [ ] Start a 2-player Studio test server (`Test -> Local Server -> 2 Players`).
- [ ] Player 1 steps onto `Play Circle #1`:
  - Pad glow turns **Amber**, `PadBillboard` updates for all players to `1/4 • AUTO-START 45s` with Player 1's name, and Player 1's `QueueHud` displays their headshot.
- [ ] Player 2 steps onto `Play Circle #1`:
  - `PadBillboard` updates for both clients to `2/4 • AUTO-START ...` listing both names, and `QueueHud` shows both headshots.
- [ ] Player 2 steps off `Play Circle #1`:
  - Count decreases back to `1/4`, Player 2's name and headshot vanish immediately, and Player 2's `QueueHud` hides.
- [ ] Player 1 walks directly onto `Play Circle #2` while another circle exists:
  - Verify Player 1 is removed from Circle #1 (`0/4`, dim glow) and added only to Circle #2 (never in two circles simultaneously).
- [ ] **Friends Circle (`Play Circle #3`)**:
  - Non-friend player steps in after host -> verify rejection notice `"Friends-only circle — must be Roblox friends with <Host>."` and count stays `1/4`.

## 4. 4/4 Teleport & Reserved Server Handoff
- [ ] Start a 4-player test (or temporarily set `LobbyConfig.QUEUE_SIZE = 2` for a 2-player live test in a published Experience).
- [ ] Fill the pad to `4/4` (`QUEUE_SIZE/QUEUE_SIZE`):
  - Pad glow changes to **Green / Countdown Red**, `PadBillboard` and `QueueHud` immediately display `LAUNCHING IN 5...` -> `1`.
- [ ] At `0`, verify `TeleportService:ReserveServer` + `TeleportService:TeleportAsync` launches all 4 players into the **same** private reserved server of `GAME_PLACE_ID` (`122077989749573`).
- [ ] On arrival at the destination place, inspect `player:GetJoinData().TeleportData` on server and confirm `PartyId` and each player's `Coins`, `EquippedCharacterSkin`, and `EquippedWeaponSkin` arrived intact.
- [ ] Verify pad returns cleanly to `0/4` idle state in the lobby server.

## 5. Player Disconnect / Death Mid-Countdown
- [ ] Fill a circle to `4/4` (or let `AUTO_START_TIMEOUT` reach the 5-second launch countdown) so `"LAUNCHING IN 5..."` is active.
- [ ] At `LAUNCHING IN 3`, have one queued player:
  - **Case A:** Leave / disconnect from the game (`Players.PlayerRemoving`).
  - **Case B:** Reset character / die (`Humanoid.Died`).
  - **Case C:** Walk off the circle pad.
- [ ] Verify the countdown **immediately cancels**, remaining players receive the notice `"<Name> left the circle — countdown cancelled."`, pad glow reverts to **Amber**, count decrements accurately (`3/4`), and no partial teleport fires prematurely.

## 6. Teleport Failure Handling & Retry
- [ ] Test in Studio Play mode (where cross-place teleport fails) or temporarily point `LobbyConfig.GAME_PLACE_ID` to an invalid/unpublished Place ID.
- [ ] Trigger a launch (`4/4` or wait out `AUTO_START_TIMEOUT`).
- [ ] Verify server logs the warning, fires `"Teleport failed — retrying (1/2)..."` / `(2/2)` notices via `QueueNotice`, retries up to `LobbyConfig.MAX_TELEPORT_RETRIES` times, and on final failure displays a clear red UI notice (`"Teleport failed: ... Step back in to retry."`) and resets the pad cleanly without soft-locking any player.
