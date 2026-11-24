--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ObjectivePickups = require(script.Parent.ObjectivePickups)

local SafeRoomService = {}

local STARTING_SCRAP = 15
local CLUE_SCRAP_REWARD = 10
local OBJECTIVE_SCRAP_REWARD = 15

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material,
	collide: boolean
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function awardScrapAll(amount: number)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("DungeonEntered") == true and p:GetAttribute("SittingOut") ~= true then
			local cur = p:GetAttribute("RunScrap")
			local base = if typeof(cur) == "number" then cur else 0
			p:SetAttribute("RunScrap", base + amount)
		end
	end
end

function SafeRoomService.init()
	local function resetPlayer(p: Player)
		p:SetAttribute("RunScrap", STARTING_SCRAP)
		p:SetAttribute("InSafeRoom", false)
		p:SetAttribute("ReviveTokens", 0)
		p:SetAttribute("ReviveTokenClaimed", false)
	end

	Players.PlayerAdded:Connect(resetPlayer)
	for _, p in Players:GetPlayers() do
		resetPlayer(p)
	end

	Workspace:GetAttributeChangedSignal("ExpeditionNumber"):Connect(function()
		for _, p in Players:GetPlayers() do
			resetPlayer(p)
		end
	end)

	-- Award squad scrap automatically when clues or objectives are collected
	task.spawn(function()
		local matchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes", 10)
		if not matchRemotes then
			return
		end

		local collectedClues = matchRemotes:WaitForChild("CollectedClues", 10)
		if collectedClues then
			collectedClues.ChildAdded:Connect(function()
				awardScrapAll(CLUE_SCRAP_REWARD)
			end)
		end

		local lastKeys, lastFuses = 0, 0
		matchRemotes:GetAttributeChangedSignal("Keys"):Connect(function()
			local k = matchRemotes:GetAttribute("Keys")
			if typeof(k) == "number" then
				if k > lastKeys then
					awardScrapAll(OBJECTIVE_SCRAP_REWARD)
				end
				lastKeys = k
			end
		end)
		matchRemotes:GetAttributeChangedSignal("Fuses"):Connect(function()
			local f = matchRemotes:GetAttribute("Fuses")
			if typeof(f) == "number" then
				if f > lastFuses then
					awardScrapAll(OBJECTIVE_SCRAP_REWARD)
				end
				lastFuses = f
			end
		end)
	end)
end

local activeMonitorThread: thread? = nil

function SafeRoomService.install(rooms: { Model })
	if activeMonitorThread then
		task.cancel(activeMonitorThread)
		activeMonitorThread = nil
	end

	local safeRoom: Model? = nil
	for _, r in rooms do
		if r:GetAttribute("SafeRoom") == true then
			safeRoom = r
			break
		end
	end
	if not safeRoom then
		return
	end

	-- Dress the Toad-Maker Safe Room booth along the left side so center walkway stays clear
	local existingBooth = safeRoom:FindFirstChild("ToadMakerBooth")
	if existingBooth then
		existingBooth:Destroy()
	end

	local booth = Instance.new("Folder")
	booth.Name = "ToadMakerBooth"
	booth.Parent = safeRoom

	local pivot = safeRoom:GetPivot()
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { safeRoom }
	rayParams.RespectCanCollide = true
	local floorHit = Workspace:Raycast(pivot.Position + Vector3.yAxis * 4, -Vector3.yAxis * 12, rayParams)
	local floorY = if floorHit then floorHit.Position.Y else pivot.Position.Y + 0.5
	local origin = CFrame.new(pivot.X, floorY, pivot.Z) * pivot.Rotation

	local wood = Color3.fromRGB(76, 52, 34)
	local iron = Color3.fromRGB(54, 58, 60)
	local brass = Color3.fromRGB(168, 138, 72)

	-- Counter + canopy + warm sanctuary lantern grounded on floorY
	makePart(
		booth,
		"Counter",
		Vector3.new(2.4, 3.2, 10.5),
		origin * CFrame.new(-7.6, 1.6, 0),
		wood,
		Enum.Material.Wood,
		true
	)
	makePart(
		booth,
		"Canopy",
		Vector3.new(3.4, 0.3, 11.4),
		origin * CFrame.new(-7.4, 6.4, 0),
		iron,
		Enum.Material.CorrodedMetal,
		false
	)
	local lantern = makePart(
		booth,
		"SanctuaryLantern",
		Vector3.new(0.6, 0.8, 0.6),
		origin * CFrame.new(-7.2, 3.6, -4.0),
		Color3.fromRGB(255, 214, 132),
		Enum.Material.Neon,
		false
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 206, 128)
	light.Range = 32
	light.Brightness = 2.0
	light.Shadows = false
	light.Parent = lantern

	-- Toad-Maker shopkeeper silhouette behind the counter
	makePart(
		booth,
		"KeeperBody",
		Vector3.new(1.8, 3.2, 1.4),
		origin * CFrame.new(-9.2, 1.6, 0),
		Color3.fromRGB(48, 62, 46),
		Enum.Material.Fabric,
		true
	)
	makePart(
		booth,
		"KeeperHead",
		Vector3.new(1.1, 1.1, 1.1),
		origin * CFrame.new(-9.2, 3.75, 0),
		Color3.fromRGB(68, 88, 56),
		Enum.Material.Pebble,
		false
	)
	for _, ez in { -0.25, 0.25 } do
		makePart(
			booth,
			"KeeperEye",
			Vector3.new(0.16, 0.16, 0.16),
			origin * CFrame.new(-8.65, 3.9, ez),
			Color3.fromRGB(235, 198, 86),
			Enum.Material.Neon,
			false
		)
	end

	-- Signplate hung cleanly above the counter canopy facing center walkway
	local sign = makePart(
		booth,
		"SafeSign",
		Vector3.new(0.15, 1.1, 6.8),
		origin * CFrame.new(-5.8, 6.4, 0),
		Color3.fromRGB(42, 54, 44),
		Enum.Material.Metal,
		false
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.Parent = sign
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.Text = "TOAD-MAKER SANCTUARY"
	txt.TextColor3 = Color3.fromRGB(244, 218, 152)
	txt.Font = Enum.Font.Garamond
	txt.TextScaled = true
	txt.Parent = gui

	local function spend(player: Player, cost: number): boolean
		local scrap = player:GetAttribute("RunScrap")
		local cur = if typeof(scrap) == "number" then scrap else 0
		if cur < cost then
			return false
		end
		player:SetAttribute("RunScrap", cur - cost)
		return true
	end

	local function addVendorItem(
		name: string,
		zOffset: number,
		color: Color3,
		actionText: string,
		objectText: string,
		cost: number,
		onBuy: (Player) -> boolean
	)
		local item = makePart(
			booth,
			name,
			Vector3.new(0.9, 0.7, 0.9),
			origin * CFrame.new(-7.1, 3.55, zOffset),
			color,
			Enum.Material.Metal,
			false
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = string.format("%s (%d Scrap)", actionText, cost)
		prompt.ObjectText = objectText
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = item

		prompt.Triggered:Connect(function(player: Player)
			if not ObjectivePickups.inReach(player, item, prompt.MaxActivationDistance) then
				return
			end
			if spend(player, cost) then
				if not onBuy(player) then
					-- Refund if purchase couldn't apply (e.g. already owns max token or full HP)
					local cur = player:GetAttribute("RunScrap")
					player:SetAttribute("RunScrap", (if typeof(cur) == "number" then cur else 0) + cost)
				end
			end
		end)
	end

	addVendorItem("BatteryVendor", -2.2, brass, "Buy Battery +40%", "Emergency Cell", 15, function(player: Player)
		local shopRemotes = ReplicatedStorage:FindFirstChild("ShopRemotes")
		local ev = shopRemotes and shopRemotes:FindFirstChild("BatteryGiftReceived")
		if ev and ev:IsA("RemoteEvent") then
			ev:FireClient(player, 40)
			return true
		end
		return false
	end)

	addVendorItem(
		"MedkitVendor",
		0.4,
		Color3.fromRGB(168, 56, 52),
		"Buy Medkit +40 HP",
		"Field Bandage",
		20,
		function(player: Player)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
				hum.Health = math.min(hum.MaxHealth, hum.Health + 40)
				return true
			end
			return false
		end
	)

	addVendorItem(
		"TokenVendor",
		3.0,
		Color3.fromRGB(94, 168, 118),
		"Buy Revive Token",
		"Toad Charm (1/run)",
		35,
		function(player: Player)
			if player:GetAttribute("ReviveTokenClaimed") == true then
				return false
			end
			local cur = player:GetAttribute("ReviveTokens")
			if typeof(cur) == "number" and cur >= 1 then
				return false
			end
			player:SetAttribute("ReviveTokens", 1)
			return true
		end
	)

	-- Track InSafeRoom attribute for players inside safeRoom bounding box
	local roomCF, roomSize = safeRoom:GetBoundingBox()
	local half = roomSize * 0.5
	activeMonitorThread = task.spawn(function()
		while safeRoom.Parent do
			for _, p in Players:GetPlayers() do
				local char = p.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local inside = false
				if hrp and hrp:IsA("BasePart") then
					local rel = roomCF:PointToObjectSpace(hrp.Position)
					inside = math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
				end
				if p:GetAttribute("InSafeRoom") ~= inside then
					p:SetAttribute("InSafeRoom", inside)
				end
			end
			task.wait(0.25)
		end
	end)
end

return SafeRoomService
