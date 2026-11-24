--!strict
local Workspace = game:GetService("Workspace")
local Config = require(script.Parent.Config)
local Pieces = require(script.Parent.Pieces)
local Registry = require(script.Parent.MonsterRegistry)

local names = {
	"Landing Room",
	"Abandoned Room",
	"Model Room",
	"Toad Room",
	"Fuse Room",
	"Field Note Room",
	"Locked Study",
	"Flooded Room",
	"Storage",
	"Exit Airlock",
}
export type Node = { model: Model, position: Vector3, neighbors: { number } }
export type Layout = { root: Folder, nodes: { Node }, rooms: { Model }, landing: BasePart, exit: BasePart }
local Layout = {}
local current: Layout? = nil

local function anchor(m: Model, name: string): BasePart
	return m:FindFirstChild(name) :: BasePart
end

local function assemble(world: Folder, origin: CFrame, seed: number): Layout
	local rng = Random.new(seed)
	local nodes: { Node } = {}
	local rooms: { Model } = {}
	local spine: { number } = {}
	local markers: { BasePart } = {}
	local function place(kind: string, name: string, side: number, socket: BasePart?, flicker: boolean?): Model?
		local piece = Pieces.make(kind, name, side, flicker == true)
		local prev = if socket then socket.Parent :: Model else nil
		local entry = anchor(piece, "Entrance")
		local target = if socket then socket.CFrame * CFrame.Angles(0, math.pi, 0) else origin
		piece:PivotTo(target * piece:GetPivot():ToObjectSpace(entry.CFrame):Inverse())
		local query = OverlapParams.new()
		query.RespectCanCollide = true
		-- Only the short frame at this attachment can share the join. Other authored
		-- geometry, including earlier turns and rooms, participates in the query.
		if prev and prev:GetAttribute("Kind") == "DoorFrame" then
			query.FilterDescendantsInstances = { prev }
		end
		local cf = piece:GetPivot() * CFrame.new(0, (Config.Height - 0.5) / 2, 0)
		local size = Vector3.new(piece:GetAttribute("Width"), Config.Height + 1.5, piece:GetAttribute("Depth"))
		if #Workspace:GetPartBoundsInBox(cf, size - Vector3.one * 0.16, query) > 0 then
			piece:Destroy()
			return nil
		end
		local id = #nodes + 1
		piece:SetAttribute("NodeId", id)
		-- Room patrol endpoints stay inside their doorway, clear of center props.
		local position = if kind == "Room"
			then entry.Position - entry.CFrame.LookVector * 4
			else piece:GetPivot().Position
		piece:SetAttribute("NavPosition", position)
		local node = { model = piece, position = position, neighbors = {} :: { number } }
		table.insert(nodes, node)
		if prev then
			local parentId = prev:GetAttribute("NodeId") :: number
			piece:SetAttribute("ConnectedTo", parentId)
			table.insert(nodes[parentId].neighbors, id)
			table.insert(node.neighbors, parentId)
		end
		piece.Parent = world
		return piece
	end
	local function extend(kind: string, socket: BasePart, side: number, name: string, flicker: boolean?): Model
		local result = place(kind, name, side, socket, flicker)
		if result then
			return result
		end
		-- Try a short detour along the doorway normal before giving up this site.
		local straight = place("Straight", "Relief corridor", side, socket)
		if straight then
			if table.find(spine, (socket.Parent :: Model):GetAttribute("NodeId")) then
				table.insert(spine, straight:GetAttribute("NodeId"))
			end
			result = place(kind, name, side, anchor(straight, "Exit"), flicker)
			if result then
				return result
			end
			socket = anchor(straight, "Exit")
		end
		place("Cap", "Sealed bulkhead", side, socket)
		error("Blocked " .. name)
	end
	local socket: BasePart? = nil
	for index, roomName in names do
		local side = if rng:NextInteger(0, 1) == 0 then -1 else 1
		local junction = if socket
			then extend("Junction", socket, side, "Junction " .. index)
			else assert(place("Junction", "Junction 1", side, nil))
		local id = junction:GetAttribute("NodeId")
		table.insert(spine, id)
		if index == 1 then
			extend("Cap", anchor(junction, "Entrance"), 1, "Blind end")
		end
		local frame = extend("DoorFrame", anchor(junction, "Branch"), 1, "Door " .. index)
		local room = extend("Room", anchor(frame, "Exit"), 1, roomName)
		room:SetAttribute("RoomIndex", index)
		table.insert(rooms, room)
		if index == 2 or index == 5 or index == 8 then
			local marker = Instance.new("Part")
			marker.Name = "MonsterSpawn"
			marker.Transparency = 1
			marker.Anchored = true
			marker.CanCollide = false
			marker.CanTouch = false
			marker.CanQuery = false
			marker.Size = Vector3.one
			marker.CFrame = junction:GetPivot() * CFrame.new(0, 2, 0)
			marker:SetAttribute("NodeId", id)
			marker.Parent = junction
			table.insert(markers, marker)
		end
		socket = anchor(junction, "Exit")
		if index < #names then
			local straight = extend("Straight", socket, 1, "Spine " .. index, index == 4)
			table.insert(spine, straight:GetAttribute("NodeId"))
			socket = anchor(straight, "Exit")
			if index == 5 then
				local corner = extend("Corner", socket, 1, "East bend")
				table.insert(spine, corner:GetAttribute("NodeId"))
				local after = extend("Straight", anchor(corner, "Exit"), 1, "Bend approach")
				table.insert(spine, after:GetAttribute("NodeId"))
				socket = anchor(after, "Exit")
			end
		end
	end
	extend("Cap", assert(socket), 1, "End bulkhead")
	Registry.configure(markers, spine)
	return {
		root = world,
		nodes = nodes,
		rooms = rooms,
		landing = anchor(rooms[1], "Floor"),
		exit = anchor(rooms[10], "Floor"),
	}
end

function Layout.get(): Layout
	if current then
		return current
	end
	for attempt = 0, 2 do
		local world = Instance.new("Folder")
		world.Name = "BunkerHallways"
		world.Parent = Workspace
		local ok, result = pcall(assemble, world, Config.Origin * CFrame.new(attempt * 512, 0, 0), Config.Seed)
		if ok then
			current = result
			for _, piece in world:GetChildren() do
				if piece:GetAttribute("Flickering") then
					local lamp = piece:FindFirstChild("Lamp") :: BasePart
					local light = lamp:FindFirstChildOfClass("PointLight") :: PointLight
					task.spawn(function()
						while world.Parent do
							task.wait(3.8)
							if not lamp.Parent then
								return
							end
							light.Brightness = 0.5
							task.wait(0.18)
							light.Brightness = 1.6
						end
					end)
				end
			end
			world:SetAttribute("Seed", Config.Seed)
			world:SetAttribute("RoomCount", #result.rooms)
			print(
				("[BunkerHallways] %d rooms, %d graph nodes, %d empty monster slots"):format(
					#result.rooms,
					#result.nodes,
					#Registry.slots
				)
			)
			return result
		end
		world:Destroy()
		warn("[BunkerHallways] Retrying site:", result)
	end
	error("No unobstructed site for the ten-room bunker")
end
return Layout
