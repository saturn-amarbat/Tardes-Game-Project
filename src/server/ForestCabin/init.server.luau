--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local teleportModule = script.Parent:FindFirstChild("TeleportManager")
local TeleportManager = if teleportModule and teleportModule:IsA("ModuleScript") then require(teleportModule) else nil

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
	local match = game:GetService("ReplicatedStorage"):FindFirstChild("MatchRemotes")
	local phase = match and match:GetAttribute("RunState")
	if player:GetAttribute("SittingOut") or (phase and phase ~= "Forest" and phase ~= "Active") then
		return nil
	end
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

local hardware = require(script.CottageHardware).install(cabin, key, hatch)
local relay = require(script.SurveyRelay).install(vault, lift)
local lamp = cabin:FindFirstChild("Pilothouse lamp")
Workspace:SetAttribute("BlackpineStart", start.Position)
local approach = if lamp and lamp:IsA("BasePart") then lamp.Position else hatch.Position
Workspace:SetAttribute("BlackpineCottage", Vector3.new(approach.X, hatch.Position.Y, approach.Z))
Workspace:SetAttribute("BlackpineOpeningStep", "FindKey")
require(script.TrailMarkers).install(opening, start)

local firstPull = "Restore lift power"
local ride = liftPrompt.ActionText
local relayCycle = 0
liftPrompt.ActionText = firstPull

-- The key belongs to the expedition. Its finder can leave without stranding the party.
local recovered = false
local originalKeyTransparency = key.Transparency
local originalHatchTransparency = hatch.Transparency
Workspace:GetAttributeChangedSignal("ExpeditionNumber"):Connect(function()
	recovered = false
	Workspace:SetAttribute("BlackpineOpeningStep", "FindKey")
	relayCycle += 1
	relay.reset()
	hardware.reset()
	liftPrompt.ActionText = firstPull
	liftPrompt.Enabled = true
	key.Transparency = originalKeyTransparency
	keyPrompt.Enabled = true
	hatch.CanCollide = true
	hatch.Transparency = originalHatchTransparency
	hatchPrompt.Enabled = true
	hatchPrompt.ObjectText = "Locked • check the kitchen"
end)
keyPrompt.Triggered:Connect(function(player)
	if recovered or not nearby(player, key) then
		return
	end
	recovered = true
	Workspace:SetAttribute("BlackpineOpeningStep", "UnlockHatch")
	hardware.takeKey()
	keyPrompt.Enabled = false
	key.Transparency = 1
	hatchPrompt.ObjectText = "Cellar • key recovered"
end)

hatchPrompt.ObjectText = "Locked • check the kitchen"
hatchPrompt.Triggered:Connect(function(player)
	if recovered and hatchPrompt.Enabled and nearby(player, hatch) then
		hatchPrompt.Enabled = false
		Workspace:SetAttribute("BlackpineOpeningStep", "FindLift")
		hatch.CanCollide = false
		hatch.Transparency = 1
		hardware.open()
		relay.open()
	end
end)

-- Keep each expedition member in control of when they leave the galleries.
local busy: { [Player]: boolean } = {}
liftPrompt.Triggered:Connect(function(player)
	local character = nearby(player, lift)
	if
		not liftPrompt.Enabled
		or not character
		or busy[player]
		or hatchPrompt.Enabled
		or player:GetAttribute("DungeonEntered")
	then
		return
	end
	-- The first pull energizes the recorder for the whole party. Boarding stays individual.
	if relay.power() then
		Workspace:SetAttribute("BlackpineOpeningStep", "BoardLift")
		local cycle = relayCycle
		liftPrompt.Enabled = false
		liftPrompt.ActionText = ride
		task.delay(1.5, function()
			if cycle == relayCycle then
				liftPrompt.Enabled = true
			end
		end)
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
	local filter = RaycastParams.new()
	filter.FilterType = Enum.RaycastFilterType.Include
	filter.FilterDescendantsInstances = { first :: Instance }
	filter.RespectCanCollide = true
	local floor: RaycastResult? = nil
	-- Prefer stepping inward (+1 * LookVector) into Room_01 before testing -1.
	for _, direction in { 1, -1 } do
		local candidate = entrance.Position + entrance.CFrame.LookVector * (4 * direction)
		local hit = Workspace:Raycast(candidate + Vector3.yAxis * 3, -Vector3.yAxis * 12, filter)
		if hit and hit.Normal.Y > 0.65 then
			floor = hit
			break
		end
	end
	if not floor then
		busy[player] = nil
		return
	end
	local destination = floor.Position + Vector3.yAxis * 3.5
	if TeleportManager then
		local arrived = TeleportManager.teleportPlayer(player, CFrame.new(destination), function()
			return character == nearby(player, lift) and first ~= nil and first.Parent == dungeon
		end)
		if arrived then
			player:SetAttribute("DungeonEntered", true)
		end
		busy[player] = nil
		return
	end
	local streamed = pcall(function()
		player:RequestStreamAroundAsync(destination, 6)
	end)
	if not streamed then
		busy[player] = nil
		return
	end
	if character == nearby(player, lift) and first and first.Parent == dungeon then
		character:PivotTo(CFrame.new(destination))
		player:SetAttribute("DungeonEntered", true)
	end
	busy[player] = nil
end)
Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

opening.Name = "ForestCabinOpening"
opening.Parent = Workspace

-- Keep the lobby expedition log board synchronized with MatchRemotes + Workspace attributes.
do
	local lobby = opening:FindFirstChild("LobbyDressing")
	local board = if lobby then lobby:FindFirstChild("ExpeditionBoard") else nil
	local panel = if board then board:FindFirstChild("BoardPanel") else nil
	local gui = if panel then panel:FindFirstChildOfClass("SurfaceGui") else nil
	local numberInst = if gui then gui:FindFirstChild("NumberLabel") else nil
	local stepInst = if gui then gui:FindFirstChild("StepLabel") else nil
	if numberInst and numberInst:IsA("TextLabel") and stepInst and stepInst:IsA("TextLabel") then
		local numberLabel = numberInst
		local stepLabel = stepInst
		local STEP_TEXT = {
			FindKey = "Recover the cellar key",
			UnlockHatch = "Unlock the cellar hatch",
			FindLift = "Descend to the survey vault",
			BoardLift = "Board the lift",
		}
		local function refreshBoard()
			local expNum = Workspace:GetAttribute("ExpeditionNumber")
			numberLabel.Text = string.format("EXPEDITION #%d", if typeof(expNum) == "number" then expNum else 1)

			local matchRemotes = ReplicatedStorage:FindFirstChild("MatchRemotes")
			local runState = if matchRemotes then matchRemotes:GetAttribute("RunState") else nil
			local step = Workspace:GetAttribute("BlackpineOpeningStep")
			if runState == "Active" then
				stepLabel.Text = "Survey underway — good luck"
			elseif typeof(step) == "string" and STEP_TEXT[step] then
				stepLabel.Text = STEP_TEXT[step]
			else
				stepLabel.Text = "Awaiting deployment"
			end
		end
		Workspace:GetAttributeChangedSignal("ExpeditionNumber"):Connect(refreshBoard)
		Workspace:GetAttributeChangedSignal("BlackpineOpeningStep"):Connect(refreshBoard)
		task.spawn(function()
			local matchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes", 15)
			if matchRemotes then
				matchRemotes:GetAttributeChangedSignal("RunState"):Connect(refreshBoard)
				refreshBoard()
			end
		end)
		refreshBoard()
	end
end

local function assignStart(player: Player)
	if script.Parent:FindFirstChild("Lobby") ~= nil and game.PrivateServerId == "" then
		if Workspace:GetAttribute("GameActive") ~= true and player:GetAttribute("InGame") ~= true then
			return
		end
	end
	player.RespawnLocation = start
end
start.Enabled = not (
	script.Parent:FindFirstChild("Lobby") ~= nil
	and game.PrivateServerId == ""
	and Workspace:GetAttribute("GameActive") ~= true
)
Workspace:GetAttributeChangedSignal("GameActive"):Connect(function()
	if Workspace:GetAttribute("GameActive") == true then
		start.Enabled = true
	end
end)
Players.PlayerAdded:Connect(assignStart)
for _, player in Players:GetPlayers() do
	assignStart(player)
end
