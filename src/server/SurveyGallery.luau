--!strict
local Workspace = game:GetService("Workspace")
local Instruments = require(script.Parent.SurveyInstruments)

local SurveyGallery = {}
local steel = Color3.fromRGB(62, 73, 69)
local enamel = Color3.fromRGB(131, 145, 127)
local amber = Color3.fromRGB(246, 196, 116)
local opal = Color3.fromRGB(180, 210, 196)
local up = Vector3.yAxis

type Bay = { floor: Vector3, left: RaycastResult?, right: RaycastResult?, height: number }

local function findBay(room: Model, entrance: BasePart): Bay?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { room }
	params.RespectCanCollide = true

	-- Sample only this clone. The reverse direction supports older, flipped entrance anchors.
	for _, depth in { 6, -6, 3.5, -3.5 } do
		local probe = entrance.Position + entrance.CFrame.LookVector * depth
		local floor = Workspace:Raycast(probe + up, -up * (entrance.Size.Y + 4), params)
		if not floor or floor.Normal.Y < 0.85 then
			continue
		end
		local origin = floor.Position + up * 3.9
		local ceiling = Workspace:Raycast(origin, up * 12, params)
		local height = if ceiling then math.min(10, ceiling.Position.Y - floor.Position.Y - 0.2) else 8.8
		if height < 6.8 then
			continue
		end
		local function wall(side: number): RaycastResult?
			local direction = entrance.CFrame.RightVector * side
			local hit = Workspace:Raycast(origin, direction * 17, params)
			if hit and hit.Distance >= 3.4 and math.abs(hit.Normal.Y) < 0.08 and hit.Normal:Dot(direction) < -0.9 then
				return hit
			end
			return nil
		end
		local left, right = wall(-1), wall(1)
		if left or right then
			return { floor = floor.Position, left = left, right = right, height = height }
		end
	end
	return nil
end

local function brace(parent: Folder, name: string, a: Vector3, b: Vector3, width: number, thickness: number)
	local frame = CFrame.lookAt((a + b) / 2, b)
	Instruments.part(
		parent,
		name,
		frame,
		Vector3.new(width, thickness, (b - a).Magnitude),
		steel,
		Enum.Material.CorrodedMetal
	)
end

local function lintel(folder: Folder, a: Vector3, b: Vector3, section: number)
	local frame = CFrame.lookAt((a + b) / 2, b)
	local span = (b - a).Magnitude
	if section == 1 then
		Instruments.part(
			folder,
			"PortalLintel",
			frame,
			Vector3.new(0.6, 0.37, span),
			Color3.fromRGB(106, 79, 59),
			Enum.Material.WoodPlanks
		)
		for _, offset in { -0.36, 0.36 } do
			Instruments.part(
				folder,
				"IronShoe",
				frame * CFrame.new(0, 0, span * offset),
				Vector3.new(0.68, 0.42, 0.22),
				steel,
				Enum.Material.Metal
			)
		end
	elseif section == 2 then
		brace(folder, "PortalLintel", a, b, 0.46, 0.22)
		local rail = frame.RightVector * 0.65 - up * 0.2
		brace(folder, "CableReturn", a + rail, b + rail, 0.14, 0.14)
		for _, offset in { -0.32, 0, 0.32 } do
			Instruments.part(
				folder,
				"CeramicBridge",
				frame * CFrame.new(0.33, -0.09, span * offset),
				Vector3.new(0.77, 0.23, 0.17),
				enamel,
				Enum.Material.CeramicTiles
			)
		end
	else
		local seam = a:Lerp(b, 0.54)
		local step = up * 0.45
		brace(folder, "PortalLintel", a, seam, 0.52, 0.24)
		brace(folder, "DisplacedLintel", seam - step, b - step, 0.52, 0.24)
		Instruments.part(
			folder,
			"SplicePlate",
			CFrame.new(seam - step / 2) * frame.Rotation,
			Vector3.new(0.55, 0.67, 0.3),
			enamel,
			Enum.Material.DiamondPlate
		)
	end
end

local function dress(room: Model, index: number, count: number)
	if room:GetAttribute("SurveyDressing") == false or room:FindFirstChild("SurveyGallery") then
		return
	end
	local entrance = room:FindFirstChild("Entrance")
	if not entrance or not entrance:IsA("BasePart") then
		return
	end
	local mount = room:FindFirstChild("SurveyMount", true)
	local authored = if mount and mount:IsA("Attachment") then mount.WorldCFrame else nil
	local bay = findBay(room, entrance)
	if not bay and not authored then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "SurveyGallery"
	local section = Instruments.section(index, count)
	if bay then
		local y = bay.floor.Y
		local h = bay.height
		for _, hit in { bay.left, bay.right } do
			if not hit then
				continue
			end
			local base = Vector3.new(hit.Position.X, y, hit.Position.Z) + hit.Normal * 0.14
			local frame = CFrame.lookAt(base, base + hit.Normal)
			Instruments.part(
				folder,
				"FlangedUpright",
				frame * CFrame.new(0, h / 2, 0),
				Vector3.new(0.44, h, 0.26),
				steel,
				Enum.Material.CorrodedMetal
			)
			Instruments.part(
				folder,
				"SurveyDatumBand",
				frame * CFrame.new(0, 1.35, -0.09),
				Vector3.new(0.5, 0.18, 0.23),
				enamel,
				Enum.Material.Metal
			)
			brace(folder, "Haunch", base + up * (h - 1.05), base + up * h + hit.Normal * 1.15, 0.32, 0.22)
		end
		local left, right = bay.left, bay.right
		if left and right then
			local a = Vector3.new(left.Position.X, y + h, left.Position.Z)
			local b = Vector3.new(right.Position.X, y + h, right.Position.Z)
			lintel(folder, a, b, section)
		end
		local wall = (if index % 2 == 0 then right else left) or left or right
		if wall and not authored then
			local pos = wall.Position + wall.Normal * 0.33
			authored = CFrame.lookAt(pos, pos + wall.Normal)
		end
	end
	if authored then
		Instruments.mount(folder, authored, index, count)
		local hood = Instruments.part(
			folder,
			"InspectionHood",
			authored * CFrame.new(0, 1.62, -0.24),
			Vector3.new(1.75, 0.2, 0.64),
			steel,
			Enum.Material.Metal
		)
		local tint = if section == 1 then amber else opal
		local lens = Instruments.part(
			folder,
			"OpalLens",
			hood.CFrame * CFrame.new(0, -0.12, -0.03),
			Vector3.new(1.28, 0.08, 0.33),
			tint,
			Enum.Material.Neon
		)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = 120
		light.Brightness = 0.75
		light.Range = 7
		light.Shadows = false
		light.Color = tint
		light.Parent = lens
	end
	folder.Parent = room
end

function SurveyGallery.install(rooms: { Model })
	for index, room in rooms do
		dress(room, index, #rooms)
	end
end

return SurveyGallery
