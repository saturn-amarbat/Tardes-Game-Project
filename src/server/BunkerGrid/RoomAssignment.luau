--!strict
--[[
  RoomAssignment  –  Deterministic seeded room-to-socket assignment and
  rooms[] ordering for BunkerGrid Checkpoint 3.

  Uses Random.new(seed) exclusively (never math.random) and sorts all candidate
  collections deterministically before RNG selection.
]]

local Config = require(script.Parent.Config)
local DoorResolver = require(script.Parent.DoorResolver)
local HallwaySpineV1 = require(script.Parent.HallwaySpineV1)

local RoomAssignment = {}

export type AssignedRoom = {
	index: number,
	socket: HallwaySpineV1.RoomSocket,
	prefabName: string,
	category: "Special" | "Standard",
	reserved: boolean,
	rotSteps: number,
}

export type AssignmentResult = {
	seed: number,
	orderedRooms: { AssignedRoom },
	signature: string,
}

local STANDARD_ROOMS: { string } = {
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

local function sortSocketsById(list: { HallwaySpineV1.RoomSocket })
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
end

local function shuffleDeterministic<T>(rng: Random, list: { T })
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

function RoomAssignment.assign(layout: HallwaySpineV1.SpineLayout, seed: number): AssignmentResult
	assert(typeof(seed) == "number", "RoomAssignment.assign: seed must be a number")
	local rng = Random.new(seed)

	local bySocketId: { [string]: { prefabName: string, reserved: boolean } } = {}

	-- Step 1: Reserve two distinct eligible dead-end alcove sockets for Mirror & ModelSlot
	local alcoves: { HallwaySpineV1.RoomSocket } = {}
	for _, sock in layout.sockets do
		if sock.alcoveEligible then
			table.insert(alcoves, sock)
		end
	end
	sortSocketsById(alcoves)
	assert(#alcoves >= Config.MIN_RESERVED_ALCOVES, "RoomAssignment: insufficient alcove candidates")
	shuffleDeterministic(rng, alcoves)

	local mirrorSock = alcoves[1]
	local modelSlotSock = alcoves[2]
	assert(mirrorSock.id ~= modelSlotSock.id, "RoomAssignment: Mirror and ModelSlot must use distinct sockets")
	bySocketId[mirrorSock.id] = { prefabName = "Room_Mirror", reserved = true }
	bySocketId[modelSlotSock.id] = { prefabName = "Room_ModelSlot", reserved = true }

	-- Step 2: Assign Room_Exit to BFS-farthest non-reserved socket
	local maxNonReservedDist = -1
	for _, sock in layout.sockets do
		if bySocketId[sock.id] == nil and sock.socketDist > maxNonReservedDist then
			maxNonReservedDist = sock.socketDist
		end
	end
	local exitCandidates: { HallwaySpineV1.RoomSocket } = {}
	for _, sock in layout.sockets do
		if bySocketId[sock.id] == nil and sock.socketDist == maxNonReservedDist then
			table.insert(exitCandidates, sock)
		end
	end
	sortSocketsById(exitCandidates)
	assert(#exitCandidates >= 1, "RoomAssignment: no Exit candidate")
	local exitSock = exitCandidates[rng:NextInteger(1, #exitCandidates)]
	bySocketId[exitSock.id] = { prefabName = "Room_Exit", reserved = false }

	-- Step 3: Assign Room_Safe to non-reserved, non-Exit socket in [0.40, 0.60] * maxDist
	local maxDist = layout.stats.maxSocketDist
	local safeCandidates: { HallwaySpineV1.RoomSocket } = {}
	for _, sock in layout.sockets do
		if bySocketId[sock.id] == nil then
			local ratio = sock.socketDist / maxDist
			if ratio >= 0.40 - 1e-9 and ratio <= 0.60 + 1e-9 then
				table.insert(safeCandidates, sock)
			end
		end
	end
	sortSocketsById(safeCandidates)
	assert(#safeCandidates >= 1, "RoomAssignment: no Safe candidate in [0.40, 0.60] * maxDist")
	local safeSock = safeCandidates[rng:NextInteger(1, #safeCandidates)]
	bySocketId[safeSock.id] = { prefabName = "Room_Safe", reserved = false }

	-- Step 4: Assign 6 standard rooms to remaining 6 sockets via Fisher-Yates
	local remainingSockets: { HallwaySpineV1.RoomSocket } = {}
	for _, sock in layout.sockets do
		if bySocketId[sock.id] == nil then
			table.insert(remainingSockets, sock)
		end
	end
	sortSocketsById(remainingSockets)
	assert(
		#remainingSockets == #STANDARD_ROOMS,
		string.format("RoomAssignment: expected %d remaining sockets, got %d", #STANDARD_ROOMS, #remainingSockets)
	)

	local stdPool = table.clone(STANDARD_ROOMS)
	shuffleDeterministic(rng, stdPool)
	for i, sock in remainingSockets do
		bySocketId[sock.id] = { prefabName = stdPool[i], reserved = false }
	end

	-- Step 5: Build orderedRooms[] preserving:
	--   - rooms[1] is a standard room (nearest standard socket)
	--   - rooms[#rooms] is Room_Exit (explicit Exit-last exception)
	--   - rooms[1..9] in non-decreasing BFS socketDist order, deterministic tie-break by socket.id
	local nonExitEntries: { AssignedRoom } = {}
	local exitEntry: AssignedRoom? = nil

	for _, sock in layout.sockets do
		local assigned = bySocketId[sock.id]
		assert(assigned ~= nil, "RoomAssignment: unassigned socket " .. sock.id)
		local rotSteps = DoorResolver.resolveRoomRotation(sock.roomFacingDir)
		assert(rotSteps ~= nil, "RoomAssignment: invalid roomFacingDir for " .. sock.id)

		local entry: AssignedRoom = {
			index = 0,
			socket = sock,
			prefabName = assigned.prefabName,
			category = if SPECIAL_SET[assigned.prefabName] then "Special" else "Standard",
			reserved = assigned.reserved,
			rotSteps = rotSteps,
		}
		if assigned.prefabName == "Room_Exit" then
			exitEntry = entry
		else
			table.insert(nonExitEntries, entry)
		end
	end

	table.sort(nonExitEntries, function(a, b)
		if a.socket.socketDist ~= b.socket.socketDist then
			return a.socket.socketDist < b.socket.socketDist
		end
		return a.socket.id < b.socket.id
	end)

	local orderedRooms: { AssignedRoom } = {}
	for i, entry in nonExitEntries do
		entry.index = i
		table.insert(orderedRooms, entry)
	end
	assert(exitEntry ~= nil, "RoomAssignment: missing Room_Exit")
	exitEntry.index = #orderedRooms + 1
	table.insert(orderedRooms, exitEntry)

	-- Validate invariants
	assert(#orderedRooms == Config.ROOM_COUNT, "RoomAssignment: room count ~= " .. tostring(Config.ROOM_COUNT))
	assert(orderedRooms[1].category == "Standard", "RoomAssignment: rooms[1] must be Standard")
	assert(orderedRooms[#orderedRooms].prefabName == "Room_Exit", "RoomAssignment: rooms[#rooms] must be Room_Exit")

	local sigParts: { string } = {}
	for _, r in orderedRooms do
		table.insert(sigParts, string.format("%s=%s@r%d", r.socket.id, r.prefabName, r.rotSteps))
	end

	return {
		seed = seed,
		orderedRooms = orderedRooms,
		signature = table.concat(sigParts, "|"),
	}
end

return RoomAssignment
