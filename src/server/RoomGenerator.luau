--!strict
--[[
  FRONT-FACE SNAPPING RULE (read before editing anchor placement):
  ─────────────────────────────────────────────────────────────────
  Every room template stores two transparent anchor Parts:
    • Entrance  – sits at the room's entry doorway (-Z in model space),
                  LookVector (-Z_local) pointing INTO the room (+Z_model).
    • Exit      – sits at the room's exit doorway (+Z in model space),
                  LookVector (-Z_local) pointing INTO the room (-Z_model for
                  straight rooms, rotated for L-shapes).

  Consequently, for BOTH Entrance and Exit anchors:
    • anchor.CFrame * CFrame.new(x, y, -d) is INSIDE the room.
    • anchor.CFrame * CFrame.new(x, y, +d) is OUTSIDE the room.

  Snap algorithm (do NOT change the sign or rotation):
    1. Flip the previous room's inward-facing Exit CFrame 180° around Y so its
       LookVector points outward in the direction the next room continues:
           targetEntranceCF = prevExitCF * CFrame.Angles(0, math.pi, 0)
    2. Compute the offset from the room's pivot to its Entrance in local space,
       then solve for the new pivot that places Entrance at targetEntranceCF:
           newPivot = targetEntranceCF * entranceLocal:Inverse()
    3. PivotTo(newPivot) moves the whole model so Entrance aligns cleanly.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	-- Remember: template anchors have LookVector pointing opposite along straight rooms (Ent=+Z, Ex=-Z)
	-- Flip exit LookVector to get the travel exit direction and cross with entrance LookVector.
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

-- Amber passage lamps echo the forest trail stakes: follow the amber light deeper.
-- Both Entrance and Exit LookVectors point INTO the room (-Z_local faces interior).
local function addPassageLamp(room: Model, exitAnchor: BasePart)
	local lamp = Instance.new("Part")
	lamp.Name = "PassageLamp"
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CanQuery = false
	lamp.CanTouch = false
	lamp.CastShadow = false
	lamp.Size = Vector3.new(0.9, 0.22, 0.22)
	lamp.Material = Enum.Material.Neon
	lamp.Color = Color3.fromRGB(245, 189, 103)
	-- Positioned above ConduitRun and ExitGate ExtractionPlate without touching ceiling ribs.
	lamp.CFrame = exitAnchor.CFrame * CFrame.new(0, exitAnchor.Size.Y / 2 + 2.45, -0.9)

	-- Corroded mount bracket between the neon tube and the exit bulkhead header.
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
	glow.Color = lamp.Color
	glow.Range = 12
	glow.Brightness = 0.6
	glow.Shadows = false
	glow.Parent = lamp
end

-- Non-colliding iron door casings and brass station plates frame each threshold
-- cleanly inside the room so neither players nor MainNPC_Stalker ever snag.
local function addDoorFrame(room: Model, anchor: BasePart, labelText: string?)
	local casing = Instance.new("Model")
	casing.Name = "DoorCasing"
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

	-- Negative Z sits strictly inside this room, leaving a zero-overlap seam at Z = 0.
	trim("CasingJambL", Vector3.new(0.5, 7, 1.1), CFrame.new(-2.35, 0, -0.55))
	trim("CasingJambR", Vector3.new(0.5, 7, 1.1), CFrame.new(2.35, 0, -0.55))
	trim("CasingHeader", Vector3.new(5.2, 0.6, 1.1), CFrame.new(0, 3.8, -0.55))

	local sill = trim("CasingSill", Vector3.new(4.6, 0.12, 1.2), CFrame.new(0, -anchor.Size.Y / 2 + 0.06, -0.55))
	sill.Material = Enum.Material.DiamondPlate
	sill.Color = Color3.fromRGB(52, 48, 44)

	local conduit = trim("ConduitRun", Vector3.new(5.2, 0.28, 0.28), CFrame.new(0, 5.05, -0.55))
	conduit.Color = Color3.fromRGB(38, 34, 30)

	if labelText then
		local plate = trim("StationPlate", Vector3.new(2.1, 0.62, 0.1), CFrame.new(0, 4.55, -1.15))
		plate.Color = brass
		plate.Material = Enum.Material.Metal
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(210, 62)
		gui.LightInfluence = 0.6
		gui.MaxDistance = 60
		gui.Parent = plate
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextColor3 = Color3.fromRGB(48, 38, 26)
		label.TextScaled = false
		label.TextSize = 22
		label.Text = labelText
		label.Parent = gui
	end
	casing.Parent = room
end

-- Drifting dust motes catch flashlight beams and a subtle low hum anchors each gallery.
local function addRoomAtmosphere(room: Model)
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
	dust.Rate = 9
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
	dust.Color = ColorSequence.new(Color3.fromRGB(214, 200, 178))
	dust.LightEmission = 0.2
	dust.Acceleration = Vector3.new(0, -0.05, 0)
	dust.Parent = volume

	local tone = Instance.new("Sound")
	tone.Name = "RoomTone"
	tone.SoundId = "rbxassetid://273398061"
	tone.Looped = true
	tone.Volume = 0.22
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

	-- Cozy sanctuary architecture: woven runner, ceiling rafters, timber posts & warm wall sconces
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

	local ent = anchor("Entrance", Vector3.new(0, 3.5, -13), Vector3.new(0, 0, 1))
	anchor("Exit", Vector3.new(0, 3.5, 13), Vector3.new(0, 0, -1))
	model.WorldPivot = CFrame.new(0, -0.5, 0)
	local _ = ent
	return model
end

function RoomGenerator.generate(numRooms: number): { Model }
	local templatesFolder = ReplicatedStorage:WaitForChild("RoomTemplates", 10)
	assert(templatesFolder, "RoomTemplates folder not found in ReplicatedStorage!")

	local templates = {}
	local safeTemplate: Model? = nil
	for _, item in templatesFolder:GetChildren() do
		if item:IsA("Model") then
			if item.Name == "ToadMakerSafeRoom" or item:GetAttribute("SafeRoom") == true then
				safeTemplate = item
			else
				table.insert(templates, item)
			end
		end
	end
	assert(#templates > 0, "No hazard room templates found in ReplicatedStorage.RoomTemplates!")

	local dungeonFolder = Workspace:FindFirstChild("GeneratedDungeon")
	if not dungeonFolder then
		dungeonFolder = Instance.new("Folder")
		dungeonFolder.Name = "GeneratedDungeon"
		dungeonFolder.Parent = Workspace
	else
		dungeonFolder:ClearAllChildren()
	end

	local spawnedRooms: { Model } = {}
	local currentExitCF: CFrame = CFrame.new(0, 0, 0)
	local spawnPad = Workspace:FindFirstChild("StartSpawn")
	local safeSlot = if numRooms >= 4 then math.ceil(numRooms / 2) else 0
	local lastTurnSign = 0

	local random = Random.new()

	for roomIndex = 1, numRooms do
		local placed = false
		local availableTemplates = table.clone(templates)
		if roomIndex == safeSlot then
			local safeRoomModel = safeTemplate or buildSafeRoomTemplate()
			availableTemplates = { safeRoomModel }
		end

		while #availableTemplates > 0 do
			local templateIndex = random:NextInteger(1, #availableTemplates)
			local chosenTemplate = table.remove(availableTemplates, templateIndex) :: Model

			local candidate = chosenTemplate:Clone()
			candidate.Name = string.format("Room_%02d_%s", roomIndex, chosenTemplate.Name)
			candidate.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			if roomIndex == safeSlot then
				candidate:SetAttribute("SafeRoom", true)
				candidate:SetAttribute("SurveyDressing", false)
			end

			local entrance, exit = getRoomAnchors(candidate)
			if not entrance or not exit then
				warn("Template " .. chosenTemplate.Name .. " missing Entrance/Exit – skipping.")
				candidate:Destroy()
				continue
			end

			-- Prevent two consecutive turns in the same direction (avoids self-colliding U-turns)
			local turnSign = getRoomTurnSign(entrance, exit)
			if turnSign ~= 0 and turnSign == lastTurnSign and #availableTemplates > 0 then
				candidate:Destroy()
				continue
			end

			--[[
			  SNAP MATH (see module header for full explanation):
			  targetEntranceCF = prevExit flipped 180° → back-to-back faces.
			  newPivot = targetEntranceCF * (pivotToEntrance):Inverse()
			]]
			local targetEntranceCF = currentExitCF * CFrame.Angles(0, math.pi, 0)
			if roomIndex == 1 and spawnPad and spawnPad:IsA("BasePart") then
				-- Align the first doorway's threshold with the top of the spawn pad.
				targetEntranceCF = CFrame.new(
					spawnPad.Position + Vector3.yAxis * (spawnPad.Size.Y + entrance.Size.Y) / 2
				) * targetEntranceCF.Rotation
			end
			local entranceLocalCF = candidate:GetPivot():ToObjectSpace(entrance.CFrame)
			local newRoomPivot = targetEntranceCF * entranceLocalCF:Inverse()
			candidate:PivotTo(newRoomPivot)

			-- Overlap check: shrink bbox slightly to avoid seam false-positives.
			local candidateCF, candidateSize = candidate:GetBoundingBox()
			local overlapSize = Vector3.new(
				math.max(candidateSize.X - 1.5, 0.1),
				math.max(candidateSize.Y - 0.5, 0.1),
				math.max(candidateSize.Z - 1.5, 0.1)
			)

			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Include
			local existingParts: { BasePart } = {}
			for _, r in ipairs(spawnedRooms) do
				for _, part in ipairs(r:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= "Exit" and part.Name ~= "Entrance" then
						table.insert(existingParts, part)
					end
				end
			end
			overlapParams.FilterDescendantsInstances = existingParts

			local hits = Workspace:GetPartBoundsInBox(candidateCF, overlapSize, overlapParams)
			local solidOverlaps = 0
			for _, part in ipairs(hits) do
				if part.CanCollide then
					-- Ignore parts within 3 studs of the entrance seam (shared doorframe geometry).
					if (part.Position - entrance.Position).Magnitude > 3 then
						solidOverlaps += 1
					end
				end
			end

			if solidOverlaps == 0 then
				addPassageLamp(candidate, exit)
				addDoorFrame(candidate, entrance, string.format("STATION %02d", roomIndex))
				if roomIndex < numRooms then
					addDoorFrame(candidate, exit, string.format("STATION %02d", roomIndex + 1))
				end
				addRoomAtmosphere(candidate)
				candidate.Parent = dungeonFolder
				table.insert(spawnedRooms, candidate)
				currentExitCF = exit.CFrame
				if turnSign ~= 0 then
					lastTurnSign = turnSign
				end
				placed = true
				break
			else
				candidate:Destroy()
			end
		end

		if not placed then
			warn(string.format("RoomGenerator: cannot place room %d without overlap – halting early.", roomIndex))
			break
		end
	end

	print(string.format("RoomGenerator: generated %d/%d rooms.", #spawnedRooms, numRooms))
	return spawnedRooms
end

return RoomGenerator
