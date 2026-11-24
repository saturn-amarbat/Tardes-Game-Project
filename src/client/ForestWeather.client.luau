--!strict
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

-- A single local atmosphere covers the whole wood. Restore the place lighting
-- below the cellar and outside the opening so the procedural rooms keep their look.
local fog = Instance.new("Atmosphere")
fog.Name = "BlackpineMist"
fog.Density = 0.55
fog.Offset = 0.08
fog.Color = Color3.fromRGB(134, 144, 143)
fog.Decay = Color3.fromRGB(55, 62, 66)
fog.Haze = 2.5
local previous: Atmosphere? = nil
local active = false
local originalExposure = 0

local function leaveForest()
	fog.Parent = nil
	if previous then
		previous.Parent = Lighting
	end
	Lighting.ExposureCompensation = originalExposure
	active = false
end

script.Destroying:Connect(function()
	if active then
		leaveForest()
	end
	fog:Destroy()
end)
while true do
	local camera = Workspace.CurrentCamera
	if camera then
		local p = camera.CFrame.Position
		local inside = math.abs(p.X) < 154 and math.abs(p.Z + 172) < 147 and p.Y > 78
		if inside and not active then
			previous = Lighting:FindFirstChildOfClass("Atmosphere")
			originalExposure = Lighting.ExposureCompensation
			if previous then
				previous.Parent = nil
			end
			fog.Parent = Lighting
			Lighting.ExposureCompensation = originalExposure - 0.75
			active = true
		elseif active and not inside then
			leaveForest()
		end
	end
	task.wait(0.4)
end
