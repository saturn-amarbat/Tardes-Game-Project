--!strict
--[[
  Checkpoint3Test  –  Isolated, non-destructive verification suite for
  BunkerGrid Checkpoints 1-3 (Prefabs, DoorResolver, Exhaustive Seams,
  Spine BFS, 100-Seed Reproducibility, and Round-Reset).

  Never auto-runs in live gameplay. Invoke explicitly from Studio Command Bar / MCP.
]]

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local DoorResolver = require(script.Parent.DoorResolver)
local HallwaySpineV1 = require(script.Parent.HallwaySpineV1)
local PrefabValidator = require(script.Parent.PrefabValidator)
local RoomAssignment = require(script.Parent.RoomAssignment)

local Checkpoint3Test = {}

local EPS = 1e-3
local TEST_ORIGIN = CFrame.new(0, 38, -160)
local OWNER_ATTR = "BunkerGridTestOwner"
local OWNER_VAL = "Checkpoint3Test"

local ACTIVE_ROOMS: { string } = {
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

local SPECIAL_SET: { [string]: boolean } = {
	Room_Mirror = true,
	Room_ModelSlot = true,
	Room_Safe = true,
	Room_Exit = true,
}

local function destroyOwnedContainers(name: string)
	for _, child in Workspace:GetChildren() do
		if child.Name == name and child:GetAttribute(OWNER_ATTR) == OWNER_VAL then
			child:Destroy()
		end
	end
end

local function createOwnedContainer(name: string, runId: string): Folder
	destroyOwnedContainers(name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder:SetAttribute(OWNER_ATTR, OWNER_VAL)
	folder:SetAttribute("TestRunId", runId)
	folder.Parent = Workspace
	return folder
end

local function partWorldAABB(part: BasePart): (Vector3, Vector3)
	local cf = part.CFrame
	local half = part.Size * 0.5
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local c = cf:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
				minV = Vector3.new(math.min(minV.X, c.X), math.min(minV.Y, c.Y), math.min(minV.Z, c.Z))
				maxV = Vector3.new(math.max(maxV.X, c.X), math.max(maxV.Y, c.Y), math.max(maxV.Z, c.Z))
			end
		end
	end
	return minV, maxV
end

local function overlapVol(minA: Vector3, maxA: Vector3, minB: Vector3, maxB: Vector3): number
	local ox = math.min(maxA.X, maxB.X) - math.max(minA.X, minB.X)
	local oy = math.min(maxA.Y, maxB.Y) - math.max(minA.Y, minB.Y)
	local oz = math.min(maxA.Z, maxB.Z) - math.max(minA.Z, minB.Z)
	if ox > EPS and oy > EPS and oz > EPS then
		return ox * oy * oz
	end
	return 0
end

local function collectCollidableBoxes(model: Model): { { name: string, minV: Vector3, maxV: Vector3 } }
	local out: { { name: string, minV: Vector3, maxV: Vector3 } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			local minV, maxV = partWorldAABB(d)
			table.insert(out, { name = d.Name, minV = minV, maxV = maxV })
		end
	end
	return out
end

function Checkpoint3Test.runDoorResolverTests(): boolean
	local BASE_MASK_BY_NAME: { [string]: number } = {
		HallDeadEnd = 1,
		HallCorner = 3,
		HallStraight = 5,
		HallT = 11,
		HallCross = 15,
	}

	local EXPECTED_MASKS: { [number]: { name: string, rot: number } } = {
		[1] = { name = "HallDeadEnd", rot = 0 },
		[2] = { name = "HallDeadEnd", rot = 1 },
		[3] = { name = "HallCorner", rot = 0 },
		[4] = { name = "HallDeadEnd", rot = 2 },
		[5] = { name = "HallStraight", rot = 0 },
		[6] = { name = "HallCorner", rot = 1 },
		[7] = { name = "HallT", rot = 1 },
		[8] = { name = "HallDeadEnd", rot = 3 },
		[9] = { name = "HallCorner", rot = 3 },
		[10] = { name = "HallStraight", rot = 1 },
		[11] = { name = "HallT", rot = 0 },
		[12] = { name = "HallCorner", rot = 2 },
		[13] = { name = "HallT", rot = 3 },
		[14] = { name = "HallT", rot = 2 },
		[15] = { name = "HallCross", rot = 0 },
	}

	for mask = 1, 15 do
		local exp = EXPECTED_MASKS[mask]
		local res = DoorResolver.resolveHallway(mask)
		assert(res ~= nil, "DoorResolver returned nil for valid mask " .. tostring(mask))
		assert(
			res.prefabName == exp.name and res.rotSteps == exp.rot,
			string.format(
				"DoorResolver mask %d: expected %s@r%d, got %s@r%d",
				mask,
				exp.name,
				exp.rot,
				res.prefabName,
				res.rotSteps
			)
		)
		assert(res.rotSteps >= 0 and res.rotSteps <= 3, "Rotation out of 0..3")
		local baseMask = BASE_MASK_BY_NAME[res.prefabName]
		assert(DoorResolver.rotateMaskCW(baseMask, res.rotSteps) == mask, "Rotated base mask mismatch")
	end

	for _, badMask in { 0, -1, 16, 255, 1.5 } do
		assert(DoorResolver.resolveHallway(badMask) == nil, "DoorResolver accepted invalid mask: " .. tostring(badMask))
	end

	for _, d in DoorResolver.ALL_DIRS do
		local rot = DoorResolver.resolveRoomRotation(d)
		assert(rot ~= nil and DoorResolver.rotateMaskCW(DoorResolver.N, rot) == d, "Room rotation failed for dir " .. d)
	end

	print("[C3Test] DoorResolver: 15/15 masks + 5 invalid inputs + 4 room orientations PASS")
	return true
end

function Checkpoint3Test.runSeamTests(prefabs: Folder, runId: string): boolean
	local container = createOwnedContainer("__BunkerGridSeamTest", runId)
	local tested = 0
	local passed = 0
	local failed = 0

	local ok, err = pcall(function()
		local function testPair(nameA: string, rotA: number, nameB: string, rotB: number, dirAtoB: number)
			tested += 1
			local mA = (prefabs:FindFirstChild(nameA) :: Model):Clone()
			local mB = (prefabs:FindFirstChild(nameB) :: Model):Clone()
			local delta = DoorResolver.DIR_DELTA[dirAtoB]
			mA:PivotTo(DoorResolver.cellCFrame(TEST_ORIGIN, 0, 0, rotA))
			mB:PivotTo(DoorResolver.cellCFrame(TEST_ORIGIN, delta.dx, delta.dz, rotB))
			mA.Parent = container
			mB.Parent = container

			local boxesA = collectCollidableBoxes(mA)
			local boxesB = collectCollidableBoxes(mB)
			local maxVol = 0
			for _, a in boxesA do
				for _, b in boxesB do
					local v = overlapVol(a.minV, a.maxV, b.minV, b.maxV)
					if v > maxVol then
						maxVol = v
					end
				end
			end

			-- Physical 8x9 doorway clearance box centered on shared boundary above floor top
			local floorTopY = (mA.PrimaryPart :: BasePart).Position.Y + 0.5
			local midPos = Vector3.new(
				TEST_ORIGIN.Position.X + delta.dx * Config.CELL * 0.5,
				floorTopY + Config.DOOR_H * 0.5,
				TEST_ORIGIN.Position.Z + delta.dz * Config.CELL * 0.5
			)
			local halfW = Config.DOOR_W * 0.5 - 0.1
			local halfH = Config.DOOR_H * 0.5 - 0.1
			local clearMin = midPos
				- Vector3.new(if delta.dx ~= 0 then 1.2 else halfW, halfH, if delta.dz ~= 0 then 1.2 else halfW)
			local clearMax = midPos
				+ Vector3.new(if delta.dx ~= 0 then 1.2 else halfW, halfH, if delta.dz ~= 0 then 1.2 else halfW)
			local doorBlocked = false
			for _, a in boxesA do
				if overlapVol(a.minV, a.maxV, clearMin, clearMax) > EPS then
					doorBlocked = true
				end
			end
			for _, b in boxesB do
				if overlapVol(b.minV, b.maxV, clearMin, clearMax) > EPS then
					doorBlocked = true
				end
			end

			local disp = ((mB.PrimaryPart :: BasePart).Position - (mA.PrimaryPart :: BasePart).Position).Magnitude
			local floorYDiff =
				math.abs((mB.PrimaryPart :: BasePart).Position.Y - (mA.PrimaryPart :: BasePart).Position.Y)

			mA:Destroy()
			mB:Destroy()

			if maxVol <= EPS and not doorBlocked and math.abs(disp - Config.CELL) <= EPS and floorYDiff <= EPS then
				passed += 1
			else
				failed += 1
				warn(string.format("Seam FAIL %s(r%d)->%s(r%d) dir=%d", nameA, rotA, nameB, rotB, dirAtoB))
			end
		end

		-- Enumerate all 15 hallway masks x 4 dirs against compatible 5 base hallway prefabs
		for maskA = 1, 15 do
			local resA = DoorResolver.resolveHallway(maskA) :: DoorResolver.ResolvedTile
			for _, d in DoorResolver.ALL_DIRS do
				if bit32.band(maskA, d) ~= 0 then
					local opp = DoorResolver.OPPOSITE[d]
					local resB = DoorResolver.resolveHallway(opp) :: DoorResolver.ResolvedTile
					testPair(resA.prefabName, resA.rotSteps, resB.prefabName, resB.rotSteps, d)
				end
			end
		end

		-- All 10 active room prefabs across all 4 directions
		for _, rName in ACTIVE_ROOMS do
			for _, d in DoorResolver.ALL_DIRS do
				local opp = DoorResolver.OPPOSITE[d]
				local hallRes = DoorResolver.resolveHallway(d) :: DoorResolver.ResolvedTile
				local roomRot = DoorResolver.resolveRoomRotation(opp) :: number
				testPair(hallRes.prefabName, hallRes.rotSteps, rName, roomRot, d)
			end
		end
	end)

	destroyOwnedContainers("__BunkerGridSeamTest")
	if not ok then
		error(err)
	end
	print(string.format("[C3Test] SeamTests: %d/%d passed, %d failed", passed, tested, failed))
	assert(failed == 0, "SeamTests had failures")
	return true
end

function Checkpoint3Test.buildIntoTestContainer(seed: number, runId: string): Folder
	local prefabs = ServerStorage:WaitForChild("BunkerPrefabs") :: Folder
	local container = createOwnedContainer("__BunkerGridCheckpoint3Test", runId)
	local layout = HallwaySpineV1.buildAndValidate()
	local assignment = RoomAssignment.assign(layout, seed)

	for _, cell in layout.hallwayList do
		local resolved = DoorResolver.resolveHallway(cell.mask) :: DoorResolver.ResolvedTile
		local clone = (prefabs:FindFirstChild(resolved.prefabName) :: Model):Clone()
		clone.Name = string.format("Hall_%s_%s", cell.key, resolved.prefabName)
		if cell.role ~= "start" then
			local ps = clone:FindFirstChild("PlayerSpawn")
			if ps then
				ps:Destroy()
			end
		end
		clone:PivotTo(DoorResolver.cellCFrame(TEST_ORIGIN, cell.gx, cell.gz, resolved.rotSteps))
		clone.Parent = container
	end

	for _, r in assignment.orderedRooms do
		local clone = (prefabs:FindFirstChild(r.prefabName) :: Model):Clone()
		clone.Name = string.format("Room_%02d_%s", r.index, r.prefabName)
		clone:PivotTo(DoorResolver.cellCFrame(TEST_ORIGIN, r.socket.roomGx, r.socket.roomGz, r.rotSteps))
		clone.Parent = container
	end

	return container
end

function Checkpoint3Test.runAll()
	local runId = HttpService:GenerateGUID(false)
	local prefabs = ServerStorage:WaitForChild("BunkerPrefabs") :: Folder

	local prefabResults = PrefabValidator.validateAll(prefabs)
	assert(#prefabResults == 15, "Expected 15 validated prefabs")
	for _, r in prefabResults do
		assert(r.ok, "Prefab failed: " .. r.name)
	end
	print(string.format("[C3Test] Prefab validation: PASS (%d/15)", #prefabResults))

	Checkpoint3Test.runDoorResolverTests()
	Checkpoint3Test.runSeamTests(prefabs, runId)

	local layout = HallwaySpineV1.buildAndValidate()
	print("[C3Test] Structural BFS:\n" .. HallwaySpineV1.formatReport(layout))

	local namedSeeds = { 1, 2, 42, 100, 7419, 12345, 20261126, 99999 }
	local sigs: { [string]: boolean } = {}
	local sigCount = 0
	for i = 1, 100 do
		local seed = if i <= #namedSeeds then namedSeeds[i] else (i * 1337 + 7)
		local r1 = RoomAssignment.assign(layout, seed)
		local r2 = RoomAssignment.assign(layout, seed)
		local r3 = RoomAssignment.assign(layout, seed)
		assert(r1.signature == r2.signature and r2.signature == r3.signature, "Non-deterministic seed " .. seed)
		assert(#r1.orderedRooms == 10, "Expected 10 rooms")
		assert(r1.orderedRooms[1].category == "Standard", "rooms[1] must be Standard")
		assert(r1.orderedRooms[10].prefabName == "Room_Exit", "rooms[10] must be Room_Exit")
		local seenTypes: { [string]: boolean } = {}
		local specialCount = 0
		for idx, rm in r1.orderedRooms do
			assert(rm.index == idx, "Index mismatch")
			assert(not seenTypes[rm.prefabName], "Duplicate room type")
			seenTypes[rm.prefabName] = true
			if SPECIAL_SET[rm.prefabName] then
				specialCount += 1
			end
			if idx >= 2 and idx <= 9 then
				assert(rm.socket.socketDist >= r1.orderedRooms[idx - 1].socket.socketDist, "BFS order violated")
			end
		end
		assert(specialCount == 4, "Expected 4 special rooms")
		if not sigs[r1.signature] then
			sigs[r1.signature] = true
			sigCount += 1
		end
		if i <= #namedSeeds then
			print(string.format("[C3Test] Seed %d sig: %s", seed, r1.signature))
		end
	end
	print(string.format("[C3Test] 100-seed matrix (300 runs): PASS (%d distinct signatures)", sigCount))

	local okReset, errReset = pcall(function()
		local c1 = Checkpoint3Test.buildIntoTestContainer(7419, runId)
		assert(#c1:GetChildren() == 22, "Gen1 must have 22 models")
		local c2 = Checkpoint3Test.buildIntoTestContainer(12345, runId)
		assert(#c2:GetChildren() == 22, "Gen2 must have 22 models")
		local spawnCount = 0
		for _, d in c2:GetDescendants() do
			if d.Name == "PlayerSpawn" then
				spawnCount += 1
			end
		end
		assert(spawnCount == 1, "Expected exactly 1 PlayerSpawn, got " .. spawnCount)
	end)
	destroyOwnedContainers("__BunkerGridCheckpoint3Test")
	if not okReset then
		error(errReset)
	end
	print("[C3Test] Round reset & cleanup: PASS")
	print("[C3Test] Overall Checkpoint 3: PASS")
end

return Checkpoint3Test
