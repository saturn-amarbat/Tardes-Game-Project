--!strict
--[[
  FlashlightReplicaClient  –  Receives teammate flashlight state from the server
  and attaches / removes a mirrored SpotLight on that player's character Torso
  so co-op partners can see each other's flashlight cones.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlashlightOptics = require(script.Parent.FlashlightOptics)

local function getOrMakeReplicaSpot(character: Model): SpotLight?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return nil
	end

	local existing = torso:FindFirstChild("ReplicaFlashlight") :: SpotLight?
	if existing then
		return existing
	end

	return FlashlightOptics.replica(torso)
end

local function onToggleStateReply(sender: Player, isOn: boolean)
	local character = sender.Character
	if not character then
		return
	end
	local spot = getOrMakeReplicaSpot(character)
	if spot then
		spot.Enabled = isOn
	end
end

local function init()
	local remotes = ReplicatedStorage:WaitForChild("FlashlightRemotes", 10)
	if not remotes then
		warn("[FlashlightReplicaClient] FlashlightRemotes folder not found!")
		return
	end

	local replyEvent = remotes:WaitForChild("ToggleStateReply", 10) :: RemoteEvent?
	if not replyEvent then
		warn("[FlashlightReplicaClient] ToggleStateReply remote not found!")
		return
	end

	replyEvent.OnClientEvent:Connect(onToggleStateReply)

	-- If a teammate already had their light on when we joined, we won't get a
	-- catch-up event. The server can be extended later to send initial states.
	print("[FlashlightReplicaClient] Co-op replica listener ready.")
end

return { init = init }
