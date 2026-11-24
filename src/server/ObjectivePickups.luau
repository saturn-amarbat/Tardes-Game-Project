--!strict
local Workspace = game:GetService("Workspace")
local ObjectiveProps = require(script.Parent.ObjectiveProps)
local ObjectivePickups = {}

function ObjectivePickups.inReach(player: Player, part: BasePart, radius: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player:GetAttribute("DungeonEntered") == true
		and player:GetAttribute("SittingOut") ~= true
		and root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and (root.Position - part.Position).Magnitude <= radius
end

-- Room entrances have guaranteed walkable thresholds, even on L-shaped templates.
local function place(room: Model, kind: string, slot: number, station: BasePart?): BasePart
	local entrance = room:FindFirstChild("Entrance") :: BasePart
	local column = (slot - 1) % 3
	local row = math.floor((slot - 1) / 3)
	local part = Instance.new("Part")
	part.Name = "Objective" .. kind
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.85, 0.66, 0.28)
	part.CFrame = if station
		then station.CFrame
		else entrance.CFrame * CFrame.new((column - 1) * 0.96, -entrance.Size.Y / 2 + 2 + row * 0.8, 0)
	part.Parent = room
	return part
end

function ObjectivePickups.spawn(
	rooms: { Model },
	keyTotal: number,
	fuseTotal: number,
	collect: RemoteEvent,
	canCollect: (Player) -> boolean,
	credit: (string) -> ()
)
	local registered: { [BasePart]: { kind: string, prompt: ProximityPrompt, room: Model, prop: Folder } } = {}
	local dungeon = Workspace:FindFirstChild("GeneratedDungeon")
	local function claim(player: Player, candidate: unknown)
		if typeof(candidate) ~= "Instance" or not candidate:IsA("BasePart") then
			return
		end
		local item = registered[candidate]
		if
			not item
			or not dungeon
			or item.room.Parent ~= dungeon
			or candidate.Parent ~= item.room
			or item.prompt.Parent ~= candidate
			or not item.prompt.Enabled
			or not canCollect(player)
			or not ObjectivePickups.inReach(player, candidate, item.prompt.MaxActivationDistance)
		then
			return
		end
		-- Both entry points share this non-yielding claim.
		registered[candidate] = nil
		candidate:SetAttribute("ClaimedBy", player.UserId)
		item.prompt.Enabled = false
		item.prop:Destroy()
		credit(item.kind)
	end
	local slots: { [Model]: number } = {}
	local total = keyTotal + fuseTotal
	local first = rooms[1]
	local bay = first and first:FindFirstChild("MaintenanceBay")
	local socket = bay and bay:FindFirstChild("Fuse socket")
	local station = if socket and socket:IsA("BasePart") then socket else nil
	for i = 1, total do
		if #rooms == 0 then
			break
		end

		local kind = if i % 2 == 0 and i <= fuseTotal * 2 then "Fuse" else "Key"
		local socketForPickup = if kind == "Fuse" then station else nil
		local idx = math.clamp(math.ceil(i * #rooms / (total + 1)), 1, #rooms)
		if not socketForPickup and rooms[idx]:GetAttribute("SafeRoom") == true and #rooms > 1 then
			idx = if idx < #rooms then idx + 1 else idx - 1
		end
		local room = if socketForPickup then first else rooms[idx]
		local slot = (slots[room] or 0) + 1
		if socketForPickup then
			station = nil
		else
			slots[room] = slot
		end
		local part = place(room, kind, slot, socketForPickup)
		local prop = ObjectiveProps.mount(part, kind == "Key")
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take"
		prompt.ObjectText = if kind == "Key" then "Survey key" else "Ceramic fuse"
		prompt.MaxActivationDistance = 6
		prompt.Parent = part
		registered[part] = { kind = kind, prompt = prompt, room = room, prop = prop }
		prompt.Triggered:Connect(function(player)
			claim(player, part)
		end)
	end
	return collect.OnServerEvent:Connect(claim)
end

return ObjectivePickups
