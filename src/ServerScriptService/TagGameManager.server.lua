-- TagGameManager.server.lua
-- Логика игры "Доганялка":
-- 1. Управляет тем, кто является "квачом" (IT).
-- 2. Следит за таймером квача (если не успел догнать – проиграл).
-- 3. Передает роль квача при приближении к другим игрокам (без использования Touched).
-- 4. Синхронизирует UI с клиентами через RemoteEvent.

print("[TagGameManager] started via Rojo")

-- Сервисы Roblox
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Переменные для текущего квача и времени начала отсчета
local currentIt, tagStartTime

-- Лимит времени (секунды) для квача
local loseThreshold = 60

-- Счетчик поражений каждого игрока
local scores = {}

-- Таблица для предотвращения повторной передачи квача слишком быстро
local recentTagged = {}

-- Очередь для респауна проигравших игроков
local respawnQueue = {}
local isProcessingQueue = false

-- RemoteEvent для UI
local uiUpdateEvent = ReplicatedStorage:FindFirstChild("UpdateTagUI")
if not uiUpdateEvent then
    uiUpdateEvent = Instance.new("RemoteEvent")
    uiUpdateEvent.Name   = "UpdateTagUI"
    uiUpdateEvent.Parent = ReplicatedStorage
end

----------------------------------------------------------------------
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
----------------------------------------------------------------------

-- Окрашивание персонажа в указанный цвет
local function colorCharacter(char, color)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.BrickColor = BrickColor.new(color)
        end
    end
end

-- Случайный выбор квача, если его нет
local function assignRandomIt()
    if currentIt then return end

    local valid = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character and pl.Character:FindFirstChild("Humanoid") and pl.Character.Humanoid.Health > 0 then
            table.insert(valid, pl)
        end
    end

    if #valid == 0 then
        currentIt = nil
        return
    end

    local chosen = valid[math.random(1, #valid)]
    currentIt, tagStartTime = chosen, os.time()

    colorCharacter(chosen.Character, "Bright red")
    uiUpdateEvent:FireClient(chosen, "Start")
    uiUpdateEvent:FireAllClients("TagName", chosen.Name)
    print("[Auto] Назначен новый квач: " .. chosen.Name)
end

-- Респаун проигравших игроков
local function processRespawnQueue()
    if isProcessingQueue then return end
    isProcessingQueue = true

    while #respawnQueue > 0 do
        local plr = table.remove(respawnQueue, 1)
        if plr and plr.Parent then
            plr:LoadCharacter()
            plr.CharacterAdded:Wait()
            task.wait(0.5)

            currentIt, tagStartTime = plr, os.time()
            colorCharacter(plr.Character, "Bright red")
            uiUpdateEvent:FireClient(plr, "Start")
            uiUpdateEvent:FireAllClients("TagName", plr.Name)
            print("[Auto] Снова назначен квач: " .. plr.Name)
        end
    end

    isProcessingQueue = false
end

-- Обработка проигрыша квача (если время вышло)
local function handleLose(plr)
    if not plr then return end

    scores[plr.Name] = (scores[plr.Name] or 0) + 1
    print(plr.Name .. " проиграл и получил очко, итого: " .. scores[plr.Name])

    uiUpdateEvent:FireClient(plr, "Lose")
    uiUpdateEvent:FireAllClients("LoseCount", plr.Name)

    currentIt = nil
    if plr.Character then plr.Character:BreakJoints() end

    table.insert(respawnQueue, plr)
    task.spawn(processRespawnQueue)
end

----------------------------------------------------------------------
-- ПЕРЕДАЧА КВАЧА ПО ДИСТАНЦИИ (без Touched)
----------------------------------------------------------------------

local MAX_TAG_DISTANCE = 3  -- допустимая дистанция для передачи квача
local CHECK_INTERVAL = 0.1  -- интервал проверки (секунды)
local TAG_COOLDOWN = 2      -- кулдаун (секунды), чтобы квач не прыгал туда-сюда моментально

-- Проверка всех игроков на близость к текущему квачу
local function checkTagProximity()
    if not currentIt or not currentIt.Character then return end
    local itRoot = currentIt.Character:FindFirstChild("HumanoidRootPart")
    if not itRoot then return end

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= currentIt and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = pl.Character.HumanoidRootPart
            local distance = (itRoot.Position - targetRoot.Position).Magnitude

            if distance <= MAX_TAG_DISTANCE then
                -- Проверяем кулдаун (нельзя слишком часто передавать)
                if recentTagged[pl.Name] and tick() - recentTagged[pl.Name] < TAG_COOLDOWN then
                    continue
                end

                -- Передача роли
                print("Квач передан → " .. pl.Name)
                colorCharacter(currentIt.Character, "Medium stone grey")
                colorCharacter(pl.Character, "Bright red")
                recentTagged[pl.Name] = tick()

                local prev = currentIt
                currentIt, tagStartTime = pl, os.time()

                uiUpdateEvent:FireClient(prev, "Stop")
                uiUpdateEvent:FireClient(pl, "Start")
                uiUpdateEvent:FireAllClients("TagName", pl.Name)

                return -- выходим после передачи (за раз передаем только одному)
            end
        end
    end
end

-- Запускаем периодическую проверку расстояния
task.spawn(function()
    while true do
        task.wait(CHECK_INTERVAL)
        checkTagProximity()
    end
end)

----------------------------------------------------------------------
-- ОСНОВНОЙ ЦИКЛ: таймер для квача
----------------------------------------------------------------------
spawn(function()
    while true do
        task.wait(1)

        if not currentIt or not currentIt.Character then
            assignRandomIt()
        end

        if currentIt and tagStartTime and currentIt.Character then
            local elapsed   = os.time() - tagStartTime
            local remaining = loseThreshold - elapsed

            uiUpdateEvent:FireClient(currentIt, "Update", remaining)
            uiUpdateEvent:FireAllClients("TimerUpdate", remaining)

            if remaining <= 0 then
                handleLose(currentIt)
            end
        end
    end
end)

----------------------------------------------------------------------
-- НАЧАЛО ИГРЫ: выбор первого квача
----------------------------------------------------------------------
local function setInitialIt(plr)
    if currentIt then return end

    currentIt, tagStartTime = plr, os.time()
    colorCharacter(plr.Character, "Bright red")
    uiUpdateEvent:FireClient(plr, "Start")
    uiUpdateEvent:FireAllClients("TagName", plr.Name)
end

----------------------------------------------------------------------
-- СОБЫТИЯ ПРИ ВХОДЕ ИГРОКОВ
----------------------------------------------------------------------
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if not currentIt then
            setInitialIt(plr)
        end
    end)
end)
