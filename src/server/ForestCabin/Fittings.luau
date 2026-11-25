--!strict
local Fittings = {}
Fittings.brass = Color3.fromRGB(164, 123, 66)
Fittings.iron = Color3.fromRGB(55, 62, 59)
Fittings.enamel = Color3.fromRGB(54, 85, 78)
Fittings.paper = Color3.fromRGB(217, 201, 156)

function Fittings.part(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Material = material
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

function Fittings.rod(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	diam: number,
	color: Color3,
	material: Enum.Material
): Part
	local axis = (b - a).Unit
	local normal = if math.abs(axis.Y) > 0.98 then Vector3.zAxis else Vector3.yAxis
	local tangent = axis:Cross(normal).Unit
	local p = Fittings.part(
		parent,
		name,
		CFrame.fromMatrix((a + b) / 2, axis, tangent, axis:Cross(tangent)),
		Vector3.new((b - a).Magnitude, diam, diam),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Fittings.plate(p: Part, words: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(480, 70)
	gui.LightInfluence = 0.8
	gui.MaxDistance = 52
	gui.Parent = p
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Code
	text.TextColor3 = Fittings.paper
	text.TextSize = 36
	text.Text = words
	text.Parent = gui
end

function Fittings.light(p: Part, color: Color3, range: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.15
	light.Range = range
	light.Enabled = false
	light.Parent = p
	return light
end

return Fittings
