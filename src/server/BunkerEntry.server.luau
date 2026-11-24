--!strict
local Workspace = game:GetService("Workspace")
local SquadFall = require(script.Parent.BunkerHallways.SquadFall)
local opening = Workspace:WaitForChild("ForestCabinOpening")
local cottage = opening:WaitForChild("Wardens Cottage")
local hatch = cottage:WaitForChild("CellarHatch") :: BasePart
local lift = opening:WaitForChild("Survey Vault"):WaitForChild("SurveyLift") :: BasePart
local descend = SquadFall.attach(hatch, lift)

-- The authored lid can swing open while the party waits on streaming.
local threshold = Instance.new("Part")
threshold.Name = "BunkerDescentThreshold"
threshold.Size = hatch.Size
threshold.CFrame = hatch.CFrame
threshold.Anchored = true
threshold.Transparency = 1
threshold.CanTouch = false
threshold.CanQuery = false
threshold.Parent = cottage

-- A character that spawned after the party left can follow the same route.
local follow = Instance.new("ProximityPrompt")
follow.ActionText = "Descend"
follow.ObjectText = "Open cellar"
follow.RequiresLineOfSight = false
follow.Enabled = false
follow.Parent = threshold
follow.Triggered:Connect(function(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		root
		and root:IsA("BasePart")
		and not hatch.CanCollide
		and (root.Position - threshold.Position).Magnitude <= 12
	then
		descend()
	end
end)

local function update()
	follow.Enabled = not hatch.CanCollide
	if follow.Enabled then
		descend()
	end
end
hatch:GetPropertyChangedSignal("CanCollide"):Connect(update)
update()
