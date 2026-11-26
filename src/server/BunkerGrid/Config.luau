--!strict
--[[
  BunkerGrid Config  –  Single source of truth for modular grid, doorway,
  wall, hallway corridor, and chaser PathfindingService dimensions.

  All measurements measured & locked against ReplicatedStorage/NPCModels/MainNPC_Stalker:
    - Stalker BBox : 2.81 W x 6.39 H x 1.57 D
    - Doorways     : 8 W x 9 H (>= 2.6 overhead, >= 5.1 horizontal margin)
    - Cell         : 32 x 32 studs (30 x 30 walkable room interior)
]]

local Config = table.freeze({
	CELL = 32,
	WALL_H = 12,
	WALL_T = 1,
	DOOR_W = 8,
	DOOR_H = 9,
	HALL_W = 16,

	ROOM_COUNT = 10,

	-- Stalker (MainNPC_Stalker: 2.81 W x 6.39 H x 1.57 D) Pathfinding parameters
	AGENT_RADIUS = 2.0,
	AGENT_HEIGHT = 7.0,
	AGENT_CAN_JUMP = false,
	AGENT_WAYPOINT_SPACING = 4,
	REPATH_INTERVAL = 0.35,

	-- Reachability poll confirmation parameters
	NAVMESH_POLL_INTERVAL = 0.25,
	NAVMESH_POLL_TIMEOUT = 5.0,

	-- Topology & chase loop constraints
	MIN_RESERVED_ALCOVES = 2,
	MIN_CHASE_LOOPS = 1,
	MAX_CHASE_LOOPS = 2,
	MIN_CHASE_LOOP_SIZE = 3,
})

return Config
