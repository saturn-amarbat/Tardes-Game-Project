--!strict
--[[
  PrefabLibrary  –  Manages ServerStorage/BunkerPrefabs for modular 32x32 grid assembly.

  Reuses committed .rbxm prefabs (assets/BunkerPrefabs -> ServerStorage/BunkerPrefabs)
  and bootstraps contract-compliant prefabs for any missing entries so Studio / empty
  environments never fail.

  All dimensions come strictly from Config:
    - CELL = 32, DOOR_W = 8, DOOR_H = 9, WALL_H = 12, WALL_T = 1, HALL_W = 16
    - Every prefab has PrimaryPart "Floor" sized (CELL, 1, CELL) at (0, -0.5, 0)
    - All walls sit strictly inside [-CELL/2, +CELL/2] with ZERO part overlap
    - Base doorway orientations:
        HallDeadEnd  : N
        HallCorner   : N + E
        HallStraight : N + S
        HallT        : N + E + W
        HallCross    : N + E + S + W
        All Room_*   : N (Entrance LookVector into room interior)
]]

local ServerStorage = game:GetService("ServerStorage")

local Config = require(script.Parent.Config)
local DoorResolver = require(script.Parent.DoorResolver)
local PrefabValidator = require(script.Parent.PrefabValidator)

local PrefabLibrary = {}

local CELL = Config.CELL
local HALF = CELL / 2 -- 16
local WALL_H = Config.WALL_H -- 12
local WALL_T = Config.WALL_T -- 1
local DOOR_W = Config.DOOR_W -- 8
local DOOR_H = Config.DOOR_H -- 9
local HALL_W = Config.HALL_W -- 16
local HALL_HALF = HALL_W / 2 -- 8

local CONCRETE = Color3.fromRGB(64, 66, 62)
local DARK_STEEL = Color3.fromRGB(48, 52, 50)
local RUST = Color3.fromRGB(84, 62, 48)
local FLOOR_COL = Color3.fromRGB(54, 56, 54)
local WOOD = Color3.fromRGB(72, 48, 34)
local LAMP_WARM = Color3.fromRGB(246, 198, 122)

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
	p.CanQuery = collide
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeMarker(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = makePart(parent, name, size, cf, Color3.fromRGB(200, 120, 40), Enum.Material.SmoothPlastic, false)
	p.Transparency = 1
	p.CanQuery = false
	return p
end

local function addCeilingLamp(model: Model, yPos: number, zPos: number, color: Color3, brightness: number)
	makePart(
		model,
		"LampHousing",
		Vector3.new(1.8, 0.28, 0.6),
		CFrame.new(0, yPos, zPos),
		DARK_STEEL,
		Enum.Material.Metal,
		false
	)
	local bulb = makePart(
		model,
		"LampBulb",
		Vector3.new(1.3, 0.14, 0.36),
		CFrame.new(0, yPos - 0.16, zPos),
		color,
		Enum.Material.Neon,
		false
	)
	bulb.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 26
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = bulb
end

-- Wall panel inside [-HALF, +HALF] with optional centered doorway of DOOR_W x DOOR_H.
-- Flanks & lintel never overlap each other.
local function addPerimeterWall(
	model: Model,
	prefix: string,
	pos: Vector3,
	spanLen: number,
	alongX: boolean,
	hasDoor: boolean,
	wallColor: Color3,
	wallMat: Enum.Material
)
	local wy = WALL_H / 2
	if not hasDoor then
		local sz = if alongX then Vector3.new(spanLen, WALL_H, WALL_T) else Vector3.new(WALL_T, WALL_H, spanLen)
		makePart(model, "Wall_" .. prefix, sz, CFrame.new(pos.X, wy, pos.Z), wallColor, wallMat, true)
		return
	end

	local flank = (spanLen - DOOR_W) / 2
	assert(flank > 0, string.format("Doorway %.1f exceeds spanLen %.1f for %s", DOOR_W, spanLen, prefix))
	local offset = (DOOR_W + flank) / 2
	local lintelH = WALL_H - DOOR_H
	local lintelY = DOOR_H + lintelH / 2

	if alongX then
		makePart(
			model,
			"Wall_" .. prefix .. "_L",
			Vector3.new(flank, WALL_H, WALL_T),
			CFrame.new(pos.X - offset, wy, pos.Z),
			wallColor,
			wallMat,
			true
		)
		makePart(
			model,
			"Wall_" .. prefix .. "_R",
			Vector3.new(flank, WALL_H, WALL_T),
			CFrame.new(pos.X + offset, wy, pos.Z),
			wallColor,
			wallMat,
			true
		)
		makePart(
			model,
			"Wall_" .. prefix .. "_Lintel",
			Vector3.new(DOOR_W, lintelH, WALL_T),
			CFrame.new(pos.X, lintelY, pos.Z),
			wallColor,
			wallMat,
			true
		)
	else
		makePart(
			model,
			"Wall_" .. prefix .. "_L",
			Vector3.new(WALL_T, WALL_H, flank),
			CFrame.new(pos.X, wy, pos.Z - offset),
			wallColor,
			wallMat,
			true
		)
		makePart(
			model,
			"Wall_" .. prefix .. "_R",
			Vector3.new(WALL_T, WALL_H, flank),
			CFrame.new(pos.X, wy, pos.Z + offset),
			wallColor,
			wallMat,
			true
		)
		makePart(
			model,
			"Wall_" .. prefix .. "_Lintel",
			Vector3.new(WALL_T, lintelH, DOOR_W),
			CFrame.new(pos.X, lintelY, pos.Z),
			wallColor,
			wallMat,
			true
		)
	end
end

local function buildHallPrefab(name: string, doorMask: number, isStartTile: boolean, addMonsterSpawn: boolean): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local openN = bit32.band(doorMask, DoorResolver.N) ~= 0
	local openE = bit32.band(doorMask, DoorResolver.E) ~= 0
	local openS = bit32.band(doorMask, DoorResolver.S) ~= 0
	local openW = bit32.band(doorMask, DoorResolver.W) ~= 0

	-- Uniform (CELL, 1, CELL) Floor as PrimaryPart so every tile snaps cleanly edge-to-edge
	local floor = makePart(
		m,
		"Floor",
		Vector3.new(CELL, 1, CELL),
		CFrame.new(0, -0.5, 0),
		FLOOR_COL,
		Enum.Material.Concrete,
		true
	)
	m.PrimaryPart = floor

	-- Narrower corridor ceiling hub spanning [-HALL_HALF, +HALL_HALF]
	makePart(
		m,
		"Ceiling",
		Vector3.new(HALL_W, 1, HALL_W),
		CFrame.new(0, WALL_H + 0.5, 0),
		DARK_STEEL,
		Enum.Material.CorrodedMetal,
		true
	)

	-- Dedicated 1xWALL_Hx1 corner columns at ±(HALL_HALF - 0.5) guarantee 0 wall overlap in every mask configuration
	local postOff = HALL_HALF - WALL_T / 2 -- 7.5
	local postH = WALL_H
	makePart(
		m,
		"Post_NW",
		Vector3.new(WALL_T, postH, WALL_T),
		CFrame.new(-postOff, postH / 2, -postOff),
		CONCRETE,
		Enum.Material.Concrete,
		true
	)
	makePart(
		m,
		"Post_NE",
		Vector3.new(WALL_T, postH, WALL_T),
		CFrame.new(postOff, postH / 2, -postOff),
		CONCRETE,
		Enum.Material.Concrete,
		true
	)
	makePart(
		m,
		"Post_SW",
		Vector3.new(WALL_T, postH, WALL_T),
		CFrame.new(-postOff, postH / 2, postOff),
		CONCRETE,
		Enum.Material.Concrete,
		true
	)
	makePart(
		m,
		"Post_SE",
		Vector3.new(WALL_T, postH, WALL_T),
		CFrame.new(postOff, postH / 2, postOff),
		CONCRETE,
		Enum.Material.Concrete,
		true
	)

	local innerSpan = HALL_W - 2 * WALL_T -- 14 (sits cleanly between corner posts)
	local armLen = HALF - HALL_HALF -- 8 (reaches from ±8 out to exact ±16 cell boundary)
	local armMid = HALL_HALF + armLen / 2 -- 12
	local doorPlaneDist = HALF - WALL_T / 2 -- 15.5 (door wall flush inside [-16, +16])

	local function handleSide(dir: number, open: boolean)
		if not open then
			if dir == DoorResolver.N then
				addPerimeterWall(
					m,
					"N_Closed",
					Vector3.new(0, 0, -postOff),
					innerSpan,
					true,
					false,
					CONCRETE,
					Enum.Material.Concrete
				)
			elseif dir == DoorResolver.S then
				addPerimeterWall(
					m,
					"S_Closed",
					Vector3.new(0, 0, postOff),
					innerSpan,
					true,
					false,
					CONCRETE,
					Enum.Material.Concrete
				)
			elseif dir == DoorResolver.E then
				addPerimeterWall(
					m,
					"E_Closed",
					Vector3.new(postOff, 0, 0),
					innerSpan,
					false,
					false,
					CONCRETE,
					Enum.Material.Concrete
				)
			elseif dir == DoorResolver.W then
				addPerimeterWall(
					m,
					"W_Closed",
					Vector3.new(-postOff, 0, 0),
					innerSpan,
					false,
					false,
					CONCRETE,
					Enum.Material.Concrete
				)
			end
			return
		end

		if dir == DoorResolver.N then
			makePart(
				m,
				"ArmN_Ceiling",
				Vector3.new(HALL_W, 1, armLen),
				CFrame.new(0, WALL_H + 0.5, -armMid),
				DARK_STEEL,
				Enum.Material.CorrodedMetal,
				true
			)
			makePart(
				m,
				"ArmN_WallL",
				Vector3.new(WALL_T, WALL_H, armLen),
				CFrame.new(-postOff, WALL_H / 2, -armMid),
				CONCRETE,
				Enum.Material.Concrete,
				true
			)
			makePart(
				m,
				"ArmN_WallR",
				Vector3.new(WALL_T, WALL_H, armLen),
				CFrame.new(postOff, WALL_H / 2, -armMid),
				CONCRETE,
				Enum.Material.Concrete,
				true
			)
			addPerimeterWall(
				m,
				"N_Door",
				Vector3.new(0, 0, -doorPlaneDist),
				innerSpan,
				true,
				true,
				CONCRETE,
				Enum.Material.Concrete
			)
		elseif dir == DoorResolver.S then
			makePart(
				m,
				"ArmS_Ceiling",
				Vector3.new(HALL_W, 1, armLen),
				CFrame.new(0, WALL_H + 0.5, armMid),
				DARK_STEEL,
				Enum.Material.CorrodedMetal,
				true
			)
			makePart(
				m,
				"ArmS_WallL",
				Vector3.new(WALL_T, WALL_H, armLen),
				CFrame.new(-postOff, WALL_H / 2, armMid),
				CONCRETE,
				Enum.Material.Concrete,
				true
			)
			makePart(
				m,
				"ArmS_WallR",
				Vector3.new(WALL_T, WALL_H, armLen),
				CFrame.new(postOff, WALL_H / 2, armMid),
				CONCRETE,
				Enum.Material.Concrete,
				true
			)
			addPerimeterWall(
				m,
				"S_Door",
				Vector3.new(0, 0, doorPlaneDist),
				innerSpan,
				true,
				true,
				CONCRETE,
				Enum.Material.Concrete
			)
		elseif dir == DoorResolver.E then
			makePart(
				m,
				"ArmE_Ceiling",
				Vector3.new(armLen, 1, HALL_W),
				CFrame.new(armMid, WALL_H + 0.5, 0),
				DARK_STEEL,
				Enum.Material.CorrodedMetal,
				true
			)
			makePart(
				m,
				"ArmE_WallN",
				Vector3.new(armLen, WALL_H, WALL_T),
				CFrame.new(armMid, WALL_H / 2, -postOff),
				CONCRETE,
				Enum.Material.Concrete,
				true
			)
			makePart(
				m,
				"ArmE_WallS",
				Vector3.new(armLen, WALL_H, WALL_T),
				CFrame.new(armMid, WALL_H / 2, postOff),
				CONCRETE,
				Enum.Material.Concrete,
				true
			)
			addPerimeterWall(
				m,
				"E_Door",
				Vector3.new(doorPlaneDist, 0, 0),
				innerSpan,
				false,
				true,
				CONCRETE,
				Enum.Material.Concrete
			)
		elseif dir == DoorResolver.W then
			makePart(
				m,
				"ArmW_Ceiling",
				Vector3.new(armLen, 1, HALL_W),
				CFrame.new(-armMid, WALL_H + 0.5, 0),
				DARK_STEEL,
				Enum.Material.CorrodedMetal,
				true
			)
			makePart(
				m,
				"ArmW_WallN",
				Vector3.new(armLen, WALL_H, WALL_T),
				CFrame.new(-armMid, WALL_H / 2, -postOff),
				CONCRETE,
				Enum.Material.Concrete,
				true
			)
			makePart(
				m,
				"ArmW_WallS",
				Vector3.new(armLen, WALL_H, WALL_T),
				CFrame.new(-armMid, WALL_H / 2, postOff),
				CONCRETE,
				Enum.Material.Concrete,
				true
			)
			addPerimeterWall(
				m,
				"W_Door",
				Vector3.new(-doorPlaneDist, 0, 0),
				innerSpan,
				false,
				true,
				CONCRETE,
				Enum.Material.Concrete
			)
		end
	end

	handleSide(DoorResolver.N, openN)
	handleSide(DoorResolver.E, openE)
	handleSide(DoorResolver.S, openS)
	handleSide(DoorResolver.W, openW)

	-- Overhead industrial conduit & warm bunker ceiling light
	makePart(
		m,
		"ConduitStripe",
		Vector3.new(0.25, 0.25, HALL_W - 2),
		CFrame.new(0, WALL_H - 0.35, 0),
		RUST,
		Enum.Material.CorrodedMetal,
		false
	)
	addCeilingLamp(m, WALL_H - 0.15, 0, LAMP_WARM, 0.78)

	if isStartTile then
		-- Base HallDeadEnd opens North (-Z): PlayerSpawn faces North (-Z) toward exit doorway
		makeMarker(
			m,
			"PlayerSpawn",
			Vector3.new(4, 1, 4),
			CFrame.lookAt(Vector3.new(0, 0.5, 1.5), Vector3.new(0, 0.5, -10))
		)
		makeMarker(
			m,
			"Entrance",
			Vector3.new(4, 7, 1),
			CFrame.lookAt(Vector3.new(0, 3.5, -doorPlaneDist), Vector3.new(0, 3.5, 0))
		)
	end
	if addMonsterSpawn then
		makeMarker(m, "MonsterSpawn", Vector3.new(2, 1, 2), CFrame.new(0, 0.5, 0))
	end

	m.WorldPivot = CFrame.new(0, -0.5, 0)
	return m
end

local function buildRoomPrefab(
	name: string,
	wallColor: Color3,
	wallMat: Enum.Material,
	floorColor: Color3,
	floorMat: Enum.Material
): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local isSafeRoom = (name == "Room_Safe")
	local isExitRoom = (name == "Room_Exit")
	if isSafeRoom then
		m:SetAttribute("SafeRoom", true)
		m:SetAttribute("SurveyDressing", false)
	end

	-- Full uniform CELL (32x32) room footprint with Floor as PrimaryPart
	local floor = makePart(m, "Floor", Vector3.new(CELL, 1, CELL), CFrame.new(0, -0.5, 0), floorColor, floorMat, true)
	m.PrimaryPart = floor
	makePart(
		m,
		"Ceiling",
		Vector3.new(CELL, 1, CELL),
		CFrame.new(0, WALL_H + 0.5, 0),
		DARK_STEEL,
		Enum.Material.CorrodedMetal,
		true
	)

	-- Base open doorway ALWAYS on North (-Z) edge centered inside [-HALF, +HALF]; E & W inset by 2*WALL_T for 0 corner overlap
	local doorPlaneDist = HALF - WALL_T / 2 -- 15.5
	addPerimeterWall(m, "North", Vector3.new(0, 0, -doorPlaneDist), CELL, true, true, wallColor, wallMat)
	addPerimeterWall(m, "South", Vector3.new(0, 0, doorPlaneDist), CELL, true, false, wallColor, wallMat)
	addPerimeterWall(m, "East", Vector3.new(doorPlaneDist, 0, 0), CELL - 2 * WALL_T, false, false, wallColor, wallMat)
	addPerimeterWall(m, "West", Vector3.new(-doorPlaneDist, 0, 0), CELL - 2 * WALL_T, false, false, wallColor, wallMat)

	-- Standardized Entrance anchor at North (-Z) threshold, LookVector (+Z) strictly INTO room interior
	makeMarker(
		m,
		"Entrance",
		Vector3.new(4, 7, 1),
		CFrame.lookAt(Vector3.new(0, 3.5, -doorPlaneDist), Vector3.new(0, 3.5, 0))
	)

	-- Distinct room furnishings (kept clear of center ClueSystem floor probe [-4..+4] and doorway thresholds)
	if name == "Room_Mirror" then
		local mirror = makePart(
			m,
			"CloudedMirror",
			Vector3.new(8.4, 7.2, 0.35),
			CFrame.new(0, 5.2, HALF - WALL_T - 0.35),
			Color3.fromRGB(64, 72, 68),
			Enum.Material.Glass,
			true
		)
		mirror.Reflectance = 0.35
		makePart(
			m,
			"MirrorFrame",
			Vector3.new(9.2, 7.8, 0.25),
			CFrame.new(0, 5.2, HALF - WALL_T - 0.15),
			WOOD,
			Enum.Material.Wood,
			false
		)
		makePart(
			m,
			"BrokenChair",
			Vector3.new(2.4, 2.2, 2.4),
			CFrame.new(-10.5, 1.1, 7.5),
			WOOD,
			Enum.Material.Wood,
			true
		)
		addCeilingLamp(m, WALL_H - 0.15, 2, Color3.fromRGB(190, 214, 198), 0.78)
	elseif name == "Room_ModelSlot" then
		makePart(
			m,
			"Pedestal",
			Vector3.new(5.2, 2.0, 5.2),
			CFrame.new(0, 1.0, 7.5),
			Color3.fromRGB(58, 62, 60),
			Enum.Material.Slate,
			true
		)
		makeMarker(m, "ModelSlot", Vector3.new(2.5, 1, 2.5), CFrame.new(0, 2.2, 7.5))
		addCeilingLamp(m, WALL_H - 0.15, 7.5, Color3.fromRGB(255, 184, 108), 0.9)
	elseif isExitRoom then
		-- Exit marker on South interior face, LookVector (-Z) pointing INTO the room for ExitGate bulkhead & ExitLever_A/B
		makeMarker(
			m,
			"Exit",
			Vector3.new(4, 7, 1),
			CFrame.lookAt(Vector3.new(0, 3.5, HALF - WALL_T - 0.6), Vector3.new(0, 3.5, 0))
		)
		-- Keep X in [-6, +6], Z >= 10 completely clear for ExitDoor BlastLeaf + ExitLever_A/B (±4.2, -2.2)
		makePart(
			m,
			"BulkheadConduitL",
			Vector3.new(1.4, WALL_H - 1, 1.4),
			CFrame.new(-13.8, (WALL_H - 1) / 2, 13.8),
			DARK_STEEL,
			Enum.Material.Metal,
			true
		)
		makePart(
			m,
			"BulkheadConduitR",
			Vector3.new(1.4, WALL_H - 1, 1.4),
			CFrame.new(13.8, (WALL_H - 1) / 2, 13.8),
			DARK_STEEL,
			Enum.Material.Metal,
			true
		)
		addCeilingLamp(m, WALL_H - 0.15, 4, Color3.fromRGB(246, 178, 92), 0.92)
	elseif isSafeRoom then
		-- Spacious 30x30 sanctuary keeps SafeRoomService ToadMakerBooth (X = -7.6..-10.1) completely comfortable
		makePart(
			m,
			"SanctuaryRunner",
			Vector3.new(5.0, 0.08, 24),
			CFrame.new(0, 0.04, 0),
			Color3.fromRGB(72, 46, 40),
			Enum.Material.Fabric,
			false
		)
		addCeilingLamp(m, WALL_H - 0.15, 0, Color3.fromRGB(255, 204, 128), 1.2)
	elseif name == "Room_Generator" then
		makePart(
			m,
			"GeneratorUnit",
			Vector3.new(4.2, 4.0, 8.6),
			CFrame.new(10.8, 2.0, 2),
			RUST,
			Enum.Material.CorrodedMetal,
			true
		)
		makePart(
			m,
			"GaugePanel",
			Vector3.new(0.25, 1.4, 2.4),
			CFrame.new(8.6, 2.7, 2),
			Color3.fromRGB(168, 196, 134),
			Enum.Material.Neon,
			false
		)
		addCeilingLamp(m, WALL_H - 0.15, 0, LAMP_WARM, 0.85)
	elseif name == "Room_Flooded" then
		local water = makePart(
			m,
			"StandingWater",
			Vector3.new(CELL - 2.4, 0.18, CELL - 2.4),
			CFrame.new(0, 0.09, 0),
			Color3.fromRGB(36, 68, 66),
			Enum.Material.Glass,
			false
		)
		water.Transparency = 0.35
		addCeilingLamp(m, WALL_H - 0.15, 0, Color3.fromRGB(122, 224, 192), 0.78)
	else
		makePart(
			m,
			"SupplyCrate",
			Vector3.new(2.8, 2.4, 2.8),
			CFrame.new(11.2, 1.2, 8.5),
			WOOD,
			Enum.Material.WoodPlanks,
			true
		)
		makePart(
			m,
			"ShelfBacking",
			Vector3.new(6.2, 6.8, 1.4),
			CFrame.new(-11.2, 3.4, 4.5),
			WOOD,
			Enum.Material.Wood,
			true
		)
		addCeilingLamp(m, WALL_H - 0.15, 0, LAMP_WARM, 0.82)
	end

	-- Scripted ScareSpawn strictly inside non-Safe room interiors (never in hallways or SafeRoom)
	if not isSafeRoom then
		local scarePos = if isExitRoom
			then Vector3.new(-8.5, 0.5, 0)
			elseif name == "Room_ModelSlot" then Vector3.new(-6.5, 0.5, 5.5)
			else Vector3.new(0, 0.5, 4.5)
		makeMarker(m, "ScareSpawn", Vector3.new(2, 1, 2), CFrame.new(scarePos))
	end

	m.WorldPivot = CFrame.new(0, -0.5, 0)
	return m
end

PrefabLibrary.HALL_SPECS = {
	{ name = "HallDeadEnd", mask = DoorResolver.N, isStart = true, monsterSpawn = false },
	{ name = "HallCorner", mask = bit32.bor(DoorResolver.N, DoorResolver.E), isStart = false, monsterSpawn = false },
	{ name = "HallStraight", mask = bit32.bor(DoorResolver.N, DoorResolver.S), isStart = false, monsterSpawn = true },
	{
		name = "HallT",
		mask = bit32.bor(DoorResolver.N, DoorResolver.E, DoorResolver.W),
		isStart = false,
		monsterSpawn = true,
	},
	{ name = "HallCross", mask = 15, isStart = false, monsterSpawn = true },
}

PrefabLibrary.ROOM_SPECS = {
	{
		name = "Room_Mirror",
		wall = Color3.fromRGB(76, 54, 40),
		wallMat = Enum.Material.WoodPlanks,
		floor = FLOOR_COL,
		floorMat = Enum.Material.Concrete,
	},
	{
		name = "Room_ModelSlot",
		wall = Color3.fromRGB(64, 62, 58),
		wallMat = Enum.Material.Concrete,
		floor = FLOOR_COL,
		floorMat = Enum.Material.Slate,
	},
	{
		name = "Room_Exit",
		wall = Color3.fromRGB(58, 62, 56),
		wallMat = Enum.Material.Concrete,
		floor = FLOOR_COL,
		floorMat = Enum.Material.DiamondPlate,
	},
	{
		name = "Room_Safe",
		wall = Color3.fromRGB(68, 72, 68),
		wallMat = Enum.Material.Concrete,
		floor = FLOOR_COL,
		floorMat = Enum.Material.Concrete,
	},
	{
		name = "Room_Abandoned",
		wall = Color3.fromRGB(80, 56, 40),
		wallMat = Enum.Material.WoodPlanks,
		floor = Color3.fromRGB(52, 42, 34),
		floorMat = Enum.Material.WoodPlanks,
	},
	{
		name = "Room_Storage",
		wall = CONCRETE,
		wallMat = Enum.Material.Concrete,
		floor = FLOOR_COL,
		floorMat = Enum.Material.DiamondPlate,
	},
	{
		name = "Room_Fuse",
		wall = Color3.fromRGB(68, 76, 70),
		wallMat = Enum.Material.Concrete,
		floor = FLOOR_COL,
		floorMat = Enum.Material.Concrete,
	},
	{
		name = "Room_Flooded",
		wall = Color3.fromRGB(50, 64, 60),
		wallMat = Enum.Material.Slate,
		floor = Color3.fromRGB(40, 48, 46),
		floorMat = Enum.Material.Basalt,
	},
	{
		name = "Room_Study",
		wall = WOOD,
		wallMat = Enum.Material.WoodPlanks,
		floor = Color3.fromRGB(54, 38, 28),
		floorMat = Enum.Material.WoodPlanks,
	},
	{
		name = "Room_Generator",
		wall = DARK_STEEL,
		wallMat = Enum.Material.Metal,
		floor = Color3.fromRGB(44, 46, 50),
		floorMat = Enum.Material.DiamondPlate,
	},
	{
		name = "Room_Archive",
		wall = Color3.fromRGB(84, 78, 68),
		wallMat = Enum.Material.Concrete,
		floor = FLOOR_COL,
		floorMat = Enum.Material.Cobblestone,
	},
}

function PrefabLibrary.buildPrefabModel(name: string): Model?
	for _, spec in PrefabLibrary.HALL_SPECS do
		if spec.name == name then
			return buildHallPrefab(spec.name, spec.mask, spec.isStart, spec.monsterSpawn)
		end
	end
	for _, spec in PrefabLibrary.ROOM_SPECS do
		if spec.name == name then
			return buildRoomPrefab(spec.name, spec.wall, spec.wallMat, spec.floor, spec.floorMat)
		end
	end
	return nil
end

function PrefabLibrary.ensurePrefabs(rebuildAll: boolean?): Folder
	local existing = ServerStorage:FindFirstChild("BunkerPrefabs")
	local folder: Folder
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = "BunkerPrefabs"
		created.Parent = ServerStorage
		folder = created
	end

	local function ensure(name: string, factory: () -> Model)
		local old = folder:FindFirstChild(name)
		if old and rebuildAll then
			old:Destroy()
			old = nil
		end
		if not old then
			local m = factory()
			m.Name = name
			m.Parent = folder
		end
	end

	for _, spec in PrefabLibrary.HALL_SPECS do
		ensure(spec.name, function()
			return buildHallPrefab(spec.name, spec.mask, spec.isStart, spec.monsterSpawn)
		end)
	end

	for _, spec in PrefabLibrary.ROOM_SPECS do
		ensure(spec.name, function()
			return buildRoomPrefab(spec.name, spec.wall, spec.wallMat, spec.floor, spec.floorMat)
		end)
	end

	PrefabValidator.validateAll(folder)
	return folder
end

return PrefabLibrary
