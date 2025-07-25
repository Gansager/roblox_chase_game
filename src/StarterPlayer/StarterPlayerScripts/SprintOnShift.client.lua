-- LocalScript (StarterPlayer > StarterPlayerScripts) SprintOnShift.client.lua

local Players               = game:GetService("Players")
local UserInputService      = game:GetService("UserInputService")
local ContextActionService  = game:GetService("ContextActionService")

local player    = Players.LocalPlayer
local character, humanoid

local normalSpeed = 16
local sprintSpeed = 32

-- Инициализация Humanoid при респавне
local function setupHumanoid(char)
    character = char
    humanoid  = character:WaitForChild("Humanoid")
    humanoid.WalkSpeed = normalSpeed
end

if player.Character then
    setupHumanoid(player.Character)
end
player.CharacterAdded:Connect(setupHumanoid)

-- Универсальная функция спринта (Shift, геймпад)
local function SprintAction(_, state)
    if not humanoid then return end
    if state == Enum.UserInputState.Begin then
        humanoid.WalkSpeed = sprintSpeed
    elseif state == Enum.UserInputState.End then
        humanoid.WalkSpeed = normalSpeed
    end
end

ContextActionService:BindAction("Sprint", SprintAction, false,
    Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
    Enum.KeyCode.ButtonL3,   Enum.KeyCode.ButtonR3
)

-- На‑экранная кнопка для мобильных
if UserInputService.TouchEnabled then
    local function createSprintGui()
        -- Remove existing SprintGUI if present
        local existing = player.PlayerGui:FindFirstChild("SprintGUI")
        if existing then
            existing:Destroy()
        end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name         = "SprintGUI"
        screenGui.ResetOnSpawn = false
        screenGui.Parent       = player:WaitForChild("PlayerGui")

    local sprintBtn = Instance.new("TextButton")
    sprintBtn.Name               = "SprintBtn"
    sprintBtn.AnchorPoint        = Vector2.new(1, 1)
    sprintBtn.Position           = UDim2.new(1, -140, 1, -20)  -- подвинул левее
    sprintBtn.Size               = UDim2.new(0, 100, 0, 50)
    sprintBtn.BackgroundTransparency = 0.5
    sprintBtn.Text               = "Sprint"
    sprintBtn.Font               = Enum.Font.SourceSansBold
    sprintBtn.TextScaled         = true
    sprintBtn.Parent             = screenGui

    -- скругление и паддинги
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = sprintBtn

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft   = UDim.new(0, 12)
    padding.PaddingRight  = UDim.new(0, 12)
    padding.PaddingTop    = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.Parent = sprintBtn

    -- когда палец касается кнопки
    sprintBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            if humanoid then humanoid.WalkSpeed = sprintSpeed end
        end
    end)

    -- когда палец отрывается
    sprintBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            if humanoid then humanoid.WalkSpeed = normalSpeed end
        end
    end)
    end

    -- Create on script start
    createSprintGui()
    -- Recreate on respawn
    player.CharacterAdded:Connect(function()
        createSprintGui()
    end)
end
