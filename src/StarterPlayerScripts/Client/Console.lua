--// Services
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Globals = require(ReplicatedStorage.Shared.Globals)

--// Instances
local guiInstance = ReplicatedStorage.Console
local player = Players.LocalPlayer

--// Modules
local commands = require(Globals.Shared.Commands)
local util = require(Globals.Vendor.Util)
local net = require(Globals.Packages.Net)

--// Values

local fullGui = {}
local inGui = false

local module = {}

local doCommandEvent = net:RemoteEvent("DoCommand")

--// Functions

local function doCommand(catagory, commandIndex, ...)
	if not catagory then
		warn("Not in catagory")
		return
	end

	doCommandEvent:FireServer(catagory, commandIndex, ...)

	local command = commands[catagory][commandIndex]

	if not command["ExecuteClient"] then
		return
	end
	command:ExecuteClient(...)
end

local function checkCommand()
	local inputBox: TextBox = fullGui.InputBox
	local currentText: string = inputBox.Text

	local commandString = string.split(currentText, ".")

	local categoryKey = commandString[1]
	local category = commands[categoryKey]
	if not category then
		return nil, nil, nil, commandString
	end

	local commandKey = commandString[2]
	local command = category[commandKey]
	if not command then
		return categoryKey, nil, nil, commandString
	end

	local parameters = table.clone(commandString)
	table.remove(parameters, 1)
	table.remove(parameters, 1)

	return categoryKey, commandKey, parameters, commandString
end

local function returnPressed(enterPressed)
	if not enterPressed then
		return
	end

	local categoryKey, commandKey, parameters = checkCommand()

	fullGui.InputBox.Text = ""

	for index, stringValue in ipairs(parameters) do
		local totalParams = commands[categoryKey][commandKey].Parameters()
		if stringValue == " " or stringValue == "" or index > #totalParams then
			continue
		end

		local list = totalParams[index].Options

		for _, value in ipairs(list) do
			if tostring(value) ~= stringValue then
				continue
			end

			parameters[index] = value
		end
	end

	doCommand(categoryKey, commandKey, table.unpack(parameters))
end

local function selectSuggestion(index, currentText)
	local inputBox: TextBox = fullGui.InputBox
	local logText = inputBox.Text
	local textLength = string.len(logText)
	local reducedLength = textLength - string.len(currentText)

	task.delay(0, function()
		inputBox.Text = string.sub(logText, 0, reducedLength) .. index .. "."
		inputBox.CursorPosition = string.len(inputBox.Text) + 1
	end)
end

local function selectLatestSuggestion()
	local _, _, _, commandString = checkCommand()
	local currentText = commandString[#commandString]

	local suggestion = fullGui.Suggestions:FindFirstChildOfClass("TextButton")

	selectSuggestion(suggestion.Text, currentText)
end

local function makeSuggestions(suggestionTable, currentText, currentParameterIndex)
	if not suggestionTable then
		return
	end

	for _, suggestion in pairs(fullGui.Suggestions:GetChildren()) do
		if not suggestion:IsA("TextButton") then
			continue
		end

		suggestion:Destroy()
	end

	if currentParameterIndex then
		local optionsTable = suggestionTable()[currentParameterIndex]
		if not optionsTable then
			return
		end

		suggestionTable = optionsTable.Options
	end

	for index, value in pairs(suggestionTable) do
		if tonumber(index) then
			index = tostring(value)
		end

		if not string.match(string.upper(index), string.upper(currentText)) then
			continue
		end

		local newSuggestion: TextButton = fullGui.Objects.Suggestion:Clone()
		newSuggestion.Parent = fullGui.Suggestions
		newSuggestion.Text = index
		newSuggestion.Visible = true

		newSuggestion.MouseButton1Click:Connect(function()
			selectSuggestion(index, currentText)
			fullGui.InputBox:ReleaseFocus()
		end)
	end
end

local function onBoxChanged()
	local categoryKey, commandKey, parameters, commandString = checkCommand()
	local currentText = commandString[#commandString]

	if #commandString == 1 then
		makeSuggestions(commands, currentText)
	elseif #commandString == 2 then
		makeSuggestions(commands[categoryKey], currentText)
	elseif #commandString > 2 and commandKey then
		makeSuggestions(commands[categoryKey][commandKey].Parameters, currentText, #parameters)

		fullGui.CommandPreview.Text = commandKey

		for _, value in ipairs(commands[categoryKey][commandKey].Parameters()) do
			fullGui.CommandPreview.Text = fullGui.CommandPreview.Text .. ` <{value.Name}>`
		end

		return
	end

	fullGui.CommandPreview.Text = ""
end

local function setUpGui()
	local newGui = guiInstance:Clone()
	newGui.Parent = player:WaitForChild("PlayerGui")

	for _, guiObject in ipairs(newGui:GetDescendants()) do
		fullGui[guiObject.Name] = guiObject
	end
	fullGui.Gui = newGui
	local inputBox: TextBox = newGui.Frame.InputBox

	inputBox.Changed:Connect(onBoxChanged)
	inputBox.FocusLost:Connect(returnPressed)
end

local function reset()
	for _, suggestion in pairs(fullGui.Suggestions:GetChildren()) do
		if not suggestion:IsA("TextButton") then
			continue
		end

		suggestion:Destroy()
	end
end

local function openGui()
	-- if player.UserId ~= 72859198 then
	-- 	return
	-- end

	--signals.PauseGame:Fire()

	local inputBox: TextBox = fullGui.InputBox
	inputBox:CaptureFocus()

	local ti = TweenInfo.new(0.1, Enum.EasingStyle.Quad)

	fullGui.Gui.Enabled = true
	fullGui.Frame.Position = UDim2.fromScale(0.5, -1)

	util.tween(fullGui.Frame, ti, { Position = UDim2.fromScale(0.5, 0.025) }, false, function()
		if UserInputService.GamepadEnabled then
			GuiService:Select(fullGui.Frame)
		end
	end, Enum.PlaybackState.Completed)

	task.delay(0, function()
		inputBox.Text = ""
	end)
end

local function closeGui()
	local ti = TweenInfo.new(0.1, Enum.EasingStyle.Quad)

	util.tween(fullGui.Frame, ti, { Position = UDim2.fromScale(0.5, -1) }, false, function()
		fullGui.Gui.Enabled = false
	end)

	reset()
end

--// Main //--

function module:GameInit()
	setUpGui()
	closeGui()
end

local function toggleConsole()
	if inGui then
		closeGui()
	else
		openGui()
	end

	inGui = not inGui
	UserInputService.MouseIconEnabled = inGui
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.DPadDown and (not gpe or inGui) then
		toggleConsole()
	end

	if input.KeyCode == Enum.KeyCode.Tab and fullGui.Gui.Enabled then
		selectLatestSuggestion()
	end

	if gpe then
		return
	end

	if input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.Tilde then
		toggleConsole()
	end
end)

return module
