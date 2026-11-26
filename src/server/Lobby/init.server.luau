--!strict
--[[
  Lobby Server Bootstrap  –  initializes all Dark Forest Lobby systems.

  Guard ensures that if default.project.json syncs this folder into the main
  road/bunker place, it does NOT run or overwrite the game scene unless
  Workspace:GetAttribute("ForceLobbyScene") == true.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))

local isMainPlace = (game.PlaceId > 0 and game.PlaceId == LobbyConfig.GAME_PLACE_ID)
	or script.Parent:FindFirstChild("ForestCabin") ~= nil
if isMainPlace and Workspace:GetAttribute("ForceLobbyScene") ~= true then
	return
end

local LobbyScene = require(script.LobbyScene)
local PlayerDataService = require(script.PlayerDataService)
local ShopService = require(script.ShopService)
local QueueService = require(script.QueueService)

LobbyScene.build()
PlayerDataService.init()
ShopService.init()
QueueService.init()

print("[LobbyInit] Dark Forest Lobby online.")
