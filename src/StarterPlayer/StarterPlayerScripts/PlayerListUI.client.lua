-- LocalScript (StarterPlayer > StarterPlayerScripts)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player  = Players.LocalPlayer
local uiEvent = ReplicatedStorage:WaitForChild("UpdateTagUI")

-- Create ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name         = "PlayerListUI"
gui.ResetOnSpawn = false
gui.Parent       = player:WaitForChild("PlayerGui")

-- Create container frame
local frame = Instance.new("Frame")
frame.Name                = "PlayerListFrame"
frame.Parent              = gui
frame.AnchorPoint         = Vector2.new(1, 0.5)
frame.Position            = UDim2.new(1, -20, 0.5, 0)
frame.Size                = UDim2.new(0, 200, 0, 0)    -- height auto‑resizes below
frame.BackgroundTransparency = 1
frame.BackgroundColor3    = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel     = 0

-- Rounded corners on the frame
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 8)
frameCorner.Parent = frame

-- List layout to stack player labels
local uiList = Instance.new("UIListLayout")
uiList.Parent    = frame
uiList.SortOrder = Enum.SortOrder.Name
uiList.Padding   = UDim.new(0, 4)

-- Resize frame height based on content
uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    frame.Size = UDim2.new(0, 200, 0, uiList.AbsoluteContentSize.Y + 8)
end)

-- Track the current tagger’s name
local taggerName

-- Function to rebuild the list
local function updatePlayerList()
    -- Clear old entries, but keep UIListLayout and UICorner
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    -- Create one label per player
    for _, pl in ipairs(Players:GetPlayers()) do
        local label = Instance.new("TextLabel")
        label.Parent            = frame
        label.Size              = UDim2.new(1, -8, 0, 28)
        label.BackgroundTransparency = 0.3
        label.BackgroundColor3  = Color3.fromRGB(40, 40, 40)
        label.Text              = pl.Name
        label.Font              = Enum.Font.SourceSansBold
        label.TextSize          = 20
        label.TextXAlignment    = Enum.TextXAlignment.Center
        label.TextYAlignment    = Enum.TextYAlignment.Center

        -- Default color
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        -- Highlight the tagger in red
        if taggerName and pl.Name == taggerName then
            label.TextColor3 = Color3.fromRGB(255, 0, 0)
        end

        -- Rounded corners on each label
        local corner = Instance.new("UICorner", label)
        corner.CornerRadius = UDim.new(0, 6)
    end
end

-- When server notifies of a new tagger
uiEvent.OnClientEvent:Connect(function(newTagger)
    taggerName = newTagger
    updatePlayerList()
end)

-- Update list on join/leave
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)

-- Initial build
updatePlayerList()
