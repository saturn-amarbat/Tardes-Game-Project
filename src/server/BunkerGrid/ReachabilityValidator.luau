--!strict
--[[
  ReachabilityValidator  –  Bounded asynchronous PathfindingService reachability
  validator for BunkerGrid Checkpoint 4.

  Independent of NPCManager, player movement, damage, objectives, and game-state
  progression. Does not execute automatically on require.

  Vertical offset convention:
    Walkable floor top is local Y = 0. Navigation start/target points are placed
    at floorTopY + 0.5 studs (standing-foot clearance above Floor) so
    PathfindingService snaps cleanly to the navmesh without embedding inside Floor.
]]

local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local ReachabilityValidator = {}

export type RouteOutcome = "Success" | "NoPath" | "ComputeError" | "InvalidEndpoint" | "Timeout" | "Cancelled"

export type NavTarget = {
	id: string,
	model: Model,
	position: Vector3?,
}

export type RouteResult = {
	id: string,
	outcome: RouteOutcome,
	pathStatus: Enum.PathStatus?,
	attempts: number,
	elapsedSeconds: number,
	waypointCount: number,
	jumpWaypointCount: number,
	routeLength: number,
	endpointDistance: number,
	startPosition: Vector3,
	targetPosition: Vector3?,
	waypoints: { Vector3 },
	errorMessage: string?,
}

export type ValidationReport = {
	runId: string,
	overallOk: boolean,
	cancelled: boolean,
	elapsedSeconds: number,
	results: { RouteResult },
}

export type ComputeFn = (path: Path, startPos: Vector3, targetPos: Vector3) -> (boolean, string?)

export type ValidationRequest = {
	container: Instance,
	playerSpawn: BasePart,
	targets: { NavTarget },
	runId: string,
	timeoutSeconds: number?,
	pollIntervalSeconds: number?,
	computeFn: ComputeFn?,
}

export type ValidationHandle = {
	runId: string,
	cancelled: boolean,
	cancel: () -> (),
}

local FLOOR_CLEARANCE_Y = 0.5
local ENDPOINT_TOLERANCE = 6.0
local BOUNDS_PAD = 4.0

local activeRunId: string? = nil

local function createStalkerPath(): Path
	return PathfindingService:CreatePath({
		AgentRadius = Config.AGENT_RADIUS,
		AgentHeight = Config.AGENT_HEIGHT,
		AgentCanJump = Config.AGENT_CAN_JUMP,
		WaypointSpacing = Config.AGENT_WAYPOINT_SPACING,
	})
end

local function computeContainerBounds(container: Instance): (Vector3, Vector3)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, desc in container:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name == "Floor" then
			local half = desc.Size * 0.5
			local pos = desc.Position
			minV = Vector3.new(
				math.min(minV.X, pos.X - half.X),
				math.min(minV.Y, pos.Y - 1),
				math.min(minV.Z, pos.Z - half.Z)
			)
			maxV = Vector3.new(
				math.max(maxV.X, pos.X + half.X),
				math.max(maxV.Y, pos.Y + Config.WALL_H + 2),
				math.max(maxV.Z, pos.Z + half.Z)
			)
		end
	end
	return minV, maxV
end

local function isWithinBounds(pt: Vector3, minB: Vector3, maxB: Vector3): boolean
	return pt.X >= minB.X - BOUNDS_PAD
		and pt.X <= maxB.X + BOUNDS_PAD
		and pt.Y >= minB.Y - BOUNDS_PAD
		and pt.Y <= maxB.Y + BOUNDS_PAD
		and pt.Z >= minB.Z - BOUNDS_PAD
		and pt.Z <= maxB.Z + BOUNDS_PAD
end

function ReachabilityValidator.findWalkablePoint(model: Model, localOffset: Vector3?): Vector3?
	local floor = model.PrimaryPart or model:FindFirstChild("Floor")
	if floor == nil or not floor:IsA("BasePart") then
		return nil
	end
	local offset = localOffset or Vector3.new(0, 0, 0)
	local probeOrigin = (floor.CFrame * CFrame.new(offset.X, 4, offset.Z)).Position

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { floor }
	params.RespectCanCollide = true

	local hit = Workspace:Raycast(probeOrigin, Vector3.new(0, -10, 0), params)
	if hit == nil then
		return nil
	end
	return Vector3.new(hit.Position.X, hit.Position.Y + FLOOR_CLEARANCE_Y, hit.Position.Z)
end

local function defaultCompute(path: Path, startPos: Vector3, targetPos: Vector3): (boolean, string?)
	local ok, err = pcall(function()
		path:ComputeAsync(startPos, targetPos)
	end)
	return ok, if ok then nil else tostring(err)
end

function ReachabilityValidator.validateSingleRoute(
	startPos: Vector3,
	targetPos: Vector3?,
	minB: Vector3,
	maxB: Vector3,
	id: string,
	timeoutSeconds: number,
	pollIntervalSeconds: number,
	isCancelled: () -> boolean,
	computeFn: ComputeFn?
): RouteResult
	local t0 = os.clock()
	if targetPos == nil or not isWithinBounds(startPos, minB, maxB) or not isWithinBounds(targetPos, minB, maxB) then
		return {
			id = id,
			outcome = "InvalidEndpoint",
			pathStatus = nil,
			attempts = 0,
			elapsedSeconds = os.clock() - t0,
			waypointCount = 0,
			jumpWaypointCount = 0,
			routeLength = 0,
			endpointDistance = math.huge,
			startPosition = startPos,
			targetPosition = targetPos,
			waypoints = {},
			errorMessage = "Start or target outside container bounds",
		}
	end

	local execCompute = computeFn or defaultCompute
	local attempts = 0
	local lastStatus: Enum.PathStatus? = nil
	local lastErr: string? = nil

	while true do
		if isCancelled() then
			return {
				id = id,
				outcome = "Cancelled",
				pathStatus = lastStatus,
				attempts = attempts,
				elapsedSeconds = os.clock() - t0,
				waypointCount = 0,
				jumpWaypointCount = 0,
				routeLength = 0,
				endpointDistance = math.huge,
				startPosition = startPos,
				targetPosition = targetPos,
				waypoints = {},
				errorMessage = "Cancelled or stale generation",
			}
		end

		if (os.clock() - t0) >= timeoutSeconds and attempts > 0 then
			return {
				id = id,
				outcome = "Timeout",
				pathStatus = lastStatus,
				attempts = attempts,
				elapsedSeconds = os.clock() - t0,
				waypointCount = 0,
				jumpWaypointCount = 0,
				routeLength = 0,
				endpointDistance = math.huge,
				startPosition = startPos,
				targetPosition = targetPos,
				waypoints = {},
				errorMessage = "Exceeded NAVMESH_POLL_TIMEOUT",
			}
		end

		attempts += 1
		local path = createStalkerPath()
		local ok, errMsg = execCompute(path, startPos, targetPos)

		if isCancelled() then
			return {
				id = id,
				outcome = "Cancelled",
				pathStatus = nil,
				attempts = attempts,
				elapsedSeconds = os.clock() - t0,
				waypointCount = 0,
				jumpWaypointCount = 0,
				routeLength = 0,
				endpointDistance = math.huge,
				startPosition = startPos,
				targetPosition = targetPos,
				waypoints = {},
				errorMessage = "Cancelled during ComputeAsync",
			}
		end

		if not ok then
			lastErr = errMsg
			return {
				id = id,
				outcome = "ComputeError",
				pathStatus = nil,
				attempts = attempts,
				elapsedSeconds = os.clock() - t0,
				waypointCount = 0,
				jumpWaypointCount = 0,
				routeLength = 0,
				endpointDistance = math.huge,
				startPosition = startPos,
				targetPosition = targetPos,
				waypoints = {},
				errorMessage = lastErr,
			}
		end

		lastStatus = path.Status
		if path.Status == Enum.PathStatus.Success then
			local rawWaypoints = path:GetWaypoints()
			local pts: { Vector3 } = {}
			local jumpCount = 0
			local routeLen = 0
			local allInBounds = true

			for i, wp in rawWaypoints do
				if wp.Action == Enum.PathWaypointAction.Jump then
					jumpCount += 1
				end
				if not isWithinBounds(wp.Position, minB, maxB) then
					allInBounds = false
				end
				if i > 1 then
					routeLen += (wp.Position - rawWaypoints[i - 1].Position).Magnitude
				end
				table.insert(pts, wp.Position)
			end

			local endDist = if #pts > 0 then (pts[#pts] - targetPos).Magnitude else math.huge
			if #pts > 0 and jumpCount == 0 and allInBounds and endDist <= ENDPOINT_TOLERANCE then
				return {
					id = id,
					outcome = "Success",
					pathStatus = path.Status,
					attempts = attempts,
					elapsedSeconds = os.clock() - t0,
					waypointCount = #pts,
					jumpWaypointCount = jumpCount,
					routeLength = routeLen,
					endpointDistance = endDist,
					startPosition = startPos,
					targetPosition = targetPos,
					waypoints = pts,
					errorMessage = nil,
				}
			end
		end

		if (os.clock() - t0) + pollIntervalSeconds >= timeoutSeconds then
			return {
				id = id,
				outcome = if lastStatus == Enum.PathStatus.NoPath then "NoPath" else "Timeout",
				pathStatus = lastStatus,
				attempts = attempts,
				elapsedSeconds = os.clock() - t0,
				waypointCount = 0,
				jumpWaypointCount = 0,
				routeLength = 0,
				endpointDistance = math.huge,
				startPosition = startPos,
				targetPosition = targetPos,
				waypoints = {},
				errorMessage = lastErr or "NoPath before timeout",
			}
		end

		task.wait(pollIntervalSeconds)
	end
end

function ReachabilityValidator.validateAsync(
	request: ValidationRequest,
	callback: ((ValidationReport) -> ())?
): ValidationHandle
	activeRunId = request.runId
	local handle: ValidationHandle = {
		runId = request.runId,
		cancelled = false,
		cancel = function() end,
	}
	handle.cancel = function()
		handle.cancelled = true
	end

	local function isStale(): boolean
		return handle.cancelled or activeRunId ~= request.runId
	end

	task.spawn(function()
		local tStart = os.clock()
		local minB, maxB = computeContainerBounds(request.container)
		local startModel = request.playerSpawn.Parent
		local startPos: Vector3? = if startModel and startModel:IsA("Model")
			then ReachabilityValidator.findWalkablePoint(startModel)
			else Vector3.new(
				request.playerSpawn.Position.X,
				request.playerSpawn.Position.Y,
				request.playerSpawn.Position.Z
			)

		local timeoutSec = request.timeoutSeconds or Config.NAVMESH_POLL_TIMEOUT
		local pollSec = request.pollIntervalSeconds or Config.NAVMESH_POLL_INTERVAL
		local results: { RouteResult } = {}
		local allOk = startPos ~= nil

		for _, target in request.targets do
			if isStale() then
				break
			end
			local targetPos = target.position or ReachabilityValidator.findWalkablePoint(target.model)
			local res = ReachabilityValidator.validateSingleRoute(
				startPos or Vector3.zero,
				targetPos,
				minB,
				maxB,
				target.id,
				timeoutSec,
				pollSec,
				isStale,
				request.computeFn
			)
			if res.outcome ~= "Success" then
				allOk = false
			end
			table.insert(results, res)
		end

		if isStale() then
			return
		end

		if callback then
			callback({
				runId = request.runId,
				overallOk = allOk and not isStale(),
				cancelled = false,
				elapsedSeconds = os.clock() - tStart,
				results = results,
			})
		end
	end)

	return handle
end

return ReachabilityValidator
