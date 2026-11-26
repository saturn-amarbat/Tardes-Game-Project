--!strict
--[[
  LobbyAmbience  –  CLIENT forest ambient audio loops (crickets + wind).

  Spatial 3D emitters (campfire crackle, frog croak, far-off owl hoot,
  distant branch crack) run directly on world parts built by LobbyScene.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))

local LobbyAmbience = {}

local sounds: { Sound } = {}

local function createLoopSound(name: string, assetId: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = assetId
	sound.Volume = volume
	sound.Looped = true
	sound.Parent = SoundService
	table.insert(sounds, sound)
	return sound
end

function LobbyAmbience.init()
	local crickets = createLoopSound("LobbyCrickets", LobbyConfig.AUDIO.Crickets, 0.22)
	local wind = createLoopSound("LobbyWind", LobbyConfig.AUDIO.WindLoop, 0.14)

	crickets:Play()
	wind:Play()

	print("[LobbyAmbience] Forest ambience active.")
end

function LobbyAmbience.stop()
	for _, sound in sounds do
		if sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end
	table.clear(sounds)
end

return LobbyAmbience
