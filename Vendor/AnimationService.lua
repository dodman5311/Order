local module = { animations = {} }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Globals = require(ReplicatedStorage.Shared.Globals)

local janitor = require(Globals.Packages.Janitor)

--// Functions
function module:loadAnimations(subject: Model, animations: {} | Instance)
	local animationController = subject:FindFirstChildOfClass("Humanoid")
		or subject:FindFirstChildOfClass("AnimationController")
	if not animationController then
		return
	end

	local subjectJanitor = janitor.new()
	subjectJanitor:LinkToInstance(subject)

	if not self.animations[subject] then
		self.animations[subject] = {}
	end

	if typeof(animations) == "Instance" then
		animations = animations:GetChildren()
	end

	for _, animation in ipairs(animations) do
		self.animations[subject][animation.Name] = animationController.Animator:LoadAnimation(animation)
	end

	subjectJanitor:Add(function()
		self.animations[subject] = nil
	end)
end

function module:getAnimation(subject: Model, animationName: string): AnimationTrack?
	local animList = self.animations[subject]
	if not animList then
		return
	end
	local animation = animList[animationName]
	return animation
end

function module:getLoadedAnimations(subject: Model): {}?
	local animList = self.animations[subject]
	if not animList then
		return
	end
	return animList
end

function module:playAnimation(
	subject: Model,
	animationName: string,
	priority: Enum.AnimationPriority? | string?,
	noReplay: boolean?,
	fadeTime: number?,
	weight: number?,
	speed: number?
): AnimationTrack?
	local animation: AnimationTrack = self:getAnimation(subject, animationName)

	if not animation or (noReplay and animation.IsPlaying) then
		return animation
	end

	if priority then
		if typeof(priority) == "string" then
			priority = Enum.AnimationPriority[priority]
		end

		animation.Priority = priority
	end

	animation:Play(fadeTime, weight, speed)

	return animation
end

function module:stopAnimation(subject: Model, animationName: string, fadeTime: number?): AnimationTrack?
	local animation = self:getAnimation(subject, animationName)

	if not animation then
		return
	end
	self:getAnimation(subject, animationName):Stop(fadeTime)
	return animation
end

function module:stopAllAnimations(subject: Model, fadeTime: number?)
	local animationController = subject:FindFirstChildOfClass("Humanoid")
		or subject:FindFirstChildOfClass("AnimationController")
	if not animationController then
		return
	end

	local animator: Animator = animationController.Animator

	for _, animation: AnimationTrack in ipairs(animator:GetPlayingAnimationTracks()) do
		animation:Stop(fadeTime)
	end
end

--// Main //--

return module
