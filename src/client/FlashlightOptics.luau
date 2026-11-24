--!strict
local FlashlightOptics = {}

export type BeamConfig = {
	CoreAngle: number,
	CoreBrightness: number,
	CoreRange: number,
	CoreColor: Color3,
	SpillAngle: number,
	SpillBrightness: number,
	SpillRange: number,
	SpillColor: Color3,
	BeamLength: number,
	BeamWidth0: number,
	BeamWidth1: number,
}

local DEFAULT_REPLICA = {
	angle = 36,
	range = 45,
	brightness = 2.6,
	color = Color3.fromRGB(255, 248, 235),
}

local function createSpot(
	parent: BasePart,
	name: string,
	angle: number,
	brightness: number,
	range: number,
	color: Color3,
	shadows: boolean
): SpotLight
	local light = Instance.new("SpotLight")
	light.Name = name
	light.Angle = angle
	light.Brightness = brightness
	light.Range = range
	light.Color = color
	light.Face = Enum.NormalId.Front
	light.Shadows = shadows
	light.Enabled = false
	light.Parent = parent
	return light
end

function FlashlightOptics.localBeam(emitter: BasePart, cfg: BeamConfig): (SpotLight, SpotLight, Beam)
	local coreLight =
		createSpot(emitter, "CoreSpotLight", cfg.CoreAngle, cfg.CoreBrightness, cfg.CoreRange, cfg.CoreColor, true)
	local spillLight = createSpot(
		emitter,
		"SpillSpotLight",
		cfg.SpillAngle,
		cfg.SpillBrightness,
		cfg.SpillRange,
		cfg.SpillColor,
		false
	)

	local att0 = Instance.new("Attachment")
	att0.Name = "BeamOrigin"
	att0.Position = Vector3.zero
	att0.Parent = emitter

	local att1 = Instance.new("Attachment")
	att1.Name = "BeamEnd"
	att1.Position = Vector3.new(0, 0, -cfg.BeamLength)
	att1.Parent = emitter

	local dustBeam = Instance.new("Beam")
	dustBeam.Name = "VolumetricDustBeam"
	dustBeam.Attachment0 = att0
	dustBeam.Attachment1 = att1
	dustBeam.Width0 = cfg.BeamWidth0
	dustBeam.Width1 = cfg.BeamWidth1
	dustBeam.FaceCamera = true
	dustBeam.LightEmission = 1
	dustBeam.Color = ColorSequence.new(cfg.CoreColor)
	dustBeam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.93),
		NumberSequenceKeypoint.new(1, 1),
	})
	dustBeam.Enabled = false
	dustBeam.Parent = emitter

	return coreLight, spillLight, dustBeam
end

function FlashlightOptics.replica(parent: BasePart): SpotLight
	return createSpot(
		parent,
		"ReplicaFlashlight",
		DEFAULT_REPLICA.angle,
		DEFAULT_REPLICA.brightness,
		DEFAULT_REPLICA.range,
		DEFAULT_REPLICA.color,
		false
	)
end

function FlashlightOptics.setTint(
	coreLight: SpotLight?,
	spillLight: SpotLight?,
	dustBeam: Beam?,
	coreColor: Color3,
	spillColor: Color3
)
	if coreLight then
		coreLight.Color = coreColor
	end
	if spillLight then
		spillLight.Color = spillColor
	end
	if dustBeam then
		dustBeam.Color = ColorSequence.new(coreColor)
	end
end

return FlashlightOptics
