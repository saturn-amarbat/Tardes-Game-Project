--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

if script:FindFirstChild("Lobby") ~= nil then
	local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
	if LobbyConfig.shouldStartInLobby() then
		while Workspace:GetAttribute("GameActive") ~= true do
			Workspace:GetAttributeChangedSignal("GameActive"):Wait()
		end
	end
end

local RoomGenerator = require(script.RoomGenerator)
local FlashlightReplicator = require(script.FlashlightReplicator)
local PrologueManager = require(script.PrologueManager)
local SurveyGallery = require(script.SurveyGallery)
local MaintenanceBay = require(script.MaintenanceBay)
local NPCManager = require(script.NPCManager)
local MatchScaleManager = require(script.MatchScaleManager)
local ClueSystem = require(script.ClueSystem)
local FunnelAnalytics = require(script.FunnelAnalytics)
local InteractionRouter = require(script.InteractionRouter)
local MonetizationService = require(script.MonetizationService)
local SafeRoomService = require(script.SafeRoomService)

InteractionRouter.init()
FlashlightReplicator.init()
PrologueManager.init()
FunnelAnalytics.init()
SafeRoomService.init()
MonetizationService.init()
MatchScaleManager.init(function()
	local rooms = RoomGenerator.generate(10)
	NPCManager.init(rooms)
	ClueSystem.init(rooms)
	MaintenanceBay.install(rooms[1], #rooms > 1)
	SurveyGallery.install(rooms)
	SafeRoomService.install(rooms)
	return rooms
end)
print("[ServerInit] Milestone 3 systems online.")
