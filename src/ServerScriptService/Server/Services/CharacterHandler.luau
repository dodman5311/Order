local CharacterHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Globals = require(ReplicatedStorage.Shared.Globals)
local CharacterAnimator = require(Globals.Services.CharacterAnimator)
local Net = require(Globals.Packages.Net)
local Timer = require(Globals.Vendor.Timer)

local assets = ReplicatedStorage.Assets
local models = assets.Models
local playerModels = models.PlayerModels

local function cloneToCharacter(character)
	for _, instance in ipairs(StarterPlayer.StarterCharacterScripts:GetChildren()) do
		local newInstance = instance:Clone()
		newInstance.Parent = character
	end
end

local weaponActions = {
	EquipWeapon = function(character: Model, weaponName: string)
		local newWeapon = models.ServerWeapons:FindFirstChild(weaponName):Clone()

		newWeapon.Parent = character
		local newM6D = Instance.new("Motor6D")
		newM6D.Parent = newWeapon
		newM6D.Part0 = character["Right Arm"]
		newM6D.Part1 = newWeapon.PrimaryPart
	end,

	UnequipWeapon = function(character: Model)
		local weapon = character:FindFirstChildOfClass("Model")
		if weapon then
			weapon:Destroy()
		end
	end,

	FireWeapon = function(character: Model)
		character:SetAttribute("Attacking", true)

		local timer = Timer:getTimer(character)
		if timer then
			timer:Reset()
		end

		Timer:new(character, 5, function()
			character:SetAttribute("Attacking", false)
		end):Run()
	end,
}

function CharacterHandler:LoadCharacter(player: Player, characterIndex: number?)
	if not characterIndex then
		characterIndex = 1
	end

	local newCharacter = playerModels:FindFirstChild("Player_" .. characterIndex):Clone()
	newCharacter.Parent = workspace

	if newCharacter:FindFirstChild("Humanoid") then
		newCharacter.Humanoid:Destroy()
	end

	cloneToCharacter(newCharacter)
	player.Character = newCharacter

	CharacterAnimator:AnimateCharacter(player.Character)
end

Players.PlayerAdded:Connect(function(player: Player)
	CharacterHandler:LoadCharacter(player, #Players:GetPlayers())

	-- player.CharacterAdded:Connect(function(character)

	-- end)
end)

Net:Connect("WeaponAction", function(player, actionName, ...) -- convert to weapon action
	weaponActions[actionName](player.Character, ...)
end)

return CharacterHandler
