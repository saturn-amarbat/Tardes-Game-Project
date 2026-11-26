--!strict
--[[
  LobbyScene  –  SERVER procedural Dark Forest Lobby scene builder.

  Theme: Night dark forest, cool blue/teal fog, motivated sparse lighting,
  glinting eyes in trees, crashed car on outskirts, torn warning signs,
  scratch marks on trees, enclosed by dense dead trees + invisible walls.

  Layout:
    - Zone A (-X): Giant Frog Shopkeeper (3.5x player height) + wooden stall
    - Center (0): Spawn + central clearing with campfire & sit-able log benches
    - Zone B (+X): Play Circles (built by QueueService)

  Performance: Static anchored geometry, zero shadow-casting decorative lights
  (Single-Shadow friendly), capped particle emitters, Persistent StreamingEnabled model.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))

local LobbyScene = {}

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

local function makeEllipsoid(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material,
	collide: boolean
): Part
	local p = makePart(parent, name, size, cf, color, mat, collide)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local DIRT = Color3.fromRGB(46, 36, 26)
local DARK_DIRT = Color3.fromRGB(30, 22, 16)
local MOSS = Color3.fromRGB(36, 52, 32)
local DARK_WOOD = Color3.fromRGB(42, 30, 22)
local BARK = Color3.fromRGB(52, 38, 28)
local ROCK_GRAY = Color3.fromRGB(58, 62, 58)
local DARK_ROCK = Color3.fromRGB(38, 42, 38)
local IRON = Color3.fromRGB(50, 54, 56)
local LANTERN_GLOW = Color3.fromRGB(255, 184, 88)
local FROG_SKIN = Color3.fromRGB(42, 62, 38)
local FROG_DAMP = Color3.fromRGB(30, 44, 28)
local FROG_BELLY = Color3.fromRGB(72, 88, 54)
local FROG_EYE = Color3.fromRGB(218, 198, 72)
local MUSHROOM_CAP = Color3.fromRGB(78, 212, 138)
local FIRE_ORANGE = Color3.fromRGB(255, 126, 34)
local RUST = Color3.fromRGB(112, 62, 38)

--------------------------------------------------------------------------------
-- Lighting & Atmosphere
--------------------------------------------------------------------------------
local function setupLighting()
	local cfg = LobbyConfig.LIGHTING
	Lighting.ClockTime = cfg.ClockTime
	Lighting.Brightness = cfg.Brightness
	Lighting.Ambient = cfg.Ambient
	Lighting.OutdoorAmbient = cfg.OutdoorAmbient
	Lighting.ExposureCompensation = cfg.ExposureCompensation
	Lighting.FogColor = cfg.FogColor
	Lighting.FogStart = cfg.FogStart
	Lighting.FogEnd = cfg.FogEnd
	Lighting.GlobalShadows = true

	local sky = Lighting:FindFirstChild("LobbyNightSky")
	if not sky then
		local newSky = Instance.new("Sky")
		newSky.Name = "LobbyNightSky"
		newSky.CelestialBodiesShown = false
		newSky.StarCount = 120
		newSky.Parent = Lighting
	end

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	local atmoCfg = LobbyConfig.ATMOSPHERE
	atmo.Density = atmoCfg.Density
	atmo.Offset = atmoCfg.Offset
	atmo.Color = atmoCfg.Color
	atmo.Decay = atmoCfg.Decay
	atmo.Glare = atmoCfg.Glare
	atmo.Haze = atmoCfg.Haze

	local bloomInst = Lighting:FindFirstChild("LobbyBloom")
	local bloom: BloomEffect
	if bloomInst and bloomInst:IsA("BloomEffect") then
		bloom = bloomInst
	else
		local created = Instance.new("BloomEffect")
		created.Name = "LobbyBloom"
		created.Parent = Lighting
		bloom = created
	end
	local bloomCfg = LobbyConfig.BLOOM
	bloom.Intensity = bloomCfg.Intensity
	bloom.Size = bloomCfg.Size
	bloom.Threshold = bloomCfg.Threshold

	local ccInst = Lighting:FindFirstChild("LobbyCC")
	local cc: ColorCorrectionEffect
	if ccInst and ccInst:IsA("ColorCorrectionEffect") then
		cc = ccInst
	else
		local created = Instance.new("ColorCorrectionEffect")
		created.Name = "LobbyCC"
		created.Parent = Lighting
		cc = created
	end
	local ccCfg = LobbyConfig.COLOR_CORRECTION
	cc.Brightness = ccCfg.Brightness
	cc.Contrast = ccCfg.Contrast
	cc.Saturation = ccCfg.Saturation
	cc.TintColor = ccCfg.TintColor
end

--------------------------------------------------------------------------------
-- Ground, Path, Mud, Puddles, Leaf Litter
--------------------------------------------------------------------------------
local function buildGround(parent: Instance)
	-- Raised +0.04 studs so LobbyMap ground clears a co-located Place Baseplate (top at Y=0)
	makePart(parent, "Ground", Vector3.new(240, 2, 240), CFrame.new(0, -0.96, 0), DIRT, Enum.Material.Ground, true)

	-- Winding dirt path connecting Shop (-X) <-> Campfire (0) <-> Play Circles (+X)
	for x = -34, 34, 4 do
		local z = math.sin(x * 0.08) * 6 + 4
		local width = 7 + math.cos(x * 0.12) * 1.5
		makePart(
			parent,
			"PathSegment",
			Vector3.new(5.5, 0.14, width),
			CFrame.new(x, 0.07, z) * CFrame.Angles(0, math.rad(math.cos(x * 0.08) * 12), 0),
			DARK_DIRT,
			Enum.Material.Mud,
			false
		)
	end

	-- Leaf litter patches
	local litterPatches = {
		Vector3.new(-22, 0.05, 14),
		Vector3.new(-8, 0.05, -14),
		Vector3.new(14, 0.05, 18),
		Vector3.new(24, 0.05, -8),
		Vector3.new(-42, 0.05, -4),
		Vector3.new(10, 0.05, -22),
	}
	for i, pos in litterPatches do
		makePart(
			parent,
			"LeafLitter_" .. tostring(i),
			Vector3.new(7, 0.08, 6),
			CFrame.new(pos) * CFrame.Angles(0, math.rad(i * 37), 0),
			Color3.fromRGB(54, 40, 24),
			Enum.Material.LeafyGrass,
			false
		)
	end

	-- Mud puddles
	local puddlePositions = {
		Vector3.new(-14, 0.06, 16),
		Vector3.new(10, 0.06, -4),
		Vector3.new(22, 0.06, 14),
		Vector3.new(-28, 0.06, -2),
	}
	for i, pos in puddlePositions do
		local puddle = makePart(
			parent,
			"Puddle_" .. tostring(i),
			Vector3.new(4 + math.random() * 2.5, 0.08, 3 + math.random() * 2),
			CFrame.new(pos) * CFrame.Angles(0, math.rad(i * 29), 0),
			Color3.fromRGB(22, 28, 34),
			Enum.Material.Glass,
			false
		)
		puddle.Reflectance = 0.35
		puddle.Transparency = 0.35
	end
end

--------------------------------------------------------------------------------
-- Dead & Twisted Trees + Hanging Roots
--------------------------------------------------------------------------------
local function buildTree(parent: Instance, pos: Vector3, height: number, lean: number, hasHangingRoots: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "Tree"
	folder.Parent = parent

	local trunkCF = CFrame.new(pos.X, pos.Y + height / 2, pos.Z)
		* CFrame.Angles(math.rad(lean), math.rad(math.random(0, 360)), 0)
		* CFrame.Angles(0, 0, math.rad(90))
	local radius = 0.75 + height * 0.04
	local trunk =
		makePart(folder, "Trunk", Vector3.new(height, radius * 2, radius * 2), trunkCF, BARK, Enum.Material.Wood, true)
	trunk.Shape = Enum.PartType.Cylinder

	local branchCount = math.random(2, 3)
	for b = 1, branchCount do
		local bHeight = height * (0.45 + b * 0.14)
		local bAngle = math.rad(math.random(0, 360))
		local bLean = math.rad(32 + math.random(0, 35))
		local bLen = 3.5 + math.random() * 3.5
		local bCF = CFrame.new(pos.X, pos.Y + bHeight, pos.Z)
			* CFrame.Angles(0, bAngle, 0)
			* CFrame.Angles(bLean, 0, 0)
			* CFrame.new(0, bLen / 2, 0)
		makePart(folder, "Branch", Vector3.new(0.45, bLen, 0.45), bCF, DARK_WOOD, Enum.Material.Wood, false)

		if hasHangingRoots and b == 1 then
			local tipPos = (bCF * CFrame.new(0, bLen * 0.4, 0)).Position
			makePart(
				folder,
				"HangingRoot",
				Vector3.new(0.18, 3.2, 0.18),
				CFrame.new(tipPos.X, tipPos.Y - 1.6, tipPos.Z),
				DARK_WOOD,
				Enum.Material.Wood,
				false
			)
		end
	end

	local canopySpread = 8.5 + math.random() * 3.5
	local canopyCF = CFrame.new(pos.X, pos.Y + height * 0.86, pos.Z) * CFrame.Angles(0, math.rad(math.random(0, 90)), 0)
	makeEllipsoid(
		folder,
		"Canopy",
		Vector3.new(canopySpread, 4.8 + math.random() * 1.8, canopySpread * 0.9),
		canopyCF,
		Color3.fromRGB(20, 30, 22),
		Enum.Material.LeafyGrass,
		false
	)
	makeEllipsoid(
		folder,
		"CanopyTop",
		Vector3.new(canopySpread * 0.62, 4.2 + math.random() * 1.4, canopySpread * 0.62),
		canopyCF * CFrame.new(math.random(-1, 1), 2.8, math.random(-1, 1)),
		Color3.fromRGB(16, 24, 18),
		Enum.Material.LeafyGrass,
		false
	)
end

local function buildTrees(parent: Instance)
	local treeFolder = Instance.new("Folder")
	treeFolder.Name = "Trees"
	treeFolder.Parent = parent

	-- Outer boundary ring 1
	local radius = LobbyConfig.MAP_RADIUS
	for angle = 0, 350, 8 do
		local rad = math.rad(angle)
		local r = radius + math.random(-6, 6)
		local x = math.cos(rad) * r
		local z = math.sin(rad) * r
		buildTree(treeFolder, Vector3.new(x, 0, z), 18 + math.random(0, 12), math.random(-8, 8), false)
	end

	-- Outer boundary ring 2 (sightline blocker)
	for angle = 4, 354, 12 do
		local rad = math.rad(angle)
		local r = radius + 12 + math.random(-4, 4)
		local x = math.cos(rad) * r
		local z = math.sin(rad) * r
		buildTree(treeFolder, Vector3.new(x, 0, z), 22 + math.random(0, 10), math.random(-5, 5), false)
	end

	-- Interior twisted trees framing Shop / Clearing / Play Circles without blocking paths
	local interiorTrees = {
		Vector3.new(-20, 0, -18),
		Vector3.new(-16, 0, 28),
		Vector3.new(15, 0, 26),
		Vector3.new(22, 0, -32),
		Vector3.new(-52, 0, -18),
		Vector3.new(-56, 0, 26),
		Vector3.new(58, 0, 22),
		Vector3.new(10, 0, -35),
		Vector3.new(-28, 0, -28),
		Vector3.new(44, 0, 32),
		Vector3.new(-8, 0, 34),
		Vector3.new(62, 0, -18),
	}
	for i, pos in interiorTrees do
		buildTree(treeFolder, pos, 15 + math.random(0, 9), math.random(-12, 12), i % 3 == 0)
	end
end

--------------------------------------------------------------------------------
-- Mossy Rocks & Perimeter Cliffs
--------------------------------------------------------------------------------
local function buildRocks(parent: Instance)
	local rockFolder = Instance.new("Folder")
	rockFolder.Name = "Rocks"
	rockFolder.Parent = parent

	local rockPositions = {
		{ pos = Vector3.new(-18, 0, 2), size = Vector3.new(4, 2.4, 3.2) },
		{ pos = Vector3.new(14, 0, 20), size = Vector3.new(3.2, 2, 4) },
		{ pos = Vector3.new(-35, 0, -14), size = Vector3.new(5, 3, 4) },
		{ pos = Vector3.new(24, 0, 6), size = Vector3.new(3, 1.5, 3) },
		{ pos = Vector3.new(-10, 0, -25), size = Vector3.new(4, 2.2, 3.5) },
		{ pos = Vector3.new(48, 0, -26), size = Vector3.new(4, 2.4, 3.4) },
		{ pos = Vector3.new(-48, 0, 26), size = Vector3.new(4.2, 2.5, 4) },
	}

	for i, r in rockPositions do
		local color = if i % 2 == 0 then ROCK_GRAY else DARK_ROCK
		local rock = makePart(
			rockFolder,
			"Rock_" .. tostring(i),
			r.size,
			CFrame.new(r.pos + Vector3.new(0, r.size.Y / 2, 0))
				* CFrame.Angles(math.rad(math.random(-8, 8)), math.rad(math.random(0, 90)), 0),
			color,
			Enum.Material.Basalt,
			true
		)
		makePart(
			rockFolder,
			"Moss_" .. tostring(i),
			Vector3.new(r.size.X * 0.82, 0.16, r.size.Z * 0.82),
			rock.CFrame * CFrame.new(0, r.size.Y / 2 + 0.08, 0),
			MOSS,
			Enum.Material.LeafyGrass,
			false
		)
	end

	-- Perimeter cliff mounds to block low-angle map-edge peeking
	for angle = 0, 330, 30 do
		local rad = math.rad(angle)
		local dist = LobbyConfig.MAP_RADIUS + 8
		makePart(
			rockFolder,
			"CliffMound",
			Vector3.new(26, 12, 14),
			CFrame.new(math.cos(rad) * dist, 5, math.sin(rad) * dist) * CFrame.Angles(0, -rad + math.pi / 2, 0),
			DARK_ROCK,
			Enum.Material.Slate,
			true
		)
	end
end

--------------------------------------------------------------------------------
-- Campfire & Sit-able Gathering Logs + Directional Signposts
--------------------------------------------------------------------------------
local function buildCampfire(parent: Instance)
	local cf = CFrame.new(LobbyConfig.CAMPFIRE_POSITION)
	local fireFolder = Instance.new("Folder")
	fireFolder.Name = "Campfire"
	fireFolder.Parent = parent

	for angle = 0, 330, 30 do
		local rad = math.rad(angle)
		local x = math.cos(rad) * 3
		local z = math.sin(rad) * 3
		makePart(
			fireFolder,
			"Stone",
			Vector3.new(1.2, 0.8, 1.2),
			cf * CFrame.new(x, 0.4, z) * CFrame.Angles(0, rad, 0),
			DARK_ROCK,
			Enum.Material.Basalt,
			true
		)
	end

	-- Sit-able log benches around the campfire
	local logAngles = { 45, 165, 285 }
	for i, angle in logAngles do
		local rad = math.rad(angle)
		local x = math.cos(rad) * 5.8
		local z = math.sin(rad) * 5.8
		local logCF = CFrame.lookAt((cf * CFrame.new(x, 0.6, z)).Position, (cf * CFrame.new(0, 0.6, 0)).Position)

		makePart(fireFolder, "Log_" .. tostring(i), Vector3.new(5.2, 1.2, 1.3), logCF, BARK, Enum.Material.Wood, true)

		-- Real Seat on top of each log facing the campfire
		local seat = Instance.new("Seat")
		seat.Name = "BenchSeat_" .. tostring(i)
		seat.Size = Vector3.new(2.2, 0.3, 1.2)
		seat.CFrame = logCF * CFrame.new(0, 0.65, 0)
		seat.Transparency = 1
		seat.Anchored = true
		seat.CanCollide = false
		seat.Parent = fireFolder
	end

	local fireCore = makePart(
		fireFolder,
		"FireCore",
		Vector3.new(1.4, 1.9, 1.4),
		cf * CFrame.new(0, 1.15, 0),
		FIRE_ORANGE,
		Enum.Material.Neon,
		false
	)
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 162, 64)
	fireLight.Range = 36
	fireLight.Brightness = 2.4
	fireLight.Shadows = false
	fireLight.Parent = fireCore

	-- Sparse trail lantern posts guiding between Spawn, Zone A (Shop), and Zone B (Play Circles)
	for idx, lPos in { Vector3.new(-18, 0, 10), Vector3.new(20, 0, 2), Vector3.new(0, 0, -14) } do
		makePart(
			fireFolder,
			"TrailPost_" .. tostring(idx),
			Vector3.new(0.4, 7.5, 0.4),
			CFrame.new(lPos + Vector3.new(0, 3.75, 0)),
			DARK_WOOD,
			Enum.Material.Wood,
			true
		)
		local bulb = makePart(
			fireFolder,
			"TrailLantern_" .. tostring(idx),
			Vector3.new(0.7, 0.9, 0.7),
			CFrame.new(lPos + Vector3.new(0, 7.2, 0)),
			LANTERN_GLOW,
			Enum.Material.Neon,
			false
		)
		local lgt = Instance.new("PointLight")
		lgt.Color = Color3.fromRGB(255, 180, 92)
		lgt.Range = 22
		lgt.Brightness = 0.95
		lgt.Shadows = false
		lgt.Parent = bulb
	end

	-- Low-rate spark emitter (capped for mobile 60fps)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "CampfireSparks"
	sparks.Rate = 5
	sparks.Lifetime = NumberRange.new(1.0, 2.0)
	sparks.Speed = NumberRange.new(1.5, 3.5)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 165, 65), Color3.fromRGB(255, 75, 25))
	sparks.LightEmission = 1
	sparks.Parent = fireCore

	for i = 1, 4 do
		makePart(
			fireFolder,
			"Ember_" .. tostring(i),
			Vector3.new(0.28, 0.28, 0.28),
			cf * CFrame.new(math.random() * 1.8 - 0.9, 0.4 + math.random() * 1.2, math.random() * 1.8 - 0.9),
			Color3.fromRGB(255, 95, 25),
			Enum.Material.Neon,
			false
		)
	end

	makePart(
		fireFolder,
		"AshBase",
		Vector3.new(3.2, 0.2, 3.2),
		cf * CFrame.new(0, 0.1, 0),
		Color3.fromRGB(18, 18, 18),
		Enum.Material.Slate,
		false
	)

	local sound = Instance.new("Sound")
	sound.Name = "CampfireSound"
	sound.SoundId = LobbyConfig.AUDIO.CampfireCrackle
	sound.Volume = 0.35
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 42
	sound.Parent = fireCore
	sound:Play()

	-- Directional sightline signposts (matching reference image 1 navigation)
	local function addSignpost(name: string, pos: CFrame, labelText: string)
		makePart(
			fireFolder,
			name .. "_Post",
			Vector3.new(0.35, 4.5, 0.35),
			pos * CFrame.new(0, 2.25, 0),
			DARK_WOOD,
			Enum.Material.Wood,
			true
		)
		local board = makePart(
			fireFolder,
			name .. "_Board",
			Vector3.new(4.2, 1.1, 0.22),
			pos * CFrame.new(0, 3.9, 0),
			DARK_WOOD,
			Enum.Material.Wood,
			false
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(360, 96)
		gui.MaxDistance = 55
		gui.LightInfluence = 0.4
		gui.Parent = board
		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundTransparency = 1
		txt.Text = labelText
		txt.TextColor3 = Color3.fromRGB(234, 206, 144)
		txt.Font = Enum.Font.Fondamento
		txt.TextSize = 36
		txt.TextStrokeColor3 = Color3.fromRGB(8, 10, 10)
		txt.TextStrokeTransparency = 0.25
		txt.Parent = gui
	end

	addSignpost("ShopSign", CFrame.new(-10, 0, -2) * CFrame.Angles(0, math.rad(-25), 0), "← FROG SHOP")
	addSignpost("QueueSign", CFrame.new(10, 0, -2) * CFrame.Angles(0, math.rad(25), 0), "PLAY CIRCLES →")
end

--------------------------------------------------------------------------------
-- Zone A: Giant Frog Shopkeeper + Ramshackle Stall (-Z local forward)
--------------------------------------------------------------------------------
local function buildFrog(parent: Instance): Model
	local cf = LobbyConfig.FROG_POSITION
	local frogModel = Instance.new("Model")
	frogModel.Name = "FrogShopkeeper"
	frogModel.Parent = parent

	-- Squat, broad, unsettling frog (~13 studs tall at brow, ~15 wide) tucked behind counter
	local body = makeEllipsoid(
		frogModel,
		"Body",
		Vector3.new(11, 7.2, 10),
		cf * CFrame.new(0, 3.8, 0.8) * CFrame.Angles(math.rad(-12), 0, 0),
		FROG_SKIN,
		Enum.Material.SmoothPlastic,
		true
	)
	body.Reflectance = 0.08
	frogModel.PrimaryPart = body

	local belly = makeEllipsoid(
		frogModel,
		"Belly",
		Vector3.new(7.4, 5.4, 4.2),
		cf * CFrame.new(0, 3.4, -2.6) * CFrame.Angles(math.rad(-14), 0, 0),
		FROG_BELLY,
		Enum.Material.SmoothPlastic,
		false
	)
	belly.Reflectance = 0.05

	-- Throat sac (animated by LobbyFrogController)
	local throat = makeEllipsoid(
		frogModel,
		"Throat",
		Vector3.new(6.4, 2.8, 4.2),
		cf * CFrame.new(0, 5.7, -3.4),
		FROG_BELLY,
		Enum.Material.SmoothPlastic,
		false
	)
	throat.Reflectance = 0.08

	-- Movable Head subtree tucked low into shoulders (animated & turns toward player)
	local headModel = Instance.new("Model")
	headModel.Name = "HeadRig"
	headModel.Parent = frogModel

	local head = makeEllipsoid(
		headModel,
		"Head",
		Vector3.new(10.6, 4.4, 8.2),
		cf * CFrame.new(0, 7.9, -1.6),
		FROG_SKIN,
		Enum.Material.SmoothPlastic,
		false
	)
	head.Reflectance = 0.09
	headModel.PrimaryPart = head

	local snout = makeEllipsoid(
		headModel,
		"Snout",
		Vector3.new(9.6, 3.0, 5.2),
		cf * CFrame.new(0, 7.2, -3.8),
		FROG_SKIN,
		Enum.Material.SmoothPlastic,
		false
	)
	snout.Reflectance = 0.09

	-- Wide unsettling mouth slit tucked cleanly inside snout curve
	makePart(
		headModel,
		"MouthSlit",
		Vector3.new(5.4, 0.24, 0.8),
		cf * CFrame.new(0, 6.9, -5.6),
		Color3.fromRGB(16, 18, 16),
		Enum.Material.SmoothPlastic,
		false
	)

	-- Hidden tongue inside jaw (flicks out occasionally)
	local tongue = makePart(
		headModel,
		"Tongue",
		Vector3.new(0.8, 0.26, 3.4),
		cf * CFrame.new(0, 6.9, -4.2),
		Color3.fromRGB(148, 68, 76),
		Enum.Material.SmoothPlastic,
		false
	)
	tongue.Reflectance = 0.12

	-- Wide glossy bulging eyes seated into the brow with horizontal slit pupils + eyelids
	for idx, side in { -3.1, 3.1 } do
		local eyeTag = if idx == 1 then "L" else "R"
		local eyeBase = makePart(
			headModel,
			"EyeOrb_" .. eyeTag,
			Vector3.new(2.5, 2.5, 2.5),
			cf * CFrame.new(side, 9.2, -2.6),
			FROG_EYE,
			Enum.Material.SmoothPlastic,
			false
		)
		eyeBase.Shape = Enum.PartType.Ball
		eyeBase.Reflectance = 0.22

		local pupil = makePart(
			headModel,
			"Pupil_" .. eyeTag,
			Vector3.new(1.5, 0.5, 0.45),
			cf * CFrame.new(side, 9.2, -3.7),
			Color3.fromRGB(8, 8, 6),
			Enum.Material.SmoothPlastic,
			false
		)
		pupil.Reflectance = 0.15

		local gloss = makePart(
			headModel,
			"EyeGloss_" .. eyeTag,
			Vector3.new(0.45, 0.45, 0.25),
			cf * CFrame.new(side - 0.35, 9.7, -3.75),
			Color3.fromRGB(255, 255, 240),
			Enum.Material.Neon,
			false
		)
		gloss.CastShadow = false

		makeEllipsoid(
			headModel,
			"Eyelid_" .. eyeTag,
			Vector3.new(2.65, 0.48, 2.65),
			cf * CFrame.new(side, 10.35, -2.6),
			FROG_DAMP,
			Enum.Material.SmoothPlastic,
			false
		)
	end

	-- Damp skin mottling & warts
	local warts = {
		{ Vector3.new(3.2, 5.2, -3.4), Vector3.new(1.4, 1.1, 0.9) },
		{ Vector3.new(-3.6, 4.6, -3.2), Vector3.new(1.3, 1.0, 0.9) },
		{ Vector3.new(-2.4, 3.0, -3.6), Vector3.new(1.6, 0.9, 0.7) },
		{ Vector3.new(4.2, 5.6, 0.4), Vector3.new(1.5, 1.4, 1.4) },
	}
	for i, w in warts do
		local spot = makeEllipsoid(
			frogModel,
			"Wart_" .. tostring(i),
			w[2],
			cf * CFrame.new(w[1]),
			FROG_DAMP,
			Enum.Material.SmoothPlastic,
			false
		)
		spot.Reflectance = 0.12
	end

	-- Sprawled front arms & thick folded hind thighs
	for _, side in { -5.1, 5.1 } do
		makePart(
			frogModel,
			"FrontLeg",
			Vector3.new(2.4, 2.4, 5.2),
			cf * CFrame.new(side, 1.2, -3.6),
			FROG_SKIN,
			Enum.Material.SmoothPlastic,
			true
		)
		for f = -1, 1 do
			makePart(
				frogModel,
				"Toe",
				Vector3.new(0.58, 0.36, 2.0),
				cf * CFrame.new(side + f * 0.78, 0.25, -6.2),
				FROG_DAMP,
				Enum.Material.SmoothPlastic,
				false
			)
		end
		makeEllipsoid(
			frogModel,
			"BackLeg",
			Vector3.new(4.2, 4.6, 5.8),
			cf * CFrame.new(side * 1.18, 2.3, 1.6),
			FROG_SKIN,
			Enum.Material.SmoothPlastic,
			true
		)
	end

	-- Ramshackle wooden shop stall
	local stall = Instance.new("Folder")
	stall.Name = "ShopStall"
	stall.Parent = frogModel

	local counter = makePart(
		stall,
		"Counter",
		Vector3.new(15, 3.0, 2.4),
		cf * CFrame.new(0, 1.5, -8.2),
		DARK_WOOD,
		Enum.Material.Wood,
		true
	)

	makePart(
		stall,
		"BackWall",
		Vector3.new(17, 15, 1),
		cf * CFrame.new(0, 7.5, 5.5),
		DARK_WOOD,
		Enum.Material.Wood,
		true
	)
	for _, side in { -8.5, 8.5 } do
		makePart(
			stall,
			"SideWall",
			Vector3.new(1, 14, 12),
			cf * CFrame.new(side, 7, -0.5),
			DARK_WOOD,
			Enum.Material.Wood,
			true
		)
		makePart(
			stall,
			"FrontPost",
			Vector3.new(0.9, 14.5, 0.9),
			cf * CFrame.new(side * 0.92, 7.25, -7.8),
			DARK_WOOD,
			Enum.Material.Wood,
			true
		)
	end
	makePart(
		stall,
		"Roof",
		Vector3.new(19, 0.6, 15.5),
		cf * CFrame.new(0, 15.6, -1.2) * CFrame.Angles(math.rad(-6), 0, 0),
		IRON,
		Enum.Material.CorrodedMetal,
		false
	)

	-- Hanging lanterns mounted outside the frog's face sightline on outer posts
	for _, lx in { -7.4, 7.4 } do
		makePart(
			stall,
			"LanternCord",
			Vector3.new(0.12, 2.8, 0.12),
			cf * CFrame.new(lx, 13.4, -8.2),
			IRON,
			Enum.Material.Metal,
			false
		)
		local lantern = makePart(
			stall,
			"Lantern",
			Vector3.new(0.9, 1.2, 0.9),
			cf * CFrame.new(lx, 11.7, -8.2),
			LANTERN_GLOW,
			Enum.Material.Neon,
			false
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 186, 92)
		light.Range = 28
		light.Brightness = 1.6
		light.Shadows = false
		light.Parent = lantern
	end

	-- Interior stall ceiling lamp gently illuminating the Frog Merchant's face
	makePart(
		stall,
		"CeilingLampCord",
		Vector3.new(0.12, 1.4, 0.12),
		cf * CFrame.new(0, 14.3, -5.5),
		IRON,
		Enum.Material.Metal,
		false
	)
	local ceilingLamp = makePart(
		stall,
		"InteriorLamp",
		Vector3.new(0.8, 0.7, 0.8),
		cf * CFrame.new(0, 13.4, -5.5),
		LANTERN_GLOW,
		Enum.Material.Neon,
		false
	)
	local interiorLight = Instance.new("PointLight")
	interiorLight.Color = Color3.fromRGB(255, 198, 128)
	interiorLight.Range = 24
	interiorLight.Brightness = 1.4
	interiorLight.Shadows = false
	interiorLight.Parent = ceilingLamp

	-- Specimen jars on the counter
	for i = 1, 4 do
		local jar = makePart(
			stall,
			"Jar_" .. tostring(i),
			Vector3.new(0.75, 1.15, 0.75),
			cf * CFrame.new(-5.2 + i * 2.1, 3.58, -8.2),
			Color3.fromRGB(96, 124, 90),
			Enum.Material.Glass,
			false
		)
		jar.Transparency = 0.28
	end

	-- Prompt mounted directly on the front counter for crisp reach across PC/Mobile/Console
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrowseShopPrompt"
	prompt.ActionText = "Browse Shop"
	prompt.ObjectText = "Frog Merchant"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	local croak = Instance.new("Sound")
	croak.Name = "FrogCroak"
	croak.SoundId = LobbyConfig.AUDIO.FrogCroak
	croak.Volume = 0.45
	croak.RollOffMode = Enum.RollOffMode.InverseTapered
	croak.RollOffMinDistance = 8
	croak.RollOffMaxDistance = 40
	croak.Parent = head

	return frogModel
end

--------------------------------------------------------------------------------
-- Glowing Mushrooms & Firefly Emitters
--------------------------------------------------------------------------------
local function buildMushroomsAndFireflies(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Mushrooms"
	folder.Parent = parent

	local positions = {
		Vector3.new(-22, 0, 14),
		Vector3.new(-16, 0, -8),
		Vector3.new(18, 0, 18),
		Vector3.new(-48, 0, 5),
		Vector3.new(38, 0, 12),
		Vector3.new(-6, 0, -18),
		Vector3.new(52, 0, -8),
		Vector3.new(-32, 0, 20),
	}

	for i, pos in positions do
		local clusterFolder = Instance.new("Folder")
		clusterFolder.Name = "Cluster_" .. tostring(i)
		clusterFolder.Parent = folder

		local count = math.random(2, 4)
		for m = 1, count do
			local offset = Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)
			local stemH = 0.6 + math.random() * 0.8
			local capR = 0.4 + math.random() * 0.45

			makePart(
				clusterFolder,
				"Stem",
				Vector3.new(0.24, stemH, 0.24),
				CFrame.new(pos + offset + Vector3.new(0, stemH / 2, 0)),
				Color3.fromRGB(192, 196, 180),
				Enum.Material.SmoothPlastic,
				false
			)
			local cap = makePart(
				clusterFolder,
				"Cap",
				Vector3.new(capR * 2.2, capR * 0.9, capR * 2.2),
				CFrame.new(pos + offset + Vector3.new(0, stemH + capR * 0.2, 0)),
				Color3.fromRGB(72, 168, 128),
				Enum.Material.Neon,
				false
			)
			cap.Shape = Enum.PartType.Ball
			if m == 1 and i % 2 == 1 then
				local glow = Instance.new("PointLight")
				glow.Color = Color3.fromRGB(72, 168, 128)
				glow.Range = 9
				glow.Brightness = 0.42
				glow.Shadows = false
				glow.Parent = cap
			end
		end
	end

	-- 2 capped firefly emitters along the clearing edges
	for idx, fPos in { Vector3.new(-18, 3, 2), Vector3.new(18, 3, 6) } do
		local anchor = makePart(
			folder,
			"FireflyZone_" .. tostring(idx),
			Vector3.new(16, 4, 16),
			CFrame.new(fPos),
			MUSHROOM_CAP,
			Enum.Material.SmoothPlastic,
			false
		)
		anchor.Transparency = 1
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Fireflies"
		emitter.Rate = 4
		emitter.Lifetime = NumberRange.new(3, 5)
		emitter.Speed = NumberRange.new(0.4, 1.1)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.14)
		emitter.Color = ColorSequence.new(Color3.fromRGB(168, 244, 134))
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.LightEmission = 1
		emitter.Parent = anchor
	end
end

--------------------------------------------------------------------------------
-- Horror Outskirts Details & Spatial Sound Emitters
--------------------------------------------------------------------------------
local function buildHorrorDetails(parent: Instance)
	local detailFolder = Instance.new("Folder")
	detailFolder.Name = "HorrorDetails"
	detailFolder.Parent = parent

	-- Broken crashed car on outskirts
	local carFolder = Instance.new("Folder")
	carFolder.Name = "CrashedCar"
	carFolder.Parent = detailFolder

	local carCF = CFrame.new(-58, 0, -34) * CFrame.Angles(0, math.rad(35), math.rad(-10))
	makePart(
		carFolder,
		"CarBody",
		Vector3.new(7.5, 3.8, 13),
		carCF * CFrame.new(0, 2.3, 0),
		RUST,
		Enum.Material.CorrodedMetal,
		true
	)
	makePart(
		carFolder,
		"Windshield",
		Vector3.new(5.8, 2.8, 0.25),
		carCF * CFrame.new(0, 4.3, 4.6) * CFrame.Angles(math.rad(-25), 0, 0),
		Color3.fromRGB(28, 32, 36),
		Enum.Material.Glass,
		false
	)
	for _, wz in { -4.2, 4.2 } do
		makePart(
			carFolder,
			"Wheel",
			Vector3.new(0.8, 2.4, 2.4),
			carCF * CFrame.new(4.2, 1.1, wz),
			Color3.fromRGB(20, 20, 20),
			Enum.Material.SmoothPlastic,
			true
		)
	end

	-- Torn warning signs
	local signTexts = {
		{ pos = CFrame.new(-24, 0, -32) * CFrame.Angles(0, math.rad(15), 0), text = "KEEP OUT" },
		{ pos = CFrame.new(20, 0, -38) * CFrame.Angles(0, math.rad(-20), 0), text = "DANGER" },
		{ pos = CFrame.new(-52, 0, 18) * CFrame.Angles(0, math.rad(70), 0), text = "NO ENTRY" },
	}
	for _, sign in signTexts do
		local signFolder = Instance.new("Folder")
		signFolder.Name = "WarnSign"
		signFolder.Parent = detailFolder

		makePart(
			signFolder,
			"Post",
			Vector3.new(0.38, 5, 0.38),
			sign.pos * CFrame.new(0, 2.5, 0),
			DARK_WOOD,
			Enum.Material.Wood,
			true
		)
		local board = makePart(
			signFolder,
			"Board",
			Vector3.new(4.2, 2, 0.28),
			sign.pos * CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, math.rad(math.random(-8, 8))),
			DARK_WOOD,
			Enum.Material.Wood,
			false
		)

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(300, 160)
		gui.MaxDistance = 45
		gui.LightInfluence = 0.35
		gui.Parent = board
		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundTransparency = 1
		txt.Text = sign.text
		txt.TextColor3 = Color3.fromRGB(192, 58, 48)
		txt.Font = Enum.Font.Creepster
		txt.TextSize = 58
		txt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		txt.TextStrokeTransparency = 0.35
		txt.Rotation = math.random(-5, 5)
		txt.Parent = gui
	end

	-- Glinting eyes between outer trees
	local eyePositions = {
		Vector3.new(-66, 4.2, 8),
		Vector3.new(72, 3.6, -15),
		Vector3.new(-52, 5.0, -42),
		Vector3.new(66, 4.0, 30),
	}
	for _, pos in eyePositions do
		for _, offset in { -0.35, 0.35 } do
			local eye = makePart(
				detailFolder,
				"GlintEye",
				Vector3.new(0.14, 0.1, 0.1),
				CFrame.new(pos + Vector3.new(offset, 0, 0)),
				FROG_EYE,
				Enum.Material.Neon,
				false
			)
			eye.Transparency = 0.25
		end
	end

	-- Scratch marks on interior trees
	local scratchPositions = {
		CFrame.new(-20, 3, -16.8),
		CFrame.new(15, 2.5, 24.8),
	}
	for _, scf in scratchPositions do
		for s = 0, 2 do
			makePart(
				detailFolder,
				"Scratch",
				Vector3.new(0.14, 2.4, 0.08),
				scf * CFrame.new(s * 0.38 - 0.38, 0, 0) * CFrame.Angles(0, 0, math.rad(math.random(-5, 5))),
				Color3.fromRGB(20, 15, 10),
				Enum.Material.SmoothPlastic,
				false
			)
		end
	end

	-- Spatial 3D forest sound emitters (far-off owl + branch cracks)
	local owlPart = makePart(
		detailFolder,
		"OwlEmitter",
		Vector3.new(1, 1, 1),
		CFrame.new(-64, 14, -22),
		DARK_WOOD,
		Enum.Material.SmoothPlastic,
		false
	)
	owlPart.Transparency = 1
	local owlSound = Instance.new("Sound")
	owlSound.Name = "OwlHoot"
	owlSound.SoundId = LobbyConfig.AUDIO.OwlHoot
	owlSound.Volume = 0.28
	owlSound.RollOffMode = Enum.RollOffMode.InverseTapered
	owlSound.RollOffMinDistance = 18
	owlSound.RollOffMaxDistance = 115
	owlSound.Parent = owlPart

	local crackPart = makePart(
		detailFolder,
		"CrackEmitter",
		Vector3.new(1, 1, 1),
		CFrame.new(62, 4, 26),
		DARK_WOOD,
		Enum.Material.SmoothPlastic,
		false
	)
	crackPart.Transparency = 1
	local crackSound = Instance.new("Sound")
	crackSound.Name = "BranchCrack"
	crackSound.SoundId = LobbyConfig.AUDIO.BranchCrack
	crackSound.Volume = 0.3
	crackSound.RollOffMode = Enum.RollOffMode.InverseTapered
	crackSound.RollOffMinDistance = 16
	crackSound.RollOffMaxDistance = 110
	crackSound.Parent = crackPart
end

--------------------------------------------------------------------------------
-- Boundary Walls & Spawn & Ground Clutter
--------------------------------------------------------------------------------
local function buildBoundary(parent: Instance)
	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "Boundary"
	wallFolder.Parent = parent

	local radius = LobbyConfig.BOUNDARY_RADIUS
	local segments = 24
	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local nextAngle = ((i + 1) / segments) * math.pi * 2
		local midAngle = (angle + nextAngle) / 2
		local x = math.cos(midAngle) * radius
		local z = math.sin(midAngle) * radius

		local wallWidth = 2 * radius * math.sin(math.pi / segments) + 2
		local wall = Instance.new("Part")
		wall.Name = "BoundaryWall"
		wall.Size = Vector3.new(wallWidth, 40, 2)
		wall.CFrame = CFrame.new(x, 20, z) * CFrame.Angles(0, -midAngle + math.pi / 2, 0)
		wall.Transparency = 1
		wall.Anchored = true
		wall.CanCollide = true
		wall.CanTouch = false
		wall.CanQuery = false
		wall.Parent = wallFolder
	end
end

local function buildSpawn(parent: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Enabled = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(LobbyConfig.SPAWN_POSITION)
	spawn.Color = DIRT
	spawn.Material = Enum.Material.Ground
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.CanTouch = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = parent
end

local function buildGroundClutter(parent: Instance)
	local clutterFolder = Instance.new("Folder")
	clutterFolder.Name = "GroundClutter"
	clutterFolder.Parent = parent

	local logPositions = {
		{ CFrame.new(-30, 0.6, 18) * CFrame.Angles(0, math.rad(40), math.rad(5)), Vector3.new(8, 1.4, 1.4) },
		{ CFrame.new(35, 0.5, 24) * CFrame.Angles(0, math.rad(-30), 0), Vector3.new(6, 1.2, 1.2) },
		{ CFrame.new(-10, 0.4, -30) * CFrame.Angles(0, math.rad(70), math.rad(-3)), Vector3.new(10, 1, 1) },
	}
	for i, log in logPositions do
		makePart(clutterFolder, "FallenLog_" .. tostring(i), log[2], log[1], BARK, Enum.Material.Wood, true)
	end

	local grassPositions = {
		Vector3.new(-14, 0, 10),
		Vector3.new(8, 0, -14),
		Vector3.new(-40, 0, -8),
		Vector3.new(28, 0, -6),
		Vector3.new(-5, 0, 25),
		Vector3.new(50, 0, 8),
	}
	for i, pos in grassPositions do
		local grassClump = Instance.new("Folder")
		grassClump.Name = "Grass_" .. tostring(i)
		grassClump.Parent = clutterFolder

		for _ = 1, math.random(4, 7) do
			local offset = Vector3.new(math.random() * 3 - 1.5, 0, math.random() * 3 - 1.5)
			local h = 1.4 + math.random() * 1.3
			makePart(
				grassClump,
				"Blade",
				Vector3.new(0.15, h, 0.1),
				CFrame.new(pos + offset + Vector3.new(0, h / 2, 0))
					* CFrame.Angles(math.rad(math.random(-10, 10)), math.rad(math.random(0, 360)), 0),
				Color3.fromRGB(30 + math.random(0, 18), 46 + math.random(0, 14), 24 + math.random(0, 10)),
				Enum.Material.Grass,
				false
			)
		end
	end
end

local function startSpatialAudioLoops(map: Instance)
	local frog = map:FindFirstChild("FrogShopkeeper")
	local headRig = if frog then frog:FindFirstChild("HeadRig") else nil
	local head = if headRig then headRig:FindFirstChild("Head") else nil
	local croak = if head then head:FindFirstChild("FrogCroak") else nil
	if croak and croak:IsA("Sound") then
		task.spawn(function()
			while croak.Parent and map.Parent do
				task.wait(8 + math.random() * 11)
				if croak.Parent then
					croak.PlaybackSpeed = 0.9 + math.random() * 0.16
					croak:Play()
				end
			end
		end)
	end

	local details = map:FindFirstChild("HorrorDetails")
	local owlPart = if details then details:FindFirstChild("OwlEmitter") else nil
	local owlSound = if owlPart then owlPart:FindFirstChild("OwlHoot") else nil
	if owlSound and owlSound:IsA("Sound") then
		task.spawn(function()
			while owlSound.Parent and map.Parent do
				task.wait(16 + math.random() * 24)
				if owlSound.Parent then
					owlSound.PlaybackSpeed = 0.92 + math.random() * 0.14
					owlSound:Play()
				end
			end
		end)
	end

	local crackPart = if details then details:FindFirstChild("CrackEmitter") else nil
	local crackSound = if crackPart then crackPart:FindFirstChild("BranchCrack") else nil
	if crackSound and crackSound:IsA("Sound") then
		task.spawn(function()
			while crackSound.Parent and map.Parent do
				task.wait(22 + math.random() * 32)
				if crackSound.Parent then
					crackSound.PlaybackSpeed = 0.85 + math.random() * 0.2
					crackSound:Play()
				end
			end
		end)
	end

	local campfire = map:FindFirstChild("Campfire")
	local fireCore = if campfire then campfire:FindFirstChild("FireCore") else nil
	local fireSound = if fireCore then fireCore:FindFirstChild("CampfireSound") else nil
	if fireSound and fireSound:IsA("Sound") and not fireSound.IsPlaying then
		fireSound:Play()
	end
end

function LobbyScene.build()
	setupLighting()

	local existing = Workspace:FindFirstChild("LobbyMap")
	if existing and existing:IsA("Model") then
		existing.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		startSpatialAudioLoops(existing)
		print("[LobbyScene] Attached to authored Workspace.LobbyMap.")
		return
	end

	local map = Instance.new("Model")
	map.Name = "LobbyMap"
	map.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	map.Parent = Workspace

	buildGround(map)
	buildTrees(map)
	buildRocks(map)
	buildCampfire(map)
	buildFrog(map)
	buildMushroomsAndFireflies(map)
	buildHorrorDetails(map)
	buildBoundary(map)
	buildSpawn(map)
	buildGroundClutter(map)
	startSpatialAudioLoops(map)

	print("[LobbyScene] Dark Forest Lobby built. Instances: " .. tostring(#map:GetDescendants()))
end

return LobbyScene
