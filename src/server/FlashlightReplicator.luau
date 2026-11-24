--!strict
--[[
  FlashlightReplicator  –  Server module that broadcasts flashlight state changes
  to all OTHER clients so they see co-op teammates' SpotLight cones attached to
  the teammate's character Torso.

  How it works:
    1. A client fires ToggleState(isOn: boolean).
    2. This module forwards the state to every other client via ToggleStateReply.
    3. Each client's FlashlightReplicaClient.luau attaches / removes a SpotLight
       on the character model it receives the message about.

  Call FlashlightReplicator.init() once from the server init script.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlashlightReplicator = {}

function FlashlightReplicator.init()
	-- Ensure remote folder exists.
	local remotes = ReplicatedStorage:FindFirstChild("FlashlightRemotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "FlashlightRemotes"
		remotes.Parent = ReplicatedStorage
	end

	-- ToggleState: client → server (original M1 event).
	local toggleState = remotes:FindFirstChild("ToggleState") :: RemoteEvent?
	if not toggleState then
		toggleState = Instance.new("RemoteEvent")
		toggleState.Name = "ToggleState"
		toggleState.Parent = remotes
	end

	-- ToggleStateReply: server → all other clients with (player, isOn).
	local replyEvent = remotes:FindFirstChild("ToggleStateReply") :: RemoteEvent?
	if not replyEvent then
		replyEvent = Instance.new("RemoteEvent")
		replyEvent.Name = "ToggleStateReply"
		replyEvent.Parent = remotes
	end

	(toggleState :: RemoteEvent).OnServerEvent:Connect(function(sender: Player, isOn: boolean)
		sender:SetAttribute("FlashlightOn", isOn == true)
		-- Broadcast to every player except the sender.
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= sender then
				(replyEvent :: RemoteEvent):FireClient(other, sender, isOn)
			end
		end
	end)

	print("[FlashlightReplicator] Co-op replication ready.")
end

return FlashlightReplicator
