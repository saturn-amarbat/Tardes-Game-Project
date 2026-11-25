--!strict
--[[
  LampFlicker  –  Client-driven organic flicker for dungeon & cellar passage lamps,
  plus spatial/phase-gated metallic bunker creaks inside the underground facility.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BASE_BRIGHTNESS = 0.6
local BASE_COLOR = Color3.fromRGB(245, 189, 103)
local WARM_COLOR = Color3.fromRGB(255, 214, 150)

local GROANS = {
	"rbxassetid://9116638731", -- twisting creak 4
	"rbxassetid://9116638438", -- twisting creak 3
	"rbxassetid://9116638746", -- twisting creak 5
	"rbxassetid://9116638401", -- twisting creak 1
}

type LampEntry = {
	part: BasePart,
	light: PointLight,
	seed: number,
	stutterAt: number,
	stuttering: boolean,
}

local initialized = false

local function init()
	if initialized then
		return
	end
	initialized = true

	local localPlayer = Players.LocalPlayer
	local lamps: { LampEntry } = {}
	local registered: { [BasePart]: boolean } = {}

	local function register(inst: Instance)
		if inst.Name ~= "PassageLamp" or not inst:IsA("BasePart") or registered[inst] then
			return
		end
		local light = inst:FindFirstChildOfClass("PointLight")
		if light then
			registered[inst] = true
			table.insert(lamps, {
				part = inst,
				light = light,
				seed = math.random() * 100,
				stutterAt = os.clock() + math.random(15, 50),
				stuttering = false,
			})
		end
	end

	for _, desc in Workspace:GetDescendants() do
		register(desc)
	end
	Workspace.DescendantAdded:Connect(register)

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for i = #lamps, 1, -1 do
			local entry = lamps[i]
			if entry.part.Parent == nil or entry.light.Parent == nil then
				registered[entry.part] = nil
				table.remove(lamps, i)
			elseif not entry.stuttering then
				local n = math.noise(t * 0.8 + entry.seed, entry.seed)
				local sway = 0.75 + (n + 1) * 0.18
				entry.light.Brightness = BASE_BRIGHTNESS * sway
				entry.part.Color = BASE_COLOR:Lerp(WARM_COLOR, math.clamp((n + 1) * 0.25, 0, 1))

				if t >= entry.stutterAt then
					entry.stutterAt = t + math.random(25, 70)
					entry.stuttering = true
					task.spawn(function()
						for _ = 1, math.random(2, 4) do
							if entry.part.Parent == nil or entry.light.Parent == nil then
								entry.stuttering = false
								return
							end
							entry.light.Enabled = false
							entry.part.Material = Enum.Material.SmoothPlastic
							task.wait(math.random(30, 90) / 1000)
							if entry.part.Parent == nil or entry.light.Parent == nil then
								entry.stuttering = false
								return
							end
							entry.light.Enabled = true
							entry.part.Material = Enum.Material.Neon
							task.wait(math.random(60, 180) / 1000)
						end
						entry.stuttering = false
					end)
				end
			end
		end
	end)

	-- Distant structural groans only trigger once the player descends into the bunker.
	task.spawn(function()
		while true do
			task.wait(math.random(25, 55))
			if localPlayer:GetAttribute("DungeonEntered") ~= true then
				continue
			end
			local groan = Instance.new("Sound")
			groan.Name = "BunkerStructuralGroan"
			groan.SoundId = GROANS[math.random(#GROANS)]
			groan.Volume = 0.2 + math.random() * 0.15
			groan.PlaybackSpeed = 0.85 + math.random() * 0.25
			groan.Parent = Workspace
			groan:Play()
			groan.Ended:Once(function()
				groan:Destroy()
			end)
		end
	end)
end

return {
	init = init,
}
