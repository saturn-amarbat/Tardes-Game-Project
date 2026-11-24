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

return ShopCatalog
