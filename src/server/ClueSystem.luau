--!strict
--[[
  ClueSystem  –  SERVER-SIDE

  Spawns ProximityPrompt interactions on clue props in the generated dungeon.
  When a player collects a clue:
    • The whole squad is credited (remote fires for every player).
    • The clue prop is marked as collected (prompt disabled, visual cue).
    • A ClueCollected remote fires with the full ClueEntry data for HUD display.

  Props are found by looking for Parts tagged "Clue_<id>" in the dungeon folder,
  OR for Parts whose Name starts with "ClueProp_" (Creative Lead naming).
  If no props are found in a room, a small graybox placeholder is created so
  the system is always testable.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClueData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClueData"))

local InteractionRouter = require(script.Parent.InteractionRouter)
local ClueSystem = {}

-- ── Remotes ───────────────────────────────────────────────────────────────────
local function ensureRemote(parent: Instance, name: string): RemoteEvent
	local ev = parent:FindFirstChild(name) :: RemoteEvent?
	if ev then
		return ev
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = parent
	return created
end

local function ensureFolder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name) :: Folder?
	if f then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- ── Grounded clue prop & surface raycast ────────────────────────────────────
local function findSurfaceCFrame(room: Model): CFrame
	local pivot = room:GetPivot()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { room }
	params.RespectCanCollide = true

	for _ = 1, 6 do
		local x = math.random(-4, 4)
		local z = math.random(-4, 4)
		local probe = pivot.Position + Vector3.new(x, 6, z)
		local hit = Workspace:Raycast(probe, -Vector3.yAxis * 14, params)
		if hit and hit.Normal.Y > 0.85 then
			return CFrame.new(hit.Position + Vector3.yAxis * 0.08)
				* CFrame.Angles(math.pi / 2, math.random() * math.pi, 0)
		end
	end
	return CFrame.new(pivot.Position + Vector3.new(0, 0.5, 0))
end

local function createGrayboxProp(clueCF: CFrame, clueName: string, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = "ClueProp_" .. clueName
	part.Size = Vector3.new(0.65, 0.85, 0.05)
	part.Color = Color3.fromRGB(224, 208, 174)
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = clueCF
	part.Anchored = true
	part.CanCollide = false
	part.Parent = parent
	return part
end

-- ── Attach interaction to a prop part ────────────────────────────────────────
local function attachCluePrompt(
	prop: BasePart,
	entry: { id: string, title: string, body: string, isWallScribble: boolean },
	clueEvent: RemoteEvent,
	clueFolder: Folder
)
	-- Check if already collected this session.
	local collected = clueFolder:FindFirstChild(entry.id)
	if collected then
		return
	end

	prop:SetAttribute("Collected", false)

	local mount = prop:FindFirstChild("PromptMount")
	if not mount or not mount:IsA("Attachment") then
		local att = Instance.new("Attachment")
		att.Name = "PromptMount"
		att.Position = Vector3.new(0, 0.15, 0)
		att.Parent = prop
		mount = att
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if entry.isWallScribble then "Read Writing" else "Pick Up"
	prompt.ObjectText = entry.title
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = true
	prompt.Parent = mount

	-- Visual collected indicator (a small green PointLight).
	local collectLight = Instance.new("PointLight")
	collectLight.Color = Color3.fromRGB(100, 255, 140)
	collectLight.Brightness = 0.6
	collectLight.Range = 6
	collectLight.Enabled = false
	collectLight.Parent = prop

	InteractionRouter.register(prompt, {
		targetPart = prop,
		onTriggered = function()
			if not prompt.Enabled or prop:GetAttribute("Collected") == true or clueFolder:FindFirstChild(entry.id) then
				return
			end
			-- Lock immediately to prevent duplicate collection races.
			prop:SetAttribute("Collected", true)
			prompt.Enabled = false

			local marker = Instance.new("BoolValue")
			marker.Name = entry.id
			marker.Parent = clueFolder

			collectLight.Enabled = true
			clueEvent:FireAllClients(entry)
		end,
	})
end

-- ── Public init ───────────────────────────────────────────────────────────────
function ClueSystem.init(rooms: { Model })
	local matchRemotes = ensureFolder(ReplicatedStorage, "MatchRemotes")
	local clueEvent = ensureRemote(matchRemotes, "ClueCollected")
	local clueFolder = ensureFolder(matchRemotes, "CollectedClues")

	clueFolder:ClearAllChildren()
	local dungeonFolder = Workspace:FindFirstChild("GeneratedDungeon") :: Folder?
	if not dungeonFolder then
		warn("[ClueSystem] GeneratedDungeon not found.")
		return
	end

	-- Distribute clues across rooms (skip room 1 — that's the spawn room).
	local cluePool = table.clone(ClueData)
	-- Shuffle pool.
	for i = #cluePool, 2, -1 do
		local j = math.random(i)
		cluePool[i], cluePool[j] = cluePool[j], cluePool[i]
	end

	local placed = 0
	for roomIdx, room in ipairs(rooms) do
		if roomIdx == 1 or room:GetAttribute("SafeRoom") == true then
			continue
		end
		if placed >= #cluePool then
			break
		end

		local entry = cluePool[placed + 1]
		placed += 1

		-- Check if the Creative Lead placed a tagged prop in this room.
		local existingProp: BasePart? = nil
		for _, desc in ipairs(room:GetDescendants()) do
			if desc:IsA("BasePart") and (desc.Name == ("Clue_" .. entry.id) or desc.Name:sub(1, 9) == "ClueProp_") then
				existingProp = desc
				break
			end
		end

		local clueCF = findSurfaceCFrame(room)
		local prop = existingProp or createGrayboxProp(clueCF, entry.id, room)

		attachCluePrompt(prop :: BasePart, entry, clueEvent, clueFolder)
	end

	print(string.format("[ClueSystem] Placed %d clues across %d rooms.", placed, #rooms))
end

return ClueSystem
