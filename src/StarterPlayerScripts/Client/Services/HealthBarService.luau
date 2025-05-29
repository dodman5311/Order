export type Health = {
	Amount: number,
	PrevousAmount: number,
	Max: number,
}

local HealthBarService = {}

--// Services
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Instances
local player = Players.LocalPlayer
local gui = ReplicatedStorage.Assets.Gui:WaitForChild("HealthBar")

--// Modules
local Globals = require(ReplicatedStorage.Shared.Globals)
local Util = require(Globals.Vendor.Util)
local Janitor = require(Globals.Packages.Janitor)
local HealthBarTimers = require(Globals.Vendor.Timer):newQueue()

--// Values

--// Functions

local function moveBars(healthGui: BillboardGui, health: Health, tween: boolean?)
	local CanvasGroup = healthGui:WaitForChild("CanvasGroup")
	local bar: CanvasGroup = CanvasGroup.Bar
	local fade: Frame = CanvasGroup.Fade

	local healthUnit = health.Amount / health.Max

	if not tween then
		bar.Size = UDim2.fromScale(healthUnit, 1)
		fade.Size = UDim2.fromScale(healthUnit, 1)
		return
	end

	local damageTaken = health.PrevousAmount - health.Amount

	local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quart)
	local ti_0 = TweenInfo.new(1, Enum.EasingStyle.Quad)
	local ti_1 = TweenInfo.new(0.25, Enum.EasingStyle.Quad)

	if damageTaken > 0 then
		Util.tween(bar, ti, { Size = UDim2.fromScale(healthUnit, 1) })
		Util.tween(fade, ti_0, { Size = UDim2.fromScale(healthUnit, 1) })
	else
		Util.tween(bar, ti_1, { Size = UDim2.fromScale(healthUnit, 1) })
		Util.tween(fade, ti_1, { Size = UDim2.fromScale(healthUnit, 1) })
	end
end

local function removeGui(healthGui: BillboardGui)
	local ti = TweenInfo.new(0.35, Enum.EasingStyle.Quad)

	Util.tween(healthGui.CanvasGroup, ti, { GroupTransparency = 1 })
	Util.tween(healthGui.Background, ti, { ImageTransparency = 1 })
	Util.addToCache(healthGui, 0.35)
end

local function createHealthGui(enemy: Model, health: Health): BillboardGui
	local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
	local healthGui: BillboardGui = Util.callFromCache(gui)
	healthGui.Parent = player.PlayerGui
	healthGui.Adornee = enemy

	moveBars(healthGui, health, true)

	healthGui.CanvasGroup.GroupTransparency = 1
	healthGui.Background.ImageTransparency = 1
	healthGui.Enabled = true

	Util.tween(healthGui.CanvasGroup, ti, { GroupTransparency = 0 })
	Util.tween(healthGui.Background, ti, { ImageTransparency = 0 })

	return healthGui
end

local function getHealthGui(enemy: Model, health: Health): BillboardGui
	local healthGui: BillboardGui?

	for _, foundHealthGui: BillboardGui in ipairs(player.PlayerGui:GetChildren()) do
		if foundHealthGui.Name ~= "HealthBar" or foundHealthGui.Adornee ~= enemy then
			continue
		end

		healthGui = foundHealthGui
	end
	return healthGui or createHealthGui(enemy, health)
end

local function healthChanged(enemy: Model, health: Health): BillboardGui
	local healthGui: BillboardGui = getHealthGui(enemy, health)
	moveBars(healthGui, health, true)

	return healthGui
end

function HealthBarService:ConnectEnemy(enemy: Model)
	local humanoid: Humanoid = enemy:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local health: Health = {
		Amount = humanoid.Health,
		PrevousAmount = humanoid.Health,
		Max = humanoid.MaxHealth,
	}

	local log = humanoid.Health

	local removeTimer = HealthBarTimers:new(enemy, 3, removeGui)
	local enemyJanitor = Janitor.new()
	enemyJanitor:Add(removeTimer, "Destroy")
	enemyJanitor:LinkToInstance(enemy)

	humanoid.HealthChanged:Connect(function(healthNumber)
		health.Amount = healthNumber
		health.PrevousAmount = log
		log = health.Amount
		local healthGui = healthChanged(enemy, health)
		removeTimer.Parameters = { healthGui }

		removeTimer:Reset()
		removeTimer:Run()

		if health.Amount <= 0 then
			removeTimer:Complete()
		end
	end)
end

local function connectEnemies()
	for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do
		HealthBarService:ConnectEnemy(enemy)
	end
end

function HealthBarService:Init()
	connectEnemies()
end

CollectionService:GetInstanceAddedSignal("Enemy"):Connect(function(enemy)
	HealthBarService:ConnectEnemy(enemy)
end)

return HealthBarService
