--!strict
local Fittings = require(script.Parent.Fittings)

local TrailMarkers = {}
local amber = Color3.fromRGB(245, 189, 103)
local iron = Fittings.iron

function TrailMarkers.install(opening: Model, start: SpawnLocation)
	local wood = opening:FindFirstChild("Blackpine Wood")
	if not wood then
		return
	end
	local stakes: { BasePart } = {}
	for _, child in wood:GetChildren() do
		if child.Name == "Survey stake" and child:IsA("BasePart") then
			table.insert(stakes, child)
		end
	end
	table.sort(stakes, function(a, b)
		return (a.Position - start.Position).Magnitude < (b.Position - start.Position).Magnitude
	end)
	local first = stakes[1]
	if not first then
		return
	end
	local trail = first.Position - start.Position
	local heading = Vector3.new(trail.X, 0, trail.Z)
	if heading.Magnitude > 0.1 then
		start.CFrame = CFrame.lookAt(start.Position, start.Position + heading)
	end

	local approach = start.Position
	for i, stake in stakes do
		local position = stake.Position + Vector3.yAxis * (stake.Size.Y / 2)
		local toward = approach - position
		local direction = Vector3.new(toward.X, 0, toward.Z)
		approach = position
		if direction.Magnitude < 0.1 then
			continue
		end
		local frame = CFrame.lookAt(position, position + direction)
		Fittings.part(
			stake,
			"Rain hood",
			frame * CFrame.new(0, 0.14, -0.02),
			Vector3.new(0.68, 0.13, 0.58),
			iron,
			Enum.Material.CorrodedMetal
		)
		local lens = Fittings.part(
			stake,
			"Amber trail lens",
			frame * CFrame.new(0, -0.03, -0.2),
			Vector3.new(0.31, 0.25, 0.14),
			amber,
			Enum.Material.Neon
		)
		local light = Fittings.light(lens, amber, 8)
		light.Brightness = 0.65
		light.Enabled = true
		if i == 1 then
			local plate = Fittings.part(
				stake,
				"Cottage direction plate",
				frame * CFrame.new(0, -0.62, -0.24),
				Vector3.new(3.5, 0.53, 0.08),
				Fittings.enamel,
				Enum.Material.Metal
			)
			Fittings.plate(plate, "WARDEN’S COTTAGE")
		end
	end
end

return TrailMarkers
