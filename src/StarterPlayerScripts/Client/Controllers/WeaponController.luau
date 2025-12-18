export type Ammo = {
	Current: number,
	Max: number,
	Stored: number,
}

local weaponController = {
	EquippedWeapon = nil,
}

local weaponAmmo = {
	RevolverAmmo = {
		Current = 6,
		Max = 6,
		Stored = math.huge,
	},
	ShotgunAmmo = {
		Current = 15,
		Max = 15,
		Stored = 120,
	},
	RifleAmmo = {
		Current = 20,
		Max = 20,
		Stored = 120,
	},
}

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

--// Instances
local assets = ReplicatedStorage.Assets
local weaponsFolder = assets.Models.Weapons
--local sounds = assets.Sounds

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

--// Modules
local Globals = require(ReplicatedStorage.Shared.Globals)

local Acts = require(Globals.Vendor.Acts)
local AnimationService = require(Globals.Vendor.AnimationService)
local BulletHit = require(Globals.Client.Services.BulletHit)
local DamageService = require(Globals.Client.Services.DamageService)
local GlobalInputService = require(StarterPlayer.StarterPlayerScripts.Client.Services.GlobalInputService)

local Net = require(Globals.Packages.Net)
local Spring = require(Globals.Vendor.Spring)
local Timer = require(Globals.Vendor.Timer)
local Util = require(Globals.Vendor.Util)
local ViewmodelService = require(Globals.Vendor.ViewmodelService)

local HUD = require(Globals.Client.Services.HUDService)

--// Values
logRecoil = CFrame.Angles(0, 0, 0)
local recoilSpring = Spring.new(Vector3.zero)
recoilSpring.Damper = 0.45

local rng = Random.new()

local meleeAttackIndex = 1
local meleeAttackTimer = Timer:new("MeleeAttack", 0.5, function()
	meleeAttackIndex = 1
end)

local MARS_PELLET_COUNT = 8
local MARS_PELLET_DAMAGE = 5
local MARS_SPREAD = 5

local MARS_RIFLE_DAMAGE = 10

local REVOLVER_DAMAGE = 12

local MELEE_LIGHT_DAMAGE = 5

--// Functions

local function createViewmodel()
	local viewmodel = ViewmodelService.new(assets.Models.PlayerModels.Player_1_Viewmodel)
	viewmodel.IncludeFOVOffset = false

	viewmodel.CameraBoneName = "FakeCamera"
	viewmodel:SetOffset("DefaultOffset", "FromCamera", CFrame.new(0, -0.39, 0.25))
	viewmodel:Run()
	viewmodel:Hide()
end

local function createMotor6D(part0, part1): Motor6D
	local newMotor6D = Instance.new("Motor6D")
	newMotor6D.Parent = part1
	newMotor6D.Part0 = part0
	newMotor6D.Part1 = part1
	return newMotor6D
end

local function processHits(hits, originalPlayer)
	for _, hit: DamageService.hitInfo in pairs(hits) do
		if not hit.Result then
			continue
		end

		if not hit.Humanoid then
			BulletHit.createEffect(hit.Result, originalPlayer)
		end

		if originalPlayer then -- only do on client
			continue
		end

		if hit.Humanoid and (typeof(hit.Humanoid) == "boolean" or hit.Humanoid.Health > 0) then
			HUD:ShowHitmarker(hit)
		end
	end
end

local function equipWeapon(weaponName: string)
	Acts:waitForAct("Switching")

	if weaponController.EquippedWeapon and weaponController.EquippedWeapon.Name == weaponName then
		return
	end

	local weaponModel = weaponsFolder:FindFirstChild(weaponName)
	if not weaponModel then
		return warn(weaponName .. " not found")
	end

	Net:RemoteEvent("WeaponAction"):FireServer("EquipWeapon", weaponName)

	Acts:createAct("Switching")
	local viewmodel = ViewmodelService:GetViewmodel()

	weaponController:CallWeaponEvent("Unequip")

	weaponModel = weaponModel:Clone()
	weaponController.EquippedWeapon = weaponModel

	weaponModel.Parent = viewmodel.Model
	createMotor6D(viewmodel.Model.Base, weaponModel.FunctionalParts.Grip)

	AnimationService:loadAnimations(viewmodel.Model, weaponModel.Animations)
	AnimationService:playAnimation(viewmodel.Model, "Idle", Enum.AnimationPriority.Core)
	local equipAnimation = AnimationService:playAnimation(viewmodel.Model, "Equip", "Action")

	local startTime = os.clock()

	repeat
		task.wait()
	until equipAnimation.Length > 0 or os.clock() - startTime >= 2

	viewmodel:Show()

	HUD:ShowCrosshair(weaponName)

	task.wait(equipAnimation.Length)
	Acts:removeAct("Switching")
end

local function unequipWeapon()
	Acts:waitForAct("Switching")

	if not weaponController.EquippedWeapon then
		return
	end

	Net:RemoteEvent("WeaponAction"):FireServer("UnequipWeapon")

	Util.PlaySound(assets.Sounds.SwitchWeapons, script, 0.15)

	Acts:removeAct("Reloading", "Firing")
	Acts:createAct("Switching")

	local viewmodel = ViewmodelService:GetViewmodel()

	AnimationService:playAnimation(viewmodel.Model, "Unequip", "Action4").Stopped:Wait()
	viewmodel:Hide()
	AnimationService:stopAllAnimations(viewmodel.Model)
	weaponController.EquippedWeapon:Destroy()
	weaponController.EquippedWeapon = nil

	Acts:removeAct("Switching")
end

local function Recoil(recoilVector: Vector3, randomVector: Vector3, magnitude: number?, speed: number?)
	magnitude = magnitude or 1
	speed = speed or 1

	local randomizedVector = Vector3.new(
		rng:NextNumber(recoilVector.X + -randomVector.X, recoilVector.X + randomVector.X) * 100,
		rng:NextNumber(recoilVector.Y + -randomVector.Y, recoilVector.Y + randomVector.Y) * 100,
		rng:NextNumber(recoilVector.Z + -randomVector.Z, recoilVector.Z + randomVector.Z) * 100
	) * magnitude

	recoilSpring.Speed = 30 * speed

	recoilSpring:Impulse(randomizedVector)
end

local function muzzleEffect(muzzleName)
	if not weaponController.EquippedWeapon then
		return
	end

	for _, effect in ipairs(weaponController.EquippedWeapon.FunctionalParts[muzzleName]:GetChildren()) do
		if effect:IsA("ParticleEmitter") then
			effect:Emit(effect:GetAttribute("EmitCount"))
		elseif effect:IsA("PointLight") then
			effect.Enabled = true
			task.delay(0.05, function()
				effect.Enabled = false
			end)
		end
	end
end

local function fireBullet(damageAmount: number, spread: number?, bulletCount: number?)
	local weaponModel = weaponController.EquippedWeapon
	if not weaponModel then
		return warn("No weapon eqiupped")
	end

	local damage = DamageService.new(damageAmount, weaponModel.Name, "Bullet", player.Character)
	local hits = DamageService:CreateDamagingCast(damage, camera.CFrame.Position, camera.CFrame, spread, bulletCount)

	processHits(hits)
end

local function fireMars(inAds)
	if Acts:checkAct("Firing", "Reloading") then
		return
	end

	local ammo: Ammo = inAds and weaponAmmo.RifleAmmo or weaponAmmo.ShotgunAmmo

	if ammo.Current <= 0 then
		Util.PlaySound(assets.Sounds.Empty, script, 0.025)
		return
	end

	Acts:createAct("Firing")
	ammo.Current -= 1
	Net:RemoteEvent("WeaponAction"):FireServer("FireWeapon")

	HUD:PumpCrosshair()
	if inAds then
		HUD:UpdateAmmo("SecondaryAmmo", ammo.Current, ammo.Stored, true)

		muzzleEffect("RifleMuzzle")
		Util.PlaySound(weaponController.EquippedWeapon.Sounds.Rifle, script, 0.075)

		fireBullet(MARS_RIFLE_DAMAGE)
		AnimationService:playAnimation(ViewmodelService:GetViewmodel().Model, "AdsFire", "Action", false, 0, 2)
		Recoil(Vector3.new(-0.75, 1, 0), Vector3.new(0.5, 0.5, 2), 1, 0.75)

		task.wait(0.125)
		Acts:removeAct("Firing")
	else
		HUD:UpdateAmmo("PrimaryAmmo", ammo.Current, ammo.Stored, true)

		muzzleEffect("ShotgunMuzzle")
		Util.PlaySound(weaponController.EquippedWeapon.Sounds.Shotgun, script, 0.075)

		fireBullet(MARS_PELLET_DAMAGE, MARS_SPREAD, MARS_PELLET_COUNT)
		AnimationService:playAnimation(ViewmodelService:GetViewmodel().Model, "Fire", "Action", false, 0, 2)
		Recoil(Vector3.new(0.75, 2, 0), Vector3.new(0.6, 0.5, 4), 1, 0.5)

		task.wait(0.15)
		Acts:removeAct("Firing")
	end

	if weaponAmmo.ShotgunAmmo.Current <= 0 and weaponAmmo.RifleAmmo.Current <= 0 then
		weaponController:CallWeaponEvent("Reload")
	end
end

local function checkForReload(...)
	local ammoSources = { ... }

	if Acts:checkAct("Firing", "Reloading") then
		return false
	end

	for _, ammo: Ammo in ipairs(ammoSources) do
		if ammo.Current < ammo.Max and ammo.Stored > 0 then
			return true
		end
	end

	return false
end

local function fillMag(ammo: Ammo, isSecondary: boolean?)
	local toAdd = math.clamp(ammo.Max - ammo.Current, 0, ammo.Stored)
	local ammoType = isSecondary and "SecondaryAmmo" or "PrimaryAmmo"

	ammo.Current += toAdd
	ammo.Stored -= toAdd

	HUD:UpdateAmmo(ammoType, ammo.Current, ammo.Stored)
end

local weaponFunctions = {
	Mars = {
		Equip = function()
			HUD:ToggleSecondaryAmmo(true)
			HUD:SwitchPrimaryAmmo(weaponAmmo.ShotgunAmmo.Current, weaponAmmo.ShotgunAmmo.Stored, "Shotgun")
			equipWeapon("Mars")
		end,
		Unequip = function(self)
			self:AltOut()
			unequipWeapon()
		end,
		Attack = function()
			fireMars(Acts:checkAct("InAds"))
		end,
		Reload = function(self)
			if not checkForReload(weaponAmmo.RifleAmmo, weaponAmmo.ShotgunAmmo) then
				return
			end

			self:AltOut()

			Acts:createAct("Reloading")

			Util.PlaySound(weaponController.EquippedWeapon.Sounds.Reload, script)

			AnimationService:stopAnimation(ViewmodelService:GetViewmodel().Model, "AdsOut")
			AnimationService:stopAnimation(ViewmodelService:GetViewmodel().Model, "AdsIn")
			local reloadAnimation =
				AnimationService:playAnimation(ViewmodelService:GetViewmodel().Model, "Reload", "Action3")
			reloadAnimation.KeyframeReached:Once(function()
				reloadAnimation.Priority = Enum.AnimationPriority.Action

				if weaponController.EquippedWeapon and weaponController.EquippedWeapon.Name == "Mars" then
					fillMag(weaponAmmo.ShotgunAmmo)
					fillMag(weaponAmmo.RifleAmmo, true)
				end

				Acts:removeAct("Reloading")
			end)
		end,
		Alt = function()
			local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quart)

			if Acts:checkAct("InAds", "Reloading") then
				return
			end

			Acts:createAct("InAds")
			HUD:ShowCrosshair("Rifle")
			HUD:SwitchToAmmo("SecondaryAmmo", "Rifle")

			Util.PlaySound(weaponController.EquippedWeapon.Sounds.RifleMode, script, 0.05)
			Util.PlaySound(weaponController.EquippedWeapon.Sounds.AimIn, script, 0.1)

			Util.tween(camera, ti, { FieldOfView = 55 })
			Util.tween(UserInputService, ti, { MouseDeltaSensitivity = 0.75 })

			ViewmodelService:GetViewmodel().Bobbing.Magnitude = 0.25
			ViewmodelService:GetViewmodel().Sway.Magnitude = 0.25

			AnimationService:stopAnimation(ViewmodelService:GetViewmodel().Model, "EndSprint")
			AnimationService:stopAnimation(ViewmodelService:GetViewmodel().Model, "AdsOut")
			AnimationService:playAnimation(ViewmodelService:GetViewmodel().Model, "AdsIn", "Action2")
			AnimationService:playAnimation(ViewmodelService:GetViewmodel().Model, "AdsIdle", "Movement")
		end,
		AltOut = function()
			local ti = TweenInfo.new(0.35, Enum.EasingStyle.Quart)

			if not Acts:checkAct("InAds") then
				return
			end
			Acts:removeAct("InAds")
			HUD:ShowCrosshair("Mars")
			HUD:SwitchToAmmo("PrimaryAmmo", "Shotgun")

			Util.PlaySound(weaponController.EquippedWeapon.Sounds.ShotgunMode, script, 0.05)
			Util.PlaySound(weaponController.EquippedWeapon.Sounds.AimOut, script, 0.1)

			Util.tween(camera, ti, { FieldOfView = 70 })
			Util.tween(UserInputService, ti, { MouseDeltaSensitivity = 1 })

			ViewmodelService:GetViewmodel().Bobbing.Magnitude = 1
			ViewmodelService:GetViewmodel().Sway.Magnitude = 1

			AnimationService:stopAnimation(ViewmodelService:GetViewmodel().Model, "AdsIdle")
			AnimationService:stopAnimation(ViewmodelService:GetViewmodel().Model, "AdsIn")
			AnimationService:playAnimation(ViewmodelService:GetViewmodel().Model, "AdsOut", "Action2")
		end,
	},

	Revolver = {
		Equip = function()
			HUD:SwitchPrimaryAmmo(weaponAmmo.RevolverAmmo.Current, weaponAmmo.RevolverAmmo.Stored, "Revolver")
			HUD:ToggleSecondaryAmmo(false)
			equipWeapon("Revolver")
		end,
		Unequip = unequipWeapon,
		Attack = function(self)
			if Acts:checkAct("Firing", "Reloading") then
				return
			end
			Acts:createAct("Firing")

			if weaponAmmo.RevolverAmmo.Current <= 0 then
				Util.PlaySound(assets.Sounds.RevolverEmpty, script, 0.025)
			else
				Net:RemoteEvent("WeaponAction"):FireServer("FireWeapon")
			end

			AnimationService:playAnimation(ViewmodelService:GetViewmodel().Model, "Pull", "Action2", false, 0, 2).Stopped
				:Once(function()
					if weaponAmmo.RevolverAmmo.Current <= 0 then
						Acts:removeAct("Firing")
						return
					end

					Util.PlaySound(weaponController.EquippedWeapon.Sounds.Fire, script, 0.075)
					weaponAmmo.RevolverAmmo.Current -= 1
					fireBullet(REVOLVER_DAMAGE)
					muzzleEffect("Muzzle")

					HUD:UpdateAmmo("PrimaryAmmo", weaponAmmo.RevolverAmmo.Current, weaponAmmo.RevolverAmmo.Stored, true)
					HUD:PumpCrosshair()

					AnimationService:playAnimation(
						ViewmodelService:GetViewmodel().Model,
						"Fire",
						"Action2",
						false,
						0,
						2
					)

					Recoil(Vector3.new(0, 2, 0), Vector3.new(0.5, 0.5, 3), 1, 0.5)

					task.wait(0.15)

					Acts:removeAct("Firing")

					if weaponAmmo.RevolverAmmo.Current <= 0 then
						self:Reload()
					end
				end)
		end,
		Reload = function()
			if not checkForReload(weaponAmmo.RevolverAmmo) then
				return
			end

			Acts:createAct("Reloading")
			Util.PlaySound(weaponController.EquippedWeapon.Sounds.Reload, script)

			local reloadAnimation =
				AnimationService:playAnimation(ViewmodelService:GetViewmodel().Model, "Reload", "Action3")
			reloadAnimation.KeyframeReached:Once(function()
				reloadAnimation.Priority = Enum.AnimationPriority.Action
				if weaponController.EquippedWeapon and weaponController.EquippedWeapon.Name == "Revolver" then
					fillMag(weaponAmmo.RevolverAmmo)
				end

				Acts:removeAct("Reloading")
			end)
		end,
		Alt = function() end,
	},

	Sword = {
		Equip = function()
			equipWeapon("Sword")
		end,
		Unequip = unequipWeapon,
		Attack = function()
			if Acts:checkAct("Swing") then
				return
			end
			Acts:createAct("Swing")

			local damage = DamageService.new(MELEE_LIGHT_DAMAGE, "Sword", "Melee", player.Character)
			processHits(DamageService:CreateDamagingBox(damage, camera.CFrame, Vector3.new(10, 10, 10)))

			if meleeAttackTimer:Cancel() then
				meleeAttackIndex += 1
				if meleeAttackIndex > 3 then
					meleeAttackIndex = 1
				end
			end

			AnimationService:stopAnimation(ViewmodelService:GetViewmodel().Model, "Swing_1", 0)
			AnimationService:stopAnimation(ViewmodelService:GetViewmodel().Model, "Swing_2", 0)
			AnimationService:stopAnimation(ViewmodelService:GetViewmodel().Model, "Swing_3", 0)
			AnimationService:playAnimation(
				ViewmodelService:GetViewmodel().Model,
				"Swing_" .. meleeAttackIndex,
				"Action4",
				false,
				0,
				2
			)

			if meleeAttackIndex == 1 then
				Recoil(Vector3.new(-2, 0, 2), Vector3.new(0.25, 0.5, 0.5), 1, 0.5)
			elseif meleeAttackIndex == 2 then
				Recoil(Vector3.new(2, 0, -2), Vector3.new(0.25, 0.5, 0.5), 1, 0.5)
			elseif meleeAttackIndex == 3 then
				Recoil(Vector3.new(1, 0, 0), Vector3.new(0.25, 0.25, 4), 1, 0.4)
			end

			if meleeAttackIndex < 3 then
				task.wait(0.25)
			else
				task.wait(0.75)
			end
			Acts:removeAct("Swing")
			meleeAttackTimer:Run()
		end,
		Alt = function() end,
	},
}

function weaponController:CallWeaponEvent(event: string, weaponName: string?, ...)
	if not weaponName then
		if self.EquippedWeapon then
			weaponName = self.EquippedWeapon.Name
		else
			return
		end
	end

	local weaponDictionary = weaponFunctions[weaponName]
	if not weaponDictionary or not weaponDictionary[event] then
		return
	end

	return weaponDictionary[event](weaponDictionary, ...)
end

local function attackInput(inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	weaponController:CallWeaponEvent("Attack")
end

local function reloadInput(inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	weaponController:CallWeaponEvent("Reload")
end
local function altInput(inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		weaponController:CallWeaponEvent("Alt")
	else
		weaponController:CallWeaponEvent("AltOut")
	end
end

local function switchWeaponInput(inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end

	local equipped = weaponController.EquippedWeapon

	if not equipped or equipped.Name == "Mars" then
		weaponController:CallWeaponEvent("Unequip")
		weaponController:CallWeaponEvent("Equip", "Revolver")
	elseif equipped.Name == "Revolver" then
		weaponController:CallWeaponEvent("Unequip")
		weaponController:CallWeaponEvent("Equip", "Mars")
	else
		weaponController:CallWeaponEvent("Unequip")
		weaponController:CallWeaponEvent("Equip", "Revolver")
	end
end

function weaponController:OnDied()
	self:CallWeaponEvent("Unequip")
end

function weaponController:OnSpawn() end

function weaponController:Init()
	createViewmodel()
	GlobalInputService.CreateInputAction("Attack", attackInput, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonL2)
	GlobalInputService.CreateInputAction("Reload", reloadInput, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	GlobalInputService.CreateInputAction("Alt", altInput, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonR2)
	GlobalInputService.CreateInputAction(
		"SwitchWeapon",
		switchWeaponInput,
		{ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Q },
		Enum.KeyCode.ButtonY
	)

	GlobalInputService.CreateInputAction("Sword", function(inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end

		self:CallWeaponEvent("Unequip")
		self:CallWeaponEvent("Equip", "Sword")
	end, Enum.KeyCode.Three)
end

RunService.RenderStepped:Connect(function()
	local recoilCFrame = CFrame.Angles(
		math.rad(recoilSpring.Position.Y),
		math.rad(recoilSpring.Position.X),
		math.rad(recoilSpring.Position.Z)
	)

	camera.CFrame *= logRecoil:Inverse()
	camera.CFrame *= recoilCFrame
	logRecoil = recoilCFrame
end)

Net:Connect("DealDamage", processHits)

return weaponController
