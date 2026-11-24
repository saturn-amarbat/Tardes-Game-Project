--!strict
local RoomGenerator = require(script.RoomGenerator)
local FlashlightReplicator = require(script.FlashlightReplicator)
local PrologueManager = require(script.PrologueManager)
local NPCManager = require(script.NPCManager)
local MatchScaleManager = require(script.MatchScaleManager)
local ClueSystem = require(script.ClueSystem)

print("[ServerInit] ── Milestone 2 Server Boot ──")

local rooms = RoomGenerator.generate(10)
print(string.format("[ServerInit] Generated %d rooms.", #rooms))

FlashlightReplicator.init()
PrologueManager.init()
NPCManager.init(rooms)
MatchScaleManager.init()
ClueSystem.init(rooms)

print("[ServerInit] All server systems online.")
