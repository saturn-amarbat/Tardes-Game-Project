# Blackpine forest, cabin and bunker handoff

## Goal

Give Tardes a playable opening with a clear route through the woods, a cottage that fits its exterior and a much larger space hidden below it. Use the cellar key to make the transition legible in solo play and let up to four teammates explore and descend at their own pace.

## Original request

> Ok do that, and I want to work on the following (Make sure to create the branch with clearl descriptions of what was added, and what the goals for the enhancements that has been sent as PR)
>
> create a big dark, grey forest with a heavy but optimized atmospheric fog and a lot of tall trees, like tall pine trees and uneven terrain that gives unsettling vibe. Additionally, create a small dusty living room with Old wooden furniture, a fireplace, A small kitchen, A bedroom, a chair facing the fireplace, a picture of a family that got obscure and twisted in the picture, A locked basement entrance, Old photographs and handwritten notes, a bathroom next to the bedroom. From here on i want the players inside the house to fall into a hole or stair or something so that they fall into a huge bunker system underneath the small house, remember that i am building a game for multiple players and solo player so the story and everything has to be suited for both solo players and multiplayers.
> Initially, the cabin should seem consistent with its exterior dimensions. I don't know whats best, so just refer back to gemini, don't go strictly as my words add your own details to make the best decisions and make the forest and the small house make sense the most to make people play consistently and unique designs.

## What changed

| File | Purpose |
| --- | --- |
| `src/server/ForestCabin/Opening.rbxmx` | Editable model with a winding trail, uneven forest floor, 290 tall pines, a 32 × 24 stud cottage, original distressed family images and notes, a cellar drop, a concrete concourse and two inspection galleries. |
| `src/server/ForestCabin/init.server.luau` | Moves the opening into Workspace, assigns the forest spawn, handles the shared key and hatch, and sends each player from the lift to a safe floor inside the first generated room when available. |
| `src/client/ForestWeather.client.luau` | Applies a single local Atmosphere and lower exposure near the surface, then restores the place lighting below the cellar. Pine canopies use simple, noncolliding geometry and forest props skip shadow casting. |
| `forest-preview.project.json` | Builds an isolated Studio file with streaming enabled and its own dusk lighting. |
| `src/shared/.gitkeep` | Keeps the existing Rojo shared path present in a clean checkout. |

## Player flow and integration

1. Follow the survey stakes and the lamp above the cottage entrance. Explore the living room hearth, kitchen, bedroom and adjoining bathroom.
2. Read the shift note and pick up the brass cellar key in the kitchen. The server records one shared pickup. The state survives the finder leaving the server.
3. Unlock the cellar hatch. It stays open for the session. Each player drops to the intermediate landing and takes the emergency stairs to the concourse independently.
4. Explore the two bunker galleries, then interact with the survey lift individually. The lift looks for `Workspace.GeneratedDungeon.Room_01_*` and its `Entrance` BasePart, requests nearby streaming when enabled, and verifies a floor before moving the character. The standalone preview ends in the galleries. It displays an offline lift when the procedural rooms are unavailable.

## Working in parallel

- Run `rojo build forest-preview.project.json -o Blackpine-Survey-Cottage.rbxl` and open the result in Studio for level testing. For the integrated build, run `rojo build default.project.json -o Tardes-dev.rbxl` and use a development place with the Studio-owned `ReplicatedStorage.RoomTemplates`.
- Edit Luau in the repository. For layout changes, open a local development copy in Studio and export the updated opening back to `Opening.rbxmx`. Preserve the model and prompt names the server resolves, including `Wardens Cottage`, `Survey Vault`, `ForestStart`, `CellarKey`, `CellarHatch` and `SurveyLift`. Runtime Explorer path is `Workspace.ForestCabinOpening`.
- Coordinate spawn and opening narration with the prologue work on `milestone-2-wip`. Decide which system owns the initial spawn and when the forest route starts. Coordinate the lift with that branch's teleport manager and use one arrival flow into the generated rooms. Keep the location check and floor validation when combining the logic.
- The original main branch startup scripts look for their Rojo child modules through `script.Parent`. Use the corrected startup paths from the integration work or verify the requires before testing the lift in the full game. The standalone place has its own startup script.

## Before a shared-place release

- Walk the full route from the forest in solo play. Check that the kitchen clue is readable and that the hatch drop lands cleanly.
- Test with two and four clients. Test simultaneous key pickup, the finder disconnecting, players descending at different times and using the lift independently.
- Check the forest trail at low graphics on a real phone. Record frame rate and verify that cabin and trail landmarks stay visible. Use the Studio development place to test concurrently with the flashlight and prologue.
