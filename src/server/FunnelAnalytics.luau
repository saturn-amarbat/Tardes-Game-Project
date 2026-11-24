--!strict
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FunnelAnalytics = {}

function FunnelAnalytics.init()
	local seen: { [Player]: { [number]: boolean } } = {}

	local function getSessionId(): string
		local num = Workspace:GetAttribute("ExpeditionNumber")
		return "expedition_" .. tostring(num or 1)
	end

	local function logStep(player: Player, step: number, name: string)
		if player.Parent ~= Players then
			return
		end
		local map = seen[player]
		if not map then
			map = {}
			seen[player] = map
		end
		if map[step] then
			return
		end
		map[step] = true
		pcall(function()
			AnalyticsService:LogFunnelStepEvent(player, "CoreExpedition", getSessionId(), step, name)
		end)
	end

	local function logAllActive(step: number, name: string)
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("SittingOut") ~= true then
				logStep(p, step, name)
			end
		end
	end

	local function watchPlayer(player: Player)
		seen[player] = {}
		logStep(player, 1, "forest_spawn")
		player:GetAttributeChangedSignal("DungeonEntered"):Connect(function()
			if player:GetAttribute("DungeonEntered") == true then
				logStep(player, 6, "lift_use")
			end
		end)
	end

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		seen[player] = nil
	end)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end

	Workspace:GetAttributeChangedSignal("ExpeditionNumber"):Connect(function()
		for _, p in Players:GetPlayers() do
			seen[p] = {}
			logStep(p, 1, "forest_spawn")
		end
	end)

	Workspace:GetAttributeChangedSignal("BlackpineOpeningStep"):Connect(function()
		local step = Workspace:GetAttribute("BlackpineOpeningStep")
		if step == "UnlockHatch" then
			logAllActive(4, "cellar_key_found")
		elseif step == "FindLift" then
			logAllActive(5, "bunker_descent")
		end
	end)

	task.spawn(function()
		local prologue = ReplicatedStorage:WaitForChild("PrologueRemotes", 10)
		if prologue then
			prologue:GetAttributeChangedSignal("OmenAvailable"):Connect(function()
				if prologue:GetAttribute("OmenAvailable") == false then
					logAllActive(2, "deer_omen")
				end
			end)
		end
	end)

	task.spawn(function()
		local matchRemotes = ReplicatedStorage:WaitForChild("MatchRemotes", 10)
		if not matchRemotes then
			return
		end
		matchRemotes:GetAttributeChangedSignal("ObjectivesComplete"):Connect(function()
			if matchRemotes:GetAttribute("ObjectivesComplete") == true then
				logAllActive(7, "objective_complete")
			end
		end)
		matchRemotes:GetAttributeChangedSignal("RunState"):Connect(function()
			local phase = matchRemotes:GetAttribute("RunState")
			if phase == "Escaped" then
				logAllActive(8, "gate_escaped")
			elseif phase == "Wiped" then
				for _, p in Players:GetPlayers() do
					logStep(p, 9, "squad_wipe")
				end
			end
		end)
	end)

	print("[FunnelAnalytics] 9-stage expedition funnel tracking ready.")
end

return FunnelAnalytics
