-- LocalScript (StarterPlayer > StarterPlayerScripts) PlayerListUI.client.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player  = Players.LocalPlayer
local uiEvent = ReplicatedStorage:WaitForChild("UpdateTagUI")

-- Создаём ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name         = "PlayerListUI"
gui.ResetOnSpawn = false
gui.Parent       = player:WaitForChild("PlayerGui")

-- Контейнер для списка
local frame = Instance.new("Frame")
frame.Name                = "PlayerListFrame"
frame.Parent              = gui
frame.AnchorPoint         = Vector2.new(1, 0.5)
frame.Position            = UDim2.new(1, -20, 0.5, 0)
frame.Size                = UDim2.new(0, 200, 0, 0)
frame.BackgroundTransparency = 1
frame.BackgroundColor3    = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel     = 0

-- Скруглённые углы у фрейма
local frameCorner = Instance.new("UICorner", frame)
frameCorner.CornerRadius = UDim.new(0, 8)

-- Layout и паддинг
local uiList = Instance.new("UIListLayout", frame)
uiList.SortOrder = Enum.SortOrder.Name
uiList.Padding   = UDim.new(0, 4)

-- Автоматический ресайз фрейма под контент
uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    frame.Size = UDim2.new(0, 200, 0, uiList.AbsoluteContentSize.Y + 8)
end)

-- Таблица счётов проигрышей
local lostCounts = {}
-- Кто сейчас "квач"
local taggerName
-- Оставшееся время для квача
local remainingTime

-- Функция перерисовки списка
local function updatePlayerList()
    -- Удаляем старые метки
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    -- Создаём новые
    for _, pl in ipairs(Players:GetPlayers()) do
        local count = lostCounts[pl.Name] or 0

        -- Добавляем таймер только к квачу
        local timerText = ""
        if pl.Name == taggerName and remainingTime ~= nil then
            timerText = " – " .. remainingTime .. "s"
        end

        local label = Instance.new("TextLabel")
        label.Parent                = frame
        label.Size                  = UDim2.new(1, -8, 0, 28)
        label.BackgroundTransparency= 0.3
        label.BackgroundColor3      = Color3.fromRGB(40, 40, 40)
        label.Text                  = ("%s (%d)%s"):format(pl.Name, count, timerText)
        label.Font                  = Enum.Font.SourceSansBold
        label.TextSize              = 20
        label.TextXAlignment        = Enum.TextXAlignment.Center
        label.TextYAlignment        = Enum.TextYAlignment.Center
        label.TextColor3            = (pl.Name == taggerName)
                                      and Color3.fromRGB(150, 20, 20)
                                      or Color3.fromRGB(220, 220, 220)

        local corner = Instance.new("UICorner", label)
        corner.CornerRadius = UDim.new(0, 6)
    end
end

-- Обработка событий от сервера
uiEvent.OnClientEvent:Connect(function(action, payload)
    if action == "NewTagger" or action == "TagName" then
        -- Новый квач: сброс таймера и обновление списка
        taggerName    = payload
        remainingTime = nil
        updatePlayerList()

    elseif action == "LoseCount" then
        -- Приращение очка в таблице у всех
        if payload then
            lostCounts[payload] = (lostCounts[payload] or 0) + 1
            updatePlayerList()
        end

    elseif action == "TimerUpdate" then
        -- Получаем событие табличного таймера
        remainingTime = math.max(0, math.floor(payload))
        updatePlayerList()
    end
end)

-- Перерисовываем при входе/выходе игроков
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)

-- Первоначальный рендер
updatePlayerList()
