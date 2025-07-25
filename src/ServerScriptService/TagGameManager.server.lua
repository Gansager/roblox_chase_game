print("[TagGameManager] started via Rojo")

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local currentIt, tagStartTime
local loseThreshold = 10   -- секунд до проигрыша
local recentTagged  = {}
local scores        = {}   -- общий счёт игроков

-- RemoteEvent
local uiUpdateEvent = ReplicatedStorage:FindFirstChild("UpdateTagUI")
if not uiUpdateEvent then
    uiUpdateEvent = Instance.new("RemoteEvent")
    uiUpdateEvent.Name   = "UpdateTagUI"
    uiUpdateEvent.Parent = ReplicatedStorage
end

-- Функция покраски персонажа
local function colorCharacter(char, color)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.BrickColor = BrickColor.new(color)
        end
    end
end

-- Выбираем нового квача (если currentIt == nil)
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

    local chosen     = valid[math.random(1, #valid)]
    currentIt, tagStartTime = chosen, os.time()

    colorCharacter(chosen.Character, "Bright red")
    -- поп‑ап: видно только квачу
    uiUpdateEvent:FireClient(chosen,  "Start")
    -- всем показываем имя квача
    uiUpdateEvent:FireAllClients("TagName", chosen.Name)
    print("[Auto] Назначен новый квач: " .. chosen.Name)
end

-- Логика проигрыша
local function handleLose(plr)
    if not plr then return end

    -- обновляем счёт на сервере
    scores[plr.Name] = (scores[plr.Name] or 0) + 1
    print(plr.Name .. " проиграл и получил очко, итого: " .. scores[plr.Name])

    -- поп‑ап «You lost!» — только квачу
    uiUpdateEvent:FireClient(plr, "Lose")
    -- всем: обновить общий лист очков
    uiUpdateEvent:FireAllClients("LoseCount", plr.Name)

    -- сброс квача и «смерть»
    currentIt = nil
    if plr.Character then plr.Character:BreakJoints() end

    -- респаун + снова квачом
    task.spawn(function()
        plr:LoadCharacter()
        plr.CharacterAdded:Wait()
        task.wait(0.5)

        currentIt, tagStartTime = plr, os.time()
        colorCharacter(plr.Character, "Bright red")
        -- поп‑ап Start только к прежнему квачу
        uiUpdateEvent:FireClient(plr, "Start")
        -- всем: имя квача
        uiUpdateEvent:FireAllClients("TagName", plr.Name)
        print("[Auto] Снова назначен квач: " .. plr.Name)
    end)
end

-- Основной цикл: таймер и проверка проигрыша
spawn(function()
    while true do
        task.wait(1)

        if not currentIt or not currentIt.Character then
            assignRandomIt()
        end

        if currentIt and tagStartTime and currentIt.Character then
            local elapsed   = os.time() - tagStartTime
            local remaining = loseThreshold - elapsed

            -- 1) поп‑ап‑таймер только квачу
            uiUpdateEvent:FireClient(currentIt, "Update", remaining)
            -- 2) табличный таймер всем
            uiUpdateEvent:FireAllClients("TimerUpdate", remaining)

            if remaining <= 0 then
                handleLose(currentIt)
            end
        end
    end
end)

-- Назначение первого квача при заходе
local function setInitialIt(plr)
    if currentIt then return end

    currentIt, tagStartTime = plr, os.time()
    colorCharacter(plr.Character, "Bright red")
    -- поп‑ап: только к этим игроку
    uiUpdateEvent:FireClient(plr, "Start")
    -- всем: имя квача
    uiUpdateEvent:FireAllClients("TagName", plr.Name)
end

-- Передача квача по касанию
local function tryTag(hit)
    if not currentIt or not currentIt.Character then return end

    local targetChar = hit:FindFirstAncestorWhichIsA("Model")
    if not (targetChar and targetChar:FindFirstChild("Humanoid")) then return end
    if targetChar == currentIt.Character then return end
    if recentTagged[targetChar] and tick() - recentTagged[targetChar] < 3 then return end

    local prev = currentIt
    local targetPlr = Players:GetPlayerFromCharacter(targetChar)
    if not targetPlr then return end

    print("Передача квача → " .. targetPlr.Name)
    colorCharacter(prev.Character,    "Medium stone grey")
    colorCharacter(targetChar,        "Bright red")
    recentTagged[prev.Character] = tick()

    currentIt, tagStartTime = targetPlr, os.time()
    -- поп‑ап Stop только старому квачу
    uiUpdateEvent:FireClient(prev,      "Stop")
    -- поп‑ап Start только новому квачу
    uiUpdateEvent:FireClient(targetPlr, "Start")
    -- всем: имя квача
    uiUpdateEvent:FireAllClients("TagName", targetPlr.Name)
end

-- Навешиваем touch‑событие на каждого игрока
local function connectTouch(plr)
    plr.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart")
        task.wait(0.5)
        char.HumanoidRootPart.Touched:Connect(tryTag)
    end)
end

Players.PlayerAdded:Connect(function(plr)
    connectTouch(plr)
    if plr.Character and not currentIt then
        setInitialIt(plr)
    end
end)
