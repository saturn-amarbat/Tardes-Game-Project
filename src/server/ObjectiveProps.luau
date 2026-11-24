--!strict
local Instruments = require(script.Parent.SurveyInstruments)
local ObjectiveProps = {}

local brass = Color3.fromRGB(179, 134, 70)
local iron = Color3.fromRGB(48, 58, 54)
local ceramic = Color3.fromRGB(199, 217, 199)
local copper = Color3.fromRGB(151, 84, 50)
local metal = Enum.Material.Metal

local function cylinder(
	parent: Folder,
	name: string,
	frame: CFrame,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material
)
	local part = Instruments.part(parent, name, frame, Vector3.new(length, diameter, diameter), color, material)
	part.Shape = Enum.PartType.Cylinder
end

function ObjectiveProps.mount(anchor: BasePart, isKey: boolean): Folder
	local pickup = Instance.new("Folder")
	pickup.Name = "Pickup"
	local face = anchor.CFrame
	Instruments.part(
		pickup,
		"Enamel clip plate",
		face * CFrame.new(0, 0, 0.155),
		Vector3.new(0.84, 0.69, 0.06),
		iron,
		Enum.Material.CorrodedMetal
	)
	for _, x in { -0.35, 0.35 } do
		cylinder(
			pickup,
			"Rivet",
			face * CFrame.new(x, 0.24, 0.108) * CFrame.Angles(0, math.pi / 2, 0),
			0.045,
			0.066,
			brass,
			metal
		)
	end
	if isKey then
		-- Open bow, narrow shaft and stepped wards read as a key in silhouette.
		for i = 0, 9 do
			local a = i * math.pi / 5
			local b = (i + 1) * math.pi / 5
			local first = Vector3.new(-0.25 + math.cos(a) * 0.145, math.sin(a) * 0.145, 0)
			local last = Vector3.new(-0.25 + math.cos(b) * 0.145, math.sin(b) * 0.145, 0)
			local direction = last - first
			local frame = face
				* CFrame.new((first + last) / 2)
				* CFrame.Angles(0, 0, math.atan2(direction.Y, direction.X))
			cylinder(pickup, "Cast bow", frame, direction.Magnitude + 0.035, 0.065, brass, metal)
		end
		cylinder(pickup, "Key shaft", face * CFrame.new(0.105, 0, 0), 0.48, 0.085, brass, metal)
		for i, height in { 0.14, 0.21, 0.12 } do
			Instruments.part(
				pickup,
				"Key ward",
				face * CFrame.new(0.16 + 0.07 * i, -height / 2, 0),
				Vector3.new(0.05, height, 0.08),
				brass,
				metal
			)
		end
	else
		local vertical = face * CFrame.Angles(0, 0, math.pi / 2)
		cylinder(pickup, "Porcelain cartridge", vertical, 0.40, 0.23, ceramic, Enum.Material.CeramicTiles)
		cylinder(pickup, "Rating band", vertical, 0.065, 0.24, iron, metal)
		for _, y in { -0.23, 0.23 } do
			cylinder(
				pickup,
				"Copper ferrule",
				face * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2),
				0.11,
				0.26,
				copper,
				metal
			)
		end
	end
	local lens = Instruments.part(
		pickup,
		"Locator lens",
		face * CFrame.new(0, -0.32, 0),
		Vector3.new(0.19, 0.038, 0.07),
		brass,
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(236, 188, 109)
	light.Brightness = 0.42
	light.Range = 4
	light.Parent = lens
	pickup.Parent = anchor
	return pickup
end

return ObjectiveProps
