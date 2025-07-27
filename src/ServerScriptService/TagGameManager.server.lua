-- TagGameManager.server.lua
-- Скрипт управляет логикой игры "Доганялка" (tag game).
-- Здесь определяется, кто является "квачом" (IT), ведётся таймер,
-- передача роли при касании, проигрыши и обновление UI.

print("[TagGameManager] started via Rojo")

-- Получаем сервисы Roblox
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Переменные для текущего квача и времени начала отсчёта
local currentIt, tagStartTime

-- Максимальное время (в секундах), за которое квач должен догнать кого-то.
-- Если не успеет, он проигрывает.
local loseThreshold = 60

-- Таблица, чтобы отслеживать, кого недавно "тегнули" (чтобы избежать спама)
local recentTagged  = {}

-- Таблица с количеством поражений каждого игрока
local scores        = {}

-- Очередь для респауна игроков, которые проиграли
local respawnQueue = {}
local isProcessingQueue = false

-- RemoteEvent для синхронизации UI между сервером и клиентом
local uiUpdateEvent = ReplicatedStorage:FindFirstChild("UpdateTagUI")
if not uiUpdateEvent then
    uiUpdateEvent = Instance.new("RemoteEvent")
    uiUpdateEvent.Name   = "UpdateTagUI"
    uiUpdateEvent.Parent = ReplicatedStorage
end

----------------------------------------------------------------------
-- Вспомогательные функции
----------------------------------------------------------------------

-- Функция красит все части тела игрока (Character) в указанный цвет
local function colorCharacter(char, color)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.BrickColor = BrickColor.new(color)
        end
    end
end

-- Выбор случайного квача, если currentIt ещё не назначен
local function assignRandomIt()
    if currentIt then return end

    local valid = {} -- список игроков, которых можно сделать квачом
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character and pl.Character:FindFirstChild("Humanoid") and pl.Character.Humanoid.Health > 0 then
            table.insert(valid, pl)
        end
    end

    if #valid == 0 then
        currentIt = nil
        return
    end

    -- Случайный выбор игрока
    local chosen     = valid[math.random(1, #valid)]
    currentIt, tagStartTime = chosen, os.time()

    colorCharacter(chosen.Character, "Bright red") -- красим квача в красный
    uiUpdateEvent:FireClient(chosen,  "Start")     -- показываем поп‑ап "Ты квач!"
    uiUpdateEvent:FireAllClients("TagName", chosen.Name) -- всем показываем, кто квач
    print("[Auto] Назначен новый квач: " .. chosen.Name)
end

-- Обработка респауна игроков после проигрыша
local function processRespawnQueue()
    if isProcessingQueue then return end
    isProcessingQueue = true

    while #respawnQueue > 0 do
        local plr = table.remove(respawnQueue, 1)
        if plr and plr.Parent then
            plr:LoadCharacter()        -- респавним игрока
            plr.CharacterAdded:Wait()  -- ждём пока модель персонажа загрузится
            task.wait(0.5)

            -- Делаем этого игрока квачом
            currentIt, tagStartTime = plr, os.time()
            colorCharacter(plr.Character, "Bright red")
            uiUpdateEvent:FireClient(plr, "Start")
            uiUpdateEvent:FireAllClients("TagName", plr.Name)
            print("[Auto] Снова назначен квач: " .. plr.Name)
        end
    end

    isProcessingQueue = false
end

-- Когда квач не успел никого догнать
local function handleLose(plr)
    if not plr then return end

    -- Увеличиваем счёт поражений
    scores[plr.Name] = (scores[plr.Name] or 0) + 1
    print(plr.Name .. " проиграл и получил очко, итого: " .. scores[plr.Name])

    -- Показываем поп‑ап только проигравшему
    uiUpdateEvent:FireClient(plr, "Lose")
    -- Обновляем таблицу проигрышей у всех
    uiUpdateEvent:FireAllClients("LoseCount", plr.Name)

    -- Сбрасываем квача и "убиваем" персонажа
    currentIt = nil
    if plr.Character then plr.Character:BreakJoints() end

    -- Добавляем игрока в очередь на респаун
    table.insert(respawnQueue, plr)
    task.spawn(processRespawnQueue)
end

----------------------------------------------------------------------
-- Логика передачи квача при касании
----------------------------------------------------------------------

-- Максимальная дистанция для проверки настоящего касания
local MAX_TAG_DISTANCE = 0.1

local function tryTag(hit)
    if not currentIt or not currentIt.Character then return end

    -- Ищем модель игрока, которого коснулись
    local targetChar = hit:FindFirstAncestorWhichIsA("Model")
    if not (targetChar and targetChar:FindFirstChild("Humanoid")) then return end
    if targetChar == currentIt.Character then return end

    -- Игнорируем аксессуары, чтобы касание не срабатывало через шляпы и т.д.
    if hit:IsA("Accessory") or hit.Parent:IsA("Accessory") then return end

    -- Проверяем реальную дистанцию между центрами игроков
    local itRoot = currentIt.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not (itRoot and targetRoot) then return end
    if (itRoot.Position - targetRoot.Position).Magnitude > MAX_TAG_DISTANCE then
        return -- слишком далеко, значит не реальное касание
    end

    -- Проверяем кулдаун (нельзя передать слишком быстро)
    if recentTagged[targetChar] and tick() - recentTagged[targetChar] < 3 then return end

    -- Передача роли квача
    local prev = currentIt
    local targetPlr = Players:GetPlayerFromCharacter(targetChar)
    if not targetPlr then return end

    print("Передача квача → " .. targetPlr.Name)
    colorCharacter(prev.Character, "Medium stone grey") -- бывший квач становится серым
    colorCharacter(targetChar, "Bright red")            -- новый квач красный
    recentTagged[prev.Character] = tick()

    -- Обновляем текущего квача
    currentIt, tagStartTime = targetPlr, os.time()
    uiUpdateEvent:FireClient(prev, "Stop")              -- старый квач получает "Stop"
    uiUpdateEvent:FireClient(targetPlr, "Start")        -- новый получает "Start"
    uiUpdateEvent:FireAllClients("TagName", targetPlr.Name)
end

----------------------------------------------------------------------
-- Основной цикл: отслеживание времени квача
----------------------------------------------------------------------
spawn(function()
    while true do
        task.wait(1)

        -- Если квач не назначен — выбираем нового
        if not currentIt or not currentIt.Character then
            assignRandomIt()
        end

        -- Проверяем, не истёк ли таймер у текущего квача
        if currentIt and tagStartTime and currentIt.Character then
            local elapsed   = os.time() - tagStartTime
            local remaining = loseThreshold - elapsed

            -- Обновляем UI
            uiUpdateEvent:FireClient(currentIt, "Update", remaining)      -- таймер квачу
            uiUpdateEvent:FireAllClients("TimerUpdate", remaining)        -- таймер всем

            if remaining <= 0 then
                handleLose(currentIt) -- квач проиграл
            end
        end
    end
end)

----------------------------------------------------------------------
-- Назначение первого квача при входе игрока
----------------------------------------------------------------------
local function setInitialIt(plr)
    if currentIt then return end

    currentIt, tagStartTime = plr, os.time()
    colorCharacter(plr.Character, "Bright red")
    uiUpdateEvent:FireClient(plr, "Start")
    uiUpdateEvent:FireAllClients("TagName", plr.Name)
end

----------------------------------------------------------------------
-- Подключение событий касания к игрокам
----------------------------------------------------------------------
local function connectTouch(plr)
    -- Когда персонаж игрока загрузится
    plr.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart")
        task.wait(0.5)
        -- Навешиваем событие касания на HumanoidRootPart
        char.HumanoidRootPart.Touched:Connect(tryTag)
    end)
end

----------------------------------------------------------------------
-- Подписка на вход игроков
----------------------------------------------------------------------
Players.PlayerAdded:Connect(function(plr)
    connectTouch(plr)
    if plr.Character and not currentIt then
        setInitialIt(plr)
    end
end)
