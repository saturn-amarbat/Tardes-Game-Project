--!strict
local Workspace = game:GetService("Workspace")
local Instruments = require(script.Parent.SurveyInstruments)

local MaintenanceBay = {}
local steel = Color3.fromRGB(54, 62, 59)
local enamel = Color3.fromRGB(57, 88, 77)
local brass = Color3.fromRGB(167, 119, 62)
local amber = Color3.fromRGB(252, 201, 126)
local metal = Enum.Material.Metal

local function supported(frame: CFrame, floor: Vector3, ray: RaycastParams): boolean
	for _, x in { -2.05, 2.05 } do
		local ahead = frame * Vector3.new(x, 3, -0.4)
		local wall = Workspace:Raycast(ahead, -frame.LookVector * 0.65, ray)
		if not wall or math.abs(wall.Distance - 0.4) > 0.09 then
			return false
		end
		local foot = frame * Vector3.new(x, 0.45, -1.64)
		local ground = Workspace:Raycast(foot, -Vector3.yAxis, ray)
		if not ground or math.abs(ground.Position.Y - floor.Y) > 0.07 or ground.Normal.Y < 0.92 then
			return false
		end
	end
	return true
end

local function findWall(room: Model, entrance: BasePart): CFrame?
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { room }
	ray.RespectCanCollide = true

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { room }
	overlap.RespectCanCollide = true

	-- Probe inward first. Older templates can have their doorway rotated.
	for _, depth in { -6, -9, 6, 9 } do
		local probe = entrance.Position + entrance.CFrame.LookVector * depth
		local floor = Workspace:Raycast(probe + Vector3.yAxis, -Vector3.yAxis * 14, ray)
		if not floor or floor.Normal.Y < 0.92 then
			continue
		end
		for _, side in { -1, 1 } do
			local direction = entrance.CFrame.RightVector * side
			local hit = Workspace:Raycast(floor.Position + Vector3.yAxis * 3, direction * 14, ray)
			if not hit or hit.Distance < 4.1 or math.abs(hit.Normal.Y) > 0.05 or hit.Normal:Dot(direction) > -0.95 then
				continue
			end
			local base = Vector3.new(hit.Position.X, floor.Position.Y, hit.Position.Z)
			local frame = CFrame.lookAt(base, base - direction)
			-- Test the full footprint on the walkway side before dressing it.
			local volume = frame * CFrame.new(0, 2.6, -1.12)
			if
				#Workspace:GetPartBoundsInBox(volume, Vector3.new(4.8, 5.1, 2.04), overlap) == 0
				and supported(frame, floor.Position, ray)
			then
				return frame
			end
		end
	end
	return nil
end

local function sign(folder: Folder, frame: CFrame, width: number, words: string)
	local plate = Instruments.part(folder, "Enamel sign", frame, Vector3.new(width, 0.43, 0.065), enamel, metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.5
	gui.MaxDistance = 42
	gui.CanvasSize = Vector2.new(384, 60)
	gui.Parent = plate

	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.fromScale(1, 1)
	caption.Font = Enum.Font.Code
	caption.TextSize = 32
	caption.TextColor3 = Color3.fromRGB(236, 221, 181)
	caption.Text = words
	caption.Parent = gui
end

local function buildBench(folder: Folder, frame: CFrame)
	local function part(
		name: string,
		x: number,
		y: number,
		z: number,
		size: Vector3,
		color: Color3,
		material: Enum.Material
	): Part
		return Instruments.part(folder, name, frame * CFrame.new(x, y, z), size, color, material)
	end

	for _, x in { -1.93, 1.93 } do
		for _, z in { -0.27, -1.57 } do
			part("Cast bench leg", x, 1.34, z, Vector3.new(0.22, 2.68, 0.22), steel, Enum.Material.CorrodedMetal)
		end
	end
	part("Shelf tie", 0, 0.78, -0.7, Vector3.new(4.08, 0.18, 0.21), steel, metal)
	part("Apron", 0, 2.48, -1.57, Vector3.new(4.1, 0.35, 0.14), enamel, metal)
	part(
		"Dark oak worktop",
		0,
		2.76,
		-0.94,
		Vector3.new(4.35, 0.19, 1.77),
		Color3.fromRGB(104, 78, 54),
		Enum.Material.WoodPlanks
	)
	part("Fuse tray", 0, 2.89, -0.95, Vector3.new(1.67, 0.065, 0.79), enamel, metal)
	for _, x in { -0.8, 0.8 } do
		part("Tray lip", x, 2.97, -0.95, Vector3.new(0.065, 0.15, 0.79), brass, metal)
	end

	local socket = part("Fuse socket", 0, 3.24, -0.98, Vector3.new(0.1, 0.1, 0.1), steel, metal)
	socket.Transparency = 1

	part("Lamp hood", 0, 4.8, -0.65, Vector3.new(1.72, 0.23, 0.81), enamel, metal)
	local lens = part("Opal tube", 0, 4.6, -0.65, Vector3.new(1.4, 0.15, 0.32), amber, Enum.Material.Neon)
	for i = -2, 2 do
		part("Lamp cage rib", 0.3 * i, 4.48, -0.65, Vector3.new(0.052, 0.06, 0.73), steel, metal)
	end
	for _, z in { -0.98, -0.32 } do
		part("Lamp cage rail", 0, 4.48, z, Vector3.new(1.62, 0.06, 0.056), steel, metal)
	end
	local lamp = Instance.new("SurfaceLight")
	lamp.Face = Enum.NormalId.Bottom
	lamp.Brightness = 1.35
	lamp.Range = 10
	lamp.Angle = 125
	lamp.Color = amber
	lamp.Parent = lens

	sign(folder, frame * CFrame.new(0, 3.88, -0.14), 2.55, "LIFT MAINTENANCE")
end

function MaintenanceBay.install(room: Model?, hasNextRoom: boolean)
	if not room or room:GetAttribute("SurveyDressing") == false or room:FindFirstChild("MaintenanceBay") then
		return
	end
	local entrance, exit = room:FindFirstChild("Entrance"), room:FindFirstChild("Exit")
	if not entrance or not entrance:IsA("BasePart") or not exit or not exit:IsA("BasePart") then
		return
	end
	local frame = findWall(room, entrance)
	if not frame then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "MaintenanceBay"
	buildBench(folder, frame)

	-- Follow the wall toward the actual exit. Keep the run inside the tested bay.
	local side = if frame:PointToObjectSpace(exit.Position).X < 0 then -1 else 1
	Instruments.part(
		folder,
		"Conduit rise",
		frame * CFrame.new(0, 5.01, -0.3),
		Vector3.new(0.09, 0.23, 0.09),
		brass,
		metal
	)
	Instruments.part(
		folder,
		"Conduit run",
		frame * CFrame.new(side * 1.13, 5.1, -0.3),
		Vector3.new(2.26, 0.09, 0.09),
		brass,
		metal
	)
	local exitSign = exit.CFrame
		* CFrame.new(0, exit.Size.Y / 2 - 0.48, exit.Size.Z / 2 + 0.07)
		* CFrame.Angles(0, math.pi, 0)
	sign(folder, exitSign, math.min(3.2, exit.Size.X), if hasNextRoom then "LOWER GALLERIES" else "EXTRACTION")
	folder.Parent = room
end

return MaintenanceBay
