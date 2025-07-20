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
label.Size = UDim2.new(0.5, 0, 0.1, 0)
label.Position = UDim2.new(0.25, 0, 0.05, 0)
label.BackgroundTransparency = 0.4
label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
label.TextColor3 = Color3.new(1, 0, 0)
label.TextScaled = true
label.Font = Enum.Font.SourceSansBold
label.Text = ""
label.Parent = screenGui

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
