--!strict
--[[
  LobbyConfig  –  SHARED central configuration for the Dark Forest Lobby.

  All tunables live here so the team can adjust queue size, countdown,
  prices, place IDs, lighting, audio, and layout positions without touching
  other modules.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LobbyConfig = {}

export type PadConfig = {
	cf: CFrame,
	maxPlayers: number,
	title: string,
	friendsOnly: boolean,
}

--------------------------------------------------------------------------------
-- Teleport & Destination
--------------------------------------------------------------------------------
-- Place ID of the road / forest / bunker game scene ("Project Horror")
LobbyConfig.GAME_PLACE_ID = 122077989749573
LobbyConfig.MAX_TELEPORT_RETRIES = 2
LobbyConfig.TELEPORT_RETRY_DELAY = 2.0
-- When testing in Roblox Studio, QueueService transitions launched players
-- smoothly into the actual game within the same server (Studio blocks TeleportService).
LobbyConfig.PLAYTEST_IN_PLACE_IN_STUDIO = true

--- Returns true when this server should boot players into the Dark Forest Lobby first.
function LobbyConfig.shouldStartInLobby(): boolean
	-- Live reserved servers launched from a play circle start directly in the game.
	if RunService:IsServer() and game.PrivateServerId ~= "" then
		return false
	end
	local override = Workspace:GetAttribute("ForceLobbyScene")
	if typeof(override) == "boolean" then
		return override
	end
	if Workspace:FindFirstChild("LobbyMap") ~= nil then
		return true
	end
	return game.PlaceId ~= LobbyConfig.GAME_PLACE_ID or RunService:IsStudio()
end

--------------------------------------------------------------------------------
-- Queue Pads (Play Circles: 1P, 2P, 3P, 4P)
--------------------------------------------------------------------------------
LobbyConfig.QUEUE_SIZE = 4 -- Default/max squad capacity
LobbyConfig.COUNTDOWN_SECONDS = 5 -- Launch countdown once ready
-- Seconds before partially filled multi-player circles auto-launch (0 = strict full circle)
LobbyConfig.AUTO_START_TIMEOUT = 45
LobbyConfig.FRIENDS_PAD_INDEX = 0 -- Optional index (1..4) if you want one circle locked to friends
LobbyConfig.PAD_RADIUS = 6.5 -- Studs from pad center to count as standing inside

LobbyConfig.PADS = {
	{ cf = CFrame.new(28, 0, -26), maxPlayers = 1, title = "1 PLAYER", friendsOnly = false },
	{ cf = CFrame.new(44, 0, -10), maxPlayers = 2, title = "2 PLAYERS", friendsOnly = false },
	{ cf = CFrame.new(44, 0, 10), maxPlayers = 3, title = "3 PLAYERS", friendsOnly = false },
	{ cf = CFrame.new(28, 0, 26), maxPlayers = 4, title = "4 PLAYERS", friendsOnly = false },
} :: { PadConfig }

LobbyConfig.NUM_PADS = #LobbyConfig.PADS

--------------------------------------------------------------------------------
-- Shop & Economy
--------------------------------------------------------------------------------
LobbyConfig.STARTING_COINS = 100
LobbyConfig.PURCHASE_COOLDOWN = 1.0 -- Seconds between purchases per player

LobbyConfig.RARITY_COLORS = {
	Common = Color3.fromRGB(168, 174, 168),
	Uncommon = Color3.fromRGB(96, 186, 118),
	Rare = Color3.fromRGB(82, 162, 224),
	Epic = Color3.fromRGB(168, 108, 222),
	Legendary = Color3.fromRGB(234, 176, 78),
} :: { [string]: Color3 }

--------------------------------------------------------------------------------
-- Scene Layout (world positions, studs)
--   Zone A (Shop / Frog Stall): negative X side
--   Central Clearing (Spawn & Campfire): origin
--   Zone B (Play Circles): positive X side
--------------------------------------------------------------------------------
LobbyConfig.SPAWN_POSITION = Vector3.new(0, 0.5, -10)
-- Standard Roblox -Z forward orientation facing toward central clearing
LobbyConfig.FROG_POSITION = CFrame.lookAt(Vector3.new(-38, 0, 12), Vector3.new(0, 0, 4))
LobbyConfig.CAMPFIRE_POSITION = Vector3.new(0, 0, 8)
LobbyConfig.PAD_POSITIONS = {
	CFrame.new(28, 0, -26),
	CFrame.new(44, 0, -10),
	CFrame.new(44, 0, 10),
	CFrame.new(28, 0, 26),
} :: { CFrame }

LobbyConfig.MAP_RADIUS = 85
LobbyConfig.BOUNDARY_RADIUS = 90

--------------------------------------------------------------------------------
-- Lighting & Atmosphere (Dark Forest Night)
--------------------------------------------------------------------------------
LobbyConfig.LIGHTING = {
	ClockTime = 22.5,
	Brightness = 0.72,
	Ambient = Color3.fromRGB(44, 58, 70),
	OutdoorAmbient = Color3.fromRGB(58, 78, 92),
	ExposureCompensation = 0.16,
	FogColor = Color3.fromRGB(26, 52, 64),
	FogStart = 18,
	FogEnd = 155,
}

LobbyConfig.ATMOSPHERE = {
	Density = 0.32,
	Offset = 0.08,
	Color = Color3.fromRGB(52, 86, 102),
	Decay = Color3.fromRGB(22, 38, 52),
	Glare = 0.0,
	Haze = 2.4,
}

LobbyConfig.BLOOM = {
	Intensity = 0.24,
	Size = 16,
	Threshold = 1.4,
}

LobbyConfig.COLOR_CORRECTION = {
	Brightness = 0.02,
	Contrast = 0.08,
	Saturation = -0.18,
	TintColor = Color3.fromRGB(216, 232, 248),
}

--------------------------------------------------------------------------------
-- Ambient Audio Asset IDs (verified Creator Store & existing repo sounds)
--------------------------------------------------------------------------------
LobbyConfig.AUDIO = {
	Crickets = "rbxassetid://9112762653", -- Creator Store: Crickets And Cicadas 4 (SFX)
	WindLoop = "rbxassetid://9112777914", -- Creator Store: Evening Wind Presence Loop (ProSoundEffects)
	CampfireCrackle = "rbxassetid://9079463756", -- Creator Store: Fire Crackling
	OwlHoot = "rbxassetid://150791665", -- Creator Store: Owl hoot SFX
	BranchCrack = "rbxassetid://9116146300", -- Repo Workspace.Sounds.LeafRustle
	WoodCreak = "rbxassetid://9116638731", -- Repo LampFlicker creak SFX
	FrogCroak = "rbxassetid://6276863875", -- Repo Workspace.Sounds.ToadCroak
}

--------------------------------------------------------------------------------
-- Frog Shopkeeper Greeting Lines
--------------------------------------------------------------------------------
LobbyConfig.FROG_GREETINGS = {
	"Coins from the road... or bring back what's left.",
	"Cold fog tonight. Take a skin before the trees take you.",
	"The deer is waiting down the blacktop. Gear up.",
	"Four footsteps in the mud. Not all four come back.",
} :: { string }

--------------------------------------------------------------------------------
-- DataStore
--------------------------------------------------------------------------------
LobbyConfig.DATASTORE_NAME = "PlayerData_v1"
LobbyConfig.DATASTORE_KEY_PREFIX = "Player_"
LobbyConfig.AUTO_SAVE_INTERVAL = 120
LobbyConfig.MAX_DATASTORE_RETRIES = 3

return LobbyConfig
