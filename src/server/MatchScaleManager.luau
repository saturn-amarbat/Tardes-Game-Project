--!strict
--[[
  MatchScaleManager  –  SERVER-SIDE

  Scales objectives by live player count at round start:

  1 player:  compact run  – 1 key + 1 fuse, single-switch exit lever.
  2–4 players: expanded   – (count) keys + fuses, dual-lever doors that
                            require 2 living players holding switches
                            simultaneously; auto-reverts to single-lever
                            if only 1 survivor remains.

  Creates ProximityPrompts on lever Parts named "ExitLever_A" / "ExitLever_B"
  in Workspace.  Creative Lead places the actual geometry; this module just
  wires the interaction logic.

  Fires DoorUnlocked remote → client plays door-open SFX/anim.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MatchScaleManager = {}

-- ── Types ────────────────────────────────────────────────────────────────────
type ObjectiveSet = {
	keys: number,
	fuses: number,
	dualLever: boolean,
}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function ensureRemote(parent: Instance, name: string): RemoteEvent
	local ev = parent:FindFirstChild(name) :: RemoteEvent?
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = parent
	end
	return ev :: RemoteEvent
end

local function ensureFolder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name) :: Folder?
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

local function activePlayers(): number
	return #Players:GetPlayers()
end

local function computeObjectives(count: number): ObjectiveSet
	if count <= 1 then
		return { keys = 1, fuses = 1, dualLever = false }
	else
		return { keys = count, fuses = count, dualLever = true }
	end
end

-- ── Lever logic ──────────────────────────────────────────────────────────────
local function setupSingleLever(remotes: Folder)
	local doorEvent = ensureRemote(remotes, "DoorUnlocked")

	local leverA = Workspace:FindFirstChild("ExitLever_A") :: BasePart?
	if not leverA then
		warn("[MatchScaleManager] ExitLever_A not found in Workspace (Creative Lead places it).")
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pull Lever"
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 5
	prompt.Parent = leverA

	prompt.Triggered:Connect(function(_player: Player)
		prompt.Enabled = false
		doorEvent:FireAllClients("ExitDoor")
	end)
end

local function setupDualLever(remotes: Folder)
	local doorEvent = ensureRemote(remotes, "DoorUnlocked")

	local leverA = Workspace:FindFirstChild("ExitLever_A") :: BasePart?
	local leverB = Workspace:FindFirstChild("ExitLever_B") :: BasePart?
	if not leverA or not leverB then
		warn("[MatchScaleManager] ExitLever_A or ExitLever_B missing – falling back to single lever.")
		setupSingleLever(remotes)
		return
	end

	local heldA = false
	local heldB = false
	local unlocked = false

	local function checkUnlock()
		if heldA and heldB and not unlocked then
			unlocked = true
			doorEvent:FireAllClients("ExitDoor")
		end
	end

	local function revertToSingleIfNeeded()
		-- Auto-revert: if only 1 player left, allow single lever to open.
		if activePlayers() <= 1 and not unlocked then
			unlocked = true
			doorEvent:FireAllClients("ExitDoor")
		end
	end

	-- Prompt A
	local promptA = Instance.new("ProximityPrompt")
	promptA.ActionText = "Hold Lever A"
	promptA.HoldDuration = 0
	promptA.MaxActivationDistance = 5
	promptA.Parent = leverA

	-- Prompt B
	local promptB = Instance.new("ProximityPrompt")
	promptB.ActionText = "Hold Lever B"
	promptB.HoldDuration = 0
	promptB.MaxActivationDistance = 5
	promptB.Parent = leverB

	promptA.PromptButtonHoldBegan:Connect(function(_player: Player)
		heldA = true
		checkUnlock()
	end)
	promptA.PromptButtonHoldEnded:Connect(function(_player: Player)
		heldA = false
	end)
	promptB.PromptButtonHoldBegan:Connect(function(_player: Player)
		heldB = true
		checkUnlock()
	end)
	promptB.PromptButtonHoldEnded:Connect(function(_player: Player)
		heldB = false
	end)

	Players.PlayerRemoving:Connect(function(_p: Player)
		revertToSingleIfNeeded()
	end)

	-- Poll in heartbeat: if only 1 player left at any time, revert.
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		if unlocked then
			if conn then
				conn:Disconnect()
			end
			return
		end
		revertToSingleIfNeeded()
	end)
end

-- ── Objective key/fuse tracking ──────────────────────────────────────────────
local function setupObjectiveTracking(objectives: ObjectiveSet, remotes: Folder)
	local progressEvent = ensureRemote(remotes, "ObjectiveProgress")

	local keysCollected = 0
	local fusesCollected = 0

	remotes:SetAttribute("Keys", 0)
	remotes:SetAttribute("Fuses", 0)
	remotes:SetAttribute("KeysTotal", objectives.keys)
	remotes:SetAttribute("FusesTotal", objectives.fuses)
	local collectRemote = ensureRemote(remotes, "CollectObjective")
	collectRemote.OnServerEvent:Connect(function(_player: Player, objType: string)
		if objType == "Key" and keysCollected < objectives.keys then
			keysCollected += 1
		elseif objType == "Fuse" and fusesCollected < objectives.fuses then
			fusesCollected += 1
		end
		remotes:SetAttribute("Keys", keysCollected)
		remotes:SetAttribute("Fuses", fusesCollected)
		progressEvent:FireAllClients({
			keys = keysCollected,
			keysTotal = objectives.keys,
			fuses = fusesCollected,
			fusesTotal = objectives.fuses,
		})
	end)
end

-- ── Public init ───────────────────────────────────────────────────────────────
function MatchScaleManager.init()
	local remotes = ensureFolder(ReplicatedStorage, "MatchRemotes")
	local count = activePlayers()
	local objectives = computeObjectives(count)

	print(
		string.format(
			"[MatchScaleManager] %d player(s) → %d key(s), %d fuse(s), dualLever=%s",
			count,
			objectives.keys,
			objectives.fuses,
			tostring(objectives.dualLever)
		)
	)

	setupObjectiveTracking(objectives, remotes)

	ensureRemote(remotes, "DoorUnlocked")
	local started = false
	local function updateParty()
		if started then
			return
		end
		local scaled = computeObjectives(activePlayers())
		objectives.keys = scaled.keys
		objectives.fuses = scaled.fuses
		objectives.dualLever = scaled.dualLever
		remotes:SetAttribute("KeysTotal", objectives.keys)
		remotes:SetAttribute("FusesTotal", objectives.fuses)
	end
	local function watchPlayer(player: Player)
		updateParty()
		local function enter()
			if started or player:GetAttribute("DungeonEntered") ~= true then
				return
			end
			updateParty()
			started = true
			if objectives.dualLever then
				setupDualLever(remotes)
			else
				setupSingleLever(remotes)
			end
		end
		player:GetAttributeChangedSignal("DungeonEntered"):Connect(enter)
		enter()
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function()
		task.defer(updateParty)
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	print("[MatchScaleManager] Objective scaling ready.")
end

return MatchScaleManager
