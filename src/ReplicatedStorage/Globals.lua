local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

return {
	Server = if RunService:IsServer() then ServerScriptService.Server else nil,
	Client = if RunService:IsClient() then Players.LocalPlayer.PlayerScripts.Client else nil,
	Services = if RunService:IsServer() then ServerScriptService.Server.Services else nil,
	Controllers = if RunService:IsClient() then Players.LocalPlayer.PlayerScripts.Client.Controllers else nil,
	Packages = ReplicatedStorage.Packages,
	Shared = ReplicatedStorage.Shared,
	Vendor = ReplicatedStorage.Vendor,
	Assets = ReplicatedStorage.Assets,
	Config = require(ReplicatedStorage.Shared.Config),
	Enums = require(ReplicatedStorage.Shared.Enums),
}
