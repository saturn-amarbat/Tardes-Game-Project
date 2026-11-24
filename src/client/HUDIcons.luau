--!strict
--[[
  HUDIcons  –  Crisp, resolution-independent vector-style UI icons built from Luau primitives.
  Avoids external decal permission issues and clunky emojis while keeping a cohesive
  1970s Blackpine field-survey horror aesthetic.
]]

local HUDIcons = {}

local function container(parent: Instance, name: string, size: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundTransparency = 1
	f.Parent = parent
	return f
end

local function part(parent: Instance, size: UDim2, pos: UDim2, color: Color3, rotation: number?, round: boolean?): Frame
	local p = Instance.new("Frame")
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Size = size
	p.Position = pos
	p.BackgroundColor3 = color
	p.BorderSizePixel = 0
	if rotation then
		p.Rotation = rotation
	end
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = p
	end
	p.Parent = parent
	return p
end

-- Key silhouette (ring bow + shaft + two teeth)
function HUDIcons.key(parent: Instance, color: Color3, size: number?): Frame
	local s = size or 16
	local root = container(parent, "KeyIcon", s)

	local bow = part(root, UDim2.fromScale(0.42, 0.42), UDim2.fromScale(0.28, 0.48), color, 0, true)
	bow.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.8
	stroke.Parent = bow

	part(root, UDim2.fromScale(0.46, 0.14), UDim2.fromScale(0.68, 0.48), color)
	part(root, UDim2.fromScale(0.12, 0.22), UDim2.fromScale(0.84, 0.62), color)
	part(root, UDim2.fromScale(0.12, 0.16), UDim2.fromScale(0.66, 0.59), color)
	return root
end

-- Cartridge fuse silhouette (copper caps + glass core + filament)
function HUDIcons.fuse(parent: Instance, color: Color3, size: number?): Frame
	local s = size or 16
	local root = container(parent, "FuseIcon", s)

	local body = part(root, UDim2.fromScale(0.36, 0.72), UDim2.fromScale(0.5, 0.5), color, 35)
	body.BackgroundTransparency = 0.65
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.4
	stroke.Parent = body

	part(body, UDim2.fromScale(1.1, 0.24), UDim2.fromScale(0.5, 0.12), color)
	part(body, UDim2.fromScale(1.1, 0.24), UDim2.fromScale(0.5, 0.88), color)
	part(body, UDim2.fromScale(0.24, 0.48), UDim2.fromScale(0.5, 0.5), color)
	return root
end

-- Brass scrap / gear token (notched ring)
function HUDIcons.scrap(parent: Instance, color: Color3, size: number?): Frame
	local s = size or 16
	local root = container(parent, "ScrapIcon", s)

	local outer = part(root, UDim2.fromScale(0.76, 0.76), UDim2.fromScale(0.5, 0.5), color, 0, true)
	outer.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = outer

	part(root, UDim2.fromScale(0.26, 0.26), UDim2.fromScale(0.5, 0.5), color, 45)
	return root
end

-- Flashlight silhouette + light rays
function HUDIcons.flashlight(parent: Instance, color: Color3, size: number?): (Frame, { Frame })
	local s = size or 24
	local root = container(parent, "FlashlightIcon", s)
	local rays: { Frame } = {}

	local body = part(root, UDim2.fromScale(0.52, 0.24), UDim2.fromScale(0.38, 0.62), color, -42)
	local head = part(root, UDim2.fromScale(0.22, 0.36), UDim2.fromScale(0.58, 0.42), color, -42)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 2)
	c.Parent = body
	local _ = head

	local r1 = part(root, UDim2.fromScale(0.22, 0.08), UDim2.fromScale(0.82, 0.2), color, -42)
	local r2 = part(root, UDim2.fromScale(0.2, 0.08), UDim2.fromScale(0.7, 0.14), color, -68)
	local r3 = part(root, UDim2.fromScale(0.2, 0.08), UDim2.fromScale(0.86, 0.34), color, -16)
	table.insert(rays, r1)
	table.insert(rays, r2)
	table.insert(rays, r3)

	return root, rays
end

-- Medical survival cross
function HUDIcons.health(parent: Instance, color: Color3, size: number?): Frame
	local s = size or 14
	local root = container(parent, "HealthIcon", s)
	part(root, UDim2.fromScale(0.72, 0.24), UDim2.fromScale(0.5, 0.5), color)
	part(root, UDim2.fromScale(0.24, 0.72), UDim2.fromScale(0.5, 0.5), color)
	return root
end

-- Forward chevron dash for stamina/sprint
function HUDIcons.sprint(parent: Instance, color: Color3, size: number?): Frame
	local s = size or 14
	local root = container(parent, "SprintIcon", s)
	part(root, UDim2.fromScale(0.46, 0.16), UDim2.fromScale(0.36, 0.36), color, 40)
	part(root, UDim2.fromScale(0.46, 0.16), UDim2.fromScale(0.36, 0.64), color, -40)
	part(root, UDim2.fromScale(0.46, 0.16), UDim2.fromScale(0.68, 0.36), color, 40)
	part(root, UDim2.fromScale(0.46, 0.16), UDim2.fromScale(0.68, 0.64), color, -40)
	return root
end

-- Field notebook cover + spine
function HUDIcons.journal(parent: Instance, color: Color3, size: number?): Frame
	local s = size or 16
	local root = container(parent, "JournalIcon", s)
	local cover = part(root, UDim2.fromScale(0.64, 0.8), UDim2.fromScale(0.5, 0.5), color)
	cover.BackgroundTransparency = 0.82
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.5
	stroke.Parent = cover

	part(root, UDim2.fromScale(0.14, 0.8), UDim2.fromScale(0.24, 0.5), color)
	part(root, UDim2.fromScale(0.3, 0.1), UDim2.fromScale(0.56, 0.36), color)
	part(root, UDim2.fromScale(0.3, 0.1), UDim2.fromScale(0.56, 0.54), color)
	return root
end

return HUDIcons
