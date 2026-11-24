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

local PathfindingService = game:GetService("PathfindingService")
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

	-- 3D spatialized croak loop on the toad itself (only audible when a dungeon player is nearby).
	task.spawn(function()
		local sounds = Workspace:FindFirstChild("Sounds")
		local templateCroak = sounds and sounds:FindFirstChild("ToadCroak") :: Sound?
		local localCroak: Sound? = nil
		if templateCroak and toad.PrimaryPart then
			local cloned = templateCroak:Clone()
			cloned.Volume = 0.32
			cloned.RollOffMode = Enum.RollOffMode.InverseTapered
			cloned.RollOffMinDistance = 4
			cloned.RollOffMaxDistance = 24
			cloned.Parent = toad.PrimaryPart
			localCroak = cloned
		end
		while toad.Parent do
			task.wait(TOAD_CROAK_INTERVAL + math.random() * 5)
			if localCroak and toad.PrimaryPart then
				local toadPos = toad.PrimaryPart.Position
				local playerNear = false
				for _, p in Players:GetPlayers() do
					local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if
						p:GetAttribute("DungeonEntered") == true
						and hrp
						and hrp:IsA("BasePart")
						and (hrp.Position - toadPos).Magnitude <= 28
					then
						playerNear = true
						break
					end
				end
				if playerNear then
					localCroak.PlaybackSpeed = 0.95 + math.random() * 0.15
					localCroak:Play()
				end
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
local PROXIMITY_FLICKER_RANGE = 38
local PATH_RECOMPUTE_INTERVAL = 0.35

local function spawnStalker(room: Model, npcFolder: Folder, allRooms: { Model }, flickerRemote: RemoteEvent)
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

	local humanoid = stalker:FindFirstChildOfClass("Humanoid")
	-- Keep server physics ownership so clients never freeze or rubber-band the monster
	for _, desc in stalker:GetDescendants() do
		if desc:IsA("BasePart") and not desc.Anchored then
			pcall(function()
				desc:SetNetworkOwner(nil)
			end)
		end
	end

	local state: StalkerState = "Patrol"
	local patrolPoints: { Vector3 } = {}
	for _, r in allRooms do
		if r:GetAttribute("SafeRoom") ~= true then
			local pt = randomRoomPosition(r, stalker).Position
			table.insert(patrolPoints, pt)
		end
	end
	if #patrolPoints == 0 then
		table.insert(patrolPoints, spawnCF.Position)
	end
	local patrolIdx = 1

	local sounds = Workspace:FindFirstChild("Sounds")
	local telegraphSound = sounds and sounds:FindFirstChild("StalkerTelegraph") :: Sound?
	local telegraphPlayed = false
	local nextAttack = 0
	local lastFlicker: { [Player]: number } = {}

	local path = PathfindingService:CreatePath({
		AgentRadius = 1.6,
		AgentHeight = 5.5,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})
	local waypoints: { PathWaypoint } = {}
	local wpIndex = 2
	local lastPathTime = 0
	local computingPath = false

	local losParams = RaycastParams.new()
	losParams.FilterType = Enum.RaycastFilterType.Exclude
	losParams.RespectCanCollide = true

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
		local now = os.clock()

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
				local lightOn = player:GetAttribute("FlashlightOn") == true
				local lightMult = if lightOn then 1 else 1.75
				local effective = d * lightMult
				if effective < nearestEffective then
					nearestEffective = effective
					nearestDist = d
					nearestPlayer = player
				end
				-- Subtle proximity flicker warning when monster stalks close to lit players
				if lightOn and d <= PROXIMITY_FLICKER_RANGE and (now - (lastFlicker[player] or 0)) >= 4.5 then
					lastFlicker[player] = now
					flickerRemote:FireClient(player, 0.75, 0.55, 0)
				end
			end
		end

		-- Contact damage sends the Stalker back to patrol and gives survivors time to move.
		if nearestPlayer and nearestDist < 3.4 and now >= nextAttack then
			local character = nearestPlayer.Character
			local targetHum = character and character:FindFirstChildOfClass("Humanoid")
			if targetHum and targetHum.Health > 0 then
				nextAttack = now + 6
				targetHum:TakeDamage(35)
				stalker:PivotTo(spawnCF)
				state = "Patrol"
				telegraphPlayed = false
				table.clear(waypoints)
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

		local speed = if state == "Chase" then CHASE_SPEED elseif state == "Stalk" then STALK_SPEED else PATROL_SPEED
		if humanoid then
			humanoid.WalkSpeed = speed
		end

		local targetPos: Vector3
		if state == "Patrol" then
			targetPos = patrolPoints[patrolIdx]
			if (stalkerPos - targetPos).Magnitude < 3.5 then
				patrolIdx = (patrolIdx % #patrolPoints) + 1
				targetPos = patrolPoints[patrolIdx]
			end
		else
			local char = nearestPlayer and nearestPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			targetPos = if hrp then hrp.Position else stalkerPos
		end

		if humanoid then
			-- Direct MoveTo when clear line-of-sight exists; throttled PathfindingService around walls
			local exclude: { Instance } = { npcFolder }
			for _, p in Players:GetPlayers() do
				if p.Character then
					table.insert(exclude, p.Character)
				end
			end
			losParams.FilterDescendantsInstances = exclude
			local rayVec = targetPos - stalkerPos
			local hasLoS = rayVec.Magnitude < 2 or Workspace:Raycast(stalkerPos, rayVec, losParams) == nil

			if hasLoS then
				table.clear(waypoints)
				humanoid:MoveTo(targetPos)
			else
				if not computingPath and (now - lastPathTime >= PATH_RECOMPUTE_INTERVAL or #waypoints == 0) then
					computingPath = true
					lastPathTime = now
					local originPos = stalkerPos
					local destPos = targetPos
					task.spawn(function()
						local ok = pcall(function()
							path:ComputeAsync(originPos, destPos)
						end)
						if ok and path.Status == Enum.PathStatus.Success then
							waypoints = path:GetWaypoints()
							wpIndex = 2 -- skip waypoint 1 (current starting position)
						end
						computingPath = false
					end)
				end

				local wp = waypoints[wpIndex]
				if wp then
					if (stalkerPos - wp.Position).Magnitude < 3.2 then
						wpIndex += 1
						wp = waypoints[wpIndex]
					end
					if wp then
						humanoid:MoveTo(wp.Position)
					else
						humanoid:MoveTo(targetPos)
					end
				else
					humanoid:MoveTo(targetPos)
				end
			end
		else
			-- Fallback movement if a placeholder model lacks a Humanoid
			local direction = targetPos - stalkerPos
			if direction.Magnitude > 0.1 then
				local step = direction.Unit * math.min(speed * dt, direction.Magnitude)
				local newPos = stalkerPos + step
				stalker:PivotTo(CFrame.lookAt(newPos, newPos + direction.Unit))
			end
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

	-- Spawn 2-3 passive toads spread across distinct early rooms (skip SafeRoom).
	local toadCount = math.random(2, 3)
	local earlyEnd = math.max(1, math.floor(numRooms / 3))
	for i = 1, toadCount do
		local room = rooms[((i - 1) % earlyEnd) + 1]
		if room:GetAttribute("SafeRoom") ~= true then
			spawnToad(room, npcFolder :: Folder)
		end
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
	spawnStalker(stalkerRoom, npcFolder :: Folder, rooms, flickerRemote)

	print(string.format("[NPCManager] Spawned %d toads, RoomInstanceNPCs, and 1 Stalker.", toadCount))
end

return NPCManager
