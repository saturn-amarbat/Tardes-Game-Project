--!strict
--[[
  Checkpoint4Test  –  Isolated physical reachability, chase-loop edge,
  and negative-lifecycle test suite for BunkerGrid Checkpoint 4.

  Never auto-runs in live gameplay. Invoke explicitly from Studio Command Bar / MCP.
]]

local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Checkpoint3Test = require(script.Parent.Checkpoint3Test)
local Config = require(script.Parent.Config)
local HallwaySpineV1 = require(script.Parent.HallwaySpineV1)
local ReachabilityValidator = require(script.Parent.ReachabilityValidator)
local RoomAssignment = require(script.Parent.RoomAssignment)

local Checkpoint4Test = {}

local SEEDS = { 7419, 12345, 42 }

local function destroyRunContainers(runId: string)
	for _, child in Workspace:GetChildren() do
		if
			child:GetAttribute("BunkerGridTestOwner") == "Checkpoint3Test"
			and child:GetAttribute("TestRunId") == runId
		then
			child:Destroy()
		end
	end
end

local function waitForValidation(req: ReachabilityValidator.ValidationRequest): ReachabilityValidator.ValidationReport
	local done = false
	local out: ReachabilityValidator.ValidationReport? = nil
	ReachabilityValidator.validateAsync(req, function(report)
		out = report
		done = true
	end)
	local t0 = os.clock()
	while not done and (os.clock() - t0) < 60 do
		task.wait(0.05)
	end
	assert(done and out ~= nil, "Validation timed out waiting for async callback")
	return out :: ReachabilityValidator.ValidationReport
end

local function runRoomReachabilityForSeed(seed: number, runId: string): (number, number)
	local container = Checkpoint3Test.buildIntoTestContainer(seed, runId)
	local layout = HallwaySpineV1.buildAndValidate()
	local assignment = RoomAssignment.assign(layout, seed)

	local playerSpawn = container:FindFirstChild("PlayerSpawn", true)
	assert(playerSpawn ~= nil and playerSpawn:IsA("BasePart"), "Missing PlayerSpawn")

	local roomByName: { [string]: Model } = {}
	for _, child in container:GetChildren() do
		if child:IsA("Model") and child.Name:sub(1, 5) == "Room_" then
			roomByName[child.Name] = child
		end
	end

	local targets: { ReachabilityValidator.NavTarget } = {}
	for _, rm in assignment.orderedRooms do
		local mName = string.format("Room_%02d_%s", rm.index, rm.prefabName)
		local m = roomByName[mName]
		assert(m ~= nil, "Missing room model " .. mName)
		table.insert(targets, { id = mName, model = m })
	end

	local report = waitForValidation({
		container = container,
		playerSpawn = playerSpawn,
		targets = targets,
		runId = runId .. "_" .. tostring(seed),
	})

	local passed = 0
	local failed = 0
	for i, res in report.results do
		local rm = assignment.orderedRooms[i]
		local ok = res.outcome == "Success"
		if ok then
			passed += 1
		else
			failed += 1
		end
		local tPos = res.targetPosition or Vector3.zero
		print(
			string.format(
				"Seed=%d | #%02d | %-14s | %s | (%d,%d) | d=%d | start=(%.1f,%.1f,%.1f) | target=(%.1f,%.1f,%.1f) | %s | att=%d | %.3fs | wp=%d | jmp=%d | end=%.2f | %s",
				seed,
				rm.index,
				rm.prefabName,
				rm.socket.id,
				rm.socket.roomGx,
				rm.socket.roomGz,
				rm.socket.socketDist,
				res.startPosition.X,
				res.startPosition.Y,
				res.startPosition.Z,
				tPos.X,
				tPos.Y,
				tPos.Z,
				tostring(res.outcome),
				res.attempts,
				res.elapsedSeconds,
				res.waypointCount,
				res.jumpWaypointCount,
				res.endpointDistance,
				if ok then "PASS" else "FAIL"
			)
		)
	end

	destroyRunContainers(runId)
	return passed, failed
end

local function runHallwayAndLoopTests(runId: string): (number, number, boolean)
	local container = Checkpoint3Test.buildIntoTestContainer(7419, runId)
	local layout = HallwaySpineV1.buildAndValidate()
	local playerSpawn = container:FindFirstChild("PlayerSpawn", true) :: BasePart

	local hallByKey: { [string]: Model } = {}
	for _, child in container:GetChildren() do
		if child:IsA("Model") and child.Name:sub(1, 5) == "Hall_" then
			for _, cell in layout.hallwayList do
				if child.Name:find("Hall_" .. cell.key .. "_", 1, true) then
					hallByKey[cell.key] = child
				end
			end
		end
	end

	-- 1. All 12 hallway cells from PlayerSpawn (for start cell 0,0 use +4X interior offset so start ~= target)
	local targets: { ReachabilityValidator.NavTarget } = {}
	for _, cell in layout.hallwayList do
		local posOverride: Vector3? = if cell.role == "start"
			then ReachabilityValidator.findWalkablePoint(hallByKey[cell.key], Vector3.new(4, 0, 0))
			else nil
		table.insert(targets, { id = "Hall_" .. cell.key, model = hallByKey[cell.key], position = posOverride })
	end
	local report = waitForValidation({
		container = container,
		playerSpawn = playerSpawn,
		targets = targets,
		runId = runId .. "_halls",
	})
	local hPass = 0
	local hFail = 0
	for _, r in report.results do
		if r.outcome == "Success" then
			hPass += 1
		else
			hFail += 1
		end
	end

	-- 2. Both sides of 3x3 ring around (2,1) via adjacent direct-edge checks (length <= CELL * 1.6)
	local northEastEdges = {
		{ "1,0", "2,0" },
		{ "2,0", "3,0" },
		{ "3,0", "3,1" },
		{ "3,1", "3,2" },
	}
	local westSouthEdges = {
		{ "1,0", "1,1" },
		{ "1,1", "1,2" },
		{ "1,2", "2,2" },
		{ "2,2", "3,2" },
	}

	local minB = Vector3.new(-500, 0, -500)
	local maxB = Vector3.new(500, 200, 500)
	local bothSidesOk = true
	for _, side in { northEastEdges, westSouthEdges } do
		for _, edge in side do
			local pA = ReachabilityValidator.findWalkablePoint(hallByKey[edge[1]]) :: Vector3
			local pB = ReachabilityValidator.findWalkablePoint(hallByKey[edge[2]]) :: Vector3
			local res = ReachabilityValidator.validateSingleRoute(
				pA,
				pB,
				minB,
				maxB,
				edge[1] .. "->" .. edge[2],
				Config.NAVMESH_POLL_TIMEOUT,
				Config.NAVMESH_POLL_INTERVAL,
				function()
					return false
				end,
				nil
			)
			if res.outcome ~= "Success" or res.routeLength > Config.CELL * 1.6 then
				bothSidesOk = false
				warn(
					string.format("Loop edge FAIL %s->%s: %s len=%.2f", edge[1], edge[2], res.outcome, res.routeLength)
				)
			end
		end
	end

	destroyRunContainers(runId)
	return hPass, hFail, bothSidesOk
end

local function runNegativeTests(runId: string): boolean
	local container = Checkpoint3Test.buildIntoTestContainer(7419, runId)
	local playerSpawn = container:FindFirstChild("PlayerSpawn", true) :: BasePart
	local room1: Model? = nil
	for _, child in container:GetChildren() do
		if child:IsA("Model") and child.Name:sub(1, 8) == "Room_01_" then
			room1 = child
			break
		end
	end
	assert(room1 ~= nil, "Missing Room_01_*")

	-- 8.1 Blocked doorway + recovery
	local ent = (room1 :: Model):FindFirstChild("Entrance") :: BasePart
	local blocker = Instance.new("Part")
	blocker.Name = "__TestDoorBlocker"
	blocker.Size = Vector3.new(12, 10, 2)
	blocker.Anchored = true
	blocker.CanCollide = true
	blocker.CFrame = ent.CFrame
	blocker.Parent = container

	local blockedReport = waitForValidation({
		container = container,
		playerSpawn = playerSpawn,
		targets = { { id = "BlockedRoom1", model = room1 :: Model } },
		runId = runId .. "_blocked",
		timeoutSeconds = 1.5,
		pollIntervalSeconds = 0.25,
	})
	assert(blockedReport.results[1].outcome ~= "Success", "Blocked doorway falsely reported Success!")

	blocker:Destroy()
	local recoveredReport = waitForValidation({
		container = container,
		playerSpawn = playerSpawn,
		targets = { { id = "RecoveredRoom1", model = room1 :: Model } },
		runId = runId .. "_recovered",
	})
	assert(recoveredReport.results[1].outcome == "Success", "Room failed to recover after removing blocker!")

	-- 8.2 Invalid destination
	local invalidReport = waitForValidation({
		container = container,
		playerSpawn = playerSpawn,
		targets = { { id = "OutOfBounds", model = room1 :: Model, position = Vector3.new(9999, 38, 9999) } },
		runId = runId .. "_invalid",
	})
	assert(invalidReport.results[1].outcome == "InvalidEndpoint", "Expected InvalidEndpoint")

	-- 8.3 Bounded timeout with deterministic computeFn
	local timeoutReport = waitForValidation({
		container = container,
		playerSpawn = playerSpawn,
		targets = { { id = "TimeoutTarget", model = room1 :: Model } },
		runId = runId .. "_timeout",
		timeoutSeconds = 0.4,
		pollIntervalSeconds = 0.2,
		computeFn = function(_p, _s, _t)
			task.wait(0.25)
			return true, nil
		end,
	})
	assert(
		timeoutReport.results[1].outcome == "Timeout" or timeoutReport.results[1].outcome == "NoPath",
		"Expected Timeout/NoPath"
	)

	-- 8.4 Stale generation cancellation
	local staleFired = false
	local handleA = ReachabilityValidator.validateAsync({
		container = container,
		playerSpawn = playerSpawn,
		targets = { { id = "GenA", model = room1 :: Model } },
		runId = runId .. "_genA",
		computeFn = function(_p, _s, _t)
			task.wait(0.3)
			return true, nil
		end,
	}, function()
		staleFired = true
	end)
	handleA.cancel()
	waitForValidation({
		container = container,
		playerSpawn = playerSpawn,
		targets = { { id = "GenB", model = room1 :: Model } },
		runId = runId .. "_genB",
	})
	task.wait(0.35)
	assert(not staleFired, "Stale generation A callback fired!")

	destroyRunContainers(runId)
	return true
end

function Checkpoint4Test.runAll()
	local runId = HttpService:GenerateGUID(false)
	local totalAttempted = 0
	local totalPassed = 0
	local totalFailed = 0

	local ok, err = pcall(function()
		for _, seed in SEEDS do
			local p, f = runRoomReachabilityForSeed(seed, runId)
			totalAttempted += (p + f)
			totalPassed += p
			totalFailed += f
		end

		local hPass, hFail, bothSidesOk = runHallwayAndLoopTests(runId)
		local negOk = runNegativeTests(runId)

		print(string.format("Room-target paths attempted: %d", totalAttempted))
		print(string.format("Room-target paths succeeded: %d", totalPassed))
		print(string.format("Room-target paths failed: %d", totalFailed))
		print(string.format("Hallway reachability: %d/%d", hPass, hPass + hFail))
		print(string.format("Both sides of chase loop navigable: %s", if bothSidesOk then "PASS" else "FAIL"))
		print(string.format("Negative tests: %s", if negOk then "PASS" else "FAIL"))
		assert(totalAttempted == 30 and totalPassed == 30 and totalFailed == 0, "Room reachability failed")
		assert(hPass == 12 and hFail == 0 and bothSidesOk, "Hallway/loop reachability failed")
		assert(negOk, "Negative tests failed")
		print("Overall Checkpoint 4: PASS")
	end)

	destroyRunContainers(runId)
	if not ok then
		error(err)
	end
end

return Checkpoint4Test
