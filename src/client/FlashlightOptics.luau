--!strict
local FlashlightOptics = {}

local HOTSPOT = {
	angle = 21,
	range = 49,
	brightness = 3.4,
	color = Color3.fromRGB(255, 204, 128),
}
local SPILL = {
	angle = 36,
	range = 30,
	brightness = 0.58,
	color = Color3.fromRGB(230, 156, 76),
}

type Profile = typeof(HOTSPOT)

local function spotlight(parent: BasePart, name: string, profile: Profile, shadows: boolean): SpotLight
	local light = Instance.new("SpotLight")
	light.Name = name
	light.Angle = profile.angle
	light.Range = profile.range
	light.Brightness = profile.brightness
	light.Color = profile.color
	light.Face = Enum.NormalId.Front
	light.Shadows = shadows
	light.Enabled = false
	light.Parent = parent
	return light
end

function FlashlightOptics.localBeam(parent: BasePart): (SpotLight, SpotLight)
	local hotspot = spotlight(parent, "PrimaryCone", HOTSPOT, true)
	local spill = spotlight(parent, "WarmSpill", SPILL, true)
	return hotspot, spill
end

function FlashlightOptics.replica(parent: BasePart): SpotLight
	return spotlight(parent, "ReplicaFlashlight", HOTSPOT, false)
end

function FlashlightOptics.setIntensity(hotspot: SpotLight?, spill: SpotLight?, intensity: number)
	if hotspot then
		hotspot.Brightness = HOTSPOT.brightness * intensity
	end
	if spill then
		spill.Brightness = SPILL.brightness * intensity
	end
end

function FlashlightOptics.setTint(hotspot: SpotLight?, spill: SpotLight?, hotspotColor: Color3, spillColor: Color3)
	if hotspot then
		hotspot.Color = hotspotColor
	end
	if spill then
		spill.Color = spillColor
	end
end

return FlashlightOptics
