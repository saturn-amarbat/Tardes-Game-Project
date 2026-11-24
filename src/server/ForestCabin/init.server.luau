--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local opening = (script:FindFirstChild("Opening") or Workspace:WaitForChild("ForestCabinOpening")) :: Model
local cabin = opening:WaitForChild("Wardens Cottage") :: Model
local vault = opening:WaitForChild("Survey Vault") :: Model
local start = opening:WaitForChild("ForestStart") :: SpawnLocation
local key = cabin:WaitForChild("CellarKey") :: BasePart
local hatch = cabin:WaitForChild("CellarHatch") :: BasePart
local lift = vault:WaitForChild("SurveyLift") :: BasePart
local keyPrompt = key:WaitForChild("Prompt") :: ProximityPrompt
local hatchPrompt = hatch:WaitForChild("Prompt") :: ProximityPrompt
local liftPrompt = lift:WaitForChild("Prompt") :: ProximityPrompt

local function nearby(player: Player, part: BasePart): Model?
	local character = player.Character
	local body = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		body
		and body:IsA("BasePart")
		and humanoid
		and humanoid.Health > 0
		and (body.Position - part.Position).Magnitude <= 12
	then
		return character
	end
	return nil
end

-- The key belongs to the expedition. Its finder can leave without stranding the party.
local recovered = false
keyPrompt.Triggered:Connect(function(player)
	if recovered or not nearby(player, key) then
		return
	end
	recovered = true
	keyPrompt.Enabled = false
	key.Transparency = 1
	hatchPrompt.ObjectText = "Cellar • key recovered"
end)

hatchPrompt.ObjectText = "Locked • check the kitchen"
hatchPrompt.Triggered:Connect(function(player)
	if recovered and hatchPrompt.Enabled and nearby(player, hatch) then
		hatchPrompt.Enabled = false
		hatch.CanCollide = false
		hatch.Transparency = 1
	end
end)

-- Keep each expedition member in control of when they leave the galleries.
local busy: { [Player]: boolean } = {}
liftPrompt.Triggered:Connect(function(player)
	local character = nearby(player, lift)
	if not character or busy[player] then
		return
	end
	local dungeon = Workspace:FindFirstChild("GeneratedDungeon")
	local first = if dungeon then dungeon:FindFirstChildWhichIsA("Model") else nil
	if dungeon then
		for _, room in dungeon:GetChildren() do
			if string.match(room.Name, "^Room_01_") then
				first = room
				break
			end
		end
	end
	local entrance = if first then first:FindFirstChild("Entrance") else nil
	if not entrance or not entrance:IsA("BasePart") then
		liftPrompt.ObjectText = "Survey tunnels • lift offline"
		return
	end
	busy[player] = true
	local candidate = entrance.Position - entrance.CFrame.LookVector * 4
	if Workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(candidate, 6)
		end)
	end
	if character == nearby(player, lift) and first and first.Parent == dungeon then
		local filter = RaycastParams.new()
		filter.FilterType = Enum.RaycastFilterType.Include
		filter.FilterDescendantsInstances = { first }
		filter.RespectCanCollide = true
		local floor = Workspace:Raycast(candidate + Vector3.yAxis * 3, -Vector3.yAxis * 12, filter)
		if floor and floor.Normal.Y > 0.65 then
			character:PivotTo(CFrame.new(floor.Position + Vector3.yAxis * 3.5))
		end
	end
	busy[player] = nil
end)
Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

opening.Name = "ForestCabinOpening"
opening.Parent = Workspace
local function assignStart(player: Player)
	player.RespawnLocation = start
end
Players.PlayerAdded:Connect(assignStart)
for _, player in Players:GetPlayers() do
	assignStart(player)
end
