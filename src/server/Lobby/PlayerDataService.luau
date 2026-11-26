--!strict
--[[
  PlayerDataService  –  SERVER persistent player data via DataStoreService.

  DataStore: LobbyConfig.DATASTORE_NAME ("PlayerData_v1")
  Key      : "Player_<userId>"
  Schema   :
    Coins                 : number
    OwnedCharacterSkins   : { string }
    OwnedWeaponSkins      : { string }
    EquippedCharacterSkin : string
    EquippedWeaponSkin    : string

  Handles DataStore load failures safely without overwriting existing cloud data.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local ShopCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopCatalog"))

local PlayerDataService = {}

export type PlayerData = {
	Coins: number,
	OwnedCharacterSkins: { string },
	OwnedWeaponSkins: { string },
	EquippedCharacterSkin: string,
	EquippedWeaponSkin: string,
}

local storeOk, storeOrErr = pcall(function()
	return DataStoreService:GetDataStore(LobbyConfig.DATASTORE_NAME)
end)
local store: DataStore? = if storeOk then storeOrErr :: DataStore else nil
if not storeOk then
	warn("[PlayerDataService] GetDataStore unavailable: " .. tostring(storeOrErr))
end

local sessionData: { [Player]: PlayerData } = {}
local sessionLock: { [Player]: boolean } = {}
local loadFailed: { [Player]: boolean } = {}
local savingInProgress: { [Player]: boolean } = {}

local function defaultData(): PlayerData
	return {
		Coins = LobbyConfig.STARTING_COINS,
		OwnedCharacterSkins = { "char_default" },
		OwnedWeaponSkins = { "wpn_default" },
		EquippedCharacterSkin = "char_default",
		EquippedWeaponSkin = "wpn_default",
	}
end

local function ensureStringArray(val: unknown, fallbackItem: string): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	if typeof(val) == "table" then
		for _, item in val :: { unknown } do
			if typeof(item) == "string" and not seen[item] then
				seen[item] = true
				table.insert(out, item)
			end
		end
	end
	if not seen[fallbackItem] then
		table.insert(out, 1, fallbackItem)
	end
	return out
end

local function sanitizeData(raw: unknown): PlayerData
	if typeof(raw) ~= "table" then
		return defaultData()
	end
	local t = raw :: { [string]: unknown }
	local ownedChar = ensureStringArray(t.OwnedCharacterSkins, "char_default")
	local ownedWpn = ensureStringArray(t.OwnedWeaponSkins, "wpn_default")
	local eqChar = if typeof(t.EquippedCharacterSkin) == "string" then t.EquippedCharacterSkin else "char_default"
	local eqWpn = if typeof(t.EquippedWeaponSkin) == "string" then t.EquippedWeaponSkin else "wpn_default"

	return {
		Coins = if typeof(t.Coins) == "number" then math.max(0, math.floor(t.Coins)) else LobbyConfig.STARTING_COINS,
		OwnedCharacterSkins = ownedChar,
		OwnedWeaponSkins = ownedWpn,
		EquippedCharacterSkin = eqChar,
		EquippedWeaponSkin = eqWpn,
	}
end

local function clonePayload(data: PlayerData): { [string]: any }
	return {
		Coins = data.Coins,
		OwnedCharacterSkins = table.clone(data.OwnedCharacterSkins),
		OwnedWeaponSkins = table.clone(data.OwnedWeaponSkins),
		EquippedCharacterSkin = data.EquippedCharacterSkin,
		EquippedWeaponSkin = data.EquippedWeaponSkin,
	}
end

local function loadPlayer(player: Player): (PlayerData, boolean)
	if not store then
		return defaultData(), false
	end

	local key = LobbyConfig.DATASTORE_KEY_PREFIX .. tostring(player.UserId)
	local lastErr: unknown = nil
	for attempt = 1, LobbyConfig.MAX_DATASTORE_RETRIES do
		local ok, raw = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return sanitizeData(raw), true
		end
		lastErr = raw
		if attempt < LobbyConfig.MAX_DATASTORE_RETRIES then
			task.wait(0.5 * attempt)
		end
	end

	warn(
		string.format(
			"[PlayerDataService] Failed to load data for %s after %d tries: %s",
			player.Name,
			LobbyConfig.MAX_DATASTORE_RETRIES,
			tostring(lastErr)
		)
	)
	return defaultData(), false
end

local function savePlayer(player: Player): (boolean, string?)
	if loadFailed[player] then
		return false, "Database unavailable (load failed); save skipped to prevent data loss."
	end
	if not store then
		return false, "DataStore service is unavailable."
	end
	local data = sessionData[player]
	if not data then
		return false, "No active session data."
	end
	if savingInProgress[player] then
		return false, "Save already in progress."
	end

	savingInProgress[player] = true
	local key = LobbyConfig.DATASTORE_KEY_PREFIX .. tostring(player.UserId)
	local payload = clonePayload(data)
	local ok, err = pcall(function()
		store:SetAsync(key, payload)
	end)
	savingInProgress[player] = nil

	if not ok then
		warn("[PlayerDataService] Save failed for " .. player.Name .. ": " .. tostring(err))
		return false, tostring(err)
	end
	return true, nil
end

local function publishToClient(player: Player)
	local data = sessionData[player]
	if not data then
		return
	end
	player:SetAttribute("LobbyCoins", data.Coins)
	player:SetAttribute("EquippedCharacterSkin", data.EquippedCharacterSkin)
	player:SetAttribute("EquippedWeaponSkin", data.EquippedWeaponSkin)
	player:SetAttribute("DataLoadFailed", loadFailed[player] == true)
	player:SetAttribute("LobbyDataReady", true)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function PlayerDataService.init()
	local function onJoin(player: Player)
		sessionLock[player] = true
		player:SetAttribute("LobbyDataReady", false)
		local data, ok = loadPlayer(player)
		if player.Parent ~= Players then
			sessionLock[player] = nil
			return
		end
		sessionData[player] = data
		loadFailed[player] = not ok
		sessionLock[player] = nil
		publishToClient(player)
	end

	local function onLeave(player: Player)
		if sessionData[player] and not loadFailed[player] then
			savePlayer(player)
		end
		sessionData[player] = nil
		sessionLock[player] = nil
		loadFailed[player] = nil
		savingInProgress[player] = nil
	end

	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoin, p)
	end

	-- Periodic auto-save loop
	task.spawn(function()
		while true do
			task.wait(LobbyConfig.AUTO_SAVE_INTERVAL)
			for player in sessionData do
				if player.Parent == Players and not loadFailed[player] then
					task.spawn(savePlayer, player)
				end
			end
		end
	end)

	-- Flush saves cleanly on server shutdown
	game:BindToClose(function()
		local remaining = 0
		for player in sessionData do
			if not loadFailed[player] then
				remaining += 1
				task.spawn(function()
					savePlayer(player)
					remaining -= 1
				end)
			end
		end
		local deadline = os.clock() + 5
		while remaining > 0 and os.clock() < deadline do
			task.wait(0.05)
		end
	end)

	print("[PlayerDataService] Initialized.")
end

function PlayerDataService.hasLoadFailed(player: Player): boolean
	return loadFailed[player] == true
end

function PlayerDataService.getData(player: Player): PlayerData?
	if sessionLock[player] then
		local start = os.clock()
		while sessionLock[player] and os.clock() - start < 5 do
			task.wait(0.05)
		end
	end
	return sessionData[player]
end

function PlayerDataService.addCoins(player: Player, amount: number)
	local data = sessionData[player]
	if data and amount > 0 then
		data.Coins += math.floor(amount)
		publishToClient(player)
	end
end

function PlayerDataService.spendCoins(player: Player, amount: number): boolean
	local data = sessionData[player]
	if not data or amount <= 0 then
		return false
	end
	if data.Coins < amount then
		return false
	end
	data.Coins -= amount
	publishToClient(player)
	return true
end

function PlayerDataService.ownsSkin(player: Player, skinId: string): boolean
	local data = sessionData[player]
	if not data then
		return false
	end
	for _, id in data.OwnedCharacterSkins do
		if id == skinId then
			return true
		end
	end
	for _, id in data.OwnedWeaponSkins do
		if id == skinId then
			return true
		end
	end
	return false
end

function PlayerDataService.grantSkin(player: Player, skinId: string): boolean
	local data = sessionData[player]
	if not data or PlayerDataService.ownsSkin(player, skinId) then
		return false
	end

	local entry = ShopCatalog.getSkinById(skinId)
	if not entry then
		return false
	end

	if entry.category == "Character" then
		table.insert(data.OwnedCharacterSkins, skinId)
	else
		table.insert(data.OwnedWeaponSkins, skinId)
	end

	publishToClient(player)
	return true
end

function PlayerDataService.revokeSkin(player: Player, skinId: string): boolean
	local data = sessionData[player]
	if not data then
		return false
	end
	for i, id in data.OwnedCharacterSkins do
		if id == skinId then
			table.remove(data.OwnedCharacterSkins, i)
			publishToClient(player)
			return true
		end
	end
	for i, id in data.OwnedWeaponSkins do
		if id == skinId then
			table.remove(data.OwnedWeaponSkins, i)
			publishToClient(player)
			return true
		end
	end
	return false
end

function PlayerDataService.equipSkin(player: Player, skinId: string): boolean
	local data = sessionData[player]
	if not data or not PlayerDataService.ownsSkin(player, skinId) then
		return false
	end
	local entry = ShopCatalog.getSkinById(skinId)
	if not entry then
		return false
	end

	if entry.category == "Character" then
		data.EquippedCharacterSkin = skinId
	else
		data.EquippedWeaponSkin = skinId
	end

	publishToClient(player)
	return true
end

function PlayerDataService.savePlayer(player: Player): (boolean, string?)
	return savePlayer(player)
end

return PlayerDataService
