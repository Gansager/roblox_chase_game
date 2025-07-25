-- LocalScript (StarterPlayer > StarterPlayerScripts) для отображения UI таймера и статуса "квача"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local uiEvent = ReplicatedStorage:WaitForChild("UpdateTagUI")

-- создаём UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TagUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0.2, 0, 0.1, 0)
label.AnchorPoint = Vector2.new(1, 0)
label.Position = UDim2.new(1, -20, 0, 0)
label.BackgroundTransparency = 0.5
label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
label.TextColor3 = Color3.new(0.392157, 0.05098, 0.05098)
label.TextScaled = true
label.Font = Enum.Font.SourceSansBold
label.Text = ""
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)  -- 12 пикселей радиус, можно подрегулировать
corner.Parent = label

local padding = Instance.new("UIPadding")
padding.PaddingLeft   = UDim.new(0, 12)  -- отступ слева 12px
padding.PaddingRight  = UDim.new(0, 12)  -- отступ справа 12px
padding.PaddingTop    = UDim.new(0, 6)   -- отступ сверху 6px
padding.PaddingBottom = UDim.new(0, 6)   -- отступ снизу 6px
padding.Parent = label

-- получаем события от сервера
uiEvent.OnClientEvent:Connect(function(action, value)
	if action == "Start" then
		screenGui.Enabled = true
		label.Text = "Quick! Tag another player!"
	elseif action == "Update" then
		label.Text = "Quick! Tag another player! Time left: " .. math.max(0, math.floor(value)) .. "s"
	elseif action == "Stop" then
		screenGui.Enabled = false
	elseif action == "Lose" then
		label.Text = "You lost! You were IT too long!"
		screenGui.Enabled = true
		task.delay(5, function()
			screenGui.Enabled = false
		end)
	end
end)
