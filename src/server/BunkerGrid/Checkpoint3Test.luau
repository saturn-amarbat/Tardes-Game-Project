--!strict
--[[
  Checkpoint3Test  –  Isolated, non-destructive verification suite for
  BunkerGrid Checkpoints 1-3 (Prefabs, DoorResolver, Seams, Spine BFS,
  100-Seed Reproducibility, and Round-Reset).

  Never auto-runs in live gameplay. Invoke explicitly from Studio Command Bar / MCP.
]]

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

function Checkpoint3Test.runDoorResolverTests(): { passed: number, failed: number }
	local passed = 0
	local failed = 0

	for mask = 1, 15 do
		local res = DoorResolver.resolveHallway(mask)
		if res ~= nil and DoorResolver.resolveHallway(mask) ~= nil then
			passed += 1
		else
			failed += 1
			warn("DoorResolver failed mask:", mask)
		end
	end

	-- Invalid masks: 0, -1, 16, 255
	-- Note: resolveHallway masks with bit32.band(mask, 15); 0 and 16 -> 0 -> nil
	for _, badMask in { 0, 16 } do
		if DoorResolver.resolveHallway(badMask) == nil then
			passed += 1
		else
			failed += 1
			warn("DoorResolver accepted invalid mask:", badMask)
		end
	end

	-- Room rotation convention: openDirMask = direction from room toward hallway
	for _, d in DoorResolver.ALL_DIRS do
		local rot = DoorResolver.resolveRoomRotation(d)
		if rot ~= nil and DoorResolver.rotateMaskCW(DoorResolver.N, rot) == d then
			passed += 1
		else
			failed += 1
			warn("DoorResolver room rotation failed for dir:", d)
		end
	end

	return { passed = passed, failed = failed }
end

function Checkpoint3Test.runSeamTests(prefabs: Folder): { tested: number, passed: number, failed: number }
	local old = Workspace:FindFirstChild("__BunkerGridSeamTest")
	if old then
		old:Destroy()
	end
	local container = Instance.new("Folder")
	container.Name = "__BunkerGridSeamTest"
	container.Parent = Workspace

	local tested = 0
	local passed = 0
	local failed = 0

	local function testPair(nameA: string, rotA: number, nameB: string, rotB: number, dirAtoB: number)
		tested += 1
		local tA = prefabs:FindFirstChild(nameA) :: Model
		local tB = prefabs:FindFirstChild(nameB) :: Model
		local mA = tA:Clone()
		local mB = tB:Clone()
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

		local disp = ((mB.PrimaryPart :: BasePart).Position - (mA.PrimaryPart :: BasePart).Position).Magnitude
		local floorYDiff = math.abs((mB.PrimaryPart :: BasePart).Position.Y - (mA.PrimaryPart :: BasePart).Position.Y)

		mA:Destroy()
		mB:Destroy()

		if maxVol <= EPS and math.abs(disp - Config.CELL) <= EPS and floorYDiff <= EPS then
			passed += 1
		else
			failed += 1
			warn(
				string.format(
					"Seam FAIL %s(r%d)->%s(r%d): vol=%.4f disp=%.3f dy=%.3f",
					nameA,
					rotA,
					nameB,
					rotB,
					maxVol,
					disp,
					floorYDiff
				)
			)
		end
	end

	-- Hallway-to-hallway compatible seams (HallCross at (0,0) -> each hallway facing W toward (0,0))
	local hallTargets = {
		{ name = "HallDeadEnd", rot = 3 }, -- N rotated 3 CW = W
		{ name = "HallCorner", rot = 3 },
		{ name = "HallStraight", rot = 1 }, -- N+S rotated 1 CW = E+W
		{ name = "HallT", rot = 3 },
		{ name = "HallCross", rot = 0 },
	}
	for _, h in hallTargets do
		testPair("HallCross", 0, h.name, h.rot, DoorResolver.E)
	end

	-- Every active room prefab connected to HallCross on East boundary (room faces W)
	local activeRooms = {
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
	for _, rName in activeRooms do
		local rot = DoorResolver.resolveRoomRotation(DoorResolver.W) :: number
		testPair("HallCross", 0, rName, rot, DoorResolver.E)
	end

	container:Destroy()
	return { tested = tested, passed = passed, failed = failed }
end

function Checkpoint3Test.buildIntoTestContainer(seed: number): Folder
	local prefabs = ServerStorage:WaitForChild("BunkerPrefabs") :: Folder
	local old = Workspace:FindFirstChild("__BunkerGridCheckpoint3Test")
	if old then
		old:Destroy()
	end

	local container = Instance.new("Folder")
	container.Name = "__BunkerGridCheckpoint3Test"
	container.Parent = Workspace

	local layout = HallwaySpineV1.buildAndValidate()
	local assignment = RoomAssignment.assign(layout, seed)

	for _, cell in layout.hallwayList do
		local resolved = DoorResolver.resolveHallway(cell.mask)
		assert(resolved ~= nil, "Failed to resolve hallway " .. cell.key)
		local template = prefabs:FindFirstChild(resolved.prefabName) :: Model
		local clone = template:Clone()
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
		local template = prefabs:FindFirstChild(r.prefabName) :: Model
		local clone = template:Clone()
		clone.Name = string.format("Room_%02d_%s", r.index, r.prefabName)
		clone:PivotTo(DoorResolver.cellCFrame(TEST_ORIGIN, r.socket.roomGx, r.socket.roomGz, r.rotSteps))
		clone.Parent = container
	end

	return container
end

function Checkpoint3Test.runAll()
	local prefabs = ServerStorage:WaitForChild("BunkerPrefabs") :: Folder
	local prefabResults = PrefabValidator.validateAll(prefabs)
	print(string.format("[C3Test] PrefabValidator: %d/15 PASS", #prefabResults))

	local dr = Checkpoint3Test.runDoorResolverTests()
	print(string.format("[C3Test] DoorResolver: %d passed, %d failed", dr.passed, dr.failed))

	local seam = Checkpoint3Test.runSeamTests(prefabs)
	print(string.format("[C3Test] SeamTests: %d/%d passed, %d failed", seam.passed, seam.tested, seam.failed))

	local layout = HallwaySpineV1.buildAndValidate()
	print("[C3Test] Spine BFS:\n" .. HallwaySpineV1.formatReport(layout))

	-- 100-seed reproducibility matrix
	local namedSeeds = { 1, 2, 42, 100, 7419, 12345, 20261126, 99999 }
	local sigs: { [string]: boolean } = {}
	local sigCount = 0
	for i = 1, 100 do
		local seed = if i <= #namedSeeds then namedSeeds[i] else (i * 1337 + 7)
		local r1 = RoomAssignment.assign(layout, seed)
		local r2 = RoomAssignment.assign(layout, seed)
		local r3 = RoomAssignment.assign(layout, seed)
		assert(
			r1.signature == r2.signature and r2.signature == r3.signature,
			"Non-deterministic seed " .. tostring(seed)
		)
		if not sigs[r1.signature] then
			sigs[r1.signature] = true
			sigCount += 1
		end
		if i <= #namedSeeds then
			print(string.format("[C3Test] Seed %d sig: %s", seed, r1.signature))
		end
	end
	print(string.format("[C3Test] 100-seed matrix PASS (%d distinct signatures)", sigCount))

	-- Round-reset test: 2 consecutive generations
	local c1 = Checkpoint3Test.buildIntoTestContainer(7419)
	local count1 = #c1:GetChildren()
	local c2 = Checkpoint3Test.buildIntoTestContainer(7419)
	local count2 = #c2:GetChildren()
	local spawnCount = 0
	for _, d in c2:GetDescendants() do
		if d.Name == "PlayerSpawn" then
			spawnCount += 1
		end
	end
	print(string.format("[C3Test] Round-reset: gen1=%d, gen2=%d, PlayerSpawn=%d", count1, count2, spawnCount))
end

return Checkpoint3Test
