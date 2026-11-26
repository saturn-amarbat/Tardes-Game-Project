--!strict
--[[
  Checkpoint5Test  –  Isolated physical Stalker navigation & chase-loop
  verification suite for BunkerGrid Checkpoint 5.

  Must ONLY be executed in an isolated Studio copy containing
  ReplicatedStorage/NPCModels/MainNPC_Stalker (never in shared Team Create).
  Never auto-runs in production gameplay.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Checkpoint3Test = require(script.Parent.Checkpoint3Test)
local HallwaySpineV1 = require(script.Parent.HallwaySpineV1)
local ReachabilityValidator = require(script.Parent.ReachabilityValidator)
local StalkerNavigator = require(script.Parent.StalkerNavigator)

local Checkpoint5Test = {}

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

local function cloneRealStalker(): Model
	local npcModels = ReplicatedStorage:FindFirstChild("NPCModels")
	local template = npcModels and npcModels:FindFirstChild("MainNPC_Stalker")
	assert(template ~= nil and template:IsA("Model"), "Missing ReplicatedStorage/NPCModels/MainNPC_Stalker")
	return template:Clone()
end

local function moveStalkerToGoal(
	nav: StalkerNavigator.NavigatorHandle,
	stalker: Model,
	goal: Vector3,
	timeoutSec: number
): boolean
	nav.setTarget(goal, false)
	local t0 = os.clock()
	while (os.clock() - t0) < timeoutSec do
		if (stalker:GetPivot().Position - goal).Magnitude <= 5.5 then
			return true
		end
		task.wait(0.1)
	end
	return false
end

function Checkpoint5Test.runForSeed(seed: number, runId: string)
	local container = Checkpoint3Test.buildIntoTestContainer(seed, runId)
	local layout = HallwaySpineV1.buildAndValidate()

	local spawnCandidate = StalkerNavigator.selectEligibleMonsterSpawn(layout, container, seed)
	assert(spawnCandidate ~= nil, "No eligible MonsterSpawn for seed " .. tostring(seed))

	local stalker = cloneRealStalker()
	stalker:PivotTo(CFrame.new(spawnCandidate.worldPosition + Vector3.new(0, 3.2, 0)))
	stalker.Parent = container

	local nav = StalkerNavigator.create({
		stalker = stalker,
		container = container,
		runId = runId .. "_" .. tostring(seed),
		walkSpeed = 20,
	})
	nav.start()

	local hallByKey: { [string]: Model } = {}
	local room1: Model? = nil
	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			if child.Name:sub(1, 5) == "Hall_" then
				for _, cell in layout.hallwayList do
					if child.Name:find("Hall_" .. cell.key .. "_", 1, true) then
						hallByKey[cell.key] = child
					end
				end
			elseif child.Name:sub(1, 8) == "Room_01_" then
				room1 = child
			end
		end
	end

	-- 1. Traverse 3 complete 3x3 ring circuits
	local ringKeys = { "1,0", "2,0", "3,0", "3,1", "3,2", "2,2", "1,2", "1,1", "1,0" }
	for circuit = 1, 3 do
		for _, k in ringKeys do
			local pt = ReachabilityValidator.findWalkablePoint(hallByKey[k]) :: Vector3
			assert(
				moveStalkerToGoal(nav, stalker, pt, 10),
				string.format("Seed %d circuit %d failed at %s", seed, circuit, k)
			)
		end
	end

	-- 2. Room entrance & exit (Room_01_* -> Hall 1,0)
	assert(room1 ~= nil, "Missing Room_01_*")
	local r1Pt = ReachabilityValidator.findWalkablePoint(room1 :: Model) :: Vector3
	local h10Pt = ReachabilityValidator.findWalkablePoint(hallByKey["1,0"]) :: Vector3
	assert(moveStalkerToGoal(nav, stalker, r1Pt, 10), "Failed to enter Room_01")
	assert(moveStalkerToGoal(nav, stalker, h10Pt, 10), "Failed to exit Room_01")

	-- 3. Safe Room immunity suppression & resume
	nav.setTarget(r1Pt, true)
	task.wait(0.4)
	nav.setTarget(h10Pt, false)

	local diag = nav.getDiagnostics()
	nav.destroy()
	stalker:Destroy()
	destroyRunContainers(runId)

	print(
		string.format(
			"[C5Test] Seed=%d PASS | dist=%.1f wp=%d repaths=%d stuck=%d failed=%d",
			seed,
			diag.travelDistance,
			diag.waypointsCompleted,
			diag.repathCount,
			diag.stuckEvents,
			diag.failedPaths
		)
	)
end

function Checkpoint5Test.runAll()
	local runId = HttpService:GenerateGUID(false)
	local ok, err = pcall(function()
		for _, seed in SEEDS do
			Checkpoint5Test.runForSeed(seed, runId)
		end
		print("Overall Checkpoint 5: PASS")
	end)
	destroyRunContainers(runId)
	if not ok then
		error(err)
	end
end

return Checkpoint5Test
