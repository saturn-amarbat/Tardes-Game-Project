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

function RoomGenerator.generate(numRooms: number): { Model }
	local templatesFolder = ReplicatedStorage:WaitForChild("RoomTemplates", 10)
	assert(templatesFolder, "RoomTemplates folder not found in ReplicatedStorage!")

	local templates = templatesFolder:GetChildren()
	assert(#templates > 0, "No room templates found in ReplicatedStorage.RoomTemplates!")

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

	local random = Random.new()

	for roomIndex = 1, numRooms do
		local placed = false
		local availableTemplates = table.clone(templates)

		while #availableTemplates > 0 do
			local templateIndex = random:NextInteger(1, #availableTemplates)
			local chosenTemplate = table.remove(availableTemplates, templateIndex) :: Model

			local candidate = chosenTemplate:Clone()
			candidate.Name = string.format("Room_%02d_%s", roomIndex, chosenTemplate.Name)
			candidate.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

			local entrance, exit = getRoomAnchors(candidate)
			if not entrance or not exit then
				warn("Template " .. chosenTemplate.Name .. " missing Entrance/Exit – skipping.")
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
