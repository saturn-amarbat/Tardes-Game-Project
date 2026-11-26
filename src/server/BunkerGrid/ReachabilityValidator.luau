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

export type FloorCell = {
	model: Model,
	floor: BasePart,
	cf: CFrame,
	halfX: number,
	halfZ: number,
}

local FLOOR_CLEARANCE_Y = 0.5
local ENDPOINT_TOLERANCE = 6.0
local CELL_PAD = 0.25
local SEGMENT_SAMPLE_STEP = 4.0

local activeRunId: string? = nil

local function createStalkerPath(): Path
	return PathfindingService:CreatePath({
		AgentRadius = Config.AGENT_RADIUS,
		AgentHeight = Config.AGENT_HEIGHT,
		AgentCanJump = Config.AGENT_CAN_JUMP,
		WaypointSpacing = Config.AGENT_WAYPOINT_SPACING,
	})
end

function ReachabilityValidator.collectFloorCells(container: Instance): { FloorCell }
	local cells: { FloorCell } = {}
	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			local floor = child.PrimaryPart or child:FindFirstChild("Floor")
			if floor ~= nil and floor:IsA("BasePart") then
				table.insert(cells, {
					model = child,
					floor = floor,
					cf = floor.CFrame,
					halfX = floor.Size.X * 0.5,
					halfZ = floor.Size.Z * 0.5,
				})
			end
		end
	end
	return cells
end

function ReachabilityValidator.isPointInOccupiedCells(pt: Vector3, cells: { FloorCell }): boolean
	for _, cell in cells do
		local rel = cell.cf:PointToObjectSpace(pt)
		if
			math.abs(rel.X) <= cell.halfX + CELL_PAD
			and math.abs(rel.Z) <= cell.halfZ + CELL_PAD
			and rel.Y >= -0.5
			and rel.Y <= Config.WALL_H + 2.0
		then
			return true
		end
	end
	return false
end

function ReachabilityValidator.isRouteInOccupiedCells(pts: { Vector3 }, cells: { FloorCell }): boolean
	if #pts == 0 then
		return false
	end
	for i, pt in pts do
		if not ReachabilityValidator.isPointInOccupiedCells(pt, cells) then
			return false
		end
		if i > 1 then
			local prev = pts[i - 1]
			local seg = pt - prev
			local len = seg.Magnitude
			if len > SEGMENT_SAMPLE_STEP then
				local steps = math.floor(len / SEGMENT_SAMPLE_STEP)
				for s = 1, steps do
					local sample = prev + seg * (s / (steps + 1))
					if not ReachabilityValidator.isPointInOccupiedCells(sample, cells) then
						return false
					end
				end
			end
		end
	end
	return true
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
	cells: { FloorCell },
	id: string,
	timeoutSeconds: number,
	pollIntervalSeconds: number,
	isCancelled: () -> boolean,
	computeFn: ComputeFn?
): RouteResult
	local t0 = os.clock()
	if
		#cells == 0
		or targetPos == nil
		or not ReachabilityValidator.isPointInOccupiedCells(startPos, cells)
		or not ReachabilityValidator.isPointInOccupiedCells(targetPos, cells)
	then
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
			errorMessage = "Start or target outside occupied dungeon cells",
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

		if (os.clock() - t0) >= timeoutSeconds then
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
				errorMessage = "Deadline reached before attempt",
			}
		end

		attempts += 1
		local path = createStalkerPath()
		local ok, errMsg = execCompute(path, startPos, targetPos)

		-- Check cancellation immediately after yielding computation
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

		-- Check deadline immediately after ComputeAsync returns (never accept late completion)
		if (os.clock() - t0) >= timeoutSeconds then
			return {
				id = id,
				outcome = "Timeout",
				pathStatus = if ok then path.Status else nil,
				attempts = attempts,
				elapsedSeconds = os.clock() - t0,
				waypointCount = 0,
				jumpWaypointCount = 0,
				routeLength = 0,
				endpointDistance = math.huge,
				startPosition = startPos,
				targetPosition = targetPos,
				waypoints = {},
				errorMessage = "ComputeAsync completed after deadline",
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

			for i, wp in rawWaypoints do
				if wp.Action == Enum.PathWaypointAction.Jump then
					jumpCount += 1
				end
				if i > 1 then
					routeLen += (wp.Position - rawWaypoints[i - 1].Position).Magnitude
				end
				table.insert(pts, wp.Position)
			end

			local allInRegion = ReachabilityValidator.isRouteInOccupiedCells(pts, cells)
			local endDist = if #pts > 0 then (pts[#pts] - targetPos).Magnitude else math.huge
			if #pts > 0 and jumpCount == 0 and allInRegion and endDist <= ENDPOINT_TOLERANCE then
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
			elseif not allInRegion then
				return {
					id = id,
					outcome = "InvalidEndpoint",
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
					errorMessage = "Route left occupied dungeon cells",
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
		local cells = ReachabilityValidator.collectFloorCells(request.container)
		local startValid = request.playerSpawn:IsDescendantOf(request.container)
		local startModel = request.playerSpawn.Parent
		local startPos: Vector3? = if startValid
				and startModel
				and startModel:IsA("Model")
			then ReachabilityValidator.findWalkablePoint(startModel)
			else nil

		local timeoutSec = request.timeoutSeconds or Config.NAVMESH_POLL_TIMEOUT
		local pollSec = request.pollIntervalSeconds or Config.NAVMESH_POLL_INTERVAL
		local results: { RouteResult } = {}
		local allOk = startPos ~= nil

		for _, target in request.targets do
			if isStale() then
				break
			end
			local targetOwned = target.model:IsDescendantOf(request.container)
			local targetPos = if targetOwned
				then (target.position or ReachabilityValidator.findWalkablePoint(target.model))
				else nil
			local res = ReachabilityValidator.validateSingleRoute(
				startPos or Vector3.zero,
				if startPos ~= nil then targetPos else nil,
				cells,
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
