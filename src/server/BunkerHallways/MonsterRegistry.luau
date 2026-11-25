--!strict
-- Routes are ordered node IDs from Layout; no NPCs are instantiated.
export type Slot = { occupant: Model?, spawnMarker: BasePart, patrolRoute: { number } }
local Registry = { slots = {} :: { Slot } }
function Registry.configure(spawns: { BasePart }, spine: { number })
	assert(#spawns == 3 and #spine >= 3, "Invalid hallway patrol graph")
	table.clear(Registry.slots)
	for _, spawnMarker in spawns do
		local first = spawnMarker:GetAttribute("NodeId") :: number
		local offset = assert(table.find(spine, first), "Spawn marker must be on the hallway spine")
		local route = { first }
		for i = offset + 1, math.min(#spine, offset + 4) do
			table.insert(route, spine[i])
		end
		table.insert(Registry.slots, { spawnMarker = spawnMarker, patrolRoute = route })
		assert(#route >= 2, "Patrol needs a connected neighbor")
	end
end
return Registry
