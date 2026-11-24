--!strict
--[[
  ClueData  –  SHARED module (ReplicatedStorage/Shared)

  Defines all collectible clues: documents and wall scribbles.
  Each entry has a unique ID, display title, body text, and
  optional wall-scribble flavour.  Add new entries here; no
  other modules need changing.
]]

export type ClueEntry = {
	id: string,
	title: string,
	body: string,
	isWallScribble: boolean,
}

local ClueData: { ClueEntry } = {
	{
		id = "CLUE_NOTE_01",
		title = "Torn Notebook Page",
		body = "Day 4. The generator cut out again at 2 AM. I swear something moved outside the treeline.",
		isWallScribble = false,
	},
	{
		id = "CLUE_NOTE_02",
		title = "Maintenance Log",
		body = "Fuse box in corridor B is shot. Replacement fuses in the storage locker — GREEN panel, NOT red.",
		isWallScribble = false,
	},
	{
		id = "CLUE_WALL_01",
		title = "Wall Scribble",
		body = "IT COMES WHEN THE LIGHT DIES",
		isWallScribble = true,
	},
	{
		id = "CLUE_NOTE_03",
		title = "Radio Transcript",
		body = "…signal lost on frequency 88.6. Last transmission: 'Don't go into the cabin. Don't—' [static]",
		isWallScribble = false,
	},
	{
		id = "CLUE_WALL_02",
		title = "Scratched Door",
		body = "3 of us left. then 2. then",
		isWallScribble = true,
	},
	{
		id = "CLUE_NOTE_04",
		title = "Keyring Label",
		body = "Master key — bunker generator room. Keep this AWAY from the main corridor.",
		isWallScribble = false,
	},
	{
		id = "CLUE_WALL_03",
		title = "Basement Wall",
		body = "THE DEER WAS JUST THE BEGINNING",
		isWallScribble = true,
	},
}

return ClueData
