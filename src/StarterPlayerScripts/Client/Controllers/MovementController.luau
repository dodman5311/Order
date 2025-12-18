local movementController = {}

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--// Instances
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--// Modules
local GlobalInputService = require(StarterPlayer.StarterPlayerScripts.Client.Services.GlobalInputService)
local Globals = require(ReplicatedStorage.Shared.Globals)

local Acts = require(Globals.Vendor.Acts)
local AnimationService = require(Globals.Vendor.AnimationService)
local Util = require(Globals.Vendor.Util)
local Viewmodel = require(Globals.Vendor.ViewmodelService)

--// Values

local JUMP_HEIGHT = 5
local WALK_SPEED = 16
local SPRINT_SPEED = 22

--// Functions

-- local function setCharacterPhysics(character: Model)
-- 	for _, part: BasePart in ipairs(character:GetChildren()) do
-- 		if not part:IsA("BasePart") then
-- 			continue
-- 		end

-- 		local physics = PhysicalProperties.new(0.05, 0.1, 0, 1, 1)

-- 		part.CustomPhysicalProperties = physics
-- 	end
-- end

local actsToStopSprint = {
	"InAds",
	"Firing",
}

function movementController:BeginSprint(character)
	local ti = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local humanoid: Humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or Acts:checkAct("Sprinting") then
		return
	end

	Acts:createAct("Sprinting")
	AnimationService:playAnimation(Viewmodel:GetViewmodel().Model, "EnterSprint", "Action", false, 0)
	AnimationService:playAnimation(Viewmodel:GetViewmodel().Model, "Sprint", "Movement")

	Util.tween(humanoid, ti, { WalkSpeed = SPRINT_SPEED })
	Util.tween(camera, ti, { FieldOfView = 75 })
end

function movementController:EndSprint(character)
	local ti = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local humanoid: Humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or not Acts:checkAct("Sprinting") then
		return
	end

	Acts:removeAct("Sprinting")
	AnimationService:stopAnimation(Viewmodel:GetViewmodel().Model, "Sprint")
	AnimationService:playAnimation(Viewmodel:GetViewmodel().Model, "EndSprint", "Action2")

	Util.tween(humanoid, ti, { WalkSpeed = WALK_SPEED })
	Util.tween(camera, ti, { FieldOfView = 70 })
end

local function sprintKey(playbackState: Enum.UserInputState)
	local character = player.Character
	if Acts:checkAct(table.unpack(actsToStopSprint)) then
		return
	end

	if playbackState == Enum.UserInputState.Begin then
		movementController:BeginSprint(character)
	elseif playbackState == Enum.UserInputState.End then
		movementController:EndSprint(character)
	end
end

function movementController:OnDied()
	movementController:EndSprint(player.Character)
end

function movementController:OnSpawn(character: Model)
	--GlobalInputService.CreateInputAction("Sprint", sprintKey, Enum.KeyCode.LeftShift)

	local humanoid: Humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = WALK_SPEED

	humanoid.UseJumpPower = false
	humanoid.JumpHeight = JUMP_HEIGHT

	-- for _ = 1, 3 do
	-- 	setCharacterPhysics(character)
	-- end
end

Acts.OnActAdded:Connect(function(act: string)
	if table.find(actsToStopSprint, act) then
		movementController:EndSprint(player.Character)
	end
end)

return movementController
