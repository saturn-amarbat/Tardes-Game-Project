--!strict
local TweenService = game:GetService("TweenService")
local F = require(script.Parent.Fittings)
local V = Vector3.new
local C = CFrame.new
local metal = Enum.Material.Metal
local CottageHardware = {}

local function makeKey(key: BasePart)
	local model = Instance.new("Model")
	model.Name = "WardenKey"
	model.Parent = key
	local frame = key.CFrame * C(0, key.Size.Y / 2, 0)
	local function rod(a: Vector3, b: Vector3, d: number)
		F.rod(model, "Cast brass", frame * a, frame * b, d, F.brass, metal)
	end
	for i = 0, 11 do
		local a, b = i * math.pi / 6, (i + 1) * math.pi / 6
		rod(
			V(-0.43 + 0.27 * math.cos(a), 0, 0.21 * math.sin(a)),
			V(-0.43 + 0.27 * math.cos(b), 0, 0.21 * math.sin(b)),
			0.09
		)
	end
	rod(V(-0.19, 0, 0), V(0.7, 0, 0), 0.11)
	for i = 0, 2 do
		F.part(
			model,
			"Key ward",
			frame * C(0.37 + i * 0.13, 0, 0.08),
			V(0.075, 0.09, 0.18 + i % 2 * 0.12),
			F.brass,
			metal
		)
	end
	key.Transparency = 1
	return model
end

-- Draw cut ends, nail pairs and broken grain directly on the four floor panels.
-- The underlying wood remains visible in the gaps and under the translucent ink.
local function floorBoards(panel: BasePart)
	panel.Material = Enum.Material.Wood
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Pine floor wear"
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(math.round(panel.Size.X * 24), math.round(panel.Size.Z * 24))
	gui.LightInfluence = 1
	gui.MaxDistance = 32
	gui.Parent = panel
	local w, h = gui.CanvasSize.X, gui.CanvasSize.Y
	local function mark(x: number, y: number, width: number, height: number, opacity: number, rotation: number)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(45, 32, 23)
		f.BackgroundTransparency = 1 - opacity
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(width, height)
		f.Rotation = rotation
		f.Parent = gui
	end
	local rows = math.max(1, math.floor(h / 26))
	for row = 0, rows - 1 do
		local y = math.floor(row * h / rows)
		mark(0, y, w, 1, 0.55, 0)
		local joint = math.floor(w * (0.22 + ((row * 7) % 11) * 0.051))
		mark(joint, y, 2, math.floor(h / rows), 0.65, 0)
		for _, dx in { -5, 5 } do
			mark(joint + dx, y + 4, 2, 2, 0.74, 0)
		end
		local length = math.min(46, w / 3)
		local x = math.floor(((row * 37 + 17) % 100) / 100 * (w - length))
		mark(x, y + 12, length, 1, 0.27, 2)
		mark(x + length * 0.2, y + 14, length * 0.6, 1, 0.22, -3)
	end
end

function CottageHardware.install(cabin: Model, key: BasePart, hatch: BasePart)
	local keyModel = makeKey(key)
	local lid = Instance.new("Model")
	lid.Name = "Counterweighted pine hatch"
	lid.Parent = hatch
	local sx, sz = hatch.Size.X, hatch.Size.Z
	local hinge = hatch.CFrame * C(0, hatch.Size.Y / 2, sz / 2)
	lid.WorldPivot = hinge
	local face = hinge * C(0, 0, -sz / 2)
	local pine = Color3.fromRGB(106, 77, 52)
	for i = 0, 5 do
		local board = F.part(
			lid,
			"Adzed pine",
			face * C((i - 2.5) * sx / 6, 0, 0),
			V(sx / 6 - 0.035, 0.16, sz - 0.05),
			pine:Lerp(F.brass, (i * 7 % 5) * 0.045),
			Enum.Material.Wood
		)
		-- A dark knot and two tapered grain checks sit flush with the cut face.
		local knot = board.CFrame * C(0, 0.084, (i * 0.71 % 2.3) - 1.1)
		local plug =
			F.part(lid, "End check", knot, V(0.16, 0.015, 0.36), Color3.fromRGB(76, 53, 38), Enum.Material.Wood)
		plug.Shape = Enum.PartType.Ball
		for _, side in { -1, 1 } do
			F.rod(
				lid,
				"Grain split",
				knot * V(0, 0, side * 0.13),
				knot * V(0.06, 0, side * (0.48 + i % 3 * 0.17)),
				0.021,
				plug.Color,
				Enum.Material.Wood
			)
		end
	end
	for _, side in { -1, 1 } do
		local strap = hinge * C(side * sx * 0.32, 0.11, -0.9)
		F.part(lid, "Forged strap", strap, V(0.28, 0.07, 1.75), F.iron, Enum.Material.CorrodedMetal)
		F.rod(lid, "Hinge knuckle", strap * V(-0.25, 0, 0.86), strap * V(0.25, 0, 0.86), 0.23, F.brass, metal)
		for _, z in { -0.62, 0.47 } do
			F.rod(lid, "Rivet head", strap * V(0, 0.02, z), strap * V(0, 0.09, z), 0.12, F.brass, metal)
		end
	end
	local pull = face * C(0, 0.12, -sz * 0.32)
	F.part(lid, "Escutcheon", pull, V(1.15, 0.08, 0.58), F.iron, metal)
	for i = 0, 7 do
		local a, b = i * math.pi / 8, (i + 1) * math.pi / 8
		F.rod(
			lid,
			"Bail handle",
			pull * V(0.43 * math.cos(a), 0.32 * math.sin(a), 0),
			pull * V(0.43 * math.cos(b), 0.32 * math.sin(b), 0),
			0.11,
			F.brass,
			metal
		)
	end
	-- The cabinets face the aisle on their +X side.
	for _, p in cabin:GetChildren() do
		if p.Name == "Floor joists" and p:IsA("BasePart") then
			floorBoards(p)
		end
		if p.Name == "Kitchen cabinet" and p:IsA("BasePart") then
			local door = p.CFrame * C(p.Size.X / 2 + 0.03, 0, 0)
			F.part(p, "Inset oak panel", door, V(0.08, 2.63, 2.38), pine, Enum.Material.WoodPlanks)
			for _, z in { -1.03, 1.03 } do
				F.part(p, "Door stile", door * C(0.06, 0, z), V(0.12, 2.75, 0.22), pine, Enum.Material.Wood)
			end
			F.rod(p, "Turned pull", door * V(0.06, 0.86, 0.68), door * V(0.29, 0.86, 0.68), 0.23, F.brass, metal)
		end
	end
	local angle = Instance.new("NumberValue")
	angle.Changed:Connect(function(value: number)
		lid:PivotTo(hinge * CFrame.Angles(value, 0, 0))
	end)
	local swing = TweenService:Create(
		angle,
		TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = math.rad(85) }
	)
	return {
		takeKey = function()
			keyModel.Parent = nil
		end,
		open = function()
			swing:Play()
		end,
		reset = function()
			swing:Cancel()
			angle.Value = 0
			keyModel.Parent = key
		end,
	}
end

return CottageHardware
