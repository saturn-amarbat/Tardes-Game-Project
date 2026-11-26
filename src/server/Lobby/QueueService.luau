--!strict
--[[
  QueueService  –  SERVER-AUTHORITATIVE play-circle matchmaking & teleportation.

  Spawns LobbyConfig.NUM_PADS glowing circular pads on the Zone B side of the lobby.
  Uses lightweight spatial polling (no flaky per-limb TouchEnded flicker) so stepping
  in, stepping out, dying, or disconnecting always updates counts cleanly.

  Launch Rules:
    - Pad reaches QUEUE_SIZE/QUEUE_SIZE: starts COUNTDOWN_SECONDS launch countdown immediately.
    - 1..(QUEUE_SIZE-1) players: starts AUTO_START_TIMEOUT timer (if > 0), then launches.
    - If ANY player steps out, dies, or disconnects during the launch countdown, the
      countdown cancels and resets cleanly.
    - Friends-Only pad (FRIENDS_PAD_INDEX): locked to the first player's Roblox friends
      (checked via Player:IsFriendsWithAsync).

  Teleport:
    - Reserves a private server per group using TeleportService:ReserveServer
      and TeleportService:TeleportAsync with TeleportData (coins, equipped skins, party ID).
    - Retries failed teleports (both pcall errors and TeleportService.TeleportInitFailed)
      up to MAX_TELEPORT_RETRIES times and notifies clients clearly on failure.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local PlayerDataService = require(script.Parent.PlayerDataService)

local QueueService = {}

export type PadState = {
	index: number,
	cf: CFrame,
	players: { Player },
	hostUserId: number?,
	countdown: number?,
	autoStartRemaining: number?,
	countdownThread: thread?,
	autoStartThread: thread?,
	launching: boolean,
	friendsOnly: boolean,
	model: Model?,
	billboard: BillboardGui?,
	padPart: Part?,
	glowPart: Part?,
	glowLight: PointLight?,
}

local pads: { PadState } = {}
local playerToPad: { [Player]: number } = {}
local friendCache: { [string]: boolean } = {}
local noticeCooldown: { [Player]: number } = {}
local teleportRetries: { [Player]: number } = {}
local remotesFolder: Folder? = nil

local COLOR_IDLE = Color3.fromRGB(78, 134, 146)
local COLOR_IDLE_FRIENDS = Color3.fromRGB(72, 136, 224)
local COLOR_FILLING = Color3.fromRGB(224, 152, 42)
local COLOR_FULL = Color3.fromRGB(82, 214, 112)
local COLOR_COUNTDOWN = Color3.fromRGB(226, 74, 58)

local function getRemotes(): Folder
	if remotesFolder then
		return remotesFolder
	end
	local existing = ReplicatedStorage:FindFirstChild("LobbyRemotes")
	if existing and existing:IsA("Folder") then
		remotesFolder = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "LobbyRemotes"
	folder.Parent = ReplicatedStorage
	remotesFolder = folder
	return folder
end

local function ensureRemoteEvent(name: string): RemoteEvent
	local parent = getRemotes()
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = parent
	return ev
end

local function sendNotice(player: Player, ok: boolean, reason: string)
	local now = os.clock()
	if not ok and noticeCooldown[player] and (now - noticeCooldown[player]) < 2.0 then
		return
	end
	if not ok then
		noticeCooldown[player] = now
	end
	local noticeEv = getRemotes():FindFirstChild("QueueNotice")
	if noticeEv and noticeEv:IsA("RemoteEvent") and player.Parent == Players then
		noticeEv:FireClient(player, { ok = ok, reason = reason })
	end
end

local function isFriendWithCached(player: Player, targetUserId: number): boolean
	if player.UserId == targetUserId or player.FollowUserId == targetUserId then
		return true
	end
	local key = string.format("%d_%d", math.min(player.UserId, targetUserId), math.max(player.UserId, targetUserId))
	local cached = friendCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, res = pcall(function()
		return player:IsFriendsWithAsync(targetUserId)
	end)
	local isFriend = ok and res == true
	if ok then
		friendCache[key] = isFriend
	end
	return isFriend
end

local function updatePadVisuals(pad: PadState)
	local billboard = pad.billboard
	local count = #pad.players
	local maxCount = LobbyConfig.QUEUE_SIZE

	if billboard then
		local countLabel = billboard:FindFirstChild("CountLabel")
		local namesLabel = billboard:FindFirstChild("NamesLabel")

		if countLabel and countLabel:IsA("TextLabel") then
			if pad.launching then
				countLabel.Text = "TELEPORTING..."
				countLabel.TextColor3 = Color3.fromRGB(140, 232, 168)
			elseif pad.countdown and pad.countdown > 0 then
				countLabel.Text = string.format("%d/%d • LAUNCHING IN %d", count, maxCount, math.ceil(pad.countdown))
				countLabel.TextColor3 = Color3.fromRGB(246, 118, 96)
			elseif count > 0 and pad.autoStartRemaining and pad.autoStartRemaining > 0 then
				countLabel.Text =
					string.format("%d/%d • AUTO-START %ds", count, maxCount, math.ceil(pad.autoStartRemaining))
				countLabel.TextColor3 = Color3.fromRGB(244, 194, 88)
			else
				countLabel.Text = string.format("%d/%d", count, maxCount)
				if count == 0 then
					countLabel.TextColor3 = Color3.fromRGB(168, 174, 168)
				elseif count < maxCount then
					countLabel.TextColor3 = Color3.fromRGB(244, 194, 88)
				else
					countLabel.TextColor3 = Color3.fromRGB(118, 224, 138)
				end
			end
		end

		if namesLabel and namesLabel:IsA("TextLabel") then
			if count == 0 then
				namesLabel.Text = if pad.friendsOnly then "Step in to host friends" else "Step in to join"
			else
				local names: { string } = {}
				for _, p in pad.players do
					table.insert(names, p.DisplayName)
				end
				namesLabel.Text = table.concat(names, ", ")
			end
		end
	end

	local targetColor: Color3
	if pad.countdown and pad.countdown > 0 then
		targetColor = COLOR_COUNTDOWN
	elseif count == 0 then
		targetColor = if pad.friendsOnly then COLOR_IDLE_FRIENDS else COLOR_IDLE
	elseif count < maxCount then
		targetColor = COLOR_FILLING
	else
		targetColor = COLOR_FULL
	end

	if pad.glowPart then
		pad.glowPart.Color = targetColor
	end
	if pad.glowLight then
		pad.glowLight.Color = targetColor
		pad.glowLight.Brightness = if count == 0 then 0.55 else 1.25
	end
end

local function broadcastQueueState()
	local queueUpdate = getRemotes():FindFirstChild("QueueUpdate")
	if not queueUpdate or not queueUpdate:IsA("RemoteEvent") then
		return
	end
	local states: {
		{
			index: number,
			players: { { name: string, displayName: string, userId: number } },
			countdown: number?,
			autoStartRemaining: number?,
			launching: boolean,
			friendsOnly: boolean,
			hostUserId: number?,
		}
	} =
		{}

	for _, pad in pads do
		local entries: { { name: string, displayName: string, userId: number } } = {}
		for _, p in pad.players do
			table.insert(entries, {
				name = p.Name,
				displayName = p.DisplayName,
				userId = p.UserId,
			})
		end
		table.insert(states, {
			index = pad.index,
			players = entries,
			countdown = pad.countdown,
			autoStartRemaining = pad.autoStartRemaining,
			launching = pad.launching,
			friendsOnly = pad.friendsOnly,
			hostUserId = pad.hostUserId,
		})
	end
	queueUpdate:FireAllClients(states)
end

local function cancelCountdown(pad: PadState)
	local th = pad.countdownThread
	pad.countdownThread = nil
	pad.countdown = nil
	if th and th ~= coroutine.running() then
		task.cancel(th)
	end
end

local function cancelAutoStart(pad: PadState)
	local th = pad.autoStartThread
	pad.autoStartThread = nil
	pad.autoStartRemaining = nil
	if th and th ~= coroutine.running() then
		task.cancel(th)
	end
end

local function buildTeleportPayload(pad: PadState, group: { Player }): { [string]: any }
	local partyPlayers: { [string]: { [string]: any } } = {}
	for _, p in group do
		local data = PlayerDataService.getData(p)
		partyPlayers[tostring(p.UserId)] = {
			Name = p.Name,
			Coins = if data then data.Coins else LobbyConfig.STARTING_COINS,
			EquippedCharacterSkin = if data then data.EquippedCharacterSkin else "char_default",
			EquippedWeaponSkin = if data then data.EquippedWeaponSkin else "wpn_default",
		}
	end
	return {
		PartyId = string.format("lobby_%d_pad_%d_%s", game.PlaceId, pad.index, HttpService:GenerateGUID(false)),
		LauncherPlaceId = game.PlaceId,
		IsFriendsCircle = pad.friendsOnly,
		Players = partyPlayers,
	}
end

local function resetPadRoster(pad: PadState)
	for _, p in pad.players do
		if playerToPad[p] == pad.index then
			playerToPad[p] = nil
		end
	end
	table.clear(pad.players)
	pad.hostUserId = nil
	pad.launching = false
	cancelCountdown(pad)
	cancelAutoStart(pad)
	updatePadVisuals(pad)
	broadcastQueueState()
end

local function doTeleport(pad: PadState)
	local group: { Player } = {}
	for _, p in pad.players do
		if p.Parent == Players then
			table.insert(group, p)
		end
	end
	if #group == 0 then
		resetPadRoster(pad)
		return
	end

	local placeId = LobbyConfig.GAME_PLACE_ID
	if placeId <= 0 then
		warn("[QueueService] GAME_PLACE_ID is 0; set LobbyConfig.GAME_PLACE_ID to launch.")
		for _, p in group do
			sendNotice(p, false, "Destination Place ID not configured yet (LobbyConfig.GAME_PLACE_ID).")
		end
		resetPadRoster(pad)
		return
	end

	pad.launching = true
	pad.countdownThread = nil
	pad.countdown = nil
	updatePadVisuals(pad)
	broadcastQueueState()

	local teleportData = buildTeleportPayload(pad, group)
	for _, p in group do
		teleportRetries[p] = 0
		sendNotice(p, true, "Reserving private road server...")
	end

	local attemptTeleport = function(): (boolean, unknown)
		return pcall(function()
			local accessCode = TeleportService:ReserveServer(placeId)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = accessCode
			options:SetTeleportData(teleportData)
			TeleportService:TeleportAsync(placeId, group, options)
		end)
	end

	local ok, err = attemptTeleport()
	if not ok then
		warn("[QueueService] Teleport attempt 1 failed: " .. tostring(err))
		for retry = 1, LobbyConfig.MAX_TELEPORT_RETRIES do
			task.wait(LobbyConfig.TELEPORT_RETRY_DELAY)
			-- Re-filter players still connected
			local remaining: { Player } = {}
			for _, p in group do
				if p.Parent == Players then
					table.insert(remaining, p)
				end
			end
			if #remaining == 0 then
				break
			end
			group = remaining
			for _, p in group do
				sendNotice(
					p,
					false,
					string.format("Teleport failed — retrying (%d/%d)...", retry, LobbyConfig.MAX_TELEPORT_RETRIES)
				)
			end
			ok, err = attemptTeleport()
			if ok then
				break
			end
			warn(string.format("[QueueService] Teleport retry %d failed: %s", retry, tostring(err)))
		end
	end

	if not ok then
		for _, p in group do
			if p.Parent == Players then
				sendNotice(p, false, "Teleport failed: " .. tostring(err) .. ". Step back in to retry.")
			end
		end
		resetPadRoster(pad)
		return
	end

	-- Keep pad cleared cleanly after teleport call succeeds
	resetPadRoster(pad)
end

local function startCountdown(pad: PadState)
	if pad.countdownThread or pad.launching then
		return
	end
	cancelAutoStart(pad)

	pad.countdown = LobbyConfig.COUNTDOWN_SECONDS
	updatePadVisuals(pad)
	broadcastQueueState()

	pad.countdownThread = task.spawn(function()
		for t = LobbyConfig.COUNTDOWN_SECONDS, 1, -1 do
			if #pad.players == 0 then
				pad.countdownThread = nil
				pad.countdown = nil
				updatePadVisuals(pad)
				broadcastQueueState()
				return
			end
			pad.countdown = t
			updatePadVisuals(pad)
			broadcastQueueState()
			task.wait(1)
		end
		doTeleport(pad)
	end)
end

local function startAutoStartTimer(pad: PadState)
	if LobbyConfig.AUTO_START_TIMEOUT <= 0 or pad.autoStartThread or pad.countdownThread or pad.launching then
		return
	end

	pad.autoStartRemaining = LobbyConfig.AUTO_START_TIMEOUT
	updatePadVisuals(pad)
	broadcastQueueState()

	pad.autoStartThread = task.spawn(function()
		for t = LobbyConfig.AUTO_START_TIMEOUT, 1, -1 do
			if #pad.players == 0 or #pad.players >= LobbyConfig.QUEUE_SIZE or pad.countdownThread then
				pad.autoStartThread = nil
				pad.autoStartRemaining = nil
				return
			end
			pad.autoStartRemaining = t
			updatePadVisuals(pad)
			broadcastQueueState()
			task.wait(1)
		end
		pad.autoStartThread = nil
		pad.autoStartRemaining = nil
		if #pad.players > 0 and not pad.launching then
			startCountdown(pad)
		end
	end)
end

local function removePlayerFromPad(player: Player)
	local padIndex = playerToPad[player]
	if not padIndex then
		return
	end
	playerToPad[player] = nil

	local pad = pads[padIndex]
	if not pad then
		return
	end

	for i, p in pad.players do
		if p == player then
			table.remove(pad.players, i)
			break
		end
	end

	-- Reassign friends-circle host if host left
	if pad.friendsOnly and pad.hostUserId == player.UserId then
		pad.hostUserId = if pad.players[1] then pad.players[1].UserId else nil
	end

	-- Cancel active launch countdown whenever ANY player steps off, dies, or disconnects
	if pad.countdownThread then
		cancelCountdown(pad)
		for _, remaining in pad.players do
			sendNotice(remaining, false, player.DisplayName .. " left the circle — countdown cancelled.")
		end
	end

	if #pad.players == 0 then
		pad.hostUserId = nil
		cancelAutoStart(pad)
	elseif not pad.autoStartThread and not pad.launching and LobbyConfig.AUTO_START_TIMEOUT > 0 then
		startAutoStartTimer(pad)
	end

	updatePadVisuals(pad)
	broadcastQueueState()
end

local function addPlayerToPad(player: Player, padIndex: number)
	local pad = pads[padIndex]
	if not pad or pad.launching then
		return
	end
	if playerToPad[player] == padIndex then
		return
	end

	if #pad.players >= LobbyConfig.QUEUE_SIZE then
		sendNotice(
			player,
			false,
			"This play circle is full ("
				.. tostring(LobbyConfig.QUEUE_SIZE)
				.. "/"
				.. tostring(LobbyConfig.QUEUE_SIZE)
				.. ")."
		)
		return
	end

	-- Friends-Only verification before admitting player
	if pad.friendsOnly then
		if #pad.players == 0 then
			pad.hostUserId = player.UserId
		elseif pad.hostUserId and not isFriendWithCached(player, pad.hostUserId) then
			local hostPlayer = Players:GetPlayerByUserId(pad.hostUserId)
			local hostName = if hostPlayer then hostPlayer.DisplayName else "the host"
			sendNotice(player, false, "Friends-only circle — must be Roblox friends with " .. hostName .. ".")
			return
		end
	end

	-- Leave previous circle if switching directly
	if playerToPad[player] then
		removePlayerFromPad(player)
	end

	table.insert(pad.players, player)
	playerToPad[player] = padIndex

	if #pad.players >= LobbyConfig.QUEUE_SIZE then
		startCountdown(pad)
	elseif #pad.players == 1 then
		startAutoStartTimer(pad)
	end

	updatePadVisuals(pad)
	broadcastQueueState()
end

local function createPad(index: number, cf: CFrame, friendsOnly: boolean): PadState
	local model = Instance.new("Model")
	model.Name = "QueuePad_" .. tostring(index)

	local base = Instance.new("Part")
	base.Name = "PadBase"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.6, LobbyConfig.PAD_RADIUS * 2, LobbyConfig.PAD_RADIUS * 2)
	base.CFrame = cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = Color3.fromRGB(28, 34, 32)
	base.Material = Enum.Material.Slate
	base.Anchored = true
	base.CanCollide = true
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Parent = model

	local glow = Instance.new("Part")
	glow.Name = "PadGlow"
	glow.Shape = Enum.PartType.Cylinder
	glow.Size = Vector3.new(0.28, LobbyConfig.PAD_RADIUS * 2 + 1.2, LobbyConfig.PAD_RADIUS * 2 + 1.2)
	glow.CFrame = cf * CFrame.new(0, 0.14, 0) * CFrame.Angles(0, 0, math.rad(90))
	glow.Color = if friendsOnly then COLOR_IDLE_FRIENDS else COLOR_IDLE
	glow.Material = Enum.Material.Neon
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanTouch = false
	glow.CanQuery = false
	glow.TopSurface = Enum.SurfaceType.Smooth
	glow.BottomSurface = Enum.SurfaceType.Smooth
	glow.Parent = model

	local pointLight = Instance.new("PointLight")
	pointLight.Color = if friendsOnly then COLOR_IDLE_FRIENDS else COLOR_IDLE
	pointLight.Range = 18
	pointLight.Brightness = 0.55
	pointLight.Shadows = false
	pointLight.Parent = glow

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PadBillboard"
	billboard.Size = UDim2.fromOffset(250, 96)
	billboard.StudsOffset = Vector3.new(0, 8.5, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 85
	billboard.Adornee = base
	billboard.Parent = model

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.fromScale(1, 0.32)
	titleLabel.Position = UDim2.fromScale(0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = if friendsOnly then "FRIENDS CIRCLE" else "PLAY CIRCLE #" .. tostring(index)
	titleLabel.TextColor3 = if friendsOnly then Color3.fromRGB(142, 194, 248) else Color3.fromRGB(234, 206, 144)
	titleLabel.Font = Enum.Font.Fondamento
	titleLabel.TextSize = 22
	titleLabel.TextStrokeColor3 = Color3.fromRGB(8, 10, 10)
	titleLabel.TextStrokeTransparency = 0.25
	titleLabel.Parent = billboard

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.fromScale(1, 0.38)
	countLabel.Position = UDim2.fromScale(0, 0.32)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = string.format("0/%d", LobbyConfig.QUEUE_SIZE)
	countLabel.TextColor3 = Color3.fromRGB(168, 174, 168)
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextSize = 24
	countLabel.TextStrokeColor3 = Color3.fromRGB(8, 10, 10)
	countLabel.TextStrokeTransparency = 0.2
	countLabel.Parent = billboard

	local namesLabel = Instance.new("TextLabel")
	namesLabel.Name = "NamesLabel"
	namesLabel.Size = UDim2.fromScale(1, 0.3)
	namesLabel.Position = UDim2.fromScale(0, 0.7)
	namesLabel.BackgroundTransparency = 1
	namesLabel.Text = if friendsOnly then "Step in to host friends" else "Step in to join"
	namesLabel.TextColor3 = Color3.fromRGB(220, 224, 218)
	namesLabel.Font = Enum.Font.Gotham
	namesLabel.TextSize = 13
	namesLabel.TextTruncate = Enum.TextTruncate.AtEnd
	namesLabel.TextStrokeColor3 = Color3.fromRGB(8, 10, 10)
	namesLabel.TextStrokeTransparency = 0.35
	namesLabel.Parent = billboard

	local mapContainer = Workspace:FindFirstChild("LobbyMap") or Workspace
	model.Parent = mapContainer

	return {
		index = index,
		cf = cf,
		players = {},
		hostUserId = nil,
		countdown = nil,
		autoStartRemaining = nil,
		countdownThread = nil,
		autoStartThread = nil,
		launching = false,
		friendsOnly = friendsOnly,
		model = model,
		billboard = billboard,
		padPart = base,
		glowPart = glow,
		glowLight = pointLight,
	}
end

local function bindExistingPad(index: number, model: Model, friendsOnly: boolean): PadState?
	local base = model:FindFirstChild("PadBase")
	local glow = model:FindFirstChild("PadGlow")
	local billboard = model:FindFirstChild("PadBillboard")
	if not base or not base:IsA("Part") then
		return nil
	end
	local glowPart = if glow and glow:IsA("Part") then glow else nil
	local glowLight = if glowPart then glowPart:FindFirstChildOfClass("PointLight") else nil
	local bb = if billboard and billboard:IsA("BillboardGui") then billboard else nil
	local padCF = CFrame.new(base.Position.X, base.Position.Y - 0.3, base.Position.Z)

	return {
		index = index,
		cf = padCF,
		players = {},
		hostUserId = nil,
		countdown = nil,
		autoStartRemaining = nil,
		countdownThread = nil,
		autoStartThread = nil,
		launching = false,
		friendsOnly = friendsOnly,
		model = model,
		billboard = bb,
		padPart = base,
		glowPart = glowPart,
		glowLight = glowLight,
	}
end

local function isPlayerLivingOnPad(player: Player, pad: PadState): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hrp:IsA("BasePart") or not hum or hum.Health <= 0 then
		return false
	end
	local delta = hrp.Position - pad.cf.Position
	local horizontalSq = delta.X * delta.X + delta.Z * delta.Z
	return horizontalSq <= (LobbyConfig.PAD_RADIUS * LobbyConfig.PAD_RADIUS) and math.abs(delta.Y) <= 10
end

function QueueService.init()
	ensureRemoteEvent("QueueUpdate")
	ensureRemoteEvent("QueueNotice")

	local mapContainer = Workspace:FindFirstChild("LobbyMap")
	local positions = LobbyConfig.PAD_POSITIONS
	for i = 1, math.min(LobbyConfig.NUM_PADS, #positions) do
		local isFriendsPad = (i == LobbyConfig.FRIENDS_PAD_INDEX)
		local existingPadModel = if mapContainer then mapContainer:FindFirstChild("QueuePad_" .. tostring(i)) else nil
		local pad: PadState? = nil
		if existingPadModel and existingPadModel:IsA("Model") then
			pad = bindExistingPad(i, existingPadModel, isFriendsPad)
		end
		if not pad then
			pad = createPad(i, positions[i], isFriendsPad)
		end
		if pad then
			updatePadVisuals(pad)
			table.insert(pads, pad)
		end
	end

	-- Reliable spatial occupancy polling (avoids multi-limb TouchEnded flicker)
	task.spawn(function()
		while true do
			task.wait(0.15)
			for _, player in Players:GetPlayers() do
				local currentPadIdx = playerToPad[player]
				local detectedPadIdx: number? = nil

				for _, pad in pads do
					if isPlayerLivingOnPad(player, pad) then
						detectedPadIdx = pad.index
						break
					end
				end

				if currentPadIdx and detectedPadIdx ~= currentPadIdx then
					removePlayerFromPad(player)
				end
				if detectedPadIdx and playerToPad[player] ~= detectedPadIdx then
					addPlayerToPad(player, detectedPadIdx)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromPad(player)
		noticeCooldown[player] = nil
		teleportRetries[player] = nil
	end)

	-- Asynchronous teleport failure handler with retry
	TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId, teleportOptions)
		warn(
			string.format(
				"[QueueService] TeleportInitFailed (%s): %s — %s",
				player.Name,
				tostring(teleportResult),
				tostring(errorMessage)
			)
		)
		local retries = teleportRetries[player] or 0
		if
			retries < LobbyConfig.MAX_TELEPORT_RETRIES
			and teleportResult ~= Enum.TeleportResult.Unauthorized
			and player.Parent == Players
			and placeId > 0
		then
			teleportRetries[player] = retries + 1
			sendNotice(
				player,
				false,
				string.format(
					"Teleport error (%s) — retrying (%d/%d)...",
					tostring(teleportResult),
					retries + 1,
					LobbyConfig.MAX_TELEPORT_RETRIES
				)
			)
			task.delay(LobbyConfig.TELEPORT_RETRY_DELAY, function()
				if player.Parent ~= Players then
					return
				end
				local retryOk, retryErr = pcall(function()
					TeleportService:TeleportAsync(placeId, { player }, teleportOptions)
				end)
				if not retryOk then
					warn("[QueueService] TeleportInitFailed retry error: " .. tostring(retryErr))
					sendNotice(player, false, "Teleport failed: " .. tostring(errorMessage))
				end
			end)
		else
			teleportRetries[player] = nil
			removePlayerFromPad(player)
			sendNotice(player, false, "Teleport failed: " .. tostring(errorMessage) .. ". Step back in to retry.")
		end
	end)

	broadcastQueueState()
	print("[QueueService] Initialized with " .. tostring(#pads) .. " play circles.")
end

return QueueService
