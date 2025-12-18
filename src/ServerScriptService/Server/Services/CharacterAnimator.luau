export type characterData = {
	logNeckC0: CFrame,
	logRootC0: CFrame,
	logLeftHipC0: CFrame,
	logRightHipC0: CFrame,

	angle: number,
	character: Model,
}

local CharacterAnimator = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Services

local RUN_SERVICE = game:GetService("RunService")
local AnimationService = require(ReplicatedStorage.Vendor.AnimationService)

--// Instances

--// Modules

--// Values
local characters = {}

--// Functions

local function Slerp(angle1, angle2, t)
	local theta = angle2 - angle1
	angle1 += if theta > math.pi then 2 * math.pi elseif theta < -math.pi then -2 * math.pi else 0
	return angle1 + (angle2 - angle1) * t
end

local function calculageSpeedAngle(character)
	local velocity = character.PrimaryPart.AssemblyLinearVelocity
	local relativeVelocity = character.PrimaryPart.CFrame:VectorToObjectSpace(velocity)

	local zVelocity = -relativeVelocity.Z
	local xVelocity = math.abs(relativeVelocity.X)

	velocity = zVelocity

	if zVelocity > -0.1 then
		velocity = math.clamp(zVelocity, xVelocity, math.huge)
	end

	return velocity
end

function CharacterAnimator:AnimateCharacter(character: Model)
	local humanoid = character:FindFirstChild("Humanoid")
	local animationFolder = character:FindFirstChild("Animations")
	local torso = character:FindFirstChild("Torso")

	if not (humanoid and animationFolder and torso) then
		return
	end

	AnimationService:loadAnimations(character, animationFolder)

	local neck = torso.Neck
	local rootJoint = humanoid.RootPart.RootJoint
	local leftHip = torso["Left Hip"]
	local rightHip = torso["Right Hip"]

	local newCharacter: characterData = {
		logNeckC0 = neck.C0,
		logRootC0 = rootJoint.C0,
		logLeftHipC0 = leftHip.C0,
		logRightHipC0 = rightHip.C0,

		angle = 0,
		character = character,
	}

	AnimationService:playAnimation(character, "Idle", "Idle")

	table.insert(characters, newCharacter)
end

local function runStep(dt, characterData: characterData)
	local character = characterData.character

	local humanoid = character:FindFirstChild("Humanoid")
	local torso = character:FindFirstChild("Torso")

	if not (humanoid and torso) then
		return
	end

	local neck = torso.Neck
	local rootJoint = humanoid.RootPart.RootJoint
	local leftHip = torso["Left Hip"]
	local rightHip = torso["Right Hip"]

	local desiredAngle

	local moveVelocityXZ = (humanoid.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1))
	if moveVelocityXZ.Magnitude == 0 then -- Idle
		rootJoint.C0 = characterData.logRootC0
		leftHip.C0 = characterData.logLeftHipC0
		rightHip.C0 = characterData.logRightHipC0
		neck.C0 = characterData.logNeckC0

		AnimationService:stopAnimation(character, "Walk")
		desiredAngle = 0
	else -- Moving
		local walkAnim = AnimationService:playAnimation(character, "Walk", "Movement", true)

		local offset = humanoid.RootPart.CFrame.Rotation:PointToObjectSpace(moveVelocityXZ) * Vector3.new(1, 0, 1)
		desiredAngle = -math.atan2(-offset.X, -offset.Z)

		walkAnim:AdjustSpeed(calculageSpeedAngle(character) / 10)

		if math.abs(desiredAngle) > math.pi / 2 + 0.01 then
			desiredAngle = math.sign(desiredAngle) * (math.abs(desiredAngle) - math.pi)
		end
	end

	characterData.angle = Slerp(characterData.angle, desiredAngle, 1 - math.pow(2, -15 * dt))
	local torsoToRoot = torso.CFrame:ToObjectSpace(humanoid.RootPart.CFrame).Rotation
	local rotation = torsoToRoot * CFrame.Angles(0, -characterData.angle / 2, 0) * torsoToRoot:Inverse()

	if character:GetAttribute("Attacking") then
		neck.C0 = characterData.logNeckC0
		rootJoint.C0 = characterData.logRootC0
		rotation = torsoToRoot * CFrame.Angles(0, -characterData.angle, 0) * torsoToRoot:Inverse()
	else
		neck.C0 = CFrame.Angles(0, characterData.angle / 2, 0) * characterData.logNeckC0
		rootJoint.C0 = CFrame.Angles(0, -characterData.angle / 2, 0) * characterData.logRootC0
	end

	leftHip.C0 = rotation * characterData.logLeftHipC0
	rightHip.C0 = rotation * characterData.logRightHipC0
end

--// Main //--

RUN_SERVICE.Heartbeat:Connect(function(dt)
	for _, characterData in ipairs(characters) do
		runStep(dt, characterData)
	end
end)

return CharacterAnimator
