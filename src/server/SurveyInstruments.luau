--!strict
-- Each instrument is built in wall-local coordinates. Front (-Z) faces the walkway.
local SurveyInstruments = {}

local iron = Color3.fromRGB(51, 61, 58)
local brass = Color3.fromRGB(166, 127, 69)
local enamel = Color3.fromRGB(50, 84, 78)
local paper = Color3.fromRGB(220, 207, 165)
local ink = Color3.fromRGB(47, 53, 46)
local red = Color3.fromRGB(144, 64, 45)
local timber = Color3.fromRGB(123, 83, 58)

function SurveyInstruments.part(
	parent: Folder,
	name: string,
	frame: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = parent
	return part
end

local function face(part: BasePart, width: number, height: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "InstrumentPrint"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(width, height)
	gui.LightInfluence = 0.8
	gui.MaxDistance = 42
	gui.Parent = part
	return gui
end

local function label(
	gui: SurfaceGui,
	words: string,
	x: number,
	y: number,
	w: number,
	h: number,
	size: number,
	color: Color3
)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(x, y)
	text.Size = UDim2.fromOffset(w, h)
	text.Font = Enum.Font.Code
	text.TextColor3 = color
	text.TextSize = size
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Text = words
	text.Parent = gui
end

local function rule(gui: SurfaceGui, x: number, y: number, dx: number, dy: number, thickness: number, color: Color3)
	local mark = Instance.new("Frame")
	mark.BorderSizePixel = 0
	mark.BackgroundColor3 = color
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromOffset(x + dx / 2, y + dy / 2)
	mark.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), thickness)
	mark.Rotation = math.deg(math.atan2(dy, dx))
	mark.Parent = gui
end

local function cylinder(
	parent: Folder,
	name: string,
	frame: CFrame,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material
)
	local part = SurveyInstruments.part(parent, name, frame, Vector3.new(length, diameter, diameter), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function coreRack(parent: Folder, frame: CFrame)
	for i = 0, 2 do
		local y = 0.57 - i * 0.58
		local length = 2.24 - i * 0.23
		local wood = timber:Lerp(paper, i * 0.16)
		cylinder(parent, "IncrementCore", frame * CFrame.new(-0.36, y, -0.32), length, 0.32, wood, Enum.Material.Wood)
		for _, x in { -0.96, 0.22 } do
			cylinder(parent, "SampleCollar", frame * CFrame.new(x, y, -0.32), 0.09, 0.37, brass, Enum.Material.Metal)
		end
		local tag = SurveyInstruments.part(
			parent,
			"CoreTag",
			frame * CFrame.new(1.28, y, -0.20),
			Vector3.new(0.72, 0.38, 0.06),
			paper,
			Enum.Material.SmoothPlastic
		)
		label(face(tag, 96, 48), ({ "A / 17", "B / 17", "C / 17" })[i + 1], 4, 0, 90, 48, 22, ink)
	end
end

-- The pen drops its baseline halfway across the strip, then resumes the same beat.
local function recorder(parent: Folder, frame: CFrame, roomIndex: number)
	local sheet = SurveyInstruments.part(
		parent,
		"RecorderStrip",
		frame * CFrame.new(0, 0, -0.23),
		Vector3.new(2.9, 1.48, 0.08),
		paper,
		Enum.Material.SmoothPlastic
	)
	local chart = face(sheet, 300, 152)
	for x = 20, 280, 20 do
		rule(chart, x, 38, 0, 96, 1, Color3.fromRGB(185, 171, 137))
	end
	for y = 48, 128, 20 do
		rule(chart, 10, y, 280, 0, 1, Color3.fromRGB(185, 171, 137))
	end
	label(chart, "BED MOVEMENT  /  04:17", 12, 2, 278, 30, 16, ink)
	local samples = { 0, 2, -1, 3, -2, 1, -4, 2, -1, -23, 18, -30, 17, 12, 18, 15, 19, 16, 18, 15, 19, 17, 16 }
	local x, y = 12, 76
	for i, sample in samples do
		local nx, ny = 12 + i * 12, 76 + sample + (if i > 11 then roomIndex else 0)
		rule(chart, x, y, nx - x, ny - y, 3, red)
		x, y = nx, ny
	end
	for _, side in { -1, 1 } do
		cylinder(
			parent,
			"PaperSpool",
			frame * CFrame.new(side * 1.57, 0, -0.35) * CFrame.Angles(0, 0, math.pi / 2),
			1.72,
			0.19,
			brass,
			Enum.Material.Metal
		)
	end
end

local function plumbFrame(parent: Folder, frame: CFrame)
	local board = SurveyInstruments.part(
		parent,
		"DatumScale",
		frame * CFrame.new(0, 0, -0.18),
		Vector3.new(3.4, 1.7, 0.07),
		paper,
		Enum.Material.SmoothPlastic
	)
	local scale = face(board, 340, 170)
	label(scale, "VERTICAL CONTROL", 10, 4, 260, 26, 16, ink)
	for i = 0, 16 do
		local x = 26 + i * 18
		rule(scale, x, 134, 0, if i % 4 == 0 then -26 else -12, 2, ink)
	end
	for i, angle in { -0.24, 0, 0.24 } do
		local x = (i - 2) * 0.94
		local pin = frame * CFrame.new(x, 0.83, -0.42) * CFrame.Angles(0, 0, angle)
		SurveyInstruments.part(
			parent,
			"SuspensionWire",
			pin * CFrame.new(0, -0.61, 0),
			Vector3.new(0.035, 1.22, 0.035),
			brass,
			Enum.Material.Metal
		)
		SurveyInstruments.part(
			parent,
			"PlumbBob",
			pin * CFrame.new(0, -1.32, 0) * CFrame.Angles(0, 0, math.pi / 4),
			Vector3.new(0.25, 0.25, 0.23),
			brass,
			Enum.Material.Metal
		)
	end
end

function SurveyInstruments.section(index: number, count: number): number
	return if index / count <= 0.34 then 1 elseif index / count <= 0.67 then 2 else 3
end

function SurveyInstruments.mount(parent: Folder, frame: CFrame, index: number, count: number)
	local section = SurveyInstruments.section(index, count)
	SurveyInstruments.part(parent, "EnamelCase", frame, Vector3.new(3.9, 2.55, 0.24), enamel, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		SurveyInstruments.part(
			parent,
			"EdgeBinding",
			frame * CFrame.new(1.94 * side, 0, -0.11),
			Vector3.new(0.09, 2.6, 0.2),
			iron,
			Enum.Material.DiamondPlate
		)
	end
	local title = ({ "CORE LIBRARY", "SUBSIDENCE WATCH", "PLUMB GALLERY" })[section]
	local plate = SurveyInstruments.part(
		parent,
		"StationPlate",
		frame * CFrame.new(0, 1.08, -0.16),
		Vector3.new(3.62, 0.28, 0.06),
		ink,
		Enum.Material.Metal
	)
	label(face(plate, 362, 28), string.format("BP / %02d    %s", index, title), 6, 0, 350, 28, 18, paper)
	if section == 1 then
		coreRack(parent, frame)
	elseif section == 2 then
		recorder(parent, frame, index)
	else
		plumbFrame(parent, frame)
	end
end

return SurveyInstruments
