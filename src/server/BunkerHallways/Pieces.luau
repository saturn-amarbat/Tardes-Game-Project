--!strict
local Config = require(script.Parent.Config)
local Pieces = {}
local concrete = Color3.fromRGB(76, 76, 70)
local rust = Color3.fromRGB(102, 77, 62)
local lampColor = Color3.fromRGB(206, 200, 166)
local sizes = {
	Straight = Vector2.new(14, 28),
	Corner = Vector2.new(14, 14),
	Junction = Vector2.new(14, 14),
	Cap = Vector2.new(14, 8),
	DoorFrame = Vector2.new(12, 4),
	Room = Vector2.new(26, 24),
}

local function part(
	m: Model,
	name: string,
	size: Vector3,
	position: Vector3,
	material: Enum.Material,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end
local function marker(m: Model, name: string, pos: Vector3, outward: Vector3): Part
	local p = part(m, name, Vector3.one * 0.25, pos, Enum.Material.SmoothPlastic, concrete)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p.CFrame = CFrame.lookAt(pos, pos + outward)
	return p
end

local function perimeter(m: Model, outward: Vector3, length: number, depth: number, opening: boolean)
	local tangent = Vector3.new(outward.Z, 0, -outward.X)
	local function slab(width: number, height: number, lateral: number, y: number)
		local center = outward * (depth / 2 - 0.25) + tangent * lateral + Vector3.yAxis * y
		local side = if outward.X == 0 then Vector3.new(width, height, 0.5) else Vector3.new(0.5, height, width)
		part(m, "Bulkhead", side, center, Enum.Material.Concrete, concrete)
	end
	if opening then
		local flank = (length - Config.Doorway.X) / 2
		for _, sign in { -1, 1 } do
			slab(flank, Config.Height, sign * (length - flank) / 2, Config.Height / 2)
		end
		local lintel = Config.Height - Config.Doorway.Y
		slab(Config.Doorway.X, lintel, 0, Config.Doorway.Y + lintel / 2)
	else
		slab(length, Config.Height, 0, Config.Height / 2)
	end
end

local function fixture(m: Model, spot: boolean, flicker: boolean)
	local p = part(m, "Lamp", Vector3.new(3, 0.25, 1), Vector3.new(0, 11.7, 0), Enum.Material.Neon, lampColor)
	local light = if spot then Instance.new("SpotLight") else Instance.new("PointLight")
	if light:IsA("SpotLight") then
		light.Face = Enum.NormalId.Bottom
		light.Angle = 72
	end
	light.Range = if spot then 22 else 27
	light.Brightness = 1.6
	light.Color = lampColor
	light.Shadows = false
	light.Parent = p
	if flicker then
		m:SetAttribute("Flickering", true)
	end
end

function Pieces.make(kind: string, name: string, side: number, flicker: boolean): Model
	local dim = sizes[kind]
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.WorldPivot = CFrame.identity
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Width", dim.X)
	m:SetAttribute("Depth", dim.Y)
	local forward, right = -Vector3.zAxis, Vector3.xAxis * side
	local through = kind == "Straight" or kind == "Junction" or kind == "DoorFrame"
	local branch = kind == "Corner" or kind == "Junction"
	part(
		m,
		"Floor",
		Vector3.new(dim.X, 1, dim.Y),
		Vector3.new(0, -0.5, 0),
		Enum.Material.Concrete,
		Color3.fromRGB(91, 87, 77)
	)
	part(m, "Ceiling", Vector3.new(dim.X, 0.5, dim.Y), Vector3.new(0, 12.25, 0), Enum.Material.CorrodedMetal, rust)
	perimeter(m, -forward, dim.X, dim.Y, true)
	perimeter(m, forward, dim.X, dim.Y, through)
	perimeter(m, right, dim.Y, dim.X, branch)
	perimeter(m, -right, dim.Y, dim.X, false)
	marker(m, "Entrance", -forward * dim.Y / 2, -forward)
	if kind == "Corner" then
		marker(m, "Exit", right * dim.X / 2, right)
	else
		marker(m, "Exit", forward * dim.Y / 2, forward)
	end
	if kind == "Junction" then
		marker(m, "Branch", right * dim.X / 2, right)
	end
	if kind == "Room" then
		marker(m, "Door", -forward * dim.Y / 2, -forward)
		if name == "Abandoned Room" then
			part(m, "Chair seat", Vector3.new(3, 0.45, 3), Vector3.new(-6, 1.8, -4), Enum.Material.Wood, rust)
			part(m, "Chair back", Vector3.new(3, 3, 0.4), Vector3.new(-6, 3, -5.3), Enum.Material.Wood, rust)
			part(m, "Table top", Vector3.new(5, 0.5, 3), Vector3.new(5, 3, -5), Enum.Material.Wood, rust)
			for _, x in { -1, 1 } do
				for _, z in { -1, 1 } do
					part(
						m,
						"Chair leg",
						Vector3.new(0.4, 1.6, 0.4),
						Vector3.new(-6 + x, 0.8, -4 + z),
						Enum.Material.Wood,
						rust
					)
					part(
						m,
						"Table leg",
						Vector3.new(0.5, 2.8, 0.5),
						Vector3.new(5 + 2 * x, 1.4, -5 + z),
						Enum.Material.Wood,
						rust
					)
				end
			end
			local mirror = part(
				m,
				"Clouded mirror",
				Vector3.new(6, 6, 0.3),
				Vector3.new(0, 5, -11.4),
				Enum.Material.Glass,
				Color3.fromRGB(64, 72, 68)
			)
			mirror.Reflectance = 0.32
		elseif name == "Model Room" then
			part(m, "Pedestal", Vector3.new(5, 2, 5), Vector3.new(0, 1, 0), Enum.Material.Slate, concrete)
			marker(m, "ModelSlot", Vector3.new(0, 2, 0), forward)
		end
	end
	if kind ~= "Cap" and kind ~= "DoorFrame" then
		fixture(m, name == "Model Room", flicker)
	end
	-- A painted strip below eye level remains readable without dynamic shadows.
	part(
		m,
		"Guide stripe",
		Vector3.new(0.12, 0.35, dim.Y / 3),
		Vector3.new(-dim.X / 2 + 0.55, 2, -dim.Y / 3),
		Enum.Material.Neon,
		Color3.fromRGB(103, 121, 110)
	).CanCollide =
		false
	return m
end
return Pieces
