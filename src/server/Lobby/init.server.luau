--!strict
--[[
  Lobby Server Bootstrap  –  initializes all Dark Forest Lobby systems.

  Runs whenever the server should start in the Dark Forest Lobby first
  (standalone Lobby place, public hub server, or Studio playtest with LobbyMap).
  Reserved game instances launched from a play circle skip straight to the game.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))

if not LobbyConfig.shouldStartInLobby() then
	return
end

if ServerScriptService:GetAttribute("LobbyServerBooted") == true then
	return
end
ServerScriptService:SetAttribute("LobbyServerBooted", true)

Workspace:SetAttribute("LobbyModeActive", true)
if Workspace:GetAttribute("GameActive") == nil then
	Workspace:SetAttribute("GameActive", false)
end

-- Disable non-lobby ground spawns until a play circle launches the match
for _, desc in Workspace:GetDescendants() do
	if desc:IsA("SpawnLocation") and desc.Name ~= "LobbySpawn" then
		desc.Enabled = false
	end
end

local LobbyScene = require(script.LobbyScene)
local PlayerDataService = require(script.PlayerDataService)
local ShopService = require(script.ShopService)
local QueueService = require(script.QueueService)

LobbyScene.build()

local lobbyMap = Workspace:FindFirstChild("LobbyMap")
local lobbySpawnInst = if lobbyMap
	then lobbyMap:FindFirstChild("LobbySpawn")
	else Workspace:FindFirstChild("LobbySpawn")
local lobbySpawn = if lobbySpawnInst and lobbySpawnInst:IsA("SpawnLocation") then lobbySpawnInst else nil
if lobbySpawn then
	lobbySpawn.Enabled = true
end

local function ensureLobbySpawnForPlayer(player: Player)
	if player:GetAttribute("InGame") == true or not lobbySpawn then
		return
	end
	player.RespawnLocation = lobbySpawn

	local function snapCharacterToLobby(character: Model)
		task.defer(function()
			if not character.Parent or player:GetAttribute("InGame") == true then
				return
			end
			local hrp = character:WaitForChild("HumanoidRootPart", 5)
			if not hrp or not hrp:IsA("BasePart") or player:GetAttribute("InGame") == true then
				return
			end
			local dist = (hrp.Position - lobbySpawn.Position).Magnitude
			if dist > 95 then
				pcall(function()
					player:RequestStreamAroundAsync(lobbySpawn.Position)
				end)
				if character.Parent and player:GetAttribute("InGame") ~= true then
					character:PivotTo(lobbySpawn.CFrame * CFrame.new(0, 3.5, 0))
				end
			end
		end)
	end

	player.CharacterAdded:Connect(snapCharacterToLobby)
	if player.Character then
		snapCharacterToLobby(player.Character)
	end
end

Players.PlayerAdded:Connect(ensureLobbySpawnForPlayer)
for _, player in Players:GetPlayers() do
	ensureLobbySpawnForPlayer(player)
end

PlayerDataService.init()
ShopService.init()
QueueService.init()

print("[LobbyInit] Dark Forest Lobby online.")
