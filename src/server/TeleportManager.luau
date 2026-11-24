--!strict
--[[
  TeleportManager  –  SERVER-AUTHORITATIVE squad teleport with StreamingEnabled safety.

  Usage (server scripts only):
    TeleportManager.teleportPlayer(player, targetCF)
    TeleportManager.teleportSquad(players, targetCF)   -- offset each player slightly
    TeleportManager.bindRemote()                       -- call once from init.server.luau
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeleportManager = {}

local SQUAD_SPREAD = 2.5 -- lateral stud offset between co-op squad members

-- Teleport a single player safely: pre-stream then pivot.
function TeleportManager.teleportPlayer(player: Player, targetCF: CFrame, validate: (() -> boolean)?): boolean
	local character = player.Character
	if not character then
		return false
	end

	-- RequestStreamAroundAsync blocks until geometry is loaded near targetCF.Position.
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(targetCF.Position)
	end)
	if not ok then
		warn("[TeleportManager] StreamAroundAsync failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end

	-- Re-check character still exists after the async wait.
	if player.Character ~= character or (validate and not validate()) then
		return false
	end
	character:PivotTo(targetCF)
	return true
end

-- Teleport 1-4 players, spreading them in a line perpendicular to the target's LookVector.
function TeleportManager.teleportSquad(players: { Player }, targetCF: CFrame): ()
	local count = #players
	if count == 0 then
		return
	end

	-- Calculate lateral spread offsets so no two players occupy the same point.
	local rightVec = targetCF.RightVector
	local halfSpan = (count - 1) * SQUAD_SPREAD / 2

	for i, player in ipairs(players) do
		local lateralOffset = rightVec * ((i - 1) * SQUAD_SPREAD - halfSpan)
		local memberCF = CFrame.new(targetCF.Position + lateralOffset)
			* CFrame.fromMatrix(Vector3.zero, targetCF.RightVector, targetCF.UpVector)
		-- Each player streamed and teleported concurrently.
		task.spawn(TeleportManager.teleportPlayer, player, memberCF)
	end
end

-- Wire up the RemoteEvent so the client can REQUEST a squad teleport (server validates).
function TeleportManager.bindRemote(): ()
	local remotes = ReplicatedStorage:FindFirstChild("FlashlightRemotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "FlashlightRemotes"
		remotes.Parent = ReplicatedStorage
	end

	-- TeleportRequest: client fires with a Vector3 destination.
	-- Server validates and runs the squad teleport.
	local teleportRemote = remotes:FindFirstChild("TeleportRequest") :: RemoteEvent?
	if not teleportRemote then
		teleportRemote = Instance.new("RemoteEvent")
		teleportRemote.Name = "TeleportRequest"
		teleportRemote.Parent = remotes
	end

	(teleportRemote :: RemoteEvent).OnServerEvent:Connect(function(requestingPlayer: Player, destination: Vector3)
		-- Only allow movement when the player has a live character.
		if not requestingPlayer.Character then
			return
		end
		-- Gather squad (all players currently in-game).
		local squad: { Player } = Players:GetPlayers()
		local targetCF = CFrame.new(destination)
		TeleportManager.teleportSquad(squad, targetCF)
	end)

	print("[TeleportManager] Remote bound. Squad teleport ready.")
end

return TeleportManager
