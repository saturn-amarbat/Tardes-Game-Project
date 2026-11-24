--!strict
--[[
  FRONT-FACE SNAPPING RULE (read before editing anchor placement):
  ─────────────────────────────────────────────────────────────────
  Every room template stores two transparent anchor Parts:
    • Entrance  – sits at the room's entry doorway, LookVector pointing
                  OUT of the room (away from interior, i.e. –Z in model space).
    • Exit      – sits at the room's exit doorway, LookVector pointing
                  OUT of the room (into the corridor ahead, i.e. +Z in model
                  space for straight rooms, rotated for L-shapes).

  Snap algorithm (do NOT change the sign or rotation):
    1. The previous room's Exit CFrame faces outward → its LookVector
       points in the direction the next room should continue.
    2. We want the new room's Entrance to face that same outward direction
       (they are back-to-back), so we flip the Exit CFrame 180 ° around Y:
           targetEntranceCF = prevExitCF * CFrame.Angles(0, math.pi, 0)
    3. Compute the offset from the room's pivot to its Entrance in local space,
       then solve for the new pivot that places Entrance at targetEntranceCF:
           newPivot = targetEntranceCF * entranceLocal:Inverse()
    4. PivotTo(newPivot) moves the whole model so Entrance aligns exactly.
  This guarantees rooms always connect face-to-face and never spawn backwards.
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
