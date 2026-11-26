--!strict
--[[
  FRONT-FACE SNAPPING RULE (read before editing anchor placement):
  ─────────────────────────────────────────────────────────────────
  Every room template or modular bay stores transparent anchor Parts:
    • Entrance           – sits at entry doorway (-Z_local), LookVector (+Z_model) INTO room.
    • Exit               – sits at main exit doorway, LookVector pointing INTO room.
    • BranchLeft / Right – optional hub/junction sockets, LookVector pointing INTO room.

  Snap algorithm (do NOT change sign or rotation):
    targetEntranceCF = parentSocket.CFrame * CFrame.Angles(0, math.pi, 0)
    newPivot = targetEntranceCF * (pivot:ToObjectSpace(entrance.CFrame)):Inverse()

  R.E.P.O.-Style Procedural Variation Engine:
    Delegates to MazeVariations (8 Themes x 8 Topologies x 8 Decoration Sets = 8^3 = 512
    unique variations), building multi-branching junctions, turns, side wings, and
    collision-verified wall props every time players start a game or expedition.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MazeVariations = require(script.Parent.MazeVariations)

local RoomGenerator = {}

export type Room = {
	model: Model,
	entrance: BasePart,
	exit: BasePart,
}

local function getRoomAnchors(room: Model): (BasePart?, BasePart?)
	local entrance = room:FindFirstChild("Entrance")
	local exit = room:FindFirstChild("Exit")
	if entrance and entrance:IsA("BasePart") and exit and exit:IsA("BasePart") then
		return entrance, exit
	end
	return nil, nil
end

local function getRoomTurnSign(entrance: BasePart, exit: BasePart): number
	local enterDir = entrance.CFrame.LookVector
	local exitTravelDir = -exit.CFrame.LookVector
	local crossY = enterDir:Cross(exitTravelDir).Y
	if crossY > 0.4 then
		return 1 -- Left turn
	elseif crossY < -0.4 then
		return -1 -- Right turn
	end
	return 0
end

local function addPassageLamp(room: Model, exitAnchor: BasePart, lightColor: Color3?)
	local lampColor = lightColor or Color3.fromRGB(245, 189, 103)
	local lamp = Instance.new("Part")
	lamp.Name = "PassageLamp"
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CanQuery = false
	lamp.CanTouch = false
	lamp.CastShadow = false
	lamp.Size = Vector3.new(0.9, 0.22, 0.22)
	lamp.Material = Enum.Material.Neon
	lamp.Color = lampColor
	lamp.CFrame = exitAnchor.CFrame * CFrame.new(0, exitAnchor.Size.Y / 2 + 2.45, -0.9)

	local bracket = Instance.new("Part")
	bracket.Name = "LampBracket"
	bracket.Anchored = true
	bracket.CanCollide = false
	bracket.CanQuery = false
	bracket.CanTouch = false
	bracket.Size = Vector3.new(1.3, 0.48, 0.28)
	bracket.Color = Color3.fromRGB(45, 40, 35)
	bracket.Material = Enum.Material.CorrodedMetal
	bracket.CFrame = lamp.CFrame * CFrame.new(0, 0, 0.16)
	bracket.Parent = room

	lamp.Parent = room
	local glow = Instance.new("PointLight")
	glow.Color = lampColor
	glow.Range = 12
	glow.Brightness = 0.65
	glow.Shadows = false
	glow.Parent = lamp
end

local function addDoorFrame(room: Model, anchor: BasePart, labelText: string?, sealBackDoorway: boolean?)
	local casing = Instance.new("Model")
	casing.Name = "DoorCasing_" .. anchor.Name
	local iron = Color3.fromRGB(64, 58, 50)
	local brass = Color3.fromRGB(166, 124, 66)

	local function trim(name: string, size: Vector3, offset: CFrame): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = size
		p.Color = iron
		p.Material = Enum.Material.CorrodedMetal
		p.CFrame = anchor.CFrame * offset
		p.Parent = casing
		return p
	end

	trim("CasingJambL", Vector3.new(0.5, 7, 1.1), CFrame.new(-2.35, 0, -0.55))
	trim("CasingJambR", Vector3.new(0.5, 7, 1.1), CFrame.new(2.35, 0, -0.55))
	trim("CasingHeader", Vector3.new(5.2, 0.6, 1.1), CFrame.new(0, 3.8, -0.55))

	local sill = trim("CasingSill", Vector3.new(4.6, 0.12, 1.2), CFrame.new(0, -anchor.Size.Y / 2 + 0.06, -0.55))
	sill.Material = Enum.Material.DiamondPlate
	sill.Color = Color3.fromRGB(52, 48, 44)

	local conduit = trim("ConduitRun", Vector3.new(5.2, 0.28, 0.28), CFrame.new(0, 5.05, -0.55))
	conduit.Color = Color3.fromRGB(38, 34, 30)

	local anchorCF = anchor.CFrame
	local minLeftX, maxRightX = 0, 0
	local ceilingBottomLocalY = 6.5
	local existingWallLeft = false
	local existingWallRight = false
	local infillColor = Color3.fromRGB(56, 58, 56)
	local infillMaterial = Enum.Material.Concrete

	for _, desc in room:GetDescendants() do
		if
			not desc:IsA("BasePart")
			or desc == anchor
			or desc.Name == "Entrance"
			or desc.Name == "Exit"
			or desc.Name:find("Branch")
		then
			continue
		end
		local lp = anchorCF:PointToObjectSpace(desc.Position)
		if math.abs(lp.Z) <= math.max(desc.Size.Z, desc.Size.X) * 0.5 + 2.0 then
			local rightAxis = math.abs(anchorCF:VectorToObjectSpace(desc.CFrame.RightVector).X)
			local halfSpanX = if rightAxis > 0.5 then desc.Size.X * 0.5 else desc.Size.Z * 0.5
			if desc.CanCollide and lp.Y < -2.0 and (desc.Name:find("Floor") or desc.Size.Y <= 1.5) then
				minLeftX = math.min(minLeftX, lp.X - halfSpanX)
				maxRightX = math.max(maxRightX, lp.X + halfSpanX)
			elseif desc.Name:find("Ceiling") and desc.CanCollide then
				ceilingBottomLocalY = math.max(ceilingBottomLocalY, lp.Y - desc.Size.Y * 0.5)
				infillColor = desc.Color
				infillMaterial = desc.Material
			elseif desc.Name:find("Wall") and desc.CanCollide and desc.Size.Y >= 4 then
				infillColor = desc.Color
				infillMaterial = desc.Material
				if math.abs(lp.Z) <= 1.2 and lp.X - halfSpanX <= -2.1 and lp.X + halfSpanX >= -2.5 then
					existingWallLeft = true
				end
				if math.abs(lp.Z) <= 1.2 and lp.X + halfSpanX >= 2.1 and lp.X - halfSpanX <= 2.5 then
					existingWallRight = true
				end
			end
		end
	end

	local floorLocalY = -anchor.Size.Y / 2
	local fullHeight = math.max(ceilingBottomLocalY - floorLocalY, 9.5)
	local centerY = floorLocalY + fullHeight / 2

	local function solidSeam(name: string, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = true
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = size
		p.Color = color
		p.Material = mat
		p.CFrame = anchor.CFrame * offset
		p.Parent = casing
	end

	if not existingWallLeft and minLeftX < -2.15 then
		local width = math.abs(minLeftX + 2.1) + 0.5
		local centerX = minLeftX + width * 0.5 - 0.5
		solidSeam(
			"SeamWallL",
			Vector3.new(width, fullHeight, 0.9),
			CFrame.new(centerX, centerY, -0.55),
			infillColor,
			infillMaterial
		)
	end
	if not existingWallRight and maxRightX > 2.15 then
		local width = math.abs(maxRightX - 2.1) + 0.5
		local centerX = maxRightX - width * 0.5 + 0.5
		solidSeam(
			"SeamWallR",
			Vector3.new(width, fullHeight, 0.9),
			CFrame.new(centerX, centerY, -0.55),
			infillColor,
			infillMaterial
		)
	end

	local lintelBottom = 3.5
	if ceilingBottomLocalY > lintelBottom + 0.1 then
		local lintelH = ceilingBottomLocalY - lintelBottom
		solidSeam(
			"SeamLintel",
			Vector3.new(4.8, lintelH, 0.9),
			CFrame.new(0, lintelBottom + lintelH * 0.5, -0.55),
			infillColor,
			infillMaterial
		)
	end

	if sealBackDoorway then
		solidSeam(
			"EntrySealDoor",
			Vector3.new(4.4, 7.2, 0.6),
			CFrame.new(0, 0.1, -0.35),
			Color3.fromRGB(48, 54, 52),
			Enum.Material.DiamondPlate
		)
	end

	if labelText then
		local plate = trim("StationPlate", Vector3.new(2.2, 0.62, 0.1), CFrame.new(0, 4.55, -1.15))
		plate.Color = brass
		plate.Material = Enum.Material.Metal
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(220, 62)
		gui.LightInfluence = 0.6
		gui.MaxDistance = 60
		gui.Parent = plate
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextColor3 = Color3.fromRGB(48, 38, 26)
		label.TextScaled = false
		label.TextSize = 21
		label.Text = labelText
		label.Parent = gui
	end
	casing.Parent = room
end

local function addRoomAtmosphere(room: Model, dustColor: Color3)
	local cf, size = room:GetBoundingBox()
	local volume = Instance.new("Part")
	volume.Name = "RoomAtmosphere"
	volume.Anchored = true
	volume.CanCollide = false
	volume.CanQuery = false
	volume.CanTouch = false
	volume.Transparency = 1
	volume.Size = Vector3.new(math.max(size.X - 3, 4), 7, math.max(size.Z - 3, 4))
	volume.CFrame = cf
	volume.Parent = room

	local dust = Instance.new("ParticleEmitter")
	dust.Name = "DustMotes"
	dust.Rate = 8
	dust.Lifetime = NumberRange.new(6, 10)
	dust.Speed = NumberRange.new(0.1, 0.35)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.RotSpeed = NumberRange.new(-20, 20)
	dust.Size = NumberSequence.new(0.06, 0.16)
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.72),
		NumberSequenceKeypoint.new(0.85, 0.78),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Color = ColorSequence.new(dustColor)
	dust.LightEmission = 0.2
	dust.Acceleration = Vector3.new(0, -0.05, 0)
	dust.Parent = volume

	local tone = Instance.new("Sound")
	tone.Name = "RoomTone"
	tone.SoundId = "rbxassetid://273398061"
	tone.Looped = true
	tone.Volume = 0.2
	tone.RollOffMode = Enum.RollOffMode.InverseTapered
	tone.RollOffMinDistance = 10
	tone.RollOffMaxDistance = 90
	tone.Parent = volume
	tone:Play()
end

local function buildSafeRoomTemplate(): Model
	local model = Instance.new("Model")
	model.Name = "ToadMakerSafeRoom"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("SafeRoom", true)
	model:SetAttribute("SurveyDressing", false)

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, collide: boolean)
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
		p.Parent = model
		return p
	end

	local concrete = Color3.fromRGB(68, 72, 68)
	local timber = Color3.fromRGB(58, 42, 30)
	part("Floor", Vector3.new(22, 1, 26), CFrame.new(0, -0.5, 0), concrete, Enum.Material.Concrete, true)
	part("Ceiling", Vector3.new(22, 1, 26), CFrame.new(0, 11.5, 0), timber, Enum.Material.WoodPlanks, true)
	part("WallLeft", Vector3.new(1, 11, 26), CFrame.new(-10.5, 5.5, 0), concrete, Enum.Material.Concrete, true)
	part("WallRight", Vector3.new(1, 11, 26), CFrame.new(10.5, 5.5, 0), concrete, Enum.Material.Concrete, true)

	part(
		"SanctuaryRunner",
		Vector3.new(4.4, 0.06, 22),
		CFrame.new(0, 0.03, 0),
		Color3.fromRGB(72, 46, 40),
		Enum.Material.Fabric,
		false
	)
	for _, z in { -9, 0, 9 } do
		part("BeamTop", Vector3.new(20, 0.55, 0.6), CFrame.new(0, 10.7, z), timber, Enum.Material.Wood, false)
		part("PostR", Vector3.new(0.55, 11, 0.55), CFrame.new(9.7, 5.5, z), timber, Enum.Material.Wood, false)
	end
	for _, z in { -6, 6 } do
		local sconce = part(
			"WallSconce",
			Vector3.new(0.35, 0.6, 0.5),
			CFrame.new(9.7, 6.2, z),
			Color3.fromRGB(255, 198, 116),
			Enum.Material.Neon,
			false
		)
		local sl = Instance.new("PointLight")
		sl.Color = Color3.fromRGB(255, 196, 118)
		sl.Range = 20
		sl.Brightness = 0.95
		sl.Shadows = false
		sl.Parent = sconce
	end

	local function anchor(name: string, pos: Vector3, lookDir: Vector3): Part
		local a = Instance.new("Part")
		a.Name = name
		a.Size = Vector3.new(4, 7, 1)
		a.CFrame = CFrame.lookAt(pos, pos + lookDir)
		a.Transparency = 1
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.Anchored = true
		a.Parent = model
		return a
	end

	anchor("Entrance", Vector3.new(0, 3.5, -13), Vector3.new(0, 0, 1))
	anchor("Exit", Vector3.new(0, 3.5, 13), Vector3.new(0, 0, -1))
	model.WorldPivot = CFrame.new(0, -0.5, 0)
	return model
end

local MODULAR_KINDS: { [string]: boolean } = {
	CrossHub = true,
	TJunctionL = true,
	TJunctionR = true,
	CornerLeft = true,
	CornerRight = true,
	SplitCourt = true,
	StepGallery = true,
	CorridorLong = true,
	SideVault = true,
	StorageBay = true,
	DeadEndLab = true,
}

local function checkModelFits(
	candidate: Model,
	entrance: BasePart,
	existingRooms: { Model },
	parentRoom: Model?,
	exitClearanceCheck: BasePart?
): boolean
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	local existingParts: { BasePart } = {}
	for _, r in ipairs(existingRooms) do
		for _, part in ipairs(r:GetDescendants()) do
			if
				part:IsA("BasePart")
				and part.CanCollide
				and part.Name ~= "Exit"
				and part.Name ~= "Entrance"
				and not part.Name:find("Branch")
			then
				table.insert(existingParts, part)
			end
		end
	end
	if #existingParts == 0 then
		return true
	end
	overlapParams.FilterDescendantsInstances = existingParts

	local entranceCF = entrance.CFrame
	local candidateCF, candidateSize = candidate:GetBoundingBox()
	local overlapSize = Vector3.new(
		math.max(candidateSize.X - 1.5, 0.1),
		math.max(candidateSize.Y - 0.5, 0.1),
		math.max(candidateSize.Z - 1.5, 0.1)
	)
	local hits = Workspace:GetPartBoundsInBox(candidateCF, overlapSize, overlapParams)
	for _, part in ipairs(hits) do
		if parentRoom and part:IsDescendantOf(parentRoom) then
			-- Allow flush shared doorway seam walls (lp.Z >= -1.25 along outward +Z from candidate interior)
			local lp = entranceCF:PointToObjectSpace(part.Position)
			if lp.Z < -1.25 and (part.Position - entrance.Position).Magnitude > 3.5 then
				return false
			end
		else
			if (part.Position - entrance.Position).Magnitude > 3.5 then
				return false
			end
		end
	end

	-- For the final extraction room, ensure space outside Exit isn't obstructed for ExitGate
	if exitClearanceCheck then
		local outCF = exitClearanceCheck.CFrame * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 1, -4)
		local outHits = Workspace:GetPartBoundsInBox(outCF, Vector3.new(9, 8, 6), overlapParams)
		for _, part in ipairs(outHits) do
			if (part.Position - exitClearanceCheck.Position).Magnitude > 3.5 then
				return false
			end
		end
	end

	return true
end

local function buildCandidatePool(preferred: { string }, allTemplateNames: { string }, rng: Random): { string }
	local pool: { string } = {}
	local copyPref = table.clone(preferred)
	while #copyPref > 0 do
		local idx = rng:NextInteger(1, #copyPref)
		table.insert(pool, table.remove(copyPref, idx) :: string)
	end
	local copyTemplates = table.clone(allTemplateNames)
	while #copyTemplates > 0 do
		local idx = rng:NextInteger(1, #copyTemplates)
		local name = table.remove(copyTemplates, idx) :: string
		if not table.find(pool, name) then
			table.insert(pool, name)
		end
	end
	for kind in MODULAR_KINDS do
		if not table.find(pool, kind) then
			table.insert(pool, kind)
		end
	end
	return pool
end

local function instantiateByKind(
	name: string,
	authoredByName: { [string]: Model },
	theme: MazeVariations.ThemeDef,
	rng: Random
): Model?
	if authoredByName[name] then
		return authoredByName[name]:Clone()
	elseif MODULAR_KINDS[name] then
		return MazeVariations.buildModularPiece(name, theme, rng)
	end
	return nil
end

function RoomGenerator.generate(numRooms: number): { Model }
	local templatesFolder = ReplicatedStorage:WaitForChild("RoomTemplates", 10)
	assert(templatesFolder, "RoomTemplates folder not found in ReplicatedStorage!")

	local authoredByName: { [string]: Model } = {}
	local templateNames: { string } = {}
	local safeTemplate: Model? = nil
	for _, item in templatesFolder:GetChildren() do
		if item:IsA("Model") then
			if item.Name == "ToadMakerSafeRoom" or item:GetAttribute("SafeRoom") == true then
				safeTemplate = item
			else
				authoredByName[item.Name] = item
				table.insert(templateNames, item.Name)
			end
		end
	end
	assert(#templateNames > 0, "No hazard room templates found in ReplicatedStorage.RoomTemplates!")

	local dungeonFolder = Workspace:FindFirstChild("GeneratedDungeon")
	if not dungeonFolder then
		dungeonFolder = Instance.new("Folder")
		dungeonFolder.Name = "GeneratedDungeon"
		dungeonFolder.Parent = Workspace
	else
		dungeonFolder:ClearAllChildren()
	end

	-- Roll an 8^3 = 512 variation every run (seeded randomly unless overridden)
	local masterRng = Random.new()
	local variation = MazeVariations.pickVariation(masterRng)
	local rng = Random.new(variation.seed)

	dungeonFolder:SetAttribute("VariationCode", variation.code)
	dungeonFolder:SetAttribute("VariationIndex", variation.index)
	dungeonFolder:SetAttribute("ThemeName", variation.theme.name)
	dungeonFolder:SetAttribute("TopologyName", variation.topology.name)
	dungeonFolder:SetAttribute("DecorName", variation.decor.name)
	dungeonFolder:SetAttribute("MazeSeed", variation.seed)
	Workspace:SetAttribute(
		"MazeVariation",
		string.format("%s | %s | %s", variation.theme.name, variation.topology.name, variation.decor.name)
	)
	Workspace:SetAttribute("MazeVariationCode", variation.code)

	local spineRooms: { Model } = {}
	local branchRooms: { Model } = {}
	local allPlaced: { Model } = {}
	local openBranchSockets: { { room: Model, socket: BasePart, sectorIndex: number } } = {}

	local currentExitCF: CFrame = CFrame.new(0, 0, 0)
	local spawnPad = Workspace:FindFirstChild("StartSpawn")
	local safeSlot = if numRooms >= 4 then math.ceil(numRooms / 2) else 0
	local lastTurnSign = 0
	local headingTurns = 0

	-- Step A: Build guaranteed traversable main spine (Station 01 -> SafeRoom -> ExitGate)
	for roomIndex = 1, numRooms do
		local placed = false
		local candidates: { string }
		if roomIndex == safeSlot then
			candidates = { "__SAFEROOM__" }
		elseif roomIndex == 1 then
			-- Entry room stays straight/roomy so MaintenanceBay & SurveyLift always align cleanly
			candidates = { "BunkerAirlock", "RustyWoodHallway", "CorridorLong", "SideVault" }
		elseif roomIndex == numRooms then
			-- Extraction room keeps clean forward Exit clearance
			candidates = buildCandidatePool(
				{ "SideVault", "GeneratorSwitchRoom", "BunkerAirlock", "CorridorLong" },
				templateNames,
				rng
			)
		else
			candidates = buildCandidatePool(variation.topology.spinePreferred, templateNames, rng)
		end

		local parentSpineRoom = spineRooms[#spineRooms]
		for pass = 1, 2 do
			for _, kindName in candidates do
				local candidate: Model?
				if kindName == "__SAFEROOM__" then
					candidate = (safeTemplate or buildSafeRoomTemplate()):Clone()
				else
					candidate = instantiateByKind(kindName, authoredByName, variation.theme, rng)
				end
				if not candidate then
					continue
				end

				candidate.Name =
					string.format("Room_%02d_%s", roomIndex, kindName:gsub("__SAFEROOM__", "ToadMakerSafeRoom"))
				candidate.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				if roomIndex == safeSlot then
					candidate:SetAttribute("SafeRoom", true)
					candidate:SetAttribute("SurveyDressing", false)
				else
					MazeVariations.applyTheme(candidate, variation.theme, rng)
				end

				local entrance, exit = getRoomAnchors(candidate)
				if not entrance or not exit then
					candidate:Destroy()
					continue
				end

				local turnSign = getRoomTurnSign(entrance, exit)
				-- Keep main spine heading within [-1, +1] (180 deg forward sweep) so spine never loops back into Room_01
				if turnSign ~= 0 and math.abs(headingTurns + turnSign) > 1 then
					candidate:Destroy()
					continue
				end
				if
					pass == 1
					and turnSign ~= 0
					and turnSign == lastTurnSign
					and not variation.topology.allowConsecutiveTurns
				then
					candidate:Destroy()
					continue
				end

				local targetEntranceCF = currentExitCF * CFrame.Angles(0, math.pi, 0)
				if roomIndex == 1 and spawnPad and spawnPad:IsA("BasePart") then
					targetEntranceCF = CFrame.new(
						spawnPad.Position + Vector3.yAxis * (spawnPad.Size.Y + entrance.Size.Y) / 2
					) * targetEntranceCF.Rotation
				end
				local entranceLocalCF = candidate:GetPivot():ToObjectSpace(entrance.CFrame)
				candidate:PivotTo(targetEntranceCF * entranceLocalCF:Inverse())

				local exitClearCheck = if roomIndex == numRooms then exit else nil
				if checkModelFits(candidate, entrance, allPlaced, parentSpineRoom, exitClearCheck) then
					addPassageLamp(candidate, exit, variation.theme.lightColor)
					addDoorFrame(candidate, entrance, string.format("STATION %02d", roomIndex), roomIndex == 1)
					if roomIndex < numRooms then
						addDoorFrame(candidate, exit, string.format("STATION %02d", roomIndex + 1), false)
					else
						addDoorFrame(candidate, exit, "EXTRACTION", false)
					end
					addRoomAtmosphere(candidate, variation.theme.dustColor)

					candidate.Parent = dungeonFolder
					table.insert(spineRooms, candidate)
					table.insert(allPlaced, candidate)
					currentExitCF = exit.CFrame
					if turnSign ~= 0 then
						lastTurnSign = turnSign
						headingTurns += turnSign
					end

					-- Queue any hub side sockets (BranchLeft / BranchRight) for R.E.P.O. branching wings
					for _, child in candidate:GetChildren() do
						if (child.Name == "BranchLeft" or child.Name == "BranchRight") and child:IsA("BasePart") then
							table.insert(openBranchSockets, {
								room = candidate,
								socket = child,
								sectorIndex = roomIndex,
							})
						end
					end

					placed = true
					break
				else
					candidate:Destroy()
				end
			end
			if placed then
				break
			end
		end

		if not placed and roomIndex == safeSlot and safeSlot < numRooms then
			-- Defer SafeRoom one slot forward and bridge with a compact straight chamber
			safeSlot += 1
			for _, bridgeKind in { "RustyWoodHallway", "CorridorLong", "BunkerAirlock", "StorageBay", "SideVault" } do
				local fallbackSpacer = instantiateByKind(bridgeKind, authoredByName, variation.theme, rng)
				if fallbackSpacer then
					fallbackSpacer.Name = string.format("Room_%02d_%s", roomIndex, bridgeKind)
					fallbackSpacer.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
					MazeVariations.applyTheme(fallbackSpacer, variation.theme, rng)
					local ent, ex = getRoomAnchors(fallbackSpacer)
					if ent and ex then
						local targetCF = currentExitCF * CFrame.Angles(0, math.pi, 0)
						fallbackSpacer:PivotTo(
							targetCF * (fallbackSpacer:GetPivot():ToObjectSpace(ent.CFrame)):Inverse()
						)
						if checkModelFits(fallbackSpacer, ent, allPlaced, parentSpineRoom, nil) then
							addPassageLamp(fallbackSpacer, ex, variation.theme.lightColor)
							addDoorFrame(fallbackSpacer, ent, string.format("STATION %02d", roomIndex), false)
							addDoorFrame(fallbackSpacer, ex, string.format("STATION %02d", roomIndex + 1), false)
							addRoomAtmosphere(fallbackSpacer, variation.theme.dustColor)
							fallbackSpacer.Parent = dungeonFolder
							table.insert(spineRooms, fallbackSpacer)
							table.insert(allPlaced, fallbackSpacer)
							currentExitCF = ex.CFrame
							placed = true
							break
						end
					end
					fallbackSpacer:Destroy()
				end
			end
		end

		if not placed then
			warn(string.format("RoomGenerator: cannot place spine room %d cleanly – halting early.", roomIndex))
			break
		end
	end

	-- Step B: Grow R.E.P.O.-style branching side wings off open hub/junction sockets
	local shuffledSockets = table.clone(openBranchSockets)
	for i = #shuffledSockets, 2, -1 do
		local j = rng:NextInteger(1, i)
		shuffledSockets[i], shuffledSockets[j] = shuffledSockets[j], shuffledSockets[i]
	end

	local branchesBuilt = 0
	for _, entry in shuffledSockets do
		local parentSocket = entry.socket
		local parentRoom = entry.room
		local attachedAny = false

		if branchesBuilt < variation.topology.maxBranches and rng:NextNumber() <= variation.topology.branchChance then
			local branchPrefix = string.format("W%d", branchesBuilt + 1)
			local wingParent: Model = parentRoom
			local curSocket: BasePart = parentSocket
			local wingChain: { Model } = {}

			for depth = 1, variation.topology.maxWingDepth do
				if depth > 1 and rng:NextNumber() > 0.58 then
					break
				end
				local wingPool = buildCandidatePool(variation.topology.wingPreferred, templateNames, rng)
				local wingPlaced = false
				for _, wingKind in wingPool do
					local wing = instantiateByKind(wingKind, authoredByName, variation.theme, rng)
					if not wing then
						continue
					end
					wing.Name = string.format("Wing_%02d_%s", #branchRooms + 1, wingKind)
					wing.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
					MazeVariations.applyTheme(wing, variation.theme, rng)

					local entrance, exit = getRoomAnchors(wing)
					if not entrance or not exit then
						wing:Destroy()
						continue
					end

					local targetCF = curSocket.CFrame * CFrame.Angles(0, math.pi, 0)
					local entLocal = wing:GetPivot():ToObjectSpace(entrance.CFrame)
					wing:PivotTo(targetCF * entLocal:Inverse())

					local wingParentModel = if #wingChain > 0 then wingChain[#wingChain] else wingParent
					if checkModelFits(wing, entrance, allPlaced, wingParentModel, nil) then
						addDoorFrame(wing, entrance, string.format("SECTOR %s-%d", branchPrefix, depth), false)
						addRoomAtmosphere(wing, variation.theme.dustColor)

						-- Seal any side branch sockets on deep wing rooms so zero unsealed edges exist
						for _, subChild in wing:GetChildren() do
							if
								(subChild.Name == "BranchLeft" or subChild.Name == "BranchRight")
								and subChild:IsA("BasePart")
							then
								MazeVariations.sealSocket(wing, subChild, variation.theme)
							end
						end

						wing.Parent = dungeonFolder
						table.insert(branchRooms, wing)
						table.insert(wingChain, wing)
						table.insert(allPlaced, wing)
						curSocket = exit
						wingPlaced = true
						break
					else
						wing:Destroy()
					end
				end

				if not wingPlaced then
					break
				end
			end

			if #wingChain > 0 then
				branchesBuilt += 1
				attachedAny = true
				addDoorFrame(wingParent, parentSocket, string.format("SECTOR %s", branchPrefix), false)
				-- Seal the leaf exit of the final room in the branch wing
				local leaf = wingChain[#wingChain]
				local _, leafExit = getRoomAnchors(leaf)
				if leafExit then
					MazeVariations.sealSocket(leaf, leafExit, variation.theme)
				end
			end
		end

		-- Seal unused hub/junction side doorway so no open edge leads to the void
		if not attachedAny then
			MazeVariations.sealSocket(parentRoom, parentSocket, variation.theme)
		end
	end

	-- Step C: Apply per-run unique side decorations (never blocking center nav or Room_01 MaintenanceBay)
	for _, r in ipairs(allPlaced) do
		MazeVariations.decorateRoom(r, variation.decor, variation.theme, rng, r == spineRooms[1])
	end

	-- Assemble ordered output:
	--   [1] = Entry (SurveyLift + MaintenanceBay)
	--   [middle] = spine interior + branching side wings (spawns Objectives, Clues, NPC patrols across maze!)
	--   [#] = Final Extraction spine room (ExitGate)
	local orderedRooms: { Model } = {}
	if #spineRooms > 0 then
		table.insert(orderedRooms, spineRooms[1])
		for i = 2, #spineRooms - 1 do
			table.insert(orderedRooms, spineRooms[i])
		end
		for _, w in ipairs(branchRooms) do
			table.insert(orderedRooms, w)
		end
		if #spineRooms > 1 then
			table.insert(orderedRooms, spineRooms[#spineRooms])
		end
	end

	print(
		string.format(
			"[RoomGenerator] R.E.P.O. Maze %s (#%d/512 | %s / %s / %s | seed=%d) -> %d total rooms (%d spine + %d wing bays).",
			variation.code,
			variation.index,
			variation.theme.name,
			variation.topology.name,
			variation.decor.name,
			variation.seed,
			#orderedRooms,
			#spineRooms,
			#branchRooms
		)
	)
	return orderedRooms
end

return RoomGenerator
