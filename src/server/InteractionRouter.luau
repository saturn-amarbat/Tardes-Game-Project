--!strict
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

export type PromptCallbacks = {
	targetPart: BasePart,
	onTriggered: ((Player, ProximityPrompt, BasePart) -> ())?,
	onHoldBegan: ((Player, ProximityPrompt, BasePart) -> ())?,
	onHoldEnded: ((Player, ProximityPrompt, BasePart) -> ())?,
	onTriggerEnded: ((Player, ProximityPrompt, BasePart) -> ())?,
	onPlayerLost: ((Player) -> ())?,
}

local InteractionRouter = {}

local registered: { [ProximityPrompt]: PromptCallbacks } = {}
local initialized = false

function InteractionRouter.isValidActor(player: Player, targetPart: BasePart, maxDistance: number): boolean
	if player:GetAttribute("DungeonEntered") ~= true or player:GetAttribute("SittingOut") == true then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and targetPart.Parent ~= nil
		and (root.Position - targetPart.Position).Magnitude <= (maxDistance + 4)
end

function InteractionRouter.init()
	if initialized then
		return
	end
	initialized = true

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		local entry = registered[prompt]
		if entry and entry.onTriggered then
			if InteractionRouter.isValidActor(player, entry.targetPart, prompt.MaxActivationDistance) then
				entry.onTriggered(player, prompt, entry.targetPart)
			end
		end
	end)

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt, player: Player)
		local entry = registered[prompt]
		if entry and entry.onHoldBegan then
			if InteractionRouter.isValidActor(player, entry.targetPart, prompt.MaxActivationDistance) then
				entry.onHoldBegan(player, prompt, entry.targetPart)
			end
		end
	end)

	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt, player: Player)
		local entry = registered[prompt]
		if entry and entry.onHoldEnded then
			entry.onHoldEnded(player, prompt, entry.targetPart)
		end
	end)

	ProximityPromptService.PromptTriggerEnded:Connect(function(prompt: ProximityPrompt, player: Player)
		local entry = registered[prompt]
		if entry and entry.onTriggerEnded then
			entry.onTriggerEnded(player, prompt, entry.targetPart)
		end
	end)

	local function notifyLost(player: Player)
		for _, entry in registered do
			if entry.onPlayerLost then
				entry.onPlayerLost(player)
			end
		end
	end

	Players.PlayerRemoving:Connect(notifyLost)
	local function watchCharacter(player: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and hum:IsA("Humanoid") then
			hum.Died:Connect(function()
				notifyLost(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function(char)
			watchCharacter(p, char)
		end)
	end)
	for _, p in Players:GetPlayers() do
		if p.Character then
			task.spawn(watchCharacter, p, p.Character)
		end
		p.CharacterAdded:Connect(function(char)
			watchCharacter(p, char)
		end)
	end
end

function InteractionRouter.register(prompt: ProximityPrompt, callbacks: PromptCallbacks): () -> ()
	InteractionRouter.init()
	registered[prompt] = callbacks
	local ancestryConn = prompt.AncestryChanged:Connect(function(_, parent)
		if not parent then
			registered[prompt] = nil
		end
	end)
	return function()
		registered[prompt] = nil
		ancestryConn:Disconnect()
	end
end

return InteractionRouter
