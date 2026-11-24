--!strict
local RoomGenerator = require(script.RoomGenerator)
local FlashlightReplicator = require(script.FlashlightReplicator)
local PrologueManager = require(script.PrologueManager)
local NPCManager = require(script.NPCManager)
local MatchScaleManager = require(script.MatchScaleManager)
local ClueSystem = require(script.ClueSystem)

FlashlightReplicator.init()
PrologueManager.init()
MatchScaleManager.init(function()
	local rooms = RoomGenerator.generate(10)
	NPCManager.init(rooms)
	ClueSystem.init(rooms)
	return rooms
end)
print("[ServerInit] Milestone 3 systems online.")
