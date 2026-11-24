--!strict
--[[
  NPCManager  –  SERVER-SIDE modular NPC system.

  Pulls swappable model rigs by name from ReplicatedStorage/NPCModels.
  The Creative Lead replaces graybox placeholders with final 3D rigs; no
  code changes are needed as long as the Name matches.

  Three NPC types:
    1. ToadPassiveNPC     – ambient toads, non-lethal idle/croak hooks.
    2. RoomInstanceNPC    – brief non-lethal jumpscare inside cabin rooms,
                            drains battery and fires FlashlightController
                            flicker via FlickerRequest remote.
    3. MainNPC_Stalker    – basic state machine: Patrol → Stalk → Chase.
                            Audio telegraph fires before Chase so encounters
                            feel fair.

  Call NPCManager.init(rooms) after RoomGenerator.generate().
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NPCManager = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function getTemplate(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("NPCModels")
	if not folder then
		return nil
	end
	return folder:FindFirstChild(name) :: Model?
end

local function randomRoomPosition(room: Model, npc: Model): CFrame
	-- Return a random point on the room floor near the centre.
	local pivot = room:GetPivot()
	local offsetX = math.random(-4, 4)
	local offsetZ = math.random(-4, 4)
	local point = pivot.Position + Vector3.new(offsetX, 0, offsetZ)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { room }
	params.RespectCanCollide = true
	local floor = Workspace:Raycast(point + Vector3.yAxis * 4, -Vector3.yAxis * 12, params)
	local bounds, size = npc:GetBoundingBox()
	local pivotHeight = npc:GetPivot().Y - bounds.Y + size.Y / 2
	return CFrame.new(point.X, (if floor then floor.Position.Y else point.Y) + pivotHeight, point.Z)
end

-- ── Flicker remote for client battery drain on RoomInstanceNPC scare ─────────
local function ensureFlickerRemote(): RemoteEvent
	local remotes = ReplicatedStorage:FindFirstChild("FlashlightRemotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "FlashlightRemotes"
		remotes.Parent = ReplicatedStorage
	end
	local ev = remotes:FindFirstChild("FlickerRequest") :: RemoteEvent?
	if ev then
		return ev
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "FlickerRequest"
	created.Parent = remotes
	return created
end

-- ── 1. ToadPassiveNPC ────────────────────────────────────────────────────────
local TOAD_CROAK_INTERVAL = 8 -- seconds between croaks

local function spawnToad(room: Model, npcFolder: Folder)
	local template = getTemplate("ToadPassiveNPC")

	local toad: Model
	if template then
		toad = template:Clone()
	else
		-- Graybox placeholder (Creative Lead replaces later).
		toad = Instance.new("Model")
		toad.Name = "ToadPassiveNPC"
		local body = Instance.new("Part")
		body.Name = "HumanoidRootPart"
		body.Size = Vector3.new(1.2, 0.6, 1.4)
		body.Color = Color3.fromRGB(80, 110, 70)
		body.Anchored = true
		body.Parent = toad
		toad.PrimaryPart = body
	end

	toad:PivotTo(randomRoomPosition(room, toad))
	toad.Parent = npcFolder

	-- Croak loop hook.
	task.spawn(function()
		local sounds = Workspace:FindFirstChild("Sounds")
		local croak = sounds and sounds:FindFirstChild("ToadCroak") :: Sound?
		while toad.Parent do
			task.wait(TOAD_CROAK_INTERVAL + math.random() * 4)
			if croak then
				croak:Play()
			end
		end
	end)
end

-- ── 2. RoomInstanceNPC ───────────────────────────────────────────────────────
local JUMPSCARE_COOLDOWN = 30 -- seconds before room can scare again

local function spawnRoomInstance(room: Model, npcFolder: Folder, flickerRemote: RemoteEvent)
	local template = getTemplate("RoomInstanceNPC")

	local npc: Model
	if template then
		npc = template:Clone()
	else
		npc = Instance.new("Model")
		npc.Name = "RoomInstanceNPC"
		local body = Instance.new("Part")
		body.Name = "HumanoidRootPart"
		body.Size = Vector3.new(1, 2, 1)
		body.Color = Color3.fromRGB(50, 40, 60)
		body.Transparency = 0.5
		body.Anchored = true
		body.Parent = npc
		npc.PrimaryPart = body
	end

	npc:PivotTo(randomRoomPosition(room, npc))
	npc.Parent = npcFolder

	-- Proximity scare loop.
	local lastScare = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		if not npc.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local now = os.clock()
		if now - lastScare < JUMPSCARE_COOLDOWN then
			return
		end

		local npcPos = npc:GetPivot().Position
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and (hrp.Position - npcPos).Magnitude < 6 then
				lastScare = now
				-- Trigger flashlight flicker + battery drain on this player's client.
				flickerRemote:FireClient(player, 1.5, 0.7, 12)
				-- Brief flash-and-hide of the NPC.
				task.spawn(function()
					local body = npc.PrimaryPart
					if not body then
						return
					end
					body.Transparency = 0
					task.wait(0.15)
					if npc.PrimaryPart then
						npc.PrimaryPart.Transparency = 0.5
					end
				end)
				break
			end
		end
	end)
end

-- ── 3. MainNPC_Stalker ───────────────────────────────────────────────────────
type StalkerState = "Patrol" | "Stalk" | "Chase"

local PATROL_SPEED = 10
local STALK_SPEED = 14
local CHASE_SPEED = 20
local CHASE_DETECT_RANGE = 22
local STALK_DETECT_RANGE = 36
local TELEGRAPH_RANGE = 30 -- plays audio warning before chase

local function spawnStalker(room: Model, npcFolder: Folder)
	local template = getTemplate("MainNPC_Stalker")

	local stalker: Model
	if template then
		stalker = template:Clone()
	else
		stalker = Instance.new("Model")
		stalker.Name = "MainNPC_Stalker"
		local body = Instance.new("Part")
		body.Name = "HumanoidRootPart"
		body.Size = Vector3.new(2, 5, 2)
		body.Color = Color3.fromRGB(15, 10, 20)
		body.Anchored = true
		body.CastShadow = true
		body.Parent = stalker
		stalker.PrimaryPart = body
	end

	local spawnCF = randomRoomPosition(room, stalker)
	stalker:PivotTo(spawnCF)
	stalker.Parent = npcFolder

	local state: StalkerState = "Patrol"
	local patrolPoints: { CFrame } = {}
	-- Generate simple patrol loop near spawn.
	for i = 0, 3 do
		local angle = (i / 4) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 18, 0, math.sin(angle) * 18)
		table.insert(patrolPoints, CFrame.new(spawnCF.Position + offset))
	end
	local patrolIdx = 1

	local sounds = Workspace:FindFirstChild("Sounds")
	local telegraphSound = sounds and sounds:FindFirstChild("StalkerTelegraph") :: Sound?
	local telegraphPlayed = false
	local nextAttack = 0

	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if not stalker.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end

		-- Find nearest player (players with flashlights OFF are harder to detect; SafeRoom is immune).
		local stalkerPos = stalker:GetPivot().Position
		local nearestDist = math.huge
		local nearestEffective = math.huge
		local nearestPlayer: Player? = nil
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				hrp
				and player:GetAttribute("DungeonEntered")
				and not player:GetAttribute("SittingOut")
				and not player:GetAttribute("InSafeRoom")
			then
				local d = (hrp.Position - stalkerPos).Magnitude
				local lightMult = if player:GetAttribute("FlashlightOn") == true then 1 else 1.75
				local effective = d * lightMult
				if effective < nearestEffective then
					nearestEffective = effective
					nearestDist = d
					nearestPlayer = player
				end
			end
		end

		-- Contact damage sends the Stalker back to patrol and gives survivors time to move.
		if nearestPlayer and nearestDist < 3 and os.clock() >= nextAttack then
			local character = nearestPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				nextAttack = os.clock() + 6
				humanoid:TakeDamage(35)
				stalker:PivotTo(spawnCF)
				state = "Patrol"
				telegraphPlayed = false
				return
			end
		end
		-- State transitions (effective distance rewards turning off flashlight to hide).
		if nearestEffective < CHASE_DETECT_RANGE then
			state = "Chase"
		elseif nearestEffective < STALK_DETECT_RANGE then
			if state ~= "Chase" then
				state = "Stalk"
			end
		else
			state = "Patrol"
			telegraphPlayed = false
		end

		-- Audio telegraph (fires once per chase encounter).
		if state == "Chase" and not telegraphPlayed and nearestDist < TELEGRAPH_RANGE then
			telegraphPlayed = true
			if telegraphSound then
				telegraphSound:Play()
			end
		end

		-- Movement.
		local speed = if state == "Chase" then CHASE_SPEED elseif state == "Stalk" then STALK_SPEED else PATROL_SPEED

		local targetPos: Vector3
		if state == "Patrol" then
			local goal = patrolPoints[patrolIdx]
			targetPos = goal.Position
			if (stalkerPos - targetPos).Magnitude < 2 then
				patrolIdx = (patrolIdx % #patrolPoints) + 1
			end
		else
			local char = nearestPlayer and nearestPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			targetPos = hrp and hrp.Position or stalkerPos
		end

		local direction = (targetPos - stalkerPos)
		if direction.Magnitude > 0.1 then
			local step = direction.Unit * math.min(speed * dt, direction.Magnitude)
			local newPos = stalkerPos + step
			local lookAt = CFrame.lookAt(newPos, newPos + direction.Unit)
			stalker:PivotTo(lookAt)
		end
	end)
end

-- ── Public init ───────────────────────────────────────────────────────────────
function NPCManager.init(rooms: { Model })
	local npcFolder = Workspace:FindFirstChild("NPCs")
	if not npcFolder then
		npcFolder = Instance.new("Folder")
		npcFolder.Name = "NPCs"
		npcFolder.Parent = Workspace
	else
		npcFolder:ClearAllChildren()
	end

	local flickerRemote = ensureFlickerRemote()

	local numRooms = #rooms
	if numRooms == 0 then
		warn("[NPCManager] No rooms to spawn NPCs in.")
		return
	end

	-- Spawn 3-5 passive toads spread across first third of dungeon (plus SafeRoom toads).
	local toadCount = math.random(3, 5)
	for _ = 1, toadCount do
		local room = rooms[math.random(1, math.max(1, math.floor(numRooms / 3)))]
		spawnToad(room, npcFolder :: Folder)
	end

	-- Spawn RoomInstanceNPC in middle rooms, skipping any SafeRoom.
	for i = math.max(1, math.floor(numRooms / 3)), math.floor(numRooms * 2 / 3) do
		if rooms[i]:GetAttribute("SafeRoom") ~= true and math.random() > 0.5 then
			spawnRoomInstance(rooms[i], npcFolder :: Folder, flickerRemote)
		end
	end

	-- Spawn MainNPC_Stalker in the final third of the dungeon (outside SafeRoom).
	local stalkerRoom = rooms[math.max(1, math.floor(numRooms * 0.7))]
	if stalkerRoom:GetAttribute("SafeRoom") == true and numRooms > 1 then
		stalkerRoom = rooms[numRooms]
	end
	spawnStalker(stalkerRoom, npcFolder :: Folder)

	print(string.format("[NPCManager] Spawned %d toads, RoomInstanceNPCs, and 1 Stalker.", toadCount))
end

return NPCManager
