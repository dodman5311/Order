export type damage = {
	Amount: number,
	Source: string,
	Type: "Spontanious" | "Melee" | "Bullet",
	Dealer: Instance,
	Team: Team?,
}

export type hitInfo = {
	Damage: damage,
	Model: Model?,
	Humanoid: Humanoid | boolean?,
	Result: RaycastResult?,
	OriginCFrame: CFrame?,
	IsCritical: boolean?,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Globals = require(ReplicatedStorage.Shared.Globals)
local Net = require(Globals.Packages.Net)

local damageService = {}

local function damageFakeHealth(model: Model, damageNumber: number)
	local health = model:GetAttribute("Health")
	local maxHealth = model:GetAttribute("MaxHealth")
	model:SetAttribute("Health", math.clamp(health - damageNumber, 0, maxHealth))
end

local function damageHumanoid(humanoid: Humanoid, damageNumber: number)
	humanoid:TakeDamage(damageNumber)
end

local function pushObjectFromBullet(hitInfo: hitInfo)
	if hitInfo.Damage.Type ~= "Bullet" then
		return
	end
	local part: BasePart = hitInfo.Result.Instance

	part:ApplyImpulseAtPosition(hitInfo.OriginCFrame.LookVector * 50, hitInfo.Result.Position)
end

function damageService.dealDamage(hits: { hitInfo })
	for _, hitInfo: hitInfo in ipairs(hits) do
		pushObjectFromBullet(hitInfo)

		if not hitInfo.Humanoid then
			continue
		end

		if hitInfo.Humanoid == true then
			damageFakeHealth(hitInfo.Model, hitInfo.Damage.Amount)
		else
			damageHumanoid(hitInfo.Humanoid, hitInfo.Damage.Amount)
		end
	end
end

Net:Connect("DealDamage", function(player, hits: { hitInfo })
	damageService.dealDamage(hits)
	Net:RemoteEvent("DealDamage"):FireAllClients(hits, player)
end)

return damageService
