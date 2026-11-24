--!strict
local RoomGenerator = require(script.Parent.RoomGenerator)

print("[ServerInit] Starting Procedural Room Generation...")
local rooms = RoomGenerator.generate(10)
print(string.format("[ServerInit] Generated %d rooms successfully.", #rooms))
