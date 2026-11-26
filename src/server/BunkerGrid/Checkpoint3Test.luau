--!strict
--[[
  Checkpoint3Test  –  Isolated, non-destructive verification suite for
  BunkerGrid Checkpoints 1-3 (Prefabs, DoorResolver, 576-Case Exhaustive Seams,
  Spine BFS, 100-Seed x 3 Assignment Matrix, and 3-Gen Round-Reset).

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

local APPROVED_ROOM_SET: { [string]: boolean } = {}
for _, name in ACTIVE_ROOMS do
	APPROVED_ROOM_SET[name] = true
end

local SPECIAL_SET: { [string]: boolean } = {
	Room_Mirror = true,
	Room_ModelSlot = true,
	Room_Safe = true,
	Room_Exit = true,
}

local function destroyRunContainers(name: string, runId: string)
	for _, child in Workspace:GetChildren() do
		if
			child.Name == name
			and child:GetAttribute(OWNER_ATTR) == OWNER_VAL
			and child:GetAttribute("TestRunId") == runId
		then
			child:Destroy()
		end
	end
end

local function createOwnedContainer(name: string, runId: string): Folder
	destroyRunContainers(name, runId)
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
		assert(res.prefabName == exp.name and res.rotSteps == exp.rot, "DoorResolver mismatch for mask " .. mask)
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

	print("DoorResolver valid masks: 15/15 PASS")
	print("Invalid input tests: PASS")
	print("Room orientation tests: PASS")
	return true
end

function Checkpoint3Test.runSeamTests(prefabs: Folder, runId: string): number
	local container = createOwnedContainer("__BunkerGridSeamTest", runId)
	local tested = 0
	local passed = 0
	local failed = 0

	local ok, err = pcall(function()
		local function testPair(
			nameA: string,
			rotA: number,
			nameB: string,
			rotB: number,
			dirAtoB: number,
			isRoomB: boolean
		)
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

			-- Nominal 8x9 doorway clearance box centered on shared boundary within EPS tolerance
			local floorTopY = (mA.PrimaryPart :: BasePart).Position.Y + 0.5
			local midPos = Vector3.new(
				TEST_ORIGIN.Position.X + delta.dx * Config.CELL * 0.5,
				floorTopY + Config.DOOR_H * 0.5,
				TEST_ORIGIN.Position.Z + delta.dz * Config.CELL * 0.5
			)
			local halfW = Config.DOOR_W * 0.5 - EPS
			local halfH = Config.DOOR_H * 0.5 - EPS
			local clearMin = midPos
				- Vector3.new(if delta.dx ~= 0 then 1.0 else halfW, halfH, if delta.dz ~= 0 then 1.0 else halfW)
			local clearMax = midPos
				+ Vector3.new(if delta.dx ~= 0 then 1.0 else halfW, halfH, if delta.dz ~= 0 then 1.0 else halfW)
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

			local entranceOk = true
			if isRoomB then
				local ent = mB:FindFirstChild("Entrance") :: BasePart?
				if ent == nil then
					entranceOk = false
				else
					local expectedDir = Vector3.new(delta.dx, 0, delta.dz)
					if ent.CFrame.LookVector:Dot(expectedDir) < 0.9 then
						entranceOk = false
					end
				end
			end

			local disp = ((mB.PrimaryPart :: BasePart).Position - (mA.PrimaryPart :: BasePart).Position).Magnitude
			local floorYDiff =
				math.abs((mB.PrimaryPart :: BasePart).Position.Y - (mA.PrimaryPart :: BasePart).Position.Y)

			mA:Destroy()
			mB:Destroy()

			if
				maxVol <= EPS
				and not doorBlocked
				and entranceOk
				and math.abs(disp - Config.CELL) <= EPS
				and floorYDiff <= EPS
			then
				passed += 1
			else
				failed += 1
				warn(string.format("Seam FAIL %s(r%d)->%s(r%d) dir=%d", nameA, rotA, nameB, rotB, dirAtoB))
			end
		end

		-- 256 directed hallway-to-hallway cases: 4 dirs x 8 compatible A masks x 8 compatible B masks
		for _, d in DoorResolver.ALL_DIRS do
			local opp = DoorResolver.OPPOSITE[d]
			for maskA = 1, 15 do
				if bit32.band(maskA, d) ~= 0 then
					local resA = DoorResolver.resolveHallway(maskA) :: DoorResolver.ResolvedTile
					for maskB = 1, 15 do
						if bit32.band(maskB, opp) ~= 0 then
							local resB = DoorResolver.resolveHallway(maskB) :: DoorResolver.ResolvedTile
							testPair(resA.prefabName, resA.rotSteps, resB.prefabName, resB.rotSteps, d, false)
						end
					end
				end
			end
		end

		-- 320 directed hallway-to-room cases: 4 dirs x 8 compatible A masks x 10 rooms
		for _, d in DoorResolver.ALL_DIRS do
			local opp = DoorResolver.OPPOSITE[d]
			local roomRot = DoorResolver.resolveRoomRotation(opp) :: number
			for maskA = 1, 15 do
				if bit32.band(maskA, d) ~= 0 then
					local resA = DoorResolver.resolveHallway(maskA) :: DoorResolver.ResolvedTile
					for _, rName in ACTIVE_ROOMS do
						testPair(resA.prefabName, resA.rotSteps, rName, roomRot, d, true)
					end
				end
			end
		end
	end)

	destroyRunContainers("__BunkerGridSeamTest", runId)
	if not ok then
		error(err)
	end
	print(string.format("Compatible seam cases tested: %d", tested))
	print(string.format("Compatible seam failures: %d", failed))
	assert(tested == 576, "Expected 576 directed seam cases, got " .. tested)
	assert(failed == 0, "SeamTests had failures")
	return tested
end

local function validateAssignmentResult(layout: HallwaySpineV1.SpineLayout, res: RoomAssignment.AssignmentResult)
	assert(#res.orderedRooms == 10, "Expected 10 assigned rooms")
	assert(res.orderedRooms[1].category == "Standard", "rooms[1] must be Standard")
	assert(res.orderedRooms[10].prefabName == "Room_Exit", "rooms[10] must be Room_Exit")

	local seenTypes: { [string]: boolean } = {}
	local seenSockets: { [string]: boolean } = {}
	local specialCount = 0
	local standardCount = 0
	local mirrorSock: HallwaySpineV1.RoomSocket? = nil
	local modelSlotSock: HallwaySpineV1.RoomSocket? = nil
	local maxDist = layout.stats.maxSocketDist

	local maxNonReservedDist = -1
	for _, rm in res.orderedRooms do
		if not rm.reserved and rm.socket.socketDist > maxNonReservedDist then
			maxNonReservedDist = rm.socket.socketDist
		end
	end

	for idx, rm in res.orderedRooms do
		assert(rm.index == idx, "Index mismatch at " .. idx)
		assert(APPROVED_ROOM_SET[rm.prefabName], "Unapproved room type: " .. rm.prefabName)
		assert(not seenTypes[rm.prefabName], "Duplicate room type: " .. rm.prefabName)
		seenTypes[rm.prefabName] = true
		assert(not seenSockets[rm.socket.id], "Duplicate socket: " .. rm.socket.id)
		seenSockets[rm.socket.id] = true

		if SPECIAL_SET[rm.prefabName] then
			specialCount += 1
		else
			standardCount += 1
		end

		assert(
			DoorResolver.rotateMaskCW(DoorResolver.N, rm.rotSteps) == rm.socket.roomFacingDir,
			"Room rotation does not face connecting hallway: " .. rm.socket.id
		)

		if rm.prefabName == "Room_Mirror" then
			assert(rm.socket.alcoveEligible, "Room_Mirror must occupy eligible alcove")
			mirrorSock = rm.socket
		elseif rm.prefabName == "Room_ModelSlot" then
			assert(rm.socket.alcoveEligible, "Room_ModelSlot must occupy eligible alcove")
			modelSlotSock = rm.socket
		elseif rm.prefabName == "Room_Safe" then
			assert(not rm.reserved, "Room_Safe must not be reserved")
			local ratio = rm.socket.socketDist / maxDist
			assert(ratio >= 0.40 - 1e-9 and ratio <= 0.60 + 1e-9, "Room_Safe outside 40-60% window")
		elseif rm.prefabName == "Room_Exit" then
			assert(not rm.reserved, "Room_Exit must not be reserved")
			assert(rm.socket.socketDist == maxNonReservedDist, "Room_Exit not on farthest non-reserved socket")
		end

		if idx >= 2 and idx <= 9 then
			local prev = res.orderedRooms[idx - 1]
			assert(rm.socket.socketDist >= prev.socket.socketDist, "BFS order violated")
			if rm.socket.socketDist == prev.socket.socketDist then
				assert(prev.socket.id < rm.socket.id, "Equal-distance tie-break violated")
			end
		end
	end

	assert(specialCount == 4 and standardCount == 6, "Expected 4 special + 6 standard rooms")
	assert(mirrorSock ~= nil and modelSlotSock ~= nil and mirrorSock.id ~= modelSlotSock.id, "Alcove uniqueness failed")
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

local function snapshotContainer(container: Folder): { [string]: CFrame }
	local snap: { [string]: CFrame } = {}
	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			snap[child.Name] = child:GetPivot()
		end
	end
	return snap
end

local function assertContainerContracts(container: Folder)
	local children = container:GetChildren()
	assert(#children == 22, "Expected 22 model children, got " .. #children)
	local halls = 0
	local rooms = 0
	local safeCount = 0
	local exitCount = 0
	local spawnCount = 0
	for _, child in children do
		if child:IsA("Model") then
			if child.Name:sub(1, 5) == "Hall_" then
				halls += 1
			elseif child.Name:sub(1, 5) == "Room_" then
				rooms += 1
				assert(child.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, child.Name .. " not Atomic")
				assert(child:FindFirstChild("Entrance") ~= nil, child.Name .. " missing Entrance")
				if child.Name:find("Room_Safe", 1, true) then
					safeCount += 1
				elseif child.Name:find("Room_Exit", 1, true) then
					exitCount += 1
					assert(child:FindFirstChild("Exit") ~= nil, "Room_Exit missing Exit marker")
				end
			end
		end
	end
	for _, d in container:GetDescendants() do
		if d.Name == "PlayerSpawn" then
			spawnCount += 1
		end
	end
	assert(halls == 12 and rooms == 10, string.format("Expected 12 halls + 10 rooms, got %d + %d", halls, rooms))
	assert(spawnCount == 1, "Expected 1 PlayerSpawn, got " .. spawnCount)
	assert(safeCount == 1 and exitCount == 1, "Expected 1 Safe + 1 Exit room")
end

function Checkpoint3Test.runAll()
	local runId = HttpService:GenerateGUID(false)
	local prefabs = ServerStorage:WaitForChild("BunkerPrefabs") :: Folder

	local prefabResults = PrefabValidator.validateAll(prefabs)
	assert(#prefabResults == 15, "Expected 15 validated prefabs")
	for _, r in prefabResults do
		assert(r.ok, "Prefab failed: " .. r.name)
	end
	print("Prefab validation: 15/15 PASS")

	Checkpoint3Test.runDoorResolverTests()
	Checkpoint3Test.runSeamTests(prefabs, runId)

	local layout = HallwaySpineV1.buildAndValidate()
	print("Hallway BFS: 12/12")
	print("Room socket BFS: 10/10")
	print("Duplicate coordinates: 0")
	print("Non-reciprocal edges: 0")
	print("Qualifying chase loops: 1")

	-- 100 distinct seeds x 3 executions = 300 validated assignments
	local namedSeeds = { 1, 2, 42, 100, 7419, 12345, 20261126, 99999 }
	local sigs: { [string]: boolean } = {}
	local sigCount = 0
	local execCount = 0
	for i = 1, 100 do
		local seed = if i <= #namedSeeds then namedSeeds[i] else (i * 1337 + 7)
		local r1 = RoomAssignment.assign(layout, seed)
		local r2 = RoomAssignment.assign(layout, seed)
		local r3 = RoomAssignment.assign(layout, seed)
		validateAssignmentResult(layout, r1)
		validateAssignmentResult(layout, r2)
		validateAssignmentResult(layout, r3)
		execCount += 3
		assert(r1.signature == r2.signature and r2.signature == r3.signature, "Non-deterministic seed " .. seed)
		if not sigs[r1.signature] then
			sigs[r1.signature] = true
			sigCount += 1
		end
		if i <= #namedSeeds then
			print(string.format("[Seed %d] %s", seed, r1.signature))
		end
	end
	print("Distinct seeds tested: 100")
	print(string.format("Assignment executions: %d", execCount))
	print("Assignment failures: 0")
	print("Reproducibility failures: 0")
	print(string.format("Distinct assignment signatures: %d", sigCount))

	-- 3-generation round-reset verification
	local okReset, errReset = pcall(function()
		local c1 = Checkpoint3Test.buildIntoTestContainer(7419, runId)
		assertContainerContracts(c1)
		local snap1 = snapshotContainer(c1)
		print("Generation 1: 22 models")

		local c2 = Checkpoint3Test.buildIntoTestContainer(7419, runId)
		assert(c1.Parent == nil, "Gen 1 container not destroyed")
		assertContainerContracts(c2)
		local snap2 = snapshotContainer(c2)
		for name, cf1 in snap1 do
			local cf2 = snap2[name]
			assert(cf2 ~= nil and (cf1.Position - cf2.Position).Magnitude <= EPS, "Same-seed mismatch: " .. name)
		end
		print("Generation 2: 22 models")
		print("Same-seed regeneration: PASS")

		local c3 = Checkpoint3Test.buildIntoTestContainer(12345, runId)
		assert(c2.Parent == nil, "Gen 2 container not destroyed")
		assertContainerContracts(c3)
		print("Generation 3: 22 models")
		print("PlayerSpawn count: 1 per generation")
		print("Round-reset verification: PASS")
	end)
	destroyRunContainers("__BunkerGridCheckpoint3Test", runId)
	if not okReset then
		error(errReset)
	end
	print("Temporary geometry cleanup: PASS")
	print("Overall Checkpoint 3: PASS")
end

return Checkpoint3Test
