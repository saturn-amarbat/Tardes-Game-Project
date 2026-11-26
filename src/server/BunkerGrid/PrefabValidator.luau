--!strict
--[[
  PrefabValidator  –  Validates every prefab in ServerStorage/BunkerPrefabs against
  hard grid, boundary, marker, and zero-overlap contracts on load and in Studio.
]]

local Config = require(script.Parent.Config)

local PrefabValidator = {}

export type PrefabCheckResult = {
	name: string,
	kind: string,
	partCount: number,
	maxExtentXZ: number,
	internalOverlaps: number,
	ok: boolean,
}

local EPS = 1e-3

local function isStructuralPart(p: BasePart): boolean
	return p.Name:sub(1, 5) == "Wall_"
		or p.Name:sub(1, 5) == "Post_"
		or p.Name:sub(1, 3) == "Arm"
		or p.Name:sub(2, 8) == "_Closed"
		or p.Name == "Floor"
		or p.Name == "Ceiling"
end

local function partLocalAABB(originCF: CFrame, part: BasePart): (Vector3, Vector3)
	local relCF = originCF:ToObjectSpace(part.CFrame)
	local half = part.Size * 0.5
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = relCF:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
				minV = Vector3.new(math.min(minV.X, corner.X), math.min(minV.Y, corner.Y), math.min(minV.Z, corner.Z))
				maxV = Vector3.new(math.max(maxV.X, corner.X), math.max(maxV.Y, corner.Y), math.max(maxV.Z, corner.Z))
			end
		end
	end
	return minV, maxV
end

local function boxesOverlapVolume(minA: Vector3, maxA: Vector3, minB: Vector3, maxB: Vector3): number
	local ox = math.min(maxA.X, maxB.X) - math.max(minA.X, minB.X)
	local oy = math.min(maxA.Y, maxB.Y) - math.max(minA.Y, minB.Y)
	local oz = math.min(maxA.Z, maxB.Z) - math.max(minA.Z, minB.Z)
	if ox > EPS and oy > EPS and oz > EPS then
		return ox * oy * oz
	end
	return 0
end

function PrefabValidator.validateOne(
	model: Model,
	expectedSpec: { isHall: boolean, monsterSpawn: boolean?, isStart: boolean? }
): PrefabCheckResult
	local floor = model.PrimaryPart
	assert(
		model.ModelStreamingMode == Enum.ModelStreamingMode.Atomic,
		model.Name .. ": ModelStreamingMode must be Atomic"
	)
	assert(
		floor ~= nil and floor:IsA("BasePart") and floor.Name == "Floor",
		model.Name .. ": PrimaryPart must be BasePart named 'Floor'"
	)
	local expectedSize = Vector3.new(Config.CELL, 1, Config.CELL)
	assert(
		(floor.Size - expectedSize).Magnitude < EPS,
		string.format(
			"%s: Floor size %.2f,%.2f,%.2f ~= (%d,1,%d)",
			model.Name,
			floor.Size.X,
			floor.Size.Y,
			floor.Size.Z,
			Config.CELL,
			Config.CELL
		)
	)

	local floorCF = floor.CFrame
	local halfCell = Config.CELL / 2
	local maxExtent = 0
	local wallBoxes: { { name: string, minV: Vector3, maxV: Vector3 } } = {}
	local collidableProps: { { name: string, minV: Vector3, maxV: Vector3 } } = {}
	local partCount = 0

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			partCount += 1
			local minV, maxV = partLocalAABB(floorCF, desc)
			local extentX = math.max(math.abs(minV.X), math.abs(maxV.X))
			local extentZ = math.max(math.abs(minV.Z), math.abs(maxV.Z))
			maxExtent = math.max(maxExtent, extentX, extentZ)

			if isStructuralPart(desc) then
				assert(
					extentX <= halfCell + EPS and extentZ <= halfCell + EPS,
					string.format(
						"%s.%s exceeds +-%.1f cell bounds (X=%.2f, Z=%.2f)",
						model.Name,
						desc.Name,
						halfCell,
						extentX,
						extentZ
					)
				)
				if desc.Name ~= "Floor" and desc.Name ~= "Ceiling" and desc.CanCollide then
					table.insert(wallBoxes, { name = desc.Name, minV = minV, maxV = maxV })
				end
			elseif desc.CanCollide then
				table.insert(collidableProps, { name = desc.Name, minV = minV, maxV = maxV })
			end
		end
	end

	-- Assert zero intra-tile wall-to-wall overlap
	local internalOverlaps = 0
	for i = 1, #wallBoxes do
		for j = i + 1, #wallBoxes do
			local vol = boxesOverlapVolume(wallBoxes[i].minV, wallBoxes[i].maxV, wallBoxes[j].minV, wallBoxes[j].maxV)
			if vol > 0 then
				internalOverlaps += 1
				error(
					string.format(
						"%s: wall overlap (%.3f) between %s and %s",
						model.Name,
						vol,
						wallBoxes[i].name,
						wallBoxes[j].name
					)
				)
			end
		end
	end

	if expectedSpec.isHall then
		assert(
			model:FindFirstChild("ScareSpawn", true) == nil,
			model.Name .. ": hallway prefab must NOT contain ScareSpawn"
		)
		if expectedSpec.isStart then
			local ps = model:FindFirstChild("PlayerSpawn")
			assert(ps ~= nil and ps:IsA("BasePart"), model.Name .. ": start hallway must contain PlayerSpawn BasePart")
		end
		if expectedSpec.monsterSpawn then
			local ms = model:FindFirstChild("MonsterSpawn")
			assert(ms ~= nil and ms:IsA("BasePart"), model.Name .. ": hallway must contain MonsterSpawn BasePart")
		end
	else
		-- Room contracts
		local entrance = model:FindFirstChild("Entrance")
		assert(entrance ~= nil and entrance:IsA("BasePart"), model.Name .. ": room missing Entrance BasePart")
		local localLook = floorCF:VectorToObjectSpace(entrance.CFrame.LookVector)
		assert(
			localLook.Z > 0.9,
			string.format("%s: Entrance LookVector must point +Z into room (got Z=%.2f)", model.Name, localLook.Z)
		)

		local interiorLimit = halfCell - Config.WALL_T + EPS
		local scare = model:FindFirstChild("ScareSpawn", true)
		if model.Name == "Room_Safe" then
			assert(model:GetAttribute("SafeRoom") == true, "Room_Safe must have attribute SafeRoom = true")
			assert(
				model:GetAttribute("SurveyDressing") == false,
				"Room_Safe must have attribute SurveyDressing = false"
			)
			assert(scare == nil, "Room_Safe must NOT contain ScareSpawn")
		else
			assert(scare ~= nil and scare:IsA("BasePart"), model.Name .. ": non-Safe room missing ScareSpawn")
			local sRel = floorCF:PointToObjectSpace(scare.Position)
			assert(
				math.abs(sRel.X) <= interiorLimit and math.abs(sRel.Z) <= interiorLimit,
				string.format("%s: ScareSpawn outside room interior (%.2f, %.2f)", model.Name, sRel.X, sRel.Z)
			)
		end

		if model.Name == "Room_ModelSlot" then
			local slot = model:FindFirstChild("ModelSlot", true)
			assert(slot ~= nil and slot:IsA("BasePart"), "Room_ModelSlot missing ModelSlot marker BasePart")
		end

		if model.Name == "Room_Exit" then
			local exitPart = model:FindFirstChild("Exit")
			assert(exitPart ~= nil and exitPart:IsA("BasePart"), "Room_Exit missing Exit BasePart")
			local exitLook = floorCF:VectorToObjectSpace(exitPart.CFrame.LookVector)
			assert(
				exitLook.Z < -0.9,
				string.format("Room_Exit.Exit LookVector must point -Z into room (got Z=%.2f)", exitLook.Z)
			)

			-- Check ExitDoor BlastLeaf + ExitLever_A/B clearance inside Room_Exit
			local exitMin, exitMax = Vector3.new(-5.2, 0.1, 10.5), Vector3.new(5.2, 9.0, 14.9)
			for _, prop in collidableProps do
				local vol = boxesOverlapVolume(prop.minV, prop.maxV, exitMin, exitMax)
				assert(vol == 0, string.format("Room_Exit: prop %s blocks ExitGate/lever back-wall zone!", prop.name))
			end
		end
	end

	return {
		name = model.Name,
		kind = if expectedSpec.isHall then "Hall" else "Room",
		partCount = partCount,
		maxExtentXZ = maxExtent,
		internalOverlaps = internalOverlaps,
		ok = true,
	}
end

function PrefabValidator.validateAll(folder: Folder): { PrefabCheckResult }
	local expected: { [string]: { isHall: boolean, monsterSpawn: boolean?, isStart: boolean? } } = {
		HallDeadEnd = { isHall = true, monsterSpawn = false, isStart = true },
		HallCorner = { isHall = true, monsterSpawn = false, isStart = false },
		HallStraight = { isHall = true, monsterSpawn = true, isStart = false },
		HallT = { isHall = true, monsterSpawn = true, isStart = false },
		HallCross = { isHall = true, monsterSpawn = true, isStart = false },
		Room_Mirror = { isHall = false },
		Room_ModelSlot = { isHall = false },
		Room_Exit = { isHall = false },
		Room_Safe = { isHall = false },
		Room_Storage = { isHall = false },
		Room_Fuse = { isHall = false },
		Room_Flooded = { isHall = false },
		Room_Study = { isHall = false },
		Room_Generator = { isHall = false },
		Room_Archive = { isHall = false },
	}

	local order = {
		"HallDeadEnd",
		"HallCorner",
		"HallStraight",
		"HallT",
		"HallCross",
		"Room_Mirror",
		"Room_ModelSlot",
		"Room_Exit",
		"Room_Safe",
		"Room_Storage",
		"Room_Fuse",
		"Room_Flooded",
		"Room_Study",
		"Room_Generator",
		"Room_Archive",
	}

	local results: { PrefabCheckResult } = {}
	for _, name in order do
		local inst = folder:FindFirstChild(name)
		assert(inst ~= nil and inst:IsA("Model"), "Missing prefab Model in ServerStorage/BunkerPrefabs: " .. name)
		table.insert(results, PrefabValidator.validateOne(inst, expected[name]))
	end

	return results
end

return PrefabValidator
