local module = {}

local player = game:GetService("Players").LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = ReplicatedStorage.Assets
local cache = assets.Cache

local Globals = require(ReplicatedStorage.Shared.Globals)
local util = require(Globals.Vendor.Util)

function module.createEffect(rayResult, originalPlayer)
	if originalPlayer == player or not rayResult then
		return
	end

	local newHitEffect = assets.Effects.HitPart:Clone()

	newHitEffect.Hole.Transparency = 0
	newHitEffect.Parent = workspace
	newHitEffect.CFrame = CFrame.new(rayResult.Position, rayResult.Position + rayResult.Normal)
	newHitEffect.CFrame *= CFrame.Angles(math.rad(-90), 0, 0)

	newHitEffect.Anchored = false
	local newWeld = Instance.new("WeldConstraint")
	newWeld.Parent = newHitEffect
	newWeld.Part0 = rayResult.Instance
	newWeld.Part1 = newHitEffect

	for _, p in ipairs(newHitEffect:GetChildren()) do
		if not p:IsA("ParticleEmitter") then
			continue
		end
		p.Enabled = true
		task.delay(0.05, function()
			p.Enabled = false
		end)
	end
	task.delay(1.5, function()
		for i = 0, 1, 0.1 do
			task.wait(0.1)
			newHitEffect.Hole.Transparency = i
		end
		newHitEffect:Destroy()
	end)

	return newHitEffect
end

return module
