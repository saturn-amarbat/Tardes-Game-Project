--!strict
--[[
  LobbyConfig  –  SHARED central configuration for the Dark Forest Lobby.

  All tunables live here so the team can adjust queue size, countdown,
  prices, place IDs, lighting, audio, and layout positions without touching
  other modules.
]]

local LobbyConfig = {}

--------------------------------------------------------------------------------
-- Teleport & Destination
--------------------------------------------------------------------------------
-- Place ID of the road / forest / bunker game scene ("Project Horror")
LobbyConfig.GAME_PLACE_ID = 122077989749573
LobbyConfig.MAX_TELEPORT_RETRIES = 2
LobbyConfig.TELEPORT_RETRY_DELAY = 2.0

--------------------------------------------------------------------------------
-- Queue Pads (Play Circles)
--------------------------------------------------------------------------------
LobbyConfig.QUEUE_SIZE = 4 -- Max players per circle
LobbyConfig.COUNTDOWN_SECONDS = 5 -- Launch countdown once ready
-- Seconds before 1..(QUEUE_SIZE-1) players auto-launch (set 0 for strict full-circle only)
LobbyConfig.AUTO_START_TIMEOUT = 45
LobbyConfig.NUM_PADS = 3 -- Number of play circles in Zone B
LobbyConfig.FRIENDS_PAD_INDEX = 3 -- Pad index designated as "Friends Only"
LobbyConfig.PAD_RADIUS = 7 -- Studs from pad center to count as standing inside

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
	CFrame.new(32, 0, -20),
	CFrame.new(44, 0, 0),
	CFrame.new(32, 0, 20),
} :: { CFrame }

LobbyConfig.MAP_RADIUS = 85
LobbyConfig.BOUNDARY_RADIUS = 90

--------------------------------------------------------------------------------
-- Lighting & Atmosphere (Dark Forest Night)
--------------------------------------------------------------------------------
LobbyConfig.LIGHTING = {
	ClockTime = 0.5,
	Brightness = 0.45,
	Ambient = Color3.fromRGB(22, 32, 42),
	OutdoorAmbient = Color3.fromRGB(28, 42, 54),
	ExposureCompensation = -0.1,
	FogColor = Color3.fromRGB(24, 46, 56),
	FogStart = 18,
	FogEnd = 150,
}

LobbyConfig.ATMOSPHERE = {
	Density = 0.38,
	Offset = 0.08,
	Color = Color3.fromRGB(36, 64, 78),
	Decay = Color3.fromRGB(16, 28, 38),
	Glare = 0.0,
	Haze = 2.8,
}

LobbyConfig.BLOOM = {
	Intensity = 0.24,
	Size = 16,
	Threshold = 1.4,
}

LobbyConfig.COLOR_CORRECTION = {
	Brightness = -0.02,
	Contrast = 0.08,
	Saturation = -0.18,
	TintColor = Color3.fromRGB(216, 232, 248),
}

--------------------------------------------------------------------------------
-- Ambient Audio Asset IDs (verified Creator Store & existing repo sounds)
--------------------------------------------------------------------------------
LobbyConfig.AUDIO = {
	Crickets = "rbxassetid://9112762653", -- Creator Store: Crickets And Cicadas 4 (SFX)
	WindLoop = "rbxassetid://105667490483473", -- Creator Store: Wind Sounds Nature Ambient Forest Calm
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
