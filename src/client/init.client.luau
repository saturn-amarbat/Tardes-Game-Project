--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

if script:FindFirstChild("Lobby") ~= nil then
	local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
	if LobbyConfig.shouldStartInLobby() then
		local function suppressGameHud(child: Instance)
			if child.Name == "GameHUD" and child:IsA("ScreenGui") and localPlayer:GetAttribute("InGame") ~= true then
				child.Enabled = false
			end
		end
		local existingHud = playerGui:FindFirstChild("GameHUD")
		if existingHud then
			suppressGameHud(existingHud)
		end
		local hudConn = playerGui.ChildAdded:Connect(suppressGameHud)

		while localPlayer:GetAttribute("InGame") ~= true do
			localPlayer:GetAttributeChangedSignal("InGame"):Wait()
		end

		hudConn:Disconnect()
		local gameHud = playerGui:FindFirstChild("GameHUD")
		if gameHud and gameHud:IsA("ScreenGui") then
			gameHud.Enabled = true
		end
	end
end

local FlashlightController = require(script.FlashlightController)
require(script.FlashlightReplicaClient).init()
require(script.PrologueController).init()
require(script.ObjectiveHUD).init()
require(script.SpectatorController).init()
require(script.SprintController).init()
require(script.HorrorFeedback).init()
require(script.FieldJournal).init()
require(script.LampFlicker).init()

FlashlightController.init()

-- Auto-toggle flashlight on after spawn delay.
task.delay(1, function()
	FlashlightController.toggle()
end)
