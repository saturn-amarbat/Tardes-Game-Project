--!strict
--[[
  DoorResolver  –  Uniform 2D CELL grid & 4-bit NESW door bitmask -> prefab + rotation resolver.

  Coordinate Convention (Roblox right-handed Y-up):
    N = 1  (0001) -> -Z world, grid dz = -1
    E = 2  (0010) -> +X world, grid dx = +1
    S = 4  (0100) -> +Z world, grid dz = +1
    W = 8  (1000) -> -X world, grid dx = -1

  Clockwise 90-degree step rot in {0, 1, 2, 3}:
    CFrame transform : CFrame.Angles(0, -rot * math.pi / 2, 0)
    Bitmask transform: N(1) -> E(2) -> S(4) -> W(8) -> N(1)
]]

local Config = require(script.Parent.Config)

local DoorResolver = {}

DoorResolver.N = 1
DoorResolver.E = 2
DoorResolver.S = 4
DoorResolver.W = 8

DoorResolver.ALL_DIRS = { 1, 2, 4, 8 }

DoorResolver.DIR_NAME = {
	[1] = "N",
	[2] = "E",
	[4] = "S",
	[8] = "W",
}

DoorResolver.DIR_DELTA = {
	[1] = { dx = 0, dz = -1 },
	[2] = { dx = 1, dz = 0 },
	[4] = { dx = 0, dz = 1 },
	[8] = { dx = -1, dz = 0 },
}

DoorResolver.OPPOSITE = {
	[1] = 4,
	[2] = 8,
	[4] = 1,
	[8] = 2,
}

export type ResolvedTile = {
	prefabName: string,
	rotSteps: number,
}

-- Base unrotated door bitmasks matching ServerStorage/BunkerPrefabs geometry:
--   HallDeadEnd : N
--   HallCorner  : N + E
--   HallStraight: N + S
--   HallT       : N + E + W
--   HallCross   : N + E + S + W
local BASE_MASKS: { { name: string, mask: number } } = {
	{ name = "HallDeadEnd", mask = 1 }, -- N
	{ name = "HallCorner", mask = 3 }, -- N | E
	{ name = "HallStraight", mask = 5 }, -- N | S
	{ name = "HallT", mask = 11 }, -- N | E | W
	{ name = "HallCross", mask = 15 }, -- N | E | S | W
}

function DoorResolver.rotateMaskCW(mask: number, rotSteps: number): number
	local steps = rotSteps % 4
	if steps == 0 then
		return bit32.band(mask, 15)
	end
	local shiftedLeft = bit32.lshift(mask, steps)
	local wrappedRight = bit32.rshift(mask, 4 - steps)
	return bit32.band(bit32.bor(shiftedLeft, wrappedRight), 15)
end

-- Exact bitmask -> (prefabName, rotSteps) lookup table built once on load
local HALL_LOOKUP: { [number]: ResolvedTile } = {}
for _, entry in BASE_MASKS do
	for rot = 0, 3 do
		local rotated = DoorResolver.rotateMaskCW(entry.mask, rot)
		if not HALL_LOOKUP[rotated] then
			HALL_LOOKUP[rotated] = {
				prefabName = entry.name,
				rotSteps = rot,
			}
		end
	end
end

function DoorResolver.resolveHallway(doorMask: number): ResolvedTile?
	if typeof(doorMask) ~= "number" or doorMask % 1 ~= 0 or doorMask < 1 or doorMask > 15 then
		return nil
	end
	return HALL_LOOKUP[doorMask]
end

--- Resolves clockwise rotation steps for any single-door prefab whose base doorway faces North (1).
function DoorResolver.resolveRoomRotation(openDirMask: number): number?
	if typeof(openDirMask) ~= "number" or openDirMask % 1 ~= 0 or openDirMask < 1 or openDirMask > 15 then
		return nil
	end
	for rot = 0, 3 do
		if DoorResolver.rotateMaskCW(DoorResolver.N, rot) == openDirMask then
			return rot
		end
	end
	return nil
end

function DoorResolver.cellCFrame(origin: CFrame, gx: number, gz: number, rotSteps: number): CFrame
	local cellOffset = CFrame.new(gx * Config.CELL, 0, gz * Config.CELL)
	local rotCF = CFrame.Angles(0, -rotSteps * (math.pi / 2), 0)
	return origin * cellOffset * rotCF
end

function DoorResolver.cellKey(gx: number, gz: number): string
	return string.format("%d,%d", gx, gz)
end

function DoorResolver.countDoors(mask: number): number
	local count = 0
	for _, d in DoorResolver.ALL_DIRS do
		if bit32.band(mask, d) ~= 0 then
			count += 1
		end
	end
	return count
end

function DoorResolver.maskToString(mask: number): string
	local parts: { string } = {}
	for _, d in DoorResolver.ALL_DIRS do
		if bit32.band(mask, d) ~= 0 then
			table.insert(parts, DoorResolver.DIR_NAME[d])
		end
	end
	return if #parts > 0 then table.concat(parts, "+") else "NONE"
end

return DoorResolver
