--[[

  ___  _____  ______             _   _            
 |__ \|  __ \|  ____|         (_) | | |           
    ) | |  | | |__   _ __ ___  _| |_| |_ ___ _ __ 
   / /| |  | |  __| | '_ ` _ \| | __| __/ _ \ '__|
  / /_| |__| | |____| | | | | | | |_| ||  __/ |   
 |____|_____/|______|_| |_| |_|_|\__|\__\___|_|   
                
          Create beautiful ui particles!
  
                    By @Synitx     
         Please don't re-sell this product

]]
--

local System = {}
local tweenService = game:GetService("TweenService")

function System.new(position)
	local Settings = { -- Default values do not touch
		Amount = 10,
		LifeTime = Vector2.new(15, 20),
		Colors = { Color3.fromRGB(255, 255, 255) },
		Speed = 0.5,
		Size = 1,
		Position = position,
		Rotation = 0,
		Acceleration = UDim2.fromOffset(0, 0),
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
	}
	local items = {}

	function items:GetSettings()
		return Settings
	end
	function items:SetAmount(amount: number)
		if not amount then
			amount = 10
		end
		if amount > 100 then
			amount = 100
		end
		Settings.Amount = amount
	end
	function items:SetColor(tab)
		local p = {}
		for i, v in pairs(tab) do
			if typeof(v) == "Color3" then
				table.insert(p, v)
			end
		end
		Settings.Colors = p
	end
	function items:SetLifeTime(amount: Vector2)
		if amount then
			Settings.LifeTime = amount
		end
	end
	function items:SetSpeed(amount: number)
		if amount then
			Settings.Speed = amount
		end
	end
	function items:SetSize(amount: number)
		if amount then
			Settings.Size = amount
		end
	end
	function items:SetTexture(id: number)
		if tonumber(id) then
			if id <= 0 then
				Settings.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				return
			end
			Settings.Texture = "rbxassetid://" .. tostring(id)
		else
			Settings.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			warn("[2DEmit]: Texture id must be a number!")
		end
	end
	function items:SetRotation(deg: number)
		if deg then
			if tonumber(deg) then
				Settings.Rotation = tonumber(deg)
			else
				Settings.Rotation = 0
				warn("[2DEmit]: Rotation must be a number!")
			end
		end
	end
	function items:SetAcceleration(Acceleration: UDim2)
		if Acceleration then
			if typeof(options.Acceleration) == "UDim2" then
				Settings.Acceleration = UDim2.fromOffset(Acceleration.X.Offset, Acceleration.Y.Offset)
			end
		end
	end
	function items:Set(options)
		if typeof(options) == "table" then
			if options.Size then
				Settings.Size = options.Size
			end
			if options.Speed then
				Settings.Speed = options.Speed
			end
			if options.LifeTime then
				Settings.LifeTime = options.LifeTime
			end
			if options.Color then
				Settings.Colors = options.Color
			end
			if options.Amount then
				Settings.Amount = options.Amount
			end
			if options.Rotation then
				if tonumber(options.Rotation) then
					Settings.Rotation = tonumber(options.Rotation)
				else
					Settings.Rotation = 0
					warn("[2DEmit]: Rotation must be a number!")
				end
			end
			if options.Acceleration then
				if typeof(options.Acceleration) == "UDim2" then
					Settings.Acceleration =
						UDim2.fromOffset(options.Acceleration.X.Offset, options.Acceleration.Y.Offset)
				end
			end
			if options.Texture then
				if tonumber(options.Texture) then
					if options.Texture <= 0 then
						Settings.Texture = "rbxasset://textures/particles/sparkles_main.dds"
						return
					end
					Settings.Texture = "rbxassetid://" .. tostring(options.Texture)
				else
					Settings.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					warn("[2DEmit]: Texture id must be a number!")
				end
			end
		end
	end
	function items:Emit(amount: number)
		if not amount then
			amount = Settings.Amount
		end
		local player = game.Players.LocalPlayer
		local playerUI
		if not player then
			playerUI = game.StarterGui:FindFirstChild("2DEmitter")
			if not playerUI then
				playerUI = Instance.new("ScreenGui")
				playerUI.Name = "2DEmitter"
				playerUI.Parent = game.StarterGui
			end
		elseif not player:FindFirstChild("PlayerGui") then
			playerUI = game.StarterGui:FindFirstChild("2DEmitter")
			if not playerUI then
				playerUI = Instance.new("ScreenGui")
				playerUI.Name = "2DEmitter"
				playerUI.Parent = game.StarterGui
			end
		else
			playerUI = player.PlayerGui:FindFirstChild("2DEmitter")
			if not playerUI then
				playerUI = Instance.new("ScreenGui")
				playerUI.Name = "2DEmitter"
				playerUI.Parent = player.PlayerGui
			end
		end
		for number = 1, amount do
			local frame = Instance.new("ImageLabel")
			frame.Parent = playerUI
			frame.Name = "_particle." .. number
			frame.BorderSizePixel = 0
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Image = Settings.Texture or "rbxasset://textures/particles/sparkles_main.dds"
			frame.Size = UDim2.new(0, 15 + Settings.Size, 0, 15 + Settings.Size)
			frame.Position = position
			frame.BackgroundTransparency = 1
			if Settings.Colors and #Settings.Colors > 0 then
				frame.ImageColor3 = Settings.Colors[math.random(1, #Settings.Colors)]
			end
			local random = math.random(Settings.LifeTime.X, Settings.LifeTime.Y)
			local newPos = UDim2.new(0, 0, 0, -random)
			if (Settings.Acceleration.X.Offset ~= 0) or Settings.Acceleration.Y.Offset ~= 0 then
				newPos = Settings.Acceleration
					+ UDim2.fromOffset(
						math.random(Settings.LifeTime.X, Settings.LifeTime.Y),
						math.random(Settings.LifeTime.X, Settings.LifeTime.Y)
					)
			end
			local tween = tweenService:Create(
				frame,
				TweenInfo.new(Settings.Speed, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0),
				{
					Position = frame.Position + newPos,
					Rotation = Settings.Rotation,
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 0, 0, 0),
				}
			)
			tween:Play()
			tween.Completed:Connect(function()
				delay(0.1, function()
					frame:Destroy()
				end)
			end)
		end
	end
	return items
end

return System
