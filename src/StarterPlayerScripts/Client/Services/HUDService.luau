local HUD = {}

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

--// Instances
local player = Players.LocalPlayer
local gui = ReplicatedStorage.Assets.Gui:WaitForChild("HUD")
local assets = ReplicatedStorage.Assets
local sounds = assets.Sounds

--// Modules
local Globals = require(ReplicatedStorage.Shared.Globals)

local DamageService = require(Globals.Client.Services.DamageService)
local Util = require(Globals.Vendor.Util)
local ViewmodelService = require(Globals.Vendor.ViewmodelService)

--// Values
local currentCrosshair

--// Functions

local pumpFunctions = {
	Mars = function(crosshairFrame: ImageLabel)
		local ti_1 = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
		local ti_2 = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

		Util.tween(crosshairFrame, ti_1, { Size = UDim2.fromScale(0.4, 0.2) })
		task.delay(0.1, Util.tween, crosshairFrame, ti_2, { Size = UDim2.fromScale(0.2, 0.2) })
	end,

	Revolver = function(crosshairFrame: ImageLabel)
		local ti_1 = TweenInfo.new(0.05, Enum.EasingStyle.Linear)
		local ti_2 = TweenInfo.new(0.5, Enum.EasingStyle.Elastic)

		Util.tween(crosshairFrame, ti_1, { Size = UDim2.fromScale(0.25, 0.2) }, false, function()
			Util.tween(crosshairFrame, ti_2, { Size = UDim2.fromScale(0.2, 0.2) })
		end)
	end,

	Rifle = function(crosshairFrame: Frame)
		local ti_0 = TweenInfo.new(0.5, Enum.EasingStyle.Elastic)
		local ti_1 = TweenInfo.new(0.35, Enum.EasingStyle.Linear)
		local ti_2 = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local direction = math.random(0, 1)

		crosshairFrame.Rotation = direction == 0 and -15 or 15

		Util.tween(crosshairFrame, ti_0, { Rotation = 0 })
		Util.tween(crosshairFrame.Left, ti_1, { Position = UDim2.fromScale(0.25, 0.75) })
		Util.tween(crosshairFrame.Right, ti_1, { Position = UDim2.fromScale(0.75, 0.75) })
		Util.tween(crosshairFrame.Up, ti_1, { Position = UDim2.fromScale(0.5, 0.25) })

		task.delay(
			0.1,
			Util.tween,
			{ crosshairFrame.Up, crosshairFrame.Left, crosshairFrame.Right },
			ti_2,
			{ Position = UDim2.fromScale(0.5, 0.5) }
		)
	end,
}

local function shiftCrosshair(crosshair: Instance, hide: boolean?)
	local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quad)

	local startSize = UDim2.fromScale(0.1, 0.1)
	local sizeGoal = UDim2.fromScale(0.2, 0.2)
	local transparencyGoal = 0

	local startRotation = -10
	local rotationGoal = 0

	if hide then
		startSize = UDim2.fromScale(0.2, 0.2)
		sizeGoal = UDim2.fromScale(0.25, 0.25)
		transparencyGoal = 1

		startRotation = 0
		rotationGoal = 10
	end

	crosshair.Size = startSize
	crosshair.Rotation = startRotation
	crosshair.Visible = true

	Util.tween(crosshair, ti, { Size = sizeGoal, Rotation = rotationGoal })

	if crosshair:IsA("ImageLabel") then
		Util.tween(crosshair, ti, { ImageTransparency = transparencyGoal })
	end

	for _, imageLabel in ipairs(crosshair:GetChildren()) do
		Util.tween(imageLabel, ti, { ImageTransparency = transparencyGoal })
	end
end

function HUD:HideCrosshair(crosshairName)
	local crosshairFrame = gui.Crosshairs:FindFirstChild(crosshairName)
	if not crosshairFrame then
		return
	end

	shiftCrosshair(crosshairFrame, true)
end

function HUD:ShowCrosshair(crosshairName)
	if currentCrosshair then
		self:HideCrosshair(currentCrosshair)
	end
	currentCrosshair = crosshairName

	local crosshairFrame = gui.Crosshairs:FindFirstChild(crosshairName)
	if not crosshairFrame then
		return
	end

	shiftCrosshair(crosshairFrame)
end

function HUD:PumpCrosshair()
	if not currentCrosshair or not pumpFunctions[currentCrosshair] then
		return
	end

	local crosshair = gui.Crosshairs:FindFirstChild(currentCrosshair)
	pumpFunctions[currentCrosshair](crosshair)
end

local function setHitmarkerColor(frame: Frame, color: Color3)
	for _, line in ipairs(frame:GetChildren()) do
		if not line:IsA("Frame") then
			continue
		end

		line.BackgroundColor3 = color
	end
end

function HUD:ShowHitmarker(hitInfo: DamageService.hitInfo)
	local damage: DamageService.damage = hitInfo.Damage
	local hitmarker: Frame = gui.Hitmarker:Clone()
	hitmarker.Name = "InUse"
	hitmarker.Parent = gui
	hitmarker.Visible = true

	local ti = TweenInfo.new(0.5, Enum.EasingStyle.Quart)
	local ti_0 = TweenInfo.new(0.5, Enum.EasingStyle.Linear)

	if hitInfo.Damage.Type == "Melee" then
		Util.PlaySound(sounds.HitMarker, script, 0.05)
	else
		Util.PlaySound(sounds.HitMarker, script, 0.05)
	end

	local isHeadshot = hitInfo.Result and hitInfo.Result.Instance.Name == "Head"

	if damage.IsCritical then
		setHitmarkerColor(hitmarker, Color3.fromRGB(255, 100, 00))

		if isHeadshot then
			setHitmarkerColor(hitmarker, Color3.fromRGB(255, 0, 0))
		end
	elseif isHeadshot then
		setHitmarkerColor(hitmarker, Color3.fromRGB(255, 235, 135))
	end

	Util.tween(hitmarker.Marker_0, ti, { Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(0, 1, 0, 0) })
	Util.tween(hitmarker.Marker_1, ti, { Position = UDim2.fromScale(0.1, 0.285), Size = UDim2.new(0, 1, 0, 0) })
	Util.tween(hitmarker.Marker_2, ti, { Position = UDim2.fromScale(0.9, 0.285), Size = UDim2.new(0, 1, 0, 0) })

	Util.tween(
		{ hitmarker.Marker_0, hitmarker.Marker_1, hitmarker.Marker_2 },
		ti_0,
		{ BackgroundTransparency = 1 },
		false,
		function()
			hitmarker:Destroy()
		end
	)
end

local bulletIcons = {
	Shotgun = "rbxassetid://70895388151324",
	Rifle = "rbxassetid://113794874281059",
	Revolver = "rbxassetid://111219601407144",
}

function HUD:SwitchAmmoIcon(icon: "Revolver" | "Rifle" | "Shotgun")
	local ti = TweenInfo.new(0.5, Enum.EasingStyle.Quart)

	local ammoFrame = gui.Ammo
	local oldIcon = ammoFrame.BulletIcon
	local newIcon = oldIcon:Clone()

	newIcon.ImageTransparency = 1
	newIcon.Size = UDim2.fromScale(0.5, 0.5)
	newIcon.Position = UDim2.fromScale(0.775, 0.75)

	newIcon.Image = bulletIcons[icon]

	newIcon.Parent = ammoFrame
	oldIcon.Name = "Deleting"

	Util.tween(
		oldIcon,
		ti,
		{ ImageTransparency = 1, Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.775, 0.15) },
		false,
		function()
			oldIcon:Destroy()
		end
	)
	Util.tween(
		newIcon,
		ti,
		{ ImageTransparency = 0.5, Size = UDim2.fromScale(0.75, 0.75), Position = UDim2.fromScale(0.775, 0.45) }
	)
end

function HUD:SwitchToAmmo(ammoType: "PrimaryAmmo" | "SecondaryAmmo", icon: "Revolver" | "Rifle" | "Shotgun")
	local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quart)
	local ammoFrame = gui.Ammo
	local ammoGroup = ammoFrame[ammoType]
	local altAmmoGroup

	if ammoType == "PrimaryAmmo" then
		altAmmoGroup = ammoFrame.SecondaryAmmo
	else
		altAmmoGroup = ammoFrame.PrimaryAmmo
	end

	Util.tween(altAmmoGroup, ti, { Size = UDim2.fromScale(0.75, 0.75), GroupTransparency = 0.5 })
	Util.tween(ammoGroup, ti, { Size = UDim2.fromScale(1, 1), GroupTransparency = 0 })
	self:SwitchAmmoIcon(icon)
end

function HUD:SwitchPrimaryAmmo(currentAmmo: number, storedAmmo: number, icon: "Revolver" | "Rifle" | "Shotgun")
	self:SwitchToAmmo("PrimaryAmmo", icon)

	local ammoFrame = gui.Ammo
	local oldAmmoGroup = ammoFrame.PrimaryAmmo
	local newAmmoGroup = oldAmmoGroup:Clone()

	local ti = TweenInfo.new(0.35, Enum.EasingStyle.Quad)

	newAmmoGroup.Size = UDim2.fromScale(0.5, 0.5)
	newAmmoGroup.GroupTransparency = 1

	newAmmoGroup.Parent = ammoFrame
	oldAmmoGroup.Name = "Deleting"

	newAmmoGroup.Current.Text = currentAmmo
	newAmmoGroup.Stored.Text = storedAmmo

	Util.tween(oldAmmoGroup, ti, { GroupTransparency = 1, Size = UDim2.fromScale(1.5, 1.5) }, false, function()
		oldAmmoGroup:Destroy()
	end)
	Util.tween(newAmmoGroup, ti, { GroupTransparency = 0, Size = UDim2.fromScale(1, 1) })
end

function HUD:ToggleSecondaryAmmo(value: boolean)
	local goal = value and 0 or 1
	local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quart)

	Util.tween(gui.Ammo.SecondaryAmmo, ti, { GroupTransparency = goal })
end

function HUD:PumpAmmo(ammoType: "PrimaryAmmo" | "SecondaryAmmo")
	local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	local ti_0 = TweenInfo.new(0.5, Enum.EasingStyle.Elastic)

	local ammoFrame = gui.Ammo
	local ammoGroup = ammoFrame[ammoType]

	ammoGroup.Current.Size = UDim2.fromScale(0.55, 0.45)
	local direction = math.random(0, 1)

	ammoGroup.Current.Rotation = direction == 0 and -10 or 10

	Util.tween(ammoGroup.Current, ti, { Size = UDim2.fromScale(0.4, 0.3) })
	Util.tween(ammoGroup.Current, ti_0, { Rotation = 0 })
end

function HUD:UpdateAmmo(
	ammoType: "PrimaryAmmo" | "SecondaryAmmo",
	currentAmmo: number,
	storedAmmo: number,
	pumpDisplay: boolean?
)
	local ammoFrame = gui.Ammo
	local ammoGroup = ammoFrame[ammoType]

	ammoGroup.Current.Text = currentAmmo
	ammoGroup.Stored.Text = storedAmmo

	if pumpDisplay then
		HUD:PumpAmmo(ammoType)
	end
end

function HUD:OnSpawn()
	UserInputService.MouseIconEnabled = false
end

--// Main //--

RunService.RenderStepped:Connect(function()
	--local size = workspace.CurrentCamera.ViewportSize / 1.7

	local x, y = ViewmodelService.CurrentCameraOffset:ToEulerAnglesXYZ()

	for _, crosshair: Frame in ipairs(gui.Crosshairs:GetChildren()) do
		if crosshair:IsA("UIAspectRatioConstraint") then
			continue
		end
		crosshair.Position = UDim2.fromScale(0.5 + (y / 1.65), 0.5 + (x / 1.65))
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
gui.Enabled = true

return HUD
