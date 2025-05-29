export type damage = {
	Amount: number,
	Source: string,
	Type: "Spontanious" | "Melee" | "Bullet",
	Dealer: Instance,
	Team: Team?,
	IsCritical: boolean?,
}

export type hitInfo = {
	Damage: damage,
	Model: Model?,
	Humanoid: Humanoid | boolean?,
	Result: RaycastResult?,
	OriginCFrame: CFrame?,
	IsCritical: boolean?,
}

local damageService = {
	CritChance = 15,
}

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Instances

--// Modules
local Globals = require(ReplicatedStorage.Shared.Globals)
local Net = require(Globals.Packages.Net)

--// Values

local rng = Random.new()

--// Functions

function damageService.new(
	amount: number,
	source: string,
	type: "Spontanious" | "Melee" | "Bullet",
	dealer: Instance,
	team: Team?,
	isCritical: boolean?, -- will override critChance
	critChance: number? -- Default = damageService.CritChance
): damage
	local newDamage: damage = {
		Amount = amount,
		Source = source,
		Type = type,
		Dealer = dealer,
		Team = team,
		IsCritical = isCritical,
	}

	critChance = critChance or damageService.CritChance

	if newDamage.IsCritical == nil then
		newDamage.IsCritical = rng:NextNumber(0, 100) <= critChance
	end

	return newDamage
end

function damageService.createRaycast(
	damage: damage,
	origin: Vector3,
	directionCFrame: CFrame,
	spreadOffset: CFrame?,
	raycastParams: RaycastParams?
)
	spreadOffset = spreadOffset or CFrame.new()

	local newDirection = (directionCFrame * spreadOffset).LookVector * 350
	if not raycastParams then
		raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { damage.Dealer }
	end

	local raycast = workspace:Raycast(origin, newDirection, raycastParams)
	local model
	local humanoid

	if raycast then
		model = raycast.Instance:FindFirstAncestorOfClass("Model")
		humanoid = model and (model:FindFirstChild("Humanoid") or model:HasTag("Armor"))
	end

	return model, humanoid, raycast
end

function damageService.createHitbox(damage: damage, cframe: CFrame, size: Vector3, overlapParams: OverlapParams?)
	if not overlapParams then
		overlapParams = OverlapParams.new()
		overlapParams.FilterDescendantsInstances = { damage.Dealer }
	end

	local hits = workspace:GetPartBoundsInBox(cframe, size, overlapParams)

	local hitEnemies = {}

	for _, part: BasePart in ipairs(hits) do
		local model = part:FindFirstAncestorOfClass("Model")

		if not model then
			continue
		end

		hitEnemies[model] = model
	end

	return hitEnemies
end

function damageService.dealDamage(hits: { hitInfo })
	local hitsArray = {}

	for _, hitInfo: hitInfo in pairs(hits) do
		if not hitInfo.Result then
			continue
		end

		hitInfo.Result = {
			Distance = hitInfo.Result.Distance,
			Instance = hitInfo.Result.Instance,
			Material = hitInfo.Result.Material,
			Normal = hitInfo.Result.Normal,
			Position = hitInfo.Result.Position,
		}

		table.insert(hitsArray, hitInfo)
	end

	Net:RemoteEvent("DealDamage"):FireServer(hitsArray)
end

function damageService.getDamageNumber(hitPart: BasePart, damage: damage)
	local damageAmount = damage.Amount
	local isCritical = damage.IsCritical

	if hitPart.Name == "Head" then
		damageAmount *= 1.5
	elseif string.match(hitPart.Name, "Arm") then
		damageAmount *= 0.75
	elseif string.match(hitPart.Name, "Leg") then
		damageAmount *= 0.5
	end

	if isCritical then
		damageAmount *= 2
	end

	return damageAmount
end

local function getSpreadCFrame(spread: number)
	return CFrame.Angles(
		math.rad(rng:NextNumber(-spread, spread)),
		math.rad(rng:NextNumber(-spread, spread)),
		math.rad(rng:NextNumber(-spread, spread))
	)
end

function damageService:CreateDamagingCast(
	damage: damage,
	origin: Vector3,
	directionCFrame: CFrame,
	spread: number?,
	count: number?
): { hitInfo }
	local hits: { hitInfo } = {}

	for i = 1, count or 1 do
		-- detecthit
		local spreadCFrame = spread and getSpreadCFrame(spread) or CFrame.new()
		local model: Model?, humanoid, result: RaycastResult? =
			self.createRaycast(damage, origin, directionCFrame, spreadCFrame)

		if not result then
			continue
		end

		local damageNumber = damageService.getDamageNumber(result.Instance, damage)

		local index = model or result.Instance

		if not humanoid then
			index = "A" .. i
		end

		if hits[index] then
			hits[index].Damage.Amount += damageNumber
		else
			hits[index] = {
				Damage = table.clone(damage),
				Humanoid = humanoid,
				Model = model,
				Result = result,
				OriginCFrame = directionCFrame * spreadCFrame,
			}

			hits[index].Damage.Amount = damageNumber
		end
	end

	damageService.dealDamage(hits)
	return hits
end

function damageService:CreateDamagingBox(damage: damage, originCFrame: CFrame, size: Vector3): { hitInfo }
	local cframe = originCFrame * CFrame.new(0, 0, -size.Z / 2)
	local hits: { hitInfo } = {}

	for index, model: Model in pairs(self.createHitbox(damage, cframe, size)) do
		local direction = CFrame.lookAt(originCFrame.Position, model:GetPivot().Position)
		local model: Model?, humanoid, result: RaycastResult? =
			self.createRaycast(damage, originCFrame.Position, direction)

		if not result or not humanoid then
			continue
		end

		local damageNumber = damageService.getDamageNumber(model.PrimaryPart, damage)

		hits[index] = {
			Damage = table.clone(damage),
			Humanoid = humanoid,
			Model = model,
			Result = result,
			OriginCFrame = direction,
		}

		hits[index].Damage.Amount = damageNumber
	end

	damageService.dealDamage(hits)
	return hits
end

return damageService
