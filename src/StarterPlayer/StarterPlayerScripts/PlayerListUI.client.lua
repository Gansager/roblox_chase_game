-- LocalScript (StarterPlayer > StarterPlayerScripts) PlayerListUI.client.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local uiEvent   = ReplicatedStorage:WaitForChild("UpdateTagUI")

-- создаём GUI
local gui = Instance.new("ScreenGui")
gui.Name         = "PlayerListUI"
gui.ResetOnSpawn = false
gui.Parent       = player:WaitForChild("PlayerGui")

-- контейнер
local frame = Instance.new("Frame")
frame.Name                = "PlayerListFrame"
frame.Parent              = gui
frame.AnchorPoint         = Vector2.new(1, 0.5)
frame.Position            = UDim2.new(1, -20, 0.5, 0)
frame.Size                = UDim2.new(0, 200, 0, 0)
frame.BackgroundTransparency = 1
frame.BackgroundColor3    = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel     = 0

-- скруглённые углы
local frameCorner = Instance.new("UICorner", frame)
frameCorner.CornerRadius = UDim.new(0, 8)

-- layout
local uiList = Instance.new("UIListLayout", frame)
uiList.SortOrder = Enum.SortOrder.Name
uiList.Padding   = UDim.new(0, 4)

-- автоматически подгоняем высоту
uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    frame.Size = UDim2.new(0, 200, 0, uiList.AbsoluteContentSize.Y + 8)
end)

-- таблица проигрышей
local lostCounts = {}

-- текущее имя «квача»
local taggerName

-- обновление списка
local function updatePlayerList()
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    for _, pl in ipairs(Players:GetPlayers()) do
        local count = lostCounts[pl.Name] or 0

        local label = Instance.new("TextLabel")
        label.Parent              = frame
        label.Size                = UDim2.new(1, -8, 0, 28)
        label.BackgroundTransparency = 0.3
        label.BackgroundColor3    = Color3.fromRGB(40, 40, 40)
        label.Text                = ("%s (%d)"):format(pl.Name, count)
        label.Font                = Enum.Font.SourceSansBold
        label.TextSize            = 20
        label.TextXAlignment      = Enum.TextXAlignment.Center
        label.TextYAlignment      = Enum.TextYAlignment.Center
        label.TextColor3          = (pl.Name == taggerName) and Color3.fromRGB(150, 20, 20) or Color3.fromRGB(220, 220, 220)

        local corner = Instance.new("UICorner", label)
        corner.CornerRadius = UDim.new(0, 6)
    end
end

-- обработка RemoteEvent
uiEvent.OnClientEvent:Connect(function(action, payload)
    print("[Client] Event:", action, payload)  -- Отладка

    if action == "NewTagger" or action == "TagName" then
        taggerName = payload
        updatePlayerList()

    elseif action == "Lose" then
        if payload then
            print("[Client] Lose for:", payload)
            lostCounts[payload] = (lostCounts[payload] or 0) + 1
        end
        updatePlayerList()
    end
end)

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)

updatePlayerList()
