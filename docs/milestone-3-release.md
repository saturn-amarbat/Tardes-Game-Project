# Milestone 3 · Complete playable run

Players can finish a run from the forest lift to extraction. Keys and fuses credit the squad once per physical pickup. The server checks the registered item, player eligibility, health and reach. The lift clears the forest guidance for each player as they arrive.

The first lift arrival fixes the squad and its objective totals. After the squad collects its supplies, two living players can hold separate levers for three seconds to open extraction. A solo player or last survivor can hold either lever. Escape and squad wipe show a result, then rebuild the rooms and return everyone to the forest. Late arrivals to the server and eliminated players wait for replay.

## Test record

The project owner reports testing this iteration. Earlier Studio checks covered invalid and duplicate claims, staggered lift arrivals, a two-player lever escape, a solo escape, a wipe, and replay. The previous automated last-survivor check reached the locked gate with the original squad requirements still in force. StyLua, Selene, and Git whitespace checks passed before pushing.

## Creative Lead handoff

Place anchored `Workspace.ExitLever_A` and `Workspace.ExitLever_B` beside `Workspace.ExitDoor`, with a child `ProximityPrompt` named `Prompt` on each lever. Runtime fallbacks support the graybox. The forest opening model and Rojo mapping are outside this diff.
