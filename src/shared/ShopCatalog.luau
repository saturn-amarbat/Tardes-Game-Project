--!strict
export type FlashlightTint = {
	id: string,
	label: string,
	hotspotColor: Color3,
	spillColor: Color3,
	productId: number,
}

export type SupportProduct = {
	id: string,
	label: string,
	description: string,
	productId: number, -- Set to Creator Dashboard Developer Product ID when publishing
}

export type SkinCategory = "Character" | "Weapon"

export type SkinPreview = {
	primaryColor: Color3,
	secondaryColor: Color3,
	accentColor: Color3,
	glowColor: Color3?,
	style: string,
}

export type SkinEntry = {
	id: string,
	category: SkinCategory,
	name: string,
	rarity: string,
	price: number,
	description: string,
	preview: SkinPreview,
}

local ShopCatalog = {}

ShopCatalog.Tints = {
	StandardHalogen = {
		id = "StandardHalogen",
		label = "Warm Halogen",
		hotspotColor = Color3.fromRGB(255, 204, 128),
		spillColor = Color3.fromRGB(230, 156, 76),
		productId = 0, -- Free default
	},
	VintageBrass = {
		id = "VintageBrass",
		label = "Vintage Amber",
		hotspotColor = Color3.fromRGB(255, 178, 92),
		spillColor = Color3.fromRGB(218, 130, 56),
		productId = 0,
	},
	ColdPhosphor = {
		id = "ColdPhosphor",
		label = "Cold Phosphor",
		hotspotColor = Color3.fromRGB(212, 236, 255),
		spillColor = Color3.fromRGB(154, 198, 232),
		productId = 0,
	},
	InspectorUV = {
		id = "InspectorUV",
		label = "Survey Pale Violet",
		hotspotColor = Color3.fromRGB(214, 198, 255),
		spillColor = Color3.fromRGB(150, 132, 212),
		productId = 0,
	},
}

ShopCatalog.SupportProducts = {
	GiftBatteryPack = {
		id = "GiftBatteryPack",
		label = "Emergency Battery Gift",
		description = "Restore 50% flashlight battery for a teammate.",
		productId = 0,
	},
	GiftFieldRevive = {
		id = "GiftFieldRevive",
		label = "Field Resuscitation Kit",
		description = "Bring a fallen teammate back into the bunker expedition.",
		productId = 0,
	},
}

-- Data-driven Lobby cosmetic catalog. Add entries here without modifying UI code.
local characterSkins: { SkinEntry } = {
	{
		id = "char_default",
		category = "Character",
		name = "Forest Ranger",
		rarity = "Common",
		price = 0,
		description = "Standard-issue park ranger jacket. Smells like pine and regret.",
		preview = {
			primaryColor = Color3.fromRGB(58, 78, 52),
			secondaryColor = Color3.fromRGB(84, 62, 42),
			accentColor = Color3.fromRGB(198, 168, 92),
			style = "ranger",
		},
	},
	{
		id = "char_miner",
		category = "Character",
		name = "Abandoned Miner",
		rarity = "Common",
		price = 150,
		description = "Hard hat long dead. The headlamp flickers but never turns on.",
		preview = {
			primaryColor = Color3.fromRGB(72, 74, 78),
			secondaryColor = Color3.fromRGB(48, 44, 38),
			accentColor = Color3.fromRGB(218, 176, 62),
			glowColor = Color3.fromRGB(255, 218, 128),
			style = "miner",
		},
	},
	{
		id = "char_warden",
		category = "Character",
		name = "Park Warden",
		rarity = "Uncommon",
		price = 350,
		description = "The last warden left this coat behind. The pockets were full of teeth.",
		preview = {
			primaryColor = Color3.fromRGB(42, 54, 48),
			secondaryColor = Color3.fromRGB(28, 32, 30),
			accentColor = Color3.fromRGB(168, 138, 72),
			style = "warden",
		},
	},
	{
		id = "char_cultist",
		category = "Character",
		name = "Hooded Cultist",
		rarity = "Rare",
		price = 600,
		description = "The robe hums faintly when near the trees. Best not to listen.",
		preview = {
			primaryColor = Color3.fromRGB(46, 24, 28),
			secondaryColor = Color3.fromRGB(24, 18, 22),
			accentColor = Color3.fromRGB(180, 56, 56),
			glowColor = Color3.fromRGB(210, 62, 54),
			style = "cultist",
		},
	},
	{
		id = "char_spectre",
		category = "Character",
		name = "Pale Spectre",
		rarity = "Epic",
		price = 1000,
		description = "Translucent skin, hollow eyes. Some say it's not a costume.",
		preview = {
			primaryColor = Color3.fromRGB(178, 198, 206),
			secondaryColor = Color3.fromRGB(82, 102, 114),
			accentColor = Color3.fromRGB(168, 232, 242),
			glowColor = Color3.fromRGB(172, 234, 255),
			style = "spectre",
		},
	},
	{
		id = "char_antler",
		category = "Character",
		name = "Antler Crown",
		rarity = "Legendary",
		price = 2000,
		description = "A crown of black bone antlers. The deer watches you wear it.",
		preview = {
			primaryColor = Color3.fromRGB(28, 26, 24),
			secondaryColor = Color3.fromRGB(54, 48, 42),
			accentColor = Color3.fromRGB(218, 206, 182),
			glowColor = Color3.fromRGB(238, 184, 72),
			style = "antler",
		},
	},
}

local weaponSkins: { SkinEntry } = {
	{
		id = "wpn_default",
		category = "Weapon",
		name = "Standard Issue",
		rarity = "Common",
		price = 0,
		description = "Factory-condition flashlight housing. Reliable. Boring.",
		preview = {
			primaryColor = Color3.fromRGB(44, 48, 52),
			secondaryColor = Color3.fromRGB(90, 94, 98),
			accentColor = Color3.fromRGB(255, 204, 128),
			glowColor = Color3.fromRGB(255, 204, 128),
			style = "torch",
		},
	},
	{
		id = "wpn_rusty",
		category = "Weapon",
		name = "Rusty Machete",
		rarity = "Common",
		price = 100,
		description = "Found embedded in a tree stump. The stains won't wash off.",
		preview = {
			primaryColor = Color3.fromRGB(108, 62, 42),
			secondaryColor = Color3.fromRGB(52, 36, 26),
			accentColor = Color3.fromRGB(134, 44, 38),
			style = "blade",
		},
	},
	{
		id = "wpn_bone",
		category = "Weapon",
		name = "Bone Cleaver",
		rarity = "Uncommon",
		price = 300,
		description = "Carved from something large. The marrow still glistens.",
		preview = {
			primaryColor = Color3.fromRGB(214, 204, 182),
			secondaryColor = Color3.fromRGB(68, 44, 36),
			accentColor = Color3.fromRGB(154, 52, 46),
			style = "cleaver",
		},
	},
	{
		id = "wpn_obsidian",
		category = "Weapon",
		name = "Obsidian Edge",
		rarity = "Rare",
		price = 500,
		description = "Volcanic glass honed to an impossible edge. It drinks the light.",
		preview = {
			primaryColor = Color3.fromRGB(22, 18, 28),
			secondaryColor = Color3.fromRGB(48, 36, 62),
			accentColor = Color3.fromRGB(132, 92, 198),
			glowColor = Color3.fromRGB(132, 92, 198),
			style = "blade",
		},
	},
	{
		id = "wpn_phosphor",
		category = "Weapon",
		name = "Phosphor Blade",
		rarity = "Epic",
		price = 900,
		description = "Faint green glow along the edge. Leaves trails in the dark.",
		preview = {
			primaryColor = Color3.fromRGB(42, 68, 54),
			secondaryColor = Color3.fromRGB(26, 36, 32),
			accentColor = Color3.fromRGB(96, 232, 152),
			glowColor = Color3.fromRGB(96, 232, 152),
			style = "blade",
		},
	},
	{
		id = "wpn_void",
		category = "Weapon",
		name = "Void Shard",
		rarity = "Legendary",
		price = 1800,
		description = "A fragment of absolute nothing. Looking at it too long causes headaches.",
		preview = {
			primaryColor = Color3.fromRGB(14, 12, 20),
			secondaryColor = Color3.fromRGB(36, 24, 58),
			accentColor = Color3.fromRGB(214, 146, 255),
			glowColor = Color3.fromRGB(196, 112, 255),
			style = "shard",
		},
	},
}

ShopCatalog.CharacterSkins = characterSkins
ShopCatalog.WeaponSkins = weaponSkins

local skinsById: { [string]: SkinEntry } = {}
for _, list in { characterSkins, weaponSkins } do
	for _, entry in list do
		skinsById[entry.id] = entry
	end
end

function ShopCatalog.getSkinById(id: string): SkinEntry?
	return skinsById[id]
end

function ShopCatalog.getSkinsByCategory(category: SkinCategory): { SkinEntry }
	if category == "Character" then
		return characterSkins
	end
	return weaponSkins
end

return ShopCatalog
