--!strict
local F = require(script.Parent.Fittings)
local V = Vector3.new
local C = CFrame.new
local metal = Enum.Material.Metal
local SurveyRelay = {}

local function gantry(vault: Model)
	local lights: { PointLight } = {}
	local floor = vault:FindFirstChild("Concourse floor")
	if not floor or not floor:IsA("BasePart") then
		return lights
	end
	local bay = floor.CFrame * C(0, floor.Size.Y / 2, 24)
	for _, z in { -1.3, 1.3 } do
		for _, y in { 8.8, 11.4 } do
			F.part(floor, "Gantry chord", bay * C(0, y, z), V(39, 0.26, 0.26), F.iron, Enum.Material.CorrodedMetal)
		end
		for i = 0, 7 do
			local x = -19.5 + i * 4.875
			local rise = if i % 2 == 0 then 8.8 else 11.4
			F.rod(floor, "Lattice stay", bay * V(x, rise, z), bay * V(x + 4.875, 20.2 - rise, z), 0.17, F.iron, metal)
		end
	end
	F.part(
		floor,
		"Inspection deck",
		bay * C(0, 8.72, 0),
		V(39, 0.18, 2.8),
		Color3.fromRGB(74, 73, 64),
		Enum.Material.DiamondPlate
	)
	for _, x in { -15, 0, 15 } do
		local hood = bay * C(x, 8.45, 0)
		F.part(floor, "Porcelain shade", hood, V(1.65, 0.21, 1), F.enamel, metal)
		local globe =
			F.part(floor, "Milk glass", hood * C(0, -0.21, 0), V(0.66, 0.47, 0.66), F.paper, Enum.Material.Glass)
		globe.Shape = Enum.PartType.Ball
		table.insert(lights, F.light(globe, Color3.fromRGB(238, 197, 137), 17))
	end
	-- Mineral tide lines and rust bleeds pick up raking light on the existing pours.
	for _, wall in vault:GetChildren() do
		if wall.Name == "Retaining wall" and wall:IsA("BasePart") then
			local side = if floor.CFrame:PointToObjectSpace(wall.Position).X > 0 then -1 else 1
			local surface = wall.CFrame * C(side * (wall.Size.X / 2 + 0.025), -4, 0)
			F.part(
				wall,
				"Mineral tide",
				surface,
				V(0.045, 0.16, wall.Size.Z - 0.2),
				Color3.fromRGB(112, 113, 98),
				Enum.Material.Slate
			)
			for i = 1, 3 do
				local fall = 0.4 + i * 0.37
				F.part(
					wall,
					"Anchor bleed",
					surface * C(side * 0.02, fall / 2, (i - 2) * wall.Size.Z * 0.23),
					V(0.05, fall, 0.07 * i),
					Color3.fromRGB(88, 71, 55),
					Enum.Material.CorrodedMetal
				)
			end
		end
	end
	return lights
end

function SurveyRelay.install(vault: Model, lift: BasePart)
	local lamps = gantry(vault)
	local landing = vault:FindFirstChild("Landing")
	local lower = vault:FindFirstChild("Lower landing")
	if landing and landing:IsA("BasePart") and lower and lower:IsA("BasePart") then
		for _, side in { -1, 1 } do
			local top = landing.CFrame * V(side * 3.94, 0.5, -2.7)
			local foot = lower.CFrame * V(side * 3.94, 0.5, 0.8)
			for i = 0, 3 do
				local post = top:Lerp(foot, i / 3)
				F.rod(landing, "Stanchion", post, post + Vector3.yAxis * 2.65, 0.12, F.iron, metal)
			end
			F.rod(
				landing,
				"Worn pipe rail",
				top + Vector3.yAxis * 2.65,
				foot + Vector3.yAxis * 2.65,
				0.15,
				F.brass,
				metal
			)
		end
	end
	local pull = lift.CFrame * C(0, 0, 0.59) * CFrame.Angles(0, math.pi, 0)
	local switch = F.part(lift, "Switch bezel", pull, V(1.28, 1.83, 0.17), F.enamel, metal)
	F.rod(lift, "Switch spindle", pull * V(-0.31, -0.35, -0.08), pull * V(0.31, -0.35, -0.08), 0.26, F.brass, metal)
	local lever = F.rod(
		lift,
		"Porcelain switch",
		pull * V(0, -0.35, -0.16),
		pull * V(0, 0.29, -0.57),
		0.19,
		F.paper,
		Enum.Material.CeramicTiles
	)
	local rest = lever.CFrame
	F.plate(F.part(switch, "Switch plate", pull * C(0, 0.65, -0.12), V(1.18, 0.27, 0.05), F.iron, metal), "LIFT / MAIN")
	local base = lift.CFrame * C(4.8, 0, 1.5) * CFrame.Angles(0, math.rad(140), 0)
	local model = Instance.new("Model")
	model.Name = "Blackpine lift recorder"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = vault
	F.part(model, "Pedestal", base * C(0, -1.17, 0), V(1.3, 2.6, 0.83), F.iron, Enum.Material.CorrodedMetal)
	F.part(model, "Plinth", base * C(0, -2.37, 0), V(2.1, 0.25, 1.55), F.iron, Enum.Material.DiamondPlate)
	F.part(model, "Enamel housing", base, V(3.65, 2.55, 0.9), F.enamel, metal)
	local chart = base * C(0, 0, -0.51)
	F.part(model, "Recorder paper", chart, V(2.64, 1.38, 0.06), F.paper, Enum.Material.SmoothPlastic)
	for _, x in { -1.43, 1.43 } do
		F.rod(model, "Take-up drum", chart * V(x, -0.79, -0.05), chart * V(x, 0.79, -0.05), 0.23, F.brass, metal)
	end
	for i = -4, 4 do
		F.part(
			model,
			"Ruled stock",
			chart * C(i * 0.26, 0, -0.034),
			V(0.014, 1.34, 0.012),
			Color3.fromRGB(174, 157, 120),
			Enum.Material.SmoothPlastic
		)
	end
	local label = F.part(model, "Maker's plate", base * C(0, 0.99, -0.48), V(3.14, 0.35, 0.06), F.iron, metal)
	F.plate(label, "B.P.  /  LIFT LOAD RECORDER")
	local pen = F.part(model, "Brass stylus", chart, V(0.045, 0.49, 0.06), F.brass, metal)
	local marks: { BasePart } = {}
	local tips: { CFrame } = {}
	local previous = V(1.17, 0, -0.07)
	table.insert(tips, chart * C(previous + V(0, 0.245, -0.05)))
	for i, v in { 0, 0.02, -0.02, 0.03, 0.0, 0.43, -0.36, 0.28, -0.11, 0.12, 0.1, 0.11, 0.1 } do
		local nextPoint = V(1.17 - i * 0.18, v, -0.07)
		local ink = F.rod(
			model,
			"Oxide trace",
			chart * previous,
			chart * nextPoint,
			0.036,
			Color3.fromRGB(137, 52, 36),
			Enum.Material.SmoothPlastic
		)
		table.insert(marks, ink)
		table.insert(tips, chart * C(nextPoint + V(0, 0.245, -0.05)))
		previous = nextPoint
	end
	local pilot = F.part(model, "Relay pilot", base * C(0, -0.99, -0.47), V(0.32, 0.32, 0.19), F.iron, metal)
	pilot.Shape = Enum.PartType.Ball
	local glow = F.light(pilot, Color3.fromRGB(196, 222, 175), 9)
	local chatter = Instance.new("Sound")
	chatter.Name = "Chart escapement"
	chatter.SoundId = "rbxasset://sounds/action_jump_land.mp3"
	chatter.RollOffMinDistance = 4
	chatter.RollOffMaxDistance = 30
	chatter.Volume = 0.25
	chatter.PlaybackSpeed = 1.65
	chatter.Parent = pilot
	local epoch = 0
	local powered = false
	local function reset()
		epoch += 1
		powered = false
		lever.CFrame = rest
		for _, l in lamps do
			l.Enabled = false
		end
		for _, m in marks do
			m.Transparency = 1
		end
		pen.CFrame = tips[1]
		glow.Enabled = false
		pilot.Color = F.iron
		pilot.Material = metal
		chatter:Stop()
	end
	reset()
	return {
		open = function()
			local token = epoch
			task.spawn(function()
				for _, l in lamps do
					if token ~= epoch then
						return
					end
					l.Enabled = true
					task.wait(0.32)
				end
			end)
		end,
		power = function(): boolean
			if powered then
				return false
			end
			powered = true
			local pivot = pull * C(0, -0.35, -0.16)
			lever.CFrame = pivot * CFrame.Angles(math.rad(65), 0, 0) * pivot:ToObjectSpace(rest)
			local token = epoch
			glow.Enabled = true
			pilot.Color = glow.Color
			pilot.Material = Enum.Material.Neon
			task.spawn(function()
				for i, m in marks do
					if epoch ~= token then
						return
					end
					if i == 1 or i == 6 or i == 9 then
						chatter:Play()
					end
					m.Transparency = 0
					pen.CFrame = tips[i + 1]
					task.wait(0.10)
				end
			end)
			return true
		end,
		reset = reset,
	}
end

return SurveyRelay
