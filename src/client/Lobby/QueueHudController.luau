--!strict
--[[
  QueueHudController  –  CLIENT displays live play-circle status, countdowns,
  avatar headshots of queued teammates, friend-join hints, and teleport notices.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local Typography = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Typography"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local QueueHudController = {}

export type QueuedMember = {
	name: string,
	displayName: string,
	userId: number,
}

export type PadPayload = {
	index: number,
	maxPlayers: number?,
	title: string?,
	players: { QueuedMember },
	countdown: number?,
	autoStartRemaining: number?,
	launching: boolean,
	friendsOnly: boolean,
	hostUserId: number?,
}

local hudGui: ScreenGui? = nil
local statusFrame: Frame? = nil
local statusLabel: TextLabel? = nil
local countdownLabel: TextLabel? = nil
local avatarsRow: Frame? = nil
local friendHintLabel: TextLabel? = nil
local noticeLabel: TextLabel? = nil
local thumbnailCache: { [number]: string } = {}
local noticeToken = 0

local function getHeadshot(userId: number): string
	if thumbnailCache[userId] then
		return thumbnailCache[userId]
	end
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if ok and typeof(url) == "string" then
		thumbnailCache[userId] = url
		return url
	end
	return ""
end

local function buildHud(): ScreenGui
	local old = playerGui:FindFirstChild("QueueHud")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "QueueHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 6
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "StatusFrame"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Size = UDim2.new(0.92, 0, 0, 96)
	frame.Position = UDim2.new(0.5, 0, 0, 14)
	frame.BackgroundColor3 = Color3.fromRGB(14, 17, 16)
	frame.BackgroundTransparency = 0.14
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	statusFrame = frame

	local frameSize = Instance.new("UISizeConstraint")
	frameSize.MaxSize = Vector2.new(340, 96)
	frameSize.MinSize = Vector2.new(260, 96)
	frameSize.Parent = frame

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 10)
	frameCorner.Parent = frame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(78, 108, 128)
	frameStroke.Thickness = 1.2
	frameStroke.Transparency = 0.35
	frameStroke.Parent = frame

	local sLabel = Instance.new("TextLabel")
	sLabel.Name = "StatusLabel"
	sLabel.Size = UDim2.new(1, -16, 0, 22)
	sLabel.Position = UDim2.fromOffset(8, 6)
	sLabel.BackgroundTransparency = 1
	sLabel.Text = "Play Circle"
	sLabel.TextColor3 = Typography.Colors.ParchmentGold
	sLabel.Font = Typography.Fonts.UIBold
	sLabel.TextSize = 14
	sLabel.Parent = frame
	statusLabel = sLabel

	local cLabel = Instance.new("TextLabel")
	cLabel.Name = "CountdownLabel"
	cLabel.Size = UDim2.new(1, -16, 0, 22)
	cLabel.Position = UDim2.fromOffset(8, 28)
	cLabel.BackgroundTransparency = 1
	cLabel.Text = ""
	cLabel.TextColor3 = Color3.fromRGB(244, 194, 88)
	cLabel.Font = Typography.Fonts.UIBold
	cLabel.TextSize = 15
	cLabel.Parent = frame
	countdownLabel = cLabel

	local row = Instance.new("Frame")
	row.Name = "AvatarsRow"
	row.Size = UDim2.new(1, -16, 0, 34)
	row.Position = UDim2.fromOffset(8, 54)
	row.BackgroundTransparency = 1
	row.Parent = frame
	avatarsRow = row

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = row

	-- Friend hint banner when player joined a friend already waiting on a pad
	local hint = Instance.new("TextLabel")
	hint.Name = "FriendHintLabel"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Size = UDim2.fromOffset(340, 28)
	hint.Position = UDim2.new(0.5, 0, 0, 118)
	hint.BackgroundColor3 = Color3.fromRGB(24, 42, 62)
	hint.BackgroundTransparency = 0.2
	hint.Text = ""
	hint.TextColor3 = Color3.fromRGB(162, 212, 255)
	hint.Font = Typography.Fonts.UI
	hint.TextSize = 13
	hint.Visible = false
	hint.BorderSizePixel = 0
	hint.Parent = gui
	friendHintLabel = hint
	local hCorn = Instance.new("UICorner")
	hCorn.CornerRadius = UDim.new(0, 6)
	hCorn.Parent = hint

	-- Notice banner for queue/teleport errors
	local notice = Instance.new("TextLabel")
	notice.Name = "NoticeLabel"
	notice.AnchorPoint = Vector2.new(0.5, 0)
	notice.Size = UDim2.fromOffset(380, 36)
	notice.Position = UDim2.new(0.5, 0, 0, 152)
	notice.BackgroundColor3 = Color3.fromRGB(20, 22, 22)
	notice.BackgroundTransparency = 0.12
	notice.Text = ""
	notice.TextColor3 = Typography.Colors.Bone
	notice.Font = Typography.Fonts.UIBold
	notice.TextSize = 13
	notice.TextWrapped = true
	notice.Visible = false
	notice.BorderSizePixel = 0
	notice.Parent = gui
	noticeLabel = notice
	local nCorn = Instance.new("UICorner")
	nCorn.CornerRadius = UDim.new(0, 8)
	nCorn.Parent = notice

	return gui
end

local function showNotice(msg: string, ok: boolean)
	if not noticeLabel then
		return
	end
	noticeToken += 1
	local myToken = noticeToken
	noticeLabel.Text = msg
	noticeLabel.TextColor3 = if ok then Color3.fromRGB(122, 226, 154) else Color3.fromRGB(244, 112, 98)
	noticeLabel.Visible = true
	task.delay(3.5, function()
		if noticeToken == myToken and noticeLabel then
			noticeLabel.Visible = false
		end
	end)
end

local function updateAvatars(members: { QueuedMember })
	local row = avatarsRow
	if not row then
		return
	end
	for _, c in row:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end

	for _, m in members do
		local chip = Instance.new("Frame")
		chip.Size = UDim2.fromOffset(32, 32)
		chip.BackgroundColor3 = Color3.fromRGB(26, 32, 30)
		chip.BorderSizePixel = 0
		chip.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = chip

		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Parent = chip
		local iCorner = Instance.new("UICorner")
		iCorner.CornerRadius = UDim.new(1, 0)
		iCorner.Parent = img

		task.spawn(function()
			local url = getHeadshot(m.userId)
			if img.Parent and url ~= "" then
				img.Image = url
			end
		end)
	end
end

function QueueHudController.destroy()
	if hudGui then
		hudGui:Destroy()
		hudGui = nil
	end
	statusFrame = nil
	statusLabel = nil
	countdownLabel = nil
	avatarsRow = nil
	friendHintLabel = nil
	noticeLabel = nil
end

function QueueHudController.init()
	hudGui = buildHud()

	local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes", 10)
	if not remotes then
		warn("[QueueHudController] LobbyRemotes not found.")
		return
	end

	local queueUpdate = remotes:WaitForChild("QueueUpdate", 10)
	if queueUpdate and queueUpdate:IsA("RemoteEvent") then
		queueUpdate.OnClientEvent:Connect(function(states: { PadPayload })
			local myPad: PadPayload? = nil
			local friendPad: { index: number, friendName: string }? = nil
			local followId = player.FollowUserId

			for _, pad in states do
				for _, m in pad.players do
					if m.userId == player.UserId then
						myPad = pad
					elseif followId > 0 and m.userId == followId then
						friendPad = { index = pad.index, friendName = m.displayName }
					end
				end
			end

			if friendHintLabel then
				if not myPad and friendPad then
					friendHintLabel.Text =
						string.format("Friend %s is waiting in Play Circle #%d", friendPad.friendName, friendPad.index)
					friendHintLabel.Visible = true
				else
					friendHintLabel.Visible = false
				end
			end

			if not statusFrame then
				return
			end

			if myPad then
				statusFrame.Visible = true
				local maxCount = myPad.maxPlayers or LobbyConfig.QUEUE_SIZE
				local padLabel = myPad.title
					or (if myPad.friendsOnly then "Friends Circle" else "Play Circle #" .. tostring(myPad.index))
				if statusLabel then
					statusLabel.Text = string.format("%s — %d/%d", padLabel, #myPad.players, maxCount)
				end
				if countdownLabel then
					if myPad.launching then
						countdownLabel.Text = "Reserving server & teleporting..."
						countdownLabel.TextColor3 = Color3.fromRGB(122, 226, 154)
					elseif myPad.countdown and myPad.countdown > 0 then
						countdownLabel.Text = string.format("Launching in %d...", math.ceil(myPad.countdown))
						countdownLabel.TextColor3 = Color3.fromRGB(246, 118, 96)
					elseif myPad.autoStartRemaining and myPad.autoStartRemaining > 0 then
						countdownLabel.Text = string.format(
							"Waiting for players (auto-start in %ds)",
							math.ceil(myPad.autoStartRemaining)
						)
						countdownLabel.TextColor3 = Color3.fromRGB(244, 194, 88)
					else
						countdownLabel.Text = "Waiting for squad..."
						countdownLabel.TextColor3 = Typography.Colors.MutedSlate
					end
				end
				updateAvatars(myPad.players)
			else
				statusFrame.Visible = false
			end
		end)
	end

	local noticeEv = remotes:WaitForChild("QueueNotice", 10)
	if noticeEv and noticeEv:IsA("RemoteEvent") then
		noticeEv.OnClientEvent:Connect(function(payload: { ok: boolean, reason: string })
			showNotice(payload.reason, payload.ok)
		end)
	end

	print("[QueueHudController] Ready.")
end

return QueueHudController
