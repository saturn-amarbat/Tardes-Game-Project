--!strict
--[[
  Typography  –  SHARED typography & calligraphy hierarchy (ReplicatedStorage/Shared)

  Separates atmospheric horror calligraphy from utilitarian survival HUD text:
    • Display / Calligraphy (Fondamento): Zone/chapter titles, journal headers,
      sanctuary plaque, and handwritten note titles.
    • Wall Scribbles (Creepster): Eerie carved/scrawled messages.
    • Narrative Body (Antique): Lore scraps, dialogue subtitles, and archived notes.
    • Stencil (Code): Cold-War bunker telemetry & maintenance plates.
    • Utilitarian UI (Gotham*): Live counters, battery %, keycaps, and urgent lever prompts.
]]

local Typography = {}

Typography.Fonts = {
	Calligraphy = Enum.Font.Fondamento,
	Scribble = Enum.Font.Creepster,
	Narrative = Enum.Font.Antique,
	Stencil = Enum.Font.Code,
	UI = Enum.Font.GothamMedium,
	UIBold = Enum.Font.GothamBold,
	UIRegular = Enum.Font.Gotham,
}

Typography.Colors = {
	Bone = Color3.fromRGB(239, 234, 222),
	ParchmentGold = Color3.fromRGB(234, 206, 144),
	WallBlood = Color3.fromRGB(232, 134, 122),
	InkShadow = Color3.fromRGB(8, 10, 10),
	MutedSlate = Color3.fromRGB(162, 168, 162),
	MintClear = Color3.fromRGB(122, 226, 154),
}

function Typography.applyStroke(label: TextLabel | TextButton, transparency: number?)
	label.TextStrokeColor3 = Typography.Colors.InkShadow
	label.TextStrokeTransparency = transparency or 0.35
end

return Typography
