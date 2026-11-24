--!strict
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
				warn("Template " .. chosenTemplate.Name .. " is missing Entrance or Exit part! Skipping.")
				candidate:Destroy()
				continue
			end

			-- Room placement alignment:
			-- The new room's entrance anchor must align with currentExitCF.
			-- Note: Entrance points outward (180 deg from inside).
			-- To snap entrance flush with exit (which faces outward into the next room):
			-- targetEntranceCF = currentExitCF * CFrame.Angles(0, math.pi, 0)
			local targetEntranceCF = currentExitCF * CFrame.Angles(0, math.pi, 0)
			local entranceLocalCF = candidate:GetPivot():ToObjectSpace(entrance.CFrame)
			local newRoomPivot = targetEntranceCF * entranceLocalCF:Inverse()

			candidate:PivotTo(newRoomPivot)

			-- Check for overlap:
			-- Use candidate's bounding box shrunk slightly to avoid false positives at the seam.
			local candidateCFrame, candidateSize = candidate:GetBoundingBox()
			local overlapSize = candidateSize - Vector3.new(1.5, 0.5, 1.5)
			if overlapSize.X <= 0 or overlapSize.Y <= 0 or overlapSize.Z <= 0 then
				overlapSize = candidateSize
			end

			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Include

			-- Build list of parts to check against (all parts in previously spawned rooms, excluding exit anchors and adjoining wall parts)
			local existingParts: { BasePart } = {}
			for _, r in ipairs(spawnedRooms) do
				for _, part in ipairs(r:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= "Exit" and part.Name ~= "Entrance" then
						table.insert(existingParts, part)
					end
				end
			end
			overlapParams.FilterDescendantsInstances = existingParts

			local overlappingParts = Workspace:GetPartBoundsInBox(candidateCFrame, overlapSize, overlapParams)
			-- Filter out any non-colliding parts and parts touching right at the entrance plane
			local solidOverlaps = 0
			for _, part in ipairs(overlappingParts) do
				if part.CanCollide then
					-- Distance between part and candidate's entrance
					local distToEntrance = (part.Position - entrance.Position).Magnitude
					if distToEntrance > 3 then
						solidOverlaps += 1
					end
				end
			end

			if solidOverlaps == 0 then
				candidate.Parent = dungeonFolder
				table.insert(spawnedRooms, candidate)
				-- Update current exit CFrame for next room
				currentExitCF = exit.CFrame
				placed = true
				break
			else
				candidate:Destroy()
			end
		end

		if not placed then
			warn(
				string.format(
					"RoomGenerator: Could not place room %d without overlap. Generator halted early.",
					roomIndex
				)
			)
			break
		end
	end

	print(string.format("RoomGenerator: Successfully generated %d non-overlapping rooms.", #spawnedRooms))
	return spawnedRooms
end

return RoomGenerator
