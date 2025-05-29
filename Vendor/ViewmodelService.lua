export type offset = {
	Type: "FromCamera" | "FromBase",
	CFrame: CFrame,
}
export type viewmodelSpring = {
	Type: "Rotation" | "Position",
	Spring: any,
}

export type DefaultSpring = {
	SpringPosition: any,
	SpringRotation: any?,
	CFrame: CFrame?,
	Magnitude: number,
	Enabled: boolean,
}

export type Viewmodel = {
	Model: Model,
	Sway: DefaultSpring,
	Bobbing: DefaultSpring,

	IncludeFOVOffset: boolean,

	CameraBoneName: string,
	CameraBoneDamper: { "Pos" | "Rot" },

	Offsets: {},
	Springs: {},

	Run: (self: Viewmodel) -> nil,
	Destroy: (self: Viewmodel) -> nil,
	Hide: (self: Viewmodel) -> nil,
	Show: (self: Viewmodel) -> nil,
	UpdatePosition: (self: Viewmodel) -> nil,
	SetOffset: (self: Viewmodel, index: string, type: "FromCamera" | "FromBase", cframe: CFrame) -> offset,
	UpdateOffset: (self: Viewmodel, index: string, cframe: CFrame) -> nil,
	RemoveOffset: (self: Viewmodel, index: string) -> nil,
	SetSpring: (
		self: Viewmodel,
		index: string,
		type: "Rotation" | "Position",
		value: Vector3 | Vector2 | number,
		speed: number,
		damper: number
	) -> viewmodelSpring,
	UpdateSpring: (self: Viewmodel, index: string, property: string, value: any) -> nil,
	RemoveSpring: (self: Viewmodel, index: string) -> nil,
}

local module = {
	viewModels = {},
	CurrentCameraOffset = CFrame.new(),
}

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local uis = game:GetService("UserInputService")

--// Instances
local globals = require(ReplicatedStorage.Shared.Globals)
local vendor = globals.Vendor

local camera = workspace.CurrentCamera

--// Modules
local spring = require(vendor.Spring)

--// Values

--// Functions
local function handleBaseOffsets(viewModel, baseC0)
	local rootJoint = viewModel.Model.PrimaryPart.RootJoint
	rootJoint.C0 = baseC0

	for _, offset in pairs(viewModel.Offsets) do
		if offset.Type ~= "FromBase" then
			continue
		end
		rootJoint.C0 *= offset.CFrame
	end
end

local function positionViewModel(viewModel: Viewmodel)
	local delta = uis:GetMouseDelta()
	viewModel.Sway.SpringPosition.Target = delta * (viewModel.Sway.Magnitude * 0.25)

	local swaySpring = viewModel.Sway.SpringPosition
	local swayPos = swaySpring.Position

	local swayOffset = Vector2.new(2, 1)
	viewModel.Sway.CFrame = CFrame.new(
		math.rad(-swayPos.X) * swayOffset.X,
		math.rad(swayPos.Y) * swayOffset.Y,
		math.rad(swayPos.Y) * swayOffset.Y
	) * CFrame.Angles(
		math.rad(-swayPos.Y) * (swayOffset.Y / 2),
		math.rad(-swayPos.X) * (swayOffset.X / 2),
		math.rad(swayPos.X)
	)

	if not viewModel.Sway.Enabled then
		viewModel.Sway.CFrame = CFrame.new()
	end

	local goal = camera.CFrame * viewModel.Sway.CFrame

	for _, offset in pairs(viewModel.Offsets) do
		if offset.Type ~= "FromCamera" then
			continue
		end
		goal *= offset.CFrame
	end

	for _, spring in pairs(viewModel.Springs) do
		local frame = CFrame.new()
		local fullSpring = spring.Spring

		if spring.Type == "Position" then
			frame = CFrame.new(fullSpring.Position)
		elseif spring.Type == "Rotation" then
			local springPosition = fullSpring.Position

			frame = CFrame.Angles(math.rad(springPosition.X), math.rad(springPosition.Y), math.rad(springPosition.Z))
		end

		goal *= frame
	end

	goal *= module.CurrentCameraOffset:Inverse()

	if viewModel.IncludeFOVOffset then
		goal *= CFrame.new(0, 0, ((camera.FieldOfView / 70) - 1) * 2)
	end

	viewModel.Model:PivotTo(goal)
end

local function calculateViewmodelWalkSway(viewmodel: Viewmodel)
	local character = Players.LocalPlayer.Character
	if not Players.LocalPlayer.Character then
		return
	end

	local humanoid: Humanoid? = character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local magnitude = viewmodel.Bobbing.Magnitude * (humanoid.WalkSpeed * 2)

	local isWalking = humanoid.MoveDirection.Magnitude > 0 and humanoid.FloorMaterial ~= Enum.Material.Air

	if isWalking and viewmodel.Bobbing.Enabled then
		viewmodel.i = time() * (30 + (magnitude / 5))
		viewmodel.p = Vector3.new(math.sin(viewmodel.i / 2 - 0.4), math.sin(viewmodel.i / 4) * 1) / -19
		viewmodel.r = Vector3.new(
			math.sin(viewmodel.i / 2) / 5,
			math.cos(viewmodel.i / 4 - 0.3) / 4,
			math.sin(viewmodel.i / 4 - 0.4)
		) / 20
	else
		viewmodel.i = 0
		viewmodel.p = Vector3.new()
		viewmodel.r = Vector3.new()
	end

	viewmodel:UpdateSpring("bobbingPositionSpring", "Target", viewmodel.p * magnitude)
	viewmodel:UpdateSpring("bobbingRotationSpring", "Target", (viewmodel.r * 2) * magnitude)
end

function module.new(model: Model?): Viewmodel
	local baseC0
	local viewmodel: Viewmodel = {
		Model = model or ReplicatedStorage:FindFirstChild("ViewModel", true):Clone(),

		Sway = {
			SpringPosition = spring.new(Vector2.new(0, 0)),
			CFrame = CFrame.new(),
			Magnitude = 1,
			Enabled = true,
		},

		Bobbing = {
			SpringPosition = 0,
			SpringRotation = 0,
			Magnitude = 1,
			Enabled = true,
		},

		IncludeFOVOffset = true,

		CameraBoneName = "CameraBone",
		CameraBoneDamper = {
			Pos = 1,
			Rot = 1,
		},

		Offsets = {},
		Springs = {},

		Run = function(self)
			self:Show()
			table.insert(module.viewModels, self)
		end,
		Destroy = function(self)
			table.remove(module.viewModels, table.find(module.viewModels, self))

			self.Model:Destroy()
		end,
		Hide = function(self)
			self.Model.Parent = game
		end,
		Show = function(self)
			self.Model.Parent = camera
		end,
		UpdatePosition = function(self)
			positionViewModel(self)
		end,
		SetOffset = function(self, index: string, type: "FromCamera" | "FromBase", cframe: CFrame): offset
			self.Offsets[index] = { ["Type"] = type, ["CFrame"] = cframe }

			handleBaseOffsets(self, baseC0)
			return self.Offsets[index]
		end,
		UpdateOffset = function(self, index: string, cframe: CFrame)
			self.Offsets[index].CFrame = cframe

			handleBaseOffsets(self, baseC0)
		end,
		RemoveOffset = function(self, index: string)
			self.Offsets[index] = nil

			handleBaseOffsets(self, baseC0)
		end,
		SetSpring = function(
			self,
			index: string,
			type: "Rotation" | "Position",
			value: Vector3 | Vector2 | number,
			speed: number,
			damper: number
		): viewmodelSpring
			local newSpring = spring.new(value)
			newSpring.Speed = speed
			newSpring.Damper = damper

			self.Springs[index] = { ["Type"] = type, ["Spring"] = newSpring }

			return self.Springs[index]
		end,
		UpdateSpring = function(self, index: string, property: string, value: any)
			self.Springs[index].Spring[property] = value
		end,
		RemoveSpring = function(self, index: string)
			self.Springs[index] = nil
		end,
	}

	local primaryPart = viewmodel.Model.PrimaryPart
	baseC0 = primaryPart.RootJoint.C0

	viewmodel.Sway.SpringPosition.Speed = 15
	viewmodel.Sway.SpringPosition.Damper = 0.6

	viewmodel.Bobbing.SpringRotation = viewmodel:SetSpring("bobbingRotationSpring", "Rotation", Vector3.zero, 20, 0.4)
	viewmodel.Bobbing.SpringPosition = viewmodel:SetSpring("bobbingPositionSpring", "Rotation", Vector3.zero, 20, 0.6)

	return viewmodel
end

function module:GetViewmodel(index: number?): Viewmodel
	index = index or 1
	return self.viewModels[index]
end

local logCFrame = CFrame.new()
RunService:BindToRenderStep("RunViewmodels", Enum.RenderPriority.Character.Value, function()
	module.CurrentCameraOffset = CFrame.new()

	for _, viewmodel: Viewmodel in ipairs(module.viewModels) do
		local cameraBone = viewmodel.Model:FindFirstChild(viewmodel.CameraBoneName)
		if cameraBone then
			local diffAng = (cameraBone.Orientation - viewmodel.Model.PrimaryPart.Orientation)
				/ viewmodel.CameraBoneDamper.Rot
			local diffPos = (cameraBone.Position - viewmodel.Model.PrimaryPart.Position)
				/ viewmodel.CameraBoneDamper.Pos

			module.CurrentCameraOffset *= CFrame.new(diffPos) * CFrame.Angles(
				math.rad(diffAng.X),
				math.rad(diffAng.Y),
				math.rad(diffAng.Z)
			)
		end

		positionViewModel(viewmodel)
		calculateViewmodelWalkSway(viewmodel)
	end

	camera.CFrame *= logCFrame:Inverse()
	camera.CFrame *= module.CurrentCameraOffset

	logCFrame = module.CurrentCameraOffset
end)

--// Main //--

return module
