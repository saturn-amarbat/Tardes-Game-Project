--!strict
--[[
  MazeVariations  –  SERVER R.E.P.O.-style 8^3 (512) modular maze variation engine.

  Combines three independent 8-option axes every time players launch a run:
    Axis 1 (8): Architectural Themes & Material/Lighting Palettes
    Axis 2 (8): Modular Maze Topologies (hubs, T-splits, switchbacks, multi-room wings)
    Axis 3 (8): Modular Decoration Sets & Environmental Prop Loadouts

  8 x 8 x 8 = 512 structural variation combinations, layered with per-run Random(seed)
  room permutation and collision-safe prop placement.
]]

local Workspace = game:GetService("Workspace")

local MazeVariations = {}

export type ThemeDef = {
	id: number,
	name: string,
	floorColor: Color3,
	floorMat: Enum.Material,
	wallColor: Color3,
	wallMat: Enum.Material,
	ceilingColor: Color3,
	ceilingMat: Enum.Material,
	trimColor: Color3,
	trimMat: Enum.Material,
	accentColor: Color3,
	lightColor: Color3,
	lightBrightness: number,
	dustColor: Color3,
}

export type TopologyDef = {
	id: number,
	name: string,
	spinePreferred: { string },
	wingPreferred: { string },
	branchChance: number,
	maxBranches: number,
	maxWingDepth: number,
	allowConsecutiveTurns: boolean,
}

export type DecorDef = {
	id: number,
	name: string,
	minProps: number,
	maxProps: number,
}

export type VariationProfile = {
	theme: ThemeDef,
	topology: TopologyDef,
	decor: DecorDef,
	code: string,
	index: number,
	seed: number,
}

--------------------------------------------------------------------------------
-- Axis 1: 8 Architectural Themes
--------------------------------------------------------------------------------
MazeVariations.THEMES = {
	{
		id = 1,
		name = "McJannek Station",
		floorColor = Color3.fromRGB(54, 60, 66),
		floorMat = Enum.Material.Concrete,
		wallColor = Color3.fromRGB(76, 86, 94),
		wallMat = Enum.Material.Concrete,
		ceilingColor = Color3.fromRGB(48, 52, 58),
		ceilingMat = Enum.Material.Metal,
		trimColor = Color3.fromRGB(74, 48, 38),
		trimMat = Enum.Material.CorrodedMetal,
		accentColor = Color3.fromRGB(204, 148, 56),
		lightColor = Color3.fromRGB(248, 194, 108),
		lightBrightness = 0.85,
		dustColor = Color3.fromRGB(196, 206, 214),
	},
	{
		id = 2,
		name = "Headman Manor Wing",
		floorColor = Color3.fromRGB(52, 36, 28),
		floorMat = Enum.Material.WoodPlanks,
		wallColor = Color3.fromRGB(74, 48, 34),
		wallMat = Enum.Material.WoodPlanks,
		ceilingColor = Color3.fromRGB(42, 30, 22),
		ceilingMat = Enum.Material.Wood,
		trimColor = Color3.fromRGB(44, 52, 42),
		trimMat = Enum.Material.Wood,
		accentColor = Color3.fromRGB(132, 42, 42),
		lightColor = Color3.fromRGB(255, 192, 108),
		lightBrightness = 0.9,
		dustColor = Color3.fromRGB(224, 198, 164),
	},
	{
		id = 3,
		name = "Hydro Turbine Sublevel",
		floorColor = Color3.fromRGB(42, 52, 50),
		floorMat = Enum.Material.Basalt,
		wallColor = Color3.fromRGB(52, 68, 64),
		wallMat = Enum.Material.Slate,
		ceilingColor = Color3.fromRGB(36, 44, 42),
		ceilingMat = Enum.Material.CorrodedMetal,
		trimColor = Color3.fromRGB(82, 74, 48),
		trimMat = Enum.Material.CorrodedMetal,
		accentColor = Color3.fromRGB(68, 148, 126),
		lightColor = Color3.fromRGB(122, 232, 192),
		lightBrightness = 0.8,
		dustColor = Color3.fromRGB(168, 218, 200),
	},
	{
		id = 4,
		name = "Core Reactor Block",
		floorColor = Color3.fromRGB(40, 42, 48),
		floorMat = Enum.Material.DiamondPlate,
		wallColor = Color3.fromRGB(56, 58, 64),
		wallMat = Enum.Material.Metal,
		ceilingColor = Color3.fromRGB(34, 36, 40),
		ceilingMat = Enum.Material.CorrodedMetal,
		trimColor = Color3.fromRGB(186, 134, 38),
		trimMat = Enum.Material.Metal,
		accentColor = Color3.fromRGB(218, 118, 42),
		lightColor = Color3.fromRGB(255, 214, 142),
		lightBrightness = 0.95,
		dustColor = Color3.fromRGB(224, 198, 158),
	},
	{
		id = 5,
		name = "Blackpine Sanatorium",
		floorColor = Color3.fromRGB(78, 82, 76),
		floorMat = Enum.Material.Slate,
		wallColor = Color3.fromRGB(118, 128, 118),
		wallMat = Enum.Material.CeramicTiles,
		ceilingColor = Color3.fromRGB(64, 70, 64),
		ceilingMat = Enum.Material.Concrete,
		trimColor = Color3.fromRGB(68, 54, 48),
		trimMat = Enum.Material.CorrodedMetal,
		accentColor = Color3.fromRGB(108, 158, 132),
		lightColor = Color3.fromRGB(194, 232, 206),
		lightBrightness = 0.82,
		dustColor = Color3.fromRGB(200, 220, 206),
	},
	{
		id = 6,
		name = "Collapsed Archive",
		floorColor = Color3.fromRGB(58, 54, 48),
		floorMat = Enum.Material.Cobblestone,
		wallColor = Color3.fromRGB(82, 76, 66),
		wallMat = Enum.Material.Concrete,
		ceilingColor = Color3.fromRGB(44, 34, 28),
		ceilingMat = Enum.Material.WoodPlanks,
		trimColor = Color3.fromRGB(56, 42, 30),
		trimMat = Enum.Material.Wood,
		accentColor = Color3.fromRGB(166, 132, 76),
		lightColor = Color3.fromRGB(238, 202, 136),
		lightBrightness = 0.8,
		dustColor = Color3.fromRGB(218, 206, 182),
	},
	{
		id = 7,
		name = "Cryo Storage Bay",
		floorColor = Color3.fromRGB(72, 86, 98),
		floorMat = Enum.Material.Metal,
		wallColor = Color3.fromRGB(92, 108, 120),
		wallMat = Enum.Material.Metal,
		ceilingColor = Color3.fromRGB(48, 60, 74),
		ceilingMat = Enum.Material.Metal,
		trimColor = Color3.fromRGB(40, 52, 68),
		trimMat = Enum.Material.DiamondPlate,
		accentColor = Color3.fromRGB(108, 182, 224),
		lightColor = Color3.fromRGB(156, 220, 255),
		lightBrightness = 0.88,
		dustColor = Color3.fromRGB(198, 232, 252),
	},
	{
		id = 8,
		name = "Deep Survey Vault",
		floorColor = Color3.fromRGB(54, 58, 50),
		floorMat = Enum.Material.Concrete,
		wallColor = Color3.fromRGB(66, 74, 60),
		wallMat = Enum.Material.Concrete,
		ceilingColor = Color3.fromRGB(44, 48, 42),
		ceilingMat = Enum.Material.CorrodedMetal,
		trimColor = Color3.fromRGB(58, 62, 54),
		trimMat = Enum.Material.Metal,
		accentColor = Color3.fromRGB(238, 152, 62),
		lightColor = Color3.fromRGB(246, 178, 92),
		lightBrightness = 0.86,
		dustColor = Color3.fromRGB(204, 198, 174),
	},
} :: { ThemeDef }

--------------------------------------------------------------------------------
-- Axis 2: 8 Modular Maze Topologies
--------------------------------------------------------------------------------
MazeVariations.TOPOLOGIES = {
	{
		id = 1,
		name = "Spine & Pockets",
		spinePreferred = { "TJunctionL", "TJunctionR", "CorridorLong", "SideVault", "GeneratorSwitchRoom" },
		wingPreferred = { "SideVault", "DeadEndLab", "StorageBay" },
		branchChance = 0.72,
		maxBranches = 4,
		maxWingDepth = 1,
		allowConsecutiveTurns = false,
	},
	{
		id = 2,
		name = "Twin-Wing Crossroads",
		spinePreferred = { "CrossHub", "SplitCourt", "CorridorLong", "BunkerAirlock", "FloodedSublevel" },
		wingPreferred = { "StorageBay", "CorridorLong", "SideVault", "DeadEndLab" },
		branchChance = 0.82,
		maxBranches = 6,
		maxWingDepth = 2,
		allowConsecutiveTurns = false,
	},
	{
		id = 3,
		name = "Spiral Switchback",
		spinePreferred = { "CornerLeft", "CornerRight", "LShapedCabinStudy", "TJunctionL", "RustyWoodHallway" },
		wingPreferred = { "DeadEndLab", "SideVault", "CornerLeft", "CornerRight" },
		branchChance = 0.55,
		maxBranches = 3,
		maxWingDepth = 2,
		allowConsecutiveTurns = true,
	},
	{
		id = 4,
		name = "Grand Atrium Hubs",
		spinePreferred = { "SplitCourt", "CrossHub", "StepGallery", "RustyWoodHallway", "BunkerAirlock" },
		wingPreferred = { "SideVault", "GeneratorSwitchRoom", "DeadEndLab" },
		branchChance = 0.78,
		maxBranches = 5,
		maxWingDepth = 2,
		allowConsecutiveTurns = false,
	},
	{
		id = 5,
		name = "Sublevel Bypass Grid",
		spinePreferred = { "TJunctionL", "TJunctionR", "CrossHub", "FloodedSublevel", "StepGallery" },
		wingPreferred = { "CorridorLong", "StorageBay", "SideVault" },
		branchChance = 0.86,
		maxBranches = 6,
		maxWingDepth = 2,
		allowConsecutiveTurns = false,
	},
	{
		id = 6,
		name = "Maintenance Gauntlet",
		spinePreferred = { "StepGallery", "GeneratorSwitchRoom", "TJunctionR", "CorridorLong", "SideVault" },
		wingPreferred = { "StorageBay", "DeadEndLab", "SideVault" },
		branchChance = 0.64,
		maxBranches = 4,
		maxWingDepth = 1,
		allowConsecutiveTurns = false,
	},
	{
		id = 7,
		name = "Shattered Labyrinth",
		spinePreferred = { "CornerLeft", "CrossHub", "TJunctionL", "TJunctionR", "LShapedCabinStudy", "StepGallery" },
		wingPreferred = { "CornerRight", "DeadEndLab", "SideVault", "StorageBay" },
		branchChance = 0.74,
		maxBranches = 5,
		maxWingDepth = 2,
		allowConsecutiveTurns = true,
	},
	{
		id = 8,
		name = "Deep Vault Sector",
		spinePreferred = { "CrossHub", "SplitCourt", "SideVault", "FloodedSublevel", "GeneratorSwitchRoom" },
		wingPreferred = { "SideVault", "DeadEndLab", "StorageBay", "RustyWoodHallway" },
		branchChance = 0.90,
		maxBranches = 7,
		maxWingDepth = 2,
		allowConsecutiveTurns = false,
	},
} :: { TopologyDef }

--------------------------------------------------------------------------------
-- Axis 3: 8 Modular Decoration Loadouts
--------------------------------------------------------------------------------
MazeVariations.DECORS = {
	{ id = 1, name = "Supply Crates & Trolleys", minProps = 2, maxProps = 4 },
	{ id = 2, name = "Bio-Fungal Overgrowth", minProps = 2, maxProps = 4 },
	{ id = 3, name = "Power Conduits & Breakers", minProps = 2, maxProps = 3 },
	{ id = 4, name = "Survey Field Archives", minProps = 2, maxProps = 4 },
	{ id = 5, name = "Boilers & Steam Valves", minProps = 2, maxProps = 3 },
	{ id = 6, name = "Lockdown Barricades", minProps = 2, maxProps = 3 },
	{ id = 7, name = "Abandoned Quarters", minProps = 2, maxProps = 3 },
	{ id = 8, name = "Anomaly Salvage Caches", minProps = 2, maxProps = 4 },
} :: { DecorDef }

function MazeVariations.pickVariation(rng: Random): VariationProfile
	local a = rng:NextInteger(1, #MazeVariations.THEMES)
	local b = rng:NextInteger(1, #MazeVariations.TOPOLOGIES)
	local c = rng:NextInteger(1, #MazeVariations.DECORS)
	local theme = MazeVariations.THEMES[a]
	local topology = MazeVariations.TOPOLOGIES[b]
	local decor = MazeVariations.DECORS[c]
	local index = (a - 1) * 64 + (b - 1) * 8 + c
	local seed = rng:NextInteger(100000, 9999999)
	return {
		theme = theme,
		topology = topology,
		decor = decor,
		code = string.format("V-%d-%d-%d", a, b, c),
		index = index,
		seed = seed,
	}
end

--------------------------------------------------------------------------------
-- Modular R.E.P.O.-style Geometry Helpers
--------------------------------------------------------------------------------
local DOOR_W = 5.2
local DOOR_H = 7.4
local WALL_H = 11.0
local WALL_T = 1.0

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material,
	collide: boolean
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = collide
	p.CanQuery = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeAnchor(parent: Instance, name: string, pos: Vector3, lookAtPos: Vector3): Part
	local a = Instance.new("Part")
	a.Name = name
	a.Size = Vector3.new(4, 7, 1)
	a.CFrame = CFrame.lookAt(pos, lookAtPos)
	a.Transparency = 1
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Parent = parent
	return a
end

-- Builds a solid wall OR doorway wall along the X or Z perimeter of a rectangular bay
local function buildWallSpan(
	model: Model,
	namePrefix: string,
	center: Vector3,
	spanLen: number,
	alongX: boolean,
	hasDoor: boolean,
	theme: ThemeDef
)
	local wallCenterY = WALL_H / 2
	if not hasDoor then
		local sz = if alongX then Vector3.new(spanLen, WALL_H, WALL_T) else Vector3.new(WALL_T, WALL_H, spanLen)
		makePart(
			model,
			"Wall_" .. namePrefix,
			sz,
			CFrame.new(center.X, wallCenterY, center.Z),
			theme.wallColor,
			theme.wallMat,
			true
		)
		return
	end

	local wingLen = math.max(0.5, (spanLen - DOOR_W) / 2)
	local wingOffset = (spanLen + DOOR_W) / 4
	local lintelH = WALL_H - DOOR_H
	local lintelCenterY = DOOR_H + lintelH / 2

	if alongX then
		makePart(
			model,
			"Wall_" .. namePrefix .. "_L",
			Vector3.new(wingLen, WALL_H, WALL_T),
			CFrame.new(center.X - wingOffset, wallCenterY, center.Z),
			theme.wallColor,
			theme.wallMat,
			true
		)
		makePart(
			model,
			"Wall_" .. namePrefix .. "_R",
			Vector3.new(wingLen, WALL_H, WALL_T),
			CFrame.new(center.X + wingOffset, wallCenterY, center.Z),
			theme.wallColor,
			theme.wallMat,
			true
		)
		makePart(
			model,
			"Wall_" .. namePrefix .. "_Lintel",
			Vector3.new(DOOR_W, lintelH, WALL_T),
			CFrame.new(center.X, lintelCenterY, center.Z),
			theme.wallColor,
			theme.wallMat,
			true
		)
	else
		makePart(
			model,
			"Wall_" .. namePrefix .. "_L",
			Vector3.new(WALL_T, WALL_H, wingLen),
			CFrame.new(center.X, wallCenterY, center.Z - wingOffset),
			theme.wallColor,
			theme.wallMat,
			true
		)
		makePart(
			model,
			"Wall_" .. namePrefix .. "_R",
			Vector3.new(WALL_T, WALL_H, wingLen),
			CFrame.new(center.X, wallCenterY, center.Z + wingOffset),
			theme.wallColor,
			theme.wallMat,
			true
		)
		makePart(
			model,
			"Wall_" .. namePrefix .. "_Lintel",
			Vector3.new(WALL_T, lintelH, DOOR_W),
			CFrame.new(center.X, lintelCenterY, center.Z),
			theme.wallColor,
			theme.wallMat,
			true
		)
	end
end

local function addCeilingFixture(model: Model, pos: Vector3, theme: ThemeDef, rng: Random)
	makePart(model, "LampHousing", Vector3.new(1.6, 0.3, 0.6), CFrame.new(pos), theme.trimColor, theme.trimMat, false)
	local bulb = makePart(
		model,
		"LampBulb",
		Vector3.new(1.2, 0.14, 0.36),
		CFrame.new(pos - Vector3.new(0, 0.18, 0)),
		theme.lightColor,
		Enum.Material.Neon,
		false
	)
	bulb.CastShadow = false
	local pl = Instance.new("PointLight")
	pl.Color = theme.lightColor
	pl.Range = 22 + rng:NextInteger(0, 6)
	pl.Brightness = theme.lightBrightness
	pl.Shadows = false
	pl.Parent = bulb
end

function MazeVariations.buildModularPiece(kind: string, theme: ThemeDef, rng: Random): Model
	local dims: { [string]: { w: number, d: number, n: boolean, s: boolean, e: boolean, wOpen: boolean, exitFace: string } } =
		{
			CrossHub = { w = 24, d = 24, n = true, s = true, e = true, wOpen = true, exitFace = "N" },
			TJunctionL = { w = 22, d = 22, n = false, s = true, e = true, wOpen = true, exitFace = "W" },
			TJunctionR = { w = 22, d = 22, n = false, s = true, e = true, wOpen = true, exitFace = "E" },
			CornerLeft = { w = 18, d = 18, n = false, s = true, e = false, wOpen = true, exitFace = "W" },
			CornerRight = { w = 18, d = 18, n = false, s = true, e = true, wOpen = false, exitFace = "E" },
			SplitCourt = { w = 26, d = 26, n = true, s = true, e = true, wOpen = true, exitFace = "N" },
			StepGallery = { w = 22, d = 28, n = true, s = true, e = true, wOpen = true, exitFace = "N" },
			CorridorLong = { w = 14, d = 28, n = true, s = true, e = false, wOpen = false, exitFace = "N" },
			SideVault = { w = 18, d = 20, n = true, s = true, e = false, wOpen = false, exitFace = "N" },
			StorageBay = { w = 16, d = 18, n = true, s = true, e = false, wOpen = false, exitFace = "N" },
			DeadEndLab = { w = 20, d = 22, n = true, s = true, e = false, wOpen = false, exitFace = "N" },
		}

	local spec = dims[kind] or dims.SideVault
	local W, D = spec.w, spec.d

	local model = Instance.new("Model")
	model.Name = kind
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("ModularKind", kind)

	-- Floor (top at Y = 0) and Ceiling (bottom at Y = 11)
	makePart(model, "Floor", Vector3.new(W, 1, D), CFrame.new(0, -0.5, 0), theme.floorColor, theme.floorMat, true)
	makePart(
		model,
		"Ceiling",
		Vector3.new(W, 1, D),
		CFrame.new(0, WALL_H + 0.5, 0),
		theme.ceilingColor,
		theme.ceilingMat,
		true
	)

	-- Perimeter walls: -Z = South (Entrance), +Z = North, +X = East, -X = West
	buildWallSpan(model, "South", Vector3.new(0, 0, -D / 2 + 0.5), W, true, spec.s, theme)
	buildWallSpan(model, "North", Vector3.new(0, 0, D / 2 - 0.5), W, true, spec.n, theme)
	buildWallSpan(model, "East", Vector3.new(W / 2 - 0.5, 0, 0), D - 2, false, spec.e, theme)
	buildWallSpan(model, "West", Vector3.new(-W / 2 + 0.5, 0, 0), D - 2, false, spec.wOpen, theme)

	-- Structural ceiling beams & accent trim inside the room
	for _, z in { -D * 0.28, D * 0.28 } do
		makePart(
			model,
			"CeilingRib",
			Vector3.new(W - 2, 0.55, 0.65),
			CFrame.new(0, WALL_H - 0.3, z),
			theme.trimColor,
			theme.trimMat,
			false
		)
	end

	-- Kind-specific architectural highlights (center >= 8 studs wide stays clear for NPCs)
	if kind == "SplitCourt" or kind == "CrossHub" then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				makePart(
					model,
					"HubPillar",
					Vector3.new(1.6, WALL_H, 1.6),
					CFrame.new(sx * (W * 0.3), WALL_H / 2, sz * (D * 0.28)),
					theme.trimColor,
					theme.trimMat,
					true
				)
			end
		end
		makePart(
			model,
			"CenterGrate",
			Vector3.new(6.4, 0.08, 6.4),
			CFrame.new(0, 0.04, 0),
			theme.trimColor,
			Enum.Material.DiamondPlate,
			false
		)
	elseif kind == "StepGallery" then
		-- Raised flanking catwalk shelves outside center 12-stud walkway
		for _, sx in { -1, 1 } do
			makePart(
				model,
				"CatwalkLedge",
				Vector3.new(3.6, 1.4, D - 8),
				CFrame.new(sx * (W / 2 - 2.8), 0.7, 0),
				theme.trimColor,
				Enum.Material.DiamondPlate,
				true
			)
			makePart(
				model,
				"LedgeHazardTrim",
				Vector3.new(0.25, 0.16, D - 8),
				CFrame.new(sx * (W / 2 - 4.7), 1.42, 0),
				theme.accentColor,
				Enum.Material.Metal,
				false
			)
		end
	elseif kind == "CorridorLong" then
		makePart(
			model,
			"FloorGrateStrip",
			Vector3.new(2.8, 0.06, D - 4),
			CFrame.new(0, 0.03, 0),
			theme.trimColor,
			Enum.Material.DiamondPlate,
			false
		)
	elseif kind == "DeadEndLab" or kind == "SideVault" then
		makePart(
			model,
			"BasePlinthBand",
			Vector3.new(W - 2.2, 0.4, D - 2.2),
			CFrame.new(0, 0.2, 0),
			theme.trimColor,
			theme.trimMat,
			false
		).CanCollide =
			false
	end

	addCeilingFixture(model, Vector3.new(0, WALL_H - 0.15, 0), theme, rng)

	-- Standardized snapping anchors (LookVector faces INTO the room)
	makeAnchor(model, "Entrance", Vector3.new(0, 3.5, -D / 2), Vector3.new(0, 3.5, -D / 2 + 1))

	if spec.exitFace == "N" then
		makeAnchor(model, "Exit", Vector3.new(0, 3.5, D / 2), Vector3.new(0, 3.5, D / 2 - 1))
	elseif spec.exitFace == "W" then
		makeAnchor(model, "Exit", Vector3.new(-W / 2, 3.5, 0), Vector3.new(-W / 2 + 1, 3.5, 0))
	elseif spec.exitFace == "E" then
		makeAnchor(model, "Exit", Vector3.new(W / 2, 3.5, 0), Vector3.new(W / 2 - 1, 3.5, 0))
	end

	if spec.wOpen and spec.exitFace ~= "W" then
		makeAnchor(model, "BranchLeft", Vector3.new(-W / 2, 3.5, 0), Vector3.new(-W / 2 + 1, 3.5, 0))
	end
	if spec.e and spec.exitFace ~= "E" then
		makeAnchor(model, "BranchRight", Vector3.new(W / 2, 3.5, 0), Vector3.new(W / 2 - 1, 3.5, 0))
	end

	model.WorldPivot = CFrame.new(0, -0.5, 0)
	return model
end

--- Seals an unused Branch or leaf Exit doorway cleanly with a reinforced bulkhead.
function MazeVariations.sealSocket(room: Model, anchor: BasePart, theme: ThemeDef)
	local existing = room:FindFirstChild("BulkheadSeal_" .. anchor.Name)
	if existing then
		return
	end
	local seal = Instance.new("Model")
	seal.Name = "BulkheadSeal_" .. anchor.Name

	makePart(
		seal,
		"DoorLeaf",
		Vector3.new(DOOR_W, DOOR_H, 0.7),
		anchor.CFrame * CFrame.new(0, 0.1, -0.35),
		theme.trimColor,
		Enum.Material.DiamondPlate,
		true
	)
	makePart(
		seal,
		"DoorCrossbar",
		Vector3.new(DOOR_W - 0.8, 0.35, 0.9),
		anchor.CFrame * CFrame.new(0, 0.2, -0.45),
		theme.accentColor,
		Enum.Material.CorrodedMetal,
		false
	)
	local lamp = makePart(
		seal,
		"SealedIndicator",
		Vector3.new(0.7, 0.22, 0.2),
		anchor.CFrame * CFrame.new(0, 3.1, -0.85),
		Color3.fromRGB(196, 64, 52),
		Enum.Material.Neon,
		false
	)
	lamp.CastShadow = false
	seal.Parent = room
end

--------------------------------------------------------------------------------
-- Selective Material/Palette Re-Theming (safe on RoomTemplates & modular bays)
--------------------------------------------------------------------------------
function MazeVariations.applyTheme(room: Model, theme: ThemeDef, rng: Random)
	if room:GetAttribute("SafeRoom") == true then
		return
	end
	room:SetAttribute("ThemeName", theme.name)

	for _, desc in room:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name ~= "Entrance" and desc.Name ~= "Exit" then
			if desc.Name:find("Floor") then
				desc.Color = theme.floorColor
				desc.Material = theme.floorMat
			elseif desc.Name:find("Ceiling") then
				desc.Color = theme.ceilingColor
				desc.Material = theme.ceilingMat
			elseif desc.Name:find("Wall") then
				desc.Color = theme.wallColor
				desc.Material = theme.wallMat
			elseif
				desc.Name:find("Rib")
				or desc.Name:find("Post")
				or desc.Name:find("Rafter")
				or desc.Name:find("Pipe")
			then
				desc.Color = theme.trimColor
				desc.Material = theme.trimMat
			elseif desc.Name:find("Hazard") or desc.Name:find("Wainscot") then
				desc.Color = theme.accentColor
			elseif desc.Name:find("Bulb") or desc.Name:find("Sconce_Bulb") or desc.Name:find("Lamp") then
				if desc.Material == Enum.Material.Neon and desc.Name ~= "PassageLamp" then
					desc.Color = theme.lightColor
				end
			end
		elseif desc:IsA("PointLight") then
			local parent = desc.Parent
			if parent and parent.Name ~= "PassageLamp" then
				desc.Color = theme.lightColor
				desc.Brightness = theme.lightBrightness * (0.85 + rng:NextNumber() * 0.3)
			end
		elseif desc:IsA("ParticleEmitter") and desc.Name == "DustMotes" then
			desc.Color = ColorSequence.new(theme.dustColor)
		end
	end
end

--------------------------------------------------------------------------------
-- 8 Procedural Side-Wall / Corner Decoration Builders (never block nav paths)
--------------------------------------------------------------------------------
local function spawnDecorProp(parent: Folder, decorId: number, cf: CFrame, theme: ThemeDef, rng: Random)
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material, collide: boolean)
		return makePart(parent, name, size, cf * offset, color, mat, collide)
	end

	if decorId == 1 then
		-- Supply Crates & Barrels
		local crateMat = Color3.fromRGB(108, 82, 54)
		add("Crate", Vector3.new(2.2, 2.0, 2.2), CFrame.new(0, 1.0, -1.2), crateMat, Enum.Material.WoodPlanks, true)
		if rng:NextNumber() < 0.65 then
			add(
				"TopCrate",
				Vector3.new(1.5, 1.4, 1.5),
				CFrame.new(0.2, 2.7, -1.2) * CFrame.Angles(0, math.rad(rng:NextInteger(-18, 18)), 0),
				crateMat,
				Enum.Material.WoodPlanks,
				true
			)
		end
		local drum = add(
			"SteelDrum",
			Vector3.new(2.6, 1.6, 1.6),
			CFrame.new(1.5, 1.3, -1.1) * CFrame.Angles(0, 0, math.rad(90)),
			theme.accentColor,
			Enum.Material.CorrodedMetal,
			true
		)
		drum.Shape = Enum.PartType.Cylinder
	elseif decorId == 2 then
		-- Bio-Fungal Overgrowth
		local mossMat = Color3.fromRGB(46, 72, 46)
		add(
			"MossMound",
			Vector3.new(3.2, 0.35, 2.4),
			CFrame.new(0, 0.17, -1.2),
			mossMat,
			Enum.Material.LeafyGrass,
			false
		)
		for i = 1, 3 do
			local mx = (i - 2) * 0.65
			local h = 0.6 + rng:NextNumber() * 0.6
			add(
				"SporeStalk",
				Vector3.new(0.18, h, 0.18),
				CFrame.new(mx, h / 2, -1.1),
				Color3.fromRGB(184, 178, 152),
				Enum.Material.SmoothPlastic,
				false
			)
			local cap = add(
				"BioCap",
				Vector3.new(0.55, 0.3, 0.55),
				CFrame.new(mx, h + 0.15, -1.1),
				theme.lightColor,
				Enum.Material.Neon,
				false
			)
			cap.CastShadow = false
		end
	elseif decorId == 3 then
		-- Power Conduits & Breaker Cabinet
		add(
			"BreakerBox",
			Vector3.new(2.2, 3.4, 0.9),
			CFrame.new(0, 2.9, -0.5),
			theme.trimColor,
			Enum.Material.Metal,
			true
		)
		local led = add(
			"BreakerLED",
			Vector3.new(0.25, 0.25, 0.12),
			CFrame.new(0.6, 3.8, -0.98),
			Color3.fromRGB(96, 224, 122),
			Enum.Material.Neon,
			false
		)
		led.CastShadow = false
		add(
			"CableSpool",
			Vector3.new(1.6, 1.2, 1.6),
			CFrame.new(-1.3, 0.6, -1.2),
			Color3.fromRGB(36, 34, 32),
			Enum.Material.Wood,
			true
		)
	elseif decorId == 4 then
		-- Survey Field Archives
		local oak = Color3.fromRGB(84, 62, 42)
		add("ArchiveTable", Vector3.new(3.2, 0.22, 1.8), CFrame.new(0, 2.2, -1.0), oak, Enum.Material.WoodPlanks, true)
		for _, lx in { -1.3, 1.3 } do
			add(
				"TableLeg",
				Vector3.new(0.22, 2.1, 1.5),
				CFrame.new(lx, 1.05, -1.0),
				theme.trimColor,
				Enum.Material.Metal,
				true
			)
		end
		add(
			"PaperStack",
			Vector3.new(0.9, 0.25, 1.1),
			CFrame.new(-0.5, 2.42, -0.95) * CFrame.Angles(0, 0.3, 0),
			Color3.fromRGB(228, 218, 192),
			Enum.Material.SmoothPlastic,
			false
		)
	elseif decorId == 5 then
		-- Boilers & Steam Valves
		local tank = add(
			"PressureTank",
			Vector3.new(4.4, 1.8, 1.8),
			CFrame.new(0, 2.2, -1.0) * CFrame.Angles(0, 0, math.rad(90)),
			theme.trimColor,
			Enum.Material.CorrodedMetal,
			true
		)
		tank.Shape = Enum.PartType.Cylinder
		add(
			"ValveWheel",
			Vector3.new(0.75, 0.75, 0.2),
			CFrame.new(0, 2.6, -1.98),
			theme.accentColor,
			Enum.Material.Metal,
			false
		)
	elseif decorId == 6 then
		-- Lockdown Barricades
		for _, bx in { -1.1, 1.1 } do
			add(
				"Post",
				Vector3.new(0.24, 2.8, 0.24),
				CFrame.new(bx, 1.4, -1.3),
				theme.accentColor,
				Enum.Material.Metal,
				true
			)
		end
		add(
			"HazardRail",
			Vector3.new(3.0, 0.45, 0.18),
			CFrame.new(0, 2.2, -1.3),
			theme.accentColor,
			Enum.Material.CorrodedMetal,
			true
		)
	elseif decorId == 7 then
		-- Abandoned Quarters
		add(
			"BunkFrame",
			Vector3.new(4.2, 0.3, 2.1),
			CFrame.new(0, 1.1, -1.1),
			theme.trimColor,
			Enum.Material.Metal,
			true
		)
		add(
			"Mattress",
			Vector3.new(3.8, 0.35, 1.8),
			CFrame.new(0, 1.42, -1.1),
			Color3.fromRGB(118, 114, 102),
			Enum.Material.Fabric,
			false
		)
		add(
			"Footlocker",
			Vector3.new(1.6, 0.9, 1.0),
			CFrame.new(-1.3, 0.45, -2.5),
			Color3.fromRGB(64, 72, 54),
			Enum.Material.CorrodedMetal,
			true
		)
	else
		-- Anomaly Salvage Caches (R.E.P.O.-style brass/artifact crates)
		add(
			"SalvagePlinth",
			Vector3.new(2.2, 1.4, 1.8),
			CFrame.new(0, 0.7, -1.1),
			theme.trimColor,
			Enum.Material.Metal,
			true
		)
		local relic = add(
			"RelicCore",
			Vector3.new(0.95, 0.95, 0.95),
			CFrame.new(0, 1.9, -1.1) * CFrame.Angles(0.35, 0.7, 0.2),
			Color3.fromRGB(226, 178, 72),
			Enum.Material.Metal,
			false
		)
		local glint = add(
			"RelicGlow",
			Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(0, 1.9, -1.1),
			theme.lightColor,
			Enum.Material.Neon,
			false
		)
		glint.CastShadow = false
		local _ = relic
	end
end

function MazeVariations.decorateRoom(room: Model, decor: DecorDef, theme: ThemeDef, rng: Random, isEntryRoom: boolean)
	if room:GetAttribute("SafeRoom") == true or room:FindFirstChild("MazeDecor") then
		return
	end
	local entrance = room:FindFirstChild("Entrance")
	if not entrance or not entrance:IsA("BasePart") then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "MazeDecor"
	folder.Parent = room

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { room }
	rayParams.RespectCanCollide = true

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { room }
	overlapParams.RespectCanCollide = true

	local roomCF, roomSize = room:GetBoundingBox()
	local targetCount = rng:NextInteger(decor.minProps, decor.maxProps)
	local placedCount = 0

	-- Sample side-wall bays away from center patrol path & doorways
	local candidateDepths = { -roomSize.Z * 0.28, 0, roomSize.Z * 0.28, -roomSize.Z * 0.14, roomSize.Z * 0.14 }
	for _, zOff in candidateDepths do
		if placedCount >= targetCount then
			break
		end
		for _, side in { -1, 1 } do
			if placedCount >= targetCount then
				break
			end
			if rng:NextNumber() > 0.65 then
				continue
			end

			local probeCenter = roomCF.Position + roomCF.LookVector * zOff
			-- Keep Room_01 maintenance bay / lift zone and all doorways unobstructed
			if isEntryRoom and (probeCenter - entrance.Position).Magnitude < 14 then
				continue
			end
			if (probeCenter - entrance.Position).Magnitude < 7 then
				continue
			end

			local floorHit = Workspace:Raycast(probeCenter + Vector3.yAxis * 2, -Vector3.yAxis * 8, rayParams)
			if not floorHit or floorHit.Normal.Y < 0.88 then
				continue
			end

			local dir = roomCF.RightVector * side
			local wallHit =
				Workspace:Raycast(floorHit.Position + Vector3.yAxis * 2.5, dir * (roomSize.X * 0.6), rayParams)
			if
				not wallHit
				or wallHit.Distance < 5.2
				or math.abs(wallHit.Normal.Y) > 0.1
				or wallHit.Normal:Dot(dir) > -0.9
			then
				continue
			end

			local basePos = Vector3.new(wallHit.Position.X, floorHit.Position.Y, wallHit.Position.Z)
			local propCF = CFrame.lookAt(basePos, basePos + wallHit.Normal)
			-- Clear check: 4.4 wide x 4.2 tall x 2.6 deep footprint in front of wall must be clear & not near any Exit/Branch
			local nearDoor = false
			for _, child in room:GetChildren() do
				if (child.Name == "Exit" or child.Name:find("Branch")) and child:IsA("BasePart") then
					if (child.Position - basePos).Magnitude < 7.0 then
						nearDoor = true
						break
					end
				end
			end
			if nearDoor then
				continue
			end

			local checkCenter = propCF * CFrame.new(0, 2.2, -1.5)
			if #Workspace:GetPartBoundsInBox(checkCenter, Vector3.new(4.2, 4.0, 2.6), overlapParams) == 0 then
				spawnDecorProp(folder, decor.id, propCF, theme, rng)
				placedCount += 1
			end
		end
	end

	room:SetAttribute("DecorSet", decor.name)
end

return MazeVariations
