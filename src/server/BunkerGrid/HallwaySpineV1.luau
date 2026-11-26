--!strict
--[[
  HallwaySpineV1  –  Deterministic v1 hallway spine topology for Tardes.

  Defines:
    - 12 hallway cells including a designated start cell (0, 0), a qualifying
      3x3 chase loop around solid center (2, 1), two dead-end alcove stubs,
      and an extraction branch.
    - 10 distinct room sockets with explicit parent hallway, direction from
      hallway to room, room coordinate, expected room-facing direction,
      alcove eligibility, and BFS-computed socketDist.
    - Synchronous BFS structural validation (reachability, reciprocity,
      coordinate uniqueness, and 3x3 chase loop detection).
]]

local Config = require(script.Parent.Config)
local DoorResolver = require(script.Parent.DoorResolver)

local HallwaySpineV1 = {}

export type HallwayCell = {
	gx: number,
	gz: number,
	key: string,
	mask: number,
	role: string?,
	dist: number,
}

export type RoomSocket = {
	id: string,
	parentGx: number,
	parentGz: number,
	parentKey: string,
	dirFromHall: number,
	roomGx: number,
	roomGz: number,
	roomKey: string,
	roomFacingDir: number,
	alcoveEligible: boolean,
	socketDist: number,
}

export type SpineValidationStats = {
	totalHallwayCells: number,
	reachableHallwayCells: number,
	totalRoomSockets: number,
	reachableRoomSockets: number,
	reservedAlcoveCandidates: number,
	maxSocketDist: number,
	uniqueOccupiedCoords: number,
	duplicateCoords: number,
	disconnectedCells: number,
	nonReciprocalEdges: number,
	qualifyingChaseLoops: number,
}

export type SpineLayout = {
	startKey: string,
	hallways: { [string]: HallwayCell },
	hallwayList: { HallwayCell },
	sockets: { RoomSocket },
	stats: SpineValidationStats,
}

type RawHall = { gx: number, gz: number, mask: number, role: string? }
type RawSocket = { id: string, px: number, pz: number, dir: number, alcove: boolean }

local N = DoorResolver.N
local E = DoorResolver.E
local S = DoorResolver.S
local W = DoorResolver.W

-- 12-cell deterministic v1 spine:
--   Start (0,0) -> 3x3 ring around solid (2,1) -> 2 alcove stubs + Exit branch
local RAW_HALLS: { RawHall } = {
	{ gx = 0, gz = 0, mask = E, role = "start" },
	{ gx = 1, gz = 0, mask = bit32.bor(N, E, S, W), role = nil },
	{ gx = 2, gz = 0, mask = bit32.bor(N, E, W), role = nil },
	{ gx = 3, gz = 0, mask = bit32.bor(N, E, S, W), role = nil },
	{ gx = 3, gz = 1, mask = bit32.bor(N, E, S), role = nil },
	{ gx = 3, gz = 2, mask = bit32.bor(N, E, S, W), role = nil },
	{ gx = 2, gz = 2, mask = bit32.bor(E, S, W), role = nil },
	{ gx = 1, gz = 2, mask = bit32.bor(N, E, S, W), role = nil },
	{ gx = 1, gz = 1, mask = bit32.bor(N, S), role = nil },
	{ gx = 0, gz = 2, mask = bit32.bor(E, S), role = "alcove_stub" },
	{ gx = 2, gz = 3, mask = bit32.bor(N, S), role = "alcove_stub" },
	{ gx = 4, gz = 2, mask = bit32.bor(E, W), role = "exit_branch" },
}

local RAW_SOCKETS: { RawSocket } = {
	{ id = "S01", px = 1, pz = 0, dir = N, alcove = false },
	{ id = "S02", px = 2, pz = 0, dir = N, alcove = false },
	{ id = "S03", px = 3, pz = 0, dir = N, alcove = false },
	{ id = "S04", px = 3, pz = 0, dir = E, alcove = false },
	{ id = "S05", px = 3, pz = 1, dir = E, alcove = false },
	{ id = "S06", px = 1, pz = 2, dir = S, alcove = false },
	{ id = "S07", px = 3, pz = 2, dir = S, alcove = false },
	{ id = "S08", px = 0, pz = 2, dir = S, alcove = true },
	{ id = "S09", px = 2, pz = 3, dir = S, alcove = true },
	{ id = "S10", px = 4, pz = 2, dir = E, alcove = false },
}

local function countQualifying3x3Loops(hallways: { [string]: HallwayCell }): number
	local loops = 0
	for _, cell in hallways do
		-- Check if (cell.gx, cell.gz) is the top-left corner of a 3x3 ring around (gx+1, gz+1)
		local cx, cz = cell.gx + 1, cell.gz + 1
		local centerKey = DoorResolver.cellKey(cx, cz)
		if hallways[centerKey] == nil then
			local ringCoords = {
				{ gx = cell.gx, gz = cell.gz, req = bit32.bor(E, S) },
				{ gx = cell.gx + 1, gz = cell.gz, req = bit32.bor(E, W) },
				{ gx = cell.gx + 2, gz = cell.gz, req = bit32.bor(S, W) },
				{ gx = cell.gx + 2, gz = cell.gz + 1, req = bit32.bor(N, S) },
				{ gx = cell.gx + 2, gz = cell.gz + 2, req = bit32.bor(N, W) },
				{ gx = cell.gx + 1, gz = cell.gz + 2, req = bit32.bor(E, W) },
				{ gx = cell.gx, gz = cell.gz + 2, req = bit32.bor(N, E) },
				{ gx = cell.gx, gz = cell.gz + 1, req = bit32.bor(N, S) },
			}
			local allConnected = true
			for _, rc in ringCoords do
				local h = hallways[DoorResolver.cellKey(rc.gx, rc.gz)]
				if h == nil or bit32.band(h.mask, rc.req) ~= rc.req then
					allConnected = false
					break
				end
			end
			if allConnected then
				loops += 1
			end
		end
	end
	return loops
end

function HallwaySpineV1.buildAndValidate(): SpineLayout
	local hallways: { [string]: HallwayCell } = {}
	local hallwayList: { HallwayCell } = {}
	local occupied: { [string]: string } = {}
	local duplicateCoords = 0
	local startKey = ""

	for _, raw in RAW_HALLS do
		local key = DoorResolver.cellKey(raw.gx, raw.gz)
		if occupied[key] ~= nil then
			duplicateCoords += 1
		else
			occupied[key] = "hall"
		end
		local cell: HallwayCell = {
			gx = raw.gx,
			gz = raw.gz,
			key = key,
			mask = raw.mask,
			role = raw.role,
			dist = -1,
		}
		hallways[key] = cell
		table.insert(hallwayList, cell)
		if raw.role == "start" then
			startKey = key
		end
	end

	assert(startKey ~= "", "HallwaySpineV1: missing start hallway cell")

	local sockets: { RoomSocket } = {}
	local socketByRoomKey: { [string]: RoomSocket } = {}
	local alcoveCount = 0

	for _, raw in RAW_SOCKETS do
		local pKey = DoorResolver.cellKey(raw.px, raw.pz)
		local delta = DoorResolver.DIR_DELTA[raw.dir]
		assert(delta ~= nil, "HallwaySpineV1: invalid socket dir for " .. raw.id)
		local rx, rz = raw.px + delta.dx, raw.pz + delta.dz
		local rKey = DoorResolver.cellKey(rx, rz)
		if occupied[rKey] ~= nil then
			duplicateCoords += 1
		else
			occupied[rKey] = raw.id
		end
		local sock: RoomSocket = {
			id = raw.id,
			parentGx = raw.px,
			parentGz = raw.pz,
			parentKey = pKey,
			dirFromHall = raw.dir,
			roomGx = rx,
			roomGz = rz,
			roomKey = rKey,
			roomFacingDir = DoorResolver.OPPOSITE[raw.dir],
			alcoveEligible = raw.alcove,
			socketDist = -1,
		}
		if raw.alcove then
			alcoveCount += 1
		end
		table.insert(sockets, sock)
		socketByRoomKey[rKey] = sock
	end

	assert(duplicateCoords == 0, string.format("HallwaySpineV1: %d duplicate coordinates", duplicateCoords))
	assert(
		#sockets == Config.ROOM_COUNT,
		string.format("HallwaySpineV1: expected %d sockets, got %d", Config.ROOM_COUNT, #sockets)
	)
	assert(
		alcoveCount >= Config.MIN_RESERVED_ALCOVES,
		string.format("HallwaySpineV1: expected >= %d alcoves, got %d", Config.MIN_RESERVED_ALCOVES, alcoveCount)
	)

	-- Validate reciprocal hallway edges and socket openings
	local nonReciprocalEdges = 0
	for _, cell in hallwayList do
		for _, d in DoorResolver.ALL_DIRS do
			if bit32.band(cell.mask, d) ~= 0 then
				local delta = DoorResolver.DIR_DELTA[d]
				local nKey = DoorResolver.cellKey(cell.gx + delta.dx, cell.gz + delta.dz)
				local neighborHall = hallways[nKey]
				local neighborSock = socketByRoomKey[nKey]
				if neighborHall ~= nil then
					if bit32.band(neighborHall.mask, DoorResolver.OPPOSITE[d]) == 0 then
						nonReciprocalEdges += 1
					end
				elseif neighborSock ~= nil then
					if neighborSock.parentKey ~= cell.key or neighborSock.dirFromHall ~= d then
						nonReciprocalEdges += 1
					end
				else
					nonReciprocalEdges += 1
				end
			end
		end
	end
	assert(nonReciprocalEdges == 0, string.format("HallwaySpineV1: %d non-reciprocal edges", nonReciprocalEdges))

	-- Synchronous BFS from startKey
	local queue: { string } = { startKey }
	hallways[startKey].dist = 0
	local head = 1
	local reachableHalls = 0

	while head <= #queue do
		local curKey = queue[head]
		head += 1
		reachableHalls += 1
		local cur = hallways[curKey]
		for _, d in DoorResolver.ALL_DIRS do
			if bit32.band(cur.mask, d) ~= 0 then
				local delta = DoorResolver.DIR_DELTA[d]
				local nKey = DoorResolver.cellKey(cur.gx + delta.dx, cur.gz + delta.dz)
				local nh = hallways[nKey]
				if nh ~= nil and nh.dist == -1 then
					nh.dist = cur.dist + 1
					table.insert(queue, nKey)
				end
			end
		end
	end

	local disconnectedCells = #hallwayList - reachableHalls
	assert(disconnectedCells == 0, string.format("HallwaySpineV1: %d disconnected hallway cells", disconnectedCells))

	local reachableSockets = 0
	local maxSocketDist = 0
	for _, sock in sockets do
		local parent = hallways[sock.parentKey]
		assert(parent ~= nil and parent.dist >= 0, "HallwaySpineV1: unreachable socket parent " .. sock.id)
		assert(
			bit32.band(parent.mask, sock.dirFromHall) ~= 0,
			"HallwaySpineV1: parent hallway missing door for socket " .. sock.id
		)
		sock.socketDist = parent.dist + 1
		reachableSockets += 1
		if sock.socketDist > maxSocketDist then
			maxSocketDist = sock.socketDist
		end
	end

	local loops = countQualifying3x3Loops(hallways)
	assert(
		loops >= Config.MIN_CHASE_LOOPS and loops <= Config.MAX_CHASE_LOOPS,
		string.format(
			"HallwaySpineV1: chase loops %d outside [%d, %d]",
			loops,
			Config.MIN_CHASE_LOOPS,
			Config.MAX_CHASE_LOOPS
		)
	)

	local uniqueCount = 0
	for _ in occupied do
		uniqueCount += 1
	end

	return {
		startKey = startKey,
		hallways = hallways,
		hallwayList = hallwayList,
		sockets = sockets,
		stats = {
			totalHallwayCells = #hallwayList,
			reachableHallwayCells = reachableHalls,
			totalRoomSockets = #sockets,
			reachableRoomSockets = reachableSockets,
			reservedAlcoveCandidates = alcoveCount,
			maxSocketDist = maxSocketDist,
			uniqueOccupiedCoords = uniqueCount,
			duplicateCoords = duplicateCoords,
			disconnectedCells = disconnectedCells,
			nonReciprocalEdges = nonReciprocalEdges,
			qualifyingChaseLoops = loops,
		},
	}
end

function HallwaySpineV1.formatReport(layout: SpineLayout): string
	local s = layout.stats
	return table.concat({
		string.format("Total hallway cells: %d", s.totalHallwayCells),
		string.format("Reachable hallway cells: %d", s.reachableHallwayCells),
		string.format("Total room sockets: %d", s.totalRoomSockets),
		string.format("Reachable room sockets: %d", s.reachableRoomSockets),
		string.format("Reserved-alcove candidates: %d", s.reservedAlcoveCandidates),
		string.format("Maximum socket distance: %d", s.maxSocketDist),
		string.format("Unique occupied coordinates: %d", s.uniqueOccupiedCoords),
		string.format("Duplicate coordinates: %d", s.duplicateCoords),
		string.format("Disconnected cells: %d", s.disconnectedCells),
		string.format("Non-reciprocal edges: %d", s.nonReciprocalEdges),
		string.format("Qualifying chase loops: %d", s.qualifyingChaseLoops),
	}, "\n")
end

return HallwaySpineV1
