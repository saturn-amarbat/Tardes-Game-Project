--!strict
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local terrain = Workspace.Terrain
local fog = Instance.new("Atmosphere")
fog.Name = "BlackpineMist"
fog.Density = 0.49
fog.Offset = 0.06
fog.Color = Color3.fromRGB(154, 163, 176)
fog.Decay = Color3.fromRGB(64, 70, 86)
fog.Haze = 3.2
fog.Glare = 0

local sky = Instance.new("Sky")
sky.Name = "BlackpineOvercast"
sky.CelestialBodiesShown = false
sky.StarCount = 0

local clouds = Instance.new("Clouds")
clouds.Name = "BlackpineCloudDeck"
clouds.Cover = 0.87
clouds.Density = 0.76
clouds.Color = Color3.fromRGB(132, 140, 155)

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "BlackpineDuskGrade"
grade.TintColor = Color3.fromRGB(226, 233, 250)
grade.Saturation = -0.18
grade.Contrast = 0.06

-- Suppress the authored sky components locally and put each back when the camera leaves.
local parked: { [Instance]: Instance } = {}
local active = false
local oldExposure = 0
local oldClockTime = 0

local function replace(parent: Instance, replacement: Instance)
	for _, child in parent:GetChildren() do
		if child.ClassName == replacement.ClassName and child ~= replacement then
			parked[child] = parent
			child.Parent = nil
		end
	end
	replacement.Parent = parent
end

local function enterForest()
	oldExposure = Lighting.ExposureCompensation
	oldClockTime = Lighting.ClockTime
	replace(Lighting, sky)
	replace(Lighting, fog)
	replace(terrain, clouds)
	grade.Parent = Lighting
	Lighting.ClockTime = 18.1
	Lighting.ExposureCompensation = oldExposure - 0.32
	active = true
end

local function leaveForest()
	fog.Parent = nil
	sky.Parent = nil
	clouds.Parent = nil
	grade.Parent = nil
	for child, parent in parked do
		child.Parent = parent
	end
	table.clear(parked)
	Lighting.ClockTime = oldClockTime
	Lighting.ExposureCompensation = oldExposure
	active = false
end

script.Destroying:Connect(function()
	if active then
		leaveForest()
	end
	fog:Destroy()
	sky:Destroy()
	clouds:Destroy()
	grade:Destroy()
end)

while true do
	local camera = Workspace.CurrentCamera
	if camera then
		local p = camera.CFrame.Position
		local inside = math.abs(p.X) < 154 and math.abs(p.Z + 172) < 147 and p.Y > 78
		if inside and not active then
			enterForest()
		elseif active and not inside then
			leaveForest()
		end
	end
	task.wait(0.2)
end
