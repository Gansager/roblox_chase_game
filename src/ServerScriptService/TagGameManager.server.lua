-- Исправленная логика: всегда кто-то квач, работает с игроками в Live

print("[TagGameManager] started via Rojo")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local currentIt = nil
local tagStartTime = nil
local loseThreshold = 100

local uiUpdateEvent = ReplicatedStorage:FindFirstChild("UpdateTagUI") or Instance.new("RemoteEvent")
uiUpdateEvent.Name = "UpdateTagUI"
uiUpdateEvent.Parent = ReplicatedStorage

local recentTagged = {}

local function colorCharacter(char, color)
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.BrickColor = BrickColor.new(color)
			end
		end
	end
end

local function assignRandomIt()
	local all = Players:GetPlayers()
	if #all > 0 then
		local chosen = all[math.random(1, #all)]
		if chosen.Character then
			currentIt = chosen
			tagStartTime = os.time()
			colorCharacter(chosen.Character, "Bright red")
			uiUpdateEvent:FireClient(chosen, "Start")
			uiUpdateEvent:FireAllClients("TagName", chosen.Name)
			print("[Auto] Назначен новый квач: " .. chosen.Name)
		end
	end
end

local function handleLose(player)
	if player and player.Character then
		print(player.Name .. " проиграл: был квачом больше 10 минут")
		uiUpdateEvent:FireClient(player, "Lose")
		player.Character:BreakJoints()
		tagStartTime = nil
		assignRandomIt()
	end
end

spawn(function()
	while true do
		task.wait(1)
		if not currentIt or not currentIt.Character then
			assignRandomIt()
		end
		if currentIt and tagStartTime and currentIt.Character then
			local elapsed = os.time() - tagStartTime
			uiUpdateEvent:FireClient(currentIt, "Update", loseThreshold - elapsed)
			if elapsed >= loseThreshold then
				handleLose(currentIt)
			end
		end
	end
end)

local function setInitialIt(player)
	currentIt = player
	tagStartTime = os.time()
	print(player.Name .. " стал квачом!")
	colorCharacter(player.Character, "Bright red")
	uiUpdateEvent:FireClient(player, "Start")
	uiUpdateEvent:FireAllClients("TagName", player.Name)
end

local function tryTag(hit)
	if not currentIt or not currentIt.Character then return end

	local targetChar = hit:FindFirstAncestorWhichIsA("Model")
	if not targetChar or not targetChar:FindFirstChild("Humanoid") then return end

	local currentChar = currentIt.Character
	if targetChar == currentChar then return end

	if recentTagged[targetChar] and tick() - recentTagged[targetChar] < 3 then
		return
	end

	print("Передача квача → " .. targetChar.Name)
	colorCharacter(currentChar, "Medium stone grey")
	colorCharacter(targetChar, "Bright red")

	recentTagged[currentChar] = tick()

	local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
	if targetPlayer then
		local prevPlayer = currentIt
		currentIt = targetPlayer
		tagStartTime = os.time()
		uiUpdateEvent:FireClient(prevPlayer, "Stop")
		uiUpdateEvent:FireClient(targetPlayer, "Start")
		uiUpdateEvent:FireAllClients("TagName", targetPlayer.Name)
	end
end

local function connectTouch(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart")
		task.wait(0.5)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Touched:Connect(function(hit)
				tryTag(hit)
			end)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	connectTouch(player)
	if not currentIt then
		task.wait(2)
		if player.Character then
			setInitialIt(player)
		end
	end
end)
