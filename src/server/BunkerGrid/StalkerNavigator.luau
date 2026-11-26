--!strict
--[[
  StalkerNavigator  –  Additive physical Humanoid + PathfindingService navigator
  for MainNPC_Stalker on BunkerGrid layouts (Checkpoint 5).

  Does NOT auto-run on require, does NOT modify NPCManager.luau, and is NOT
  wired into production gameplay.
]]

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local HallwaySpineV1 = require(script.Parent.HallwaySpineV1)

local StalkerNavigator = {}

export type Diagnostics = {
	runId: string,
	pathComputations: number,
	activeComputations: number,
	repathCount: number,
	blockedEvents: number,
	stuckEvents: number,
	recoveryAttempts: number,
	failedPaths: number,
	waypointsCompleted: number,
	travelDistance: number,
	lastComputeDuration: number,
}

export type NavigatorOptions = {
	stalker: Model,
	container: Instance,
	runId: string,
	walkSpeed: number?,
	isTargetImmune: (() -> boolean)?,
}

export type NavigatorHandle = {
	runId: string,
	start: () -> (),
	stop: () -> (),
	destroy: () -> (),
	setTarget: (targetPos: Vector3?, immune: boolean?) -> (),
	getDiagnostics: () -> Diagnostics,
	isRunning: () -> boolean,
}

export type SpawnCandidate = {
	key: string,
	gx: number,
	gz: number,
	dist: number,
	marker: BasePart,
	worldPosition: Vector3,
}

local WAYPOINT_TOLERANCE = 3.2
local TARGET_REPATH_THRESHOLD = 2.0
local STUCK_WINDOW_SECONDS = 1.2
local STUCK_MIN_DISPLACEMENT = 0.75

local function enforceServerNetworkOwnership(model: Model)
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and not desc.Anchored then
			pcall(function()
				desc:SetNetworkOwner(nil)
			end)
		end
	end
end

function StalkerNavigator.selectEligibleMonsterSpawn(
	layout: HallwaySpineV1.SpineLayout,
	container: Instance,
	seed: number
): SpawnCandidate?
	local minDist = math.ceil(0.60 * layout.stats.maxSocketDist)
	local candidates: { SpawnCandidate } = {}

	for _, cell in layout.hallwayList do
		if cell.dist >= minDist then
			for _, child in container:GetChildren() do
				if child:IsA("Model") and child.Name:find("Hall_" .. cell.key .. "_", 1, true) then
					local ms = child:FindFirstChild("MonsterSpawn", true)
					local floor = child.PrimaryPart or child:FindFirstChild("Floor")
					if ms ~= nil and ms:IsA("BasePart") and floor ~= nil and floor:IsA("BasePart") then
						table.insert(candidates, {
							key = cell.key,
							gx = cell.gx,
							gz = cell.gz,
							dist = cell.dist,
							marker = ms,
							worldPosition = Vector3.new(ms.Position.X, floor.Position.Y + 0.5, ms.Position.Z),
						})
					end
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.key < b.key
	end)

	if #candidates == 0 then
		return nil
	end

	local rng = Random.new(seed)
	return candidates[rng:NextInteger(1, #candidates)]
end

function StalkerNavigator.create(opts: NavigatorOptions): NavigatorHandle
	local stalker = opts.stalker
	local humanoid = stalker:FindFirstChildOfClass("Humanoid")
	assert(humanoid ~= nil, "StalkerNavigator: stalker Model missing Humanoid")
	assert(stalker.PrimaryPart ~= nil, "StalkerNavigator: stalker Model missing PrimaryPart")

	enforceServerNetworkOwnership(stalker)

	local running = false
	local destroyed = false
	local targetPos: Vector3? = nil
	local targetImmune = false
	local lastComputedTarget: Vector3? = nil

	local waypoints: { PathWaypoint } = {}
	local wpIndex = 2
	local computingPath = false
	local forceRepath = false
	local lastPathTime = 0
	local pathGenToken = 0

	local hbConn: RBXScriptConnection? = nil
	local blockedConn: RBXScriptConnection? = nil
	local currentPath: Path? = nil

	local lastPos: Vector3? = nil
	local stuckAnchorPos: Vector3? = nil
	local stuckAnchorTime = os.clock()

	local diag: Diagnostics = {
		runId = opts.runId,
		pathComputations = 0,
		activeComputations = 0,
		repathCount = 0,
		blockedEvents = 0,
		stuckEvents = 0,
		recoveryAttempts = 0,
		failedPaths = 0,
		waypointsCompleted = 0,
		travelDistance = 0,
		lastComputeDuration = 0,
	}

	local function disconnectBlocked()
		if blockedConn then
			blockedConn:Disconnect()
			blockedConn = nil
		end
	end

	local function haltMovement()
		table.clear(waypoints)
		wpIndex = 2
		disconnectBlocked()
		currentPath = nil
		if stalker.Parent and humanoid and humanoid.Parent then
			humanoid:MoveTo(stalker:GetPivot().Position)
		end
	end

	local function computeRouteAsync(originPos: Vector3, destPos: Vector3)
		if computingPath or destroyed or not running then
			return
		end
		computingPath = true
		forceRepath = false
		lastPathTime = os.clock()
		pathGenToken += 1
		local myToken = pathGenToken

		diag.pathComputations += 1
		diag.activeComputations += 1
		diag.repathCount += 1

		local path = PathfindingService:CreatePath({
			AgentRadius = Config.AGENT_RADIUS,
			AgentHeight = Config.AGENT_HEIGHT,
			AgentCanJump = Config.AGENT_CAN_JUMP,
			WaypointSpacing = Config.AGENT_WAYPOINT_SPACING,
		})

		task.spawn(function()
			local t0 = os.clock()
			local ok = pcall(function()
				path:ComputeAsync(originPos, destPos)
			end)
			diag.lastComputeDuration = os.clock() - t0
			diag.activeComputations = math.max(0, diag.activeComputations - 1)
			computingPath = false

			-- Ignore stale or stopped generation results
			if destroyed or not running or myToken ~= pathGenToken then
				return
			end
			if targetImmune or (opts.isTargetImmune and opts.isTargetImmune()) then
				return
			end

			if ok and path.Status == Enum.PathStatus.Success then
				local wps = path:GetWaypoints()
				if #wps > 0 then
					disconnectBlocked()
					currentPath = path
					waypoints = wps
					wpIndex = if #wps >= 2 then 2 else 1
					lastComputedTarget = destPos
					blockedConn = path.Blocked:Connect(function(blockedIdx: number)
						if destroyed or not running or myToken ~= pathGenToken then
							return
						end
						if blockedIdx >= wpIndex then
							diag.blockedEvents += 1
							forceRepath = true
						end
					end)
				else
					diag.failedPaths += 1
				end
			else
				diag.failedPaths += 1
				forceRepath = true
			end
		end)
	end

	local function step(_dt: number)
		if destroyed or not running then
			return
		end
		if not stalker.Parent or not humanoid.Parent or humanoid.Health <= 0 then
			return
		end

		local curPos = stalker:GetPivot().Position
		if lastPos ~= nil then
			diag.travelDistance += (curPos - lastPos).Magnitude
		end
		lastPos = curPos

		local immuneNow = targetImmune or (opts.isTargetImmune ~= nil and opts.isTargetImmune())
		if immuneNow or targetPos == nil then
			if #waypoints > 0 then
				haltMovement()
			else
				humanoid:MoveTo(curPos)
			end
			stuckAnchorPos = curPos
			stuckAnchorTime = os.clock()
			return
		end

		if opts.walkSpeed then
			humanoid.WalkSpeed = opts.walkSpeed
		end

		local now = os.clock()
		local dest = targetPos :: Vector3
		local targetMoved = lastComputedTarget == nil
			or (dest - (lastComputedTarget :: Vector3)).Magnitude >= TARGET_REPATH_THRESHOLD

		if
			not computingPath
			and (
				forceRepath
				or (#waypoints == 0 and (now - lastPathTime >= Config.REPATH_INTERVAL))
				or (targetMoved and (now - lastPathTime >= Config.REPATH_INTERVAL))
			)
		then
			computeRouteAsync(curPos, dest)
		end

		-- Stuck recovery (bounded recomputation, never teleports or enables jumping)
		if stuckAnchorPos == nil or (curPos - (stuckAnchorPos :: Vector3)).Magnitude >= STUCK_MIN_DISPLACEMENT then
			stuckAnchorPos = curPos
			stuckAnchorTime = now
		elseif (now - stuckAnchorTime) >= STUCK_WINDOW_SECONDS and #waypoints > 0 and not computingPath then
			diag.stuckEvents += 1
			diag.recoveryAttempts += 1
			stuckAnchorPos = curPos
			stuckAnchorTime = now
			forceRepath = true
		end

		local wp = waypoints[wpIndex]
		if wp ~= nil then
			if (curPos - wp.Position).Magnitude <= WAYPOINT_TOLERANCE then
				diag.waypointsCompleted += 1
				wpIndex += 1
				wp = waypoints[wpIndex]
			end
			if wp ~= nil then
				humanoid:MoveTo(wp.Position)
			else
				humanoid:MoveTo(dest)
			end
		end
	end

	local handle: NavigatorHandle = {
		runId = opts.runId,
		start = function()
			if destroyed or running then
				return
			end
			running = true
			lastPos = stalker:GetPivot().Position
			stuckAnchorPos = lastPos
			stuckAnchorTime = os.clock()
			hbConn = RunService.Heartbeat:Connect(step)
		end,
		stop = function()
			if not running then
				return
			end
			running = false
			pathGenToken += 1
			if hbConn then
				hbConn:Disconnect()
				hbConn = nil
			end
			haltMovement()
		end,
		destroy = function()
			if destroyed then
				return
			end
			running = false
			destroyed = true
			pathGenToken += 1
			if hbConn then
				hbConn:Disconnect()
				hbConn = nil
			end
			haltMovement()
			local _ = currentPath
		end,
		setTarget = function(pos: Vector3?, immune: boolean?)
			targetPos = pos
			targetImmune = immune == true
			if targetImmune or pos == nil then
				haltMovement()
			end
		end,
		getDiagnostics = function(): Diagnostics
			return table.clone(diag)
		end,
		isRunning = function(): boolean
			return running
		end,
	}

	return handle
end

return StalkerNavigator
