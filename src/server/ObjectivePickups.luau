--!strict
local Workspace = game:GetService("Workspace")
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
local function place(room: Model, kind: string, offset: number): BasePart
	local entrance = room:FindFirstChild("Entrance") :: BasePart
	local part = Instance.new("Part")
	part.Name = "Objective" .. kind
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Size = if kind == "Key" then Vector3.new(0.9, 0.25, 0.35) else Vector3.new(0.45, 0.85, 0.45)
	part.Color = if kind == "Key" then Color3.fromRGB(215, 172, 75) else Color3.fromRGB(103, 186, 210)
	part.CFrame = entrance.CFrame * CFrame.new(offset, -entrance.Size.Y / 2 + 2, 0)
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
	local registered: { [BasePart]: { kind: string, prompt: ProximityPrompt, room: Model } } = {}
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
		candidate.Transparency = 1
		credit(item.kind)
	end
	local total = keyTotal + fuseTotal
	for i = 1, total do
		if #rooms == 0 then
			break
		end
		local room = rooms[math.clamp(math.ceil(i * #rooms / (total + 1)), 1, #rooms)]
		local kind = if i % 2 == 0 and i <= fuseTotal * 2 then "Fuse" else "Key"
		local part = place(room, kind, if kind == "Key" then -1 else 1)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Collect"
		prompt.ObjectText = kind
		prompt.MaxActivationDistance = 6
		prompt.Parent = part
		registered[part] = { kind = kind, prompt = prompt, room = room }
		prompt.Triggered:Connect(function(player)
			claim(player, part)
		end)
	end
	return collect.OnServerEvent:Connect(claim)
end

return ObjectivePickups
