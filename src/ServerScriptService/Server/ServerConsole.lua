local module = {}

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Instances
local Globals = require(ReplicatedStorage.Shared.Globals)

--// Modules
local net = require(Globals.Packages.Net)
local commands = require(Globals.Shared.Commands)

local doCommandEvent = net:RemoteEvent("DoCommand")

--// Values

--// Functions
local function doCommand(player, catagory, commandIndex, ...)
	if not catagory then
		warn("Not in catagory")
		return
	end

	local command = commands[catagory][commandIndex]

	if not command["ExecuteServer"] then
		return
	end
	command:ExecuteServer(player, ...)
end

--// Main //--
net:Connect("DoCommand", doCommand)

return module
