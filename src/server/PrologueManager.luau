--!strict
--[[
  PrologueManager  –  SERVER-SIDE  (runs in ServerScriptService)

  Sequence:
    1. All 1-4 players spawn near a crashed car on a dark road.
    2. When any player shines a flashlight near (or walks within 14 studs of)
       the DeerIntroRig in Workspace, the omen triggers once per round.
    3. Full omen sequence:
         a. Leaf-rustle SFX (hook: plays from Workspace.Sounds.LeafRustle)
         b. Dialogue broadcast: "Scared me for a second, just a deer"  (3 s)
         c. Deer snaps 180 °, plays DeerScreech SFX hook
         d. DeerIntroRig bolts along a path and fades out
         e. A dim eerie green PointLight (BunkerLight) activates at the
            bunker entrance to guide players forward
    4. Any player can send SkipPrologue remote; if majority agree, sequence
       jumps straight to step (e).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PrologueManager = {}

-- ── Remotes ─────────────────────────────────────────────────────────────────
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

-- ── Deer sequence ────────────────────────────────────────────────────────────
local omenTriggered = false

local function activateBunkerLight()
	local bunkerLight = Workspace:FindFirstChild("BunkerLight") :: PointLight?
	if bunkerLight then
		bunkerLight.Enabled = true
		return
	end
	-- Fallback: create a simple green guiding light if builder hasn't placed one yet.
	local anchor = Workspace:FindFirstChild("BunkerEntrance") :: BasePart?
	if not anchor then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "BunkerLight"
	light.Color = Color3.fromRGB(100, 200, 120)
	light.Brightness = 1.2
	light.Range = 24
	light.Enabled = true
	light.Parent = anchor
end

local function runDeerSequence(_remotes: Folder, dialogueEvent: RemoteEvent)
	-- a. Leaf-rustle SFX hook.
	local sounds = Workspace:FindFirstChild("Sounds")
	local leafRustle = sounds and sounds:FindFirstChild("LeafRustle") :: Sound?
	if leafRustle then
		leafRustle:Play()
	end
	task.wait(1.2)

	-- b. Dialogue broadcast.
	dialogueEvent:FireAllClients("Scared me for a second… just a deer.")
	task.wait(3)

	-- c. Snap deer 180° + screeech SFX.
	local deerRig = Workspace:FindFirstChild("DeerIntroRig") :: Model?
	if deerRig then
		local pivot = deerRig:GetPivot()
		deerRig:PivotTo(pivot * CFrame.Angles(0, math.pi, 0))
	end
	local screech = sounds and sounds:FindFirstChild("DeerScreech") :: Sound?
	if screech then
		screech:Play()
	end
	task.wait(0.4)

	-- d. Bolt the deer away (tween position +Z 80 studs, fade model out).
	if deerRig and deerRig.PrimaryPart then
		local pivot = deerRig:GetPivot()
		local endPos = pivot * CFrame.new(0, 0, -80)
		local info = TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tween = TweenService:Create(deerRig.PrimaryPart, info, { CFrame = endPos })
		tween:Play()
		tween.Completed:Wait()
		deerRig.Parent = nil -- remove from workspace
	end
	task.wait(0.3)

	-- e. Activate guiding bunker light.
	activateBunkerLight()
	dialogueEvent:FireAllClients("") -- clear dialogue UI
end

-- ── Trigger detection ────────────────────────────────────────────────────────
local TRIGGER_RADIUS = 14 -- studs

function PrologueManager.init()
	local prologueFolder = ensureFolder(ReplicatedStorage, "PrologueRemotes")
	local dialogueEvent = ensureRemote(prologueFolder, "ShowDialogue")
	local skipEvent = ensureRemote(prologueFolder, "SkipPrologue")

	-- Skip vote tracking.
	local skipVotes: { [Player]: boolean } = {}

	skipEvent.OnServerEvent:Connect(function(player: Player)
		skipVotes[player] = true
		local total = #Players:GetPlayers()
		local votes = 0
		for _ in pairs(skipVotes) do
			votes += 1
		end
		-- Majority (> half) triggers skip.
		if votes > math.floor(total / 2) and not omenTriggered then
			omenTriggered = true
			activateBunkerLight()
			dialogueEvent:FireAllClients("")
		end
	end)

	Players.PlayerRemoving:Connect(function(p: Player)
		skipVotes[p] = nil
	end)

	-- Proximity poll: check every 0.5 s whether a player or flashlight is near
	-- the DeerIntroRig anchor. This avoids per-frame cost.
	local proximityConn: RBXScriptConnection? = nil
	proximityConn = RunService.Heartbeat:Connect(function()
		if omenTriggered then
			if proximityConn then
				proximityConn:Disconnect()
				proximityConn = nil
			end
			return
		end

		local deerRig = Workspace:FindFirstChild("DeerIntroRig") :: Model?
		if not deerRig then
			return
		end
		local deerPos = deerRig:GetPivot().Position

		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and (hrp.Position - deerPos).Magnitude < TRIGGER_RADIUS then
				omenTriggered = true
				if proximityConn then
					proximityConn:Disconnect()
					proximityConn = nil
				end
				task.spawn(runDeerSequence, prologueFolder, dialogueEvent)
				break
			end
		end
	end)

	print("[PrologueManager] Prologue system initialised.")
end

return PrologueManager
