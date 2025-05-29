local module = {
	luck = 0,
	repetitionLuck = 0,
	airluck = false,
}
local rng = Random.new()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Globals = require(ReplicatedStorage.Shared.Globals)
local giftService = require(Globals.Client.Services.GiftsService)
local comboService = require(Globals.Client.Services.ComboService)
local Net = require(Globals.Packages.Net)
local UIService = require(Globals.Client.Services.UIService)

local assets = ReplicatedStorage.Assets

local signals = require(Globals.Signals)

function module.getLuck()
	local result = module.luck
	if giftService.CheckGift("Rabbits_Foot") then
		result += 5
	end

	if module.airluck then
		result += 5
	end

	if giftService.CheckGift("Set_Em_Up") then
		result += math.clamp(comboService.CurrentCombo, 0, 20)
	end

	if giftService.CheckGift("Tough_Luck") then
		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then
			return
		end

		result += (humanoid.MaxHealth - humanoid.Health) * 2
	end

	result += module.repetitionLuck

	return result
end

local function resetRepLuck(value)
	if not value then
		return
	end

	if module.repetitionLuck > 0 then
		UIService.doUiAction("HUD", "ActivateGift", "Gambler's_Fallacy")
	end

	module.repetitionLuck = 0
	UIService.doUiAction("HUD", "UpdateGiftProgress", "Gambler's_Fallacy", 0)
end

function module.checkChance(chance, goodLuck, PureLuck)
	if chance <= 0 then
		return
	end

	local luck = module.getLuck() / 2

	if goodLuck then
		chance += luck
	elseif goodLuck == false then
		chance -= luck
	end

	if rng:NextNumber(0, 100) <= chance then
		resetRepLuck(goodLuck)
		return true
	end

	if
		goodLuck ~= false
		and not PureLuck
		and giftService.CheckGift("Take_Two")
		and player.Character
		and rng:NextNumber(0, 100) <= math.abs(player.Character:WaitForChild("Humanoid").Health - 5) * 15
		and rng:NextNumber(0, 100) <= chance
	then
		resetRepLuck(goodLuck)

		UIService.doUiAction("HUD", "ActivateGift", "Take_Two")
		assets.Sounds.TakeTwo:Play()
		return true
	end

	return false
end

Net:RemoteFunction("CheckChance").OnClientInvoke = function(chance, goodLuck)
	return module.checkChance(chance, goodLuck)
end

return module
