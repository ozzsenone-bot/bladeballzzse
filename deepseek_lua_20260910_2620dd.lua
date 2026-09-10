--[[
    Blade Ball Script
    UI: Rayfield
    Functions: Auto Parry (ping-based), ESP, Auto Spam
]]

-- ═══════════════════════════════════════════
-- ЗАГРУЗКА UI БИБЛИОТЕКИ
-- ═══════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Blade Ball",
    LoadingTitle = "Blade Ball Script",
    LoadingSubtitle = "by OZZSE",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "BladeBallConfig"
    },
    KeySystem = false
})

-- ═══════════════════════════════════════════
-- СЕРВИСЫ
-- ═══════════════════════════════════════════
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 9e9)
local Balls = workspace:WaitForChild("Balls", 9e9)
local ParryRemote = Remotes:WaitForChild("ParryButtonPress", 9e9)

-- ═══════════════════════════════════════════
-- КОНФИГУРАЦИЯ (изменяется через UI)
-- ═══════════════════════════════════════════
local Config = {
    -- Auto Parry
    AutoParry = true,
    PingBased = true,
    PingOffset = 0,
    ParryThreshold = 0.5,
    ParryCooldown = 0.1,
    BallSpeedCheck = true,

    -- ESP
    BallESP = true,
    TargetWarning = true,

    -- Auto Spam
    AutoSpam = false,
    SpamKey = Enum.KeyCode.F,
    SpamDelay = 0.01
}

-- ═══════════════════════════════════════════
-- УТИЛИТЫ
-- ═══════════════════════════════════════════
local function getPing()
    local ok, value = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and value or 0
end

local function verifyBall(ball)
    if typeof(ball) == "Instance"
        and ball:IsA("BasePart")
        and ball:IsDescendantOf(Balls)
        and ball:GetAttribute("realBall") == true
    then
        return true
    end
    return false
end

local function isTarget()
    -- Проверка через Highlight или атрибут target
    if Player.Character and Player.Character:FindFirstChild("Highlight") then
        return true
    end
    local ball = Balls:FindFirstChildWhichIsA("BasePart")
    if ball and ball:GetAttribute("target") == Player.Name then
        return true
    end
    return false
end

local function parry()
    ParryRemote:FireServer()
end

local function getActiveBall()
    for _, ball in ipairs(Balls:GetChildren()) do
        if verifyBall(ball) then
            return ball
        end
    end
    return nil
end

-- ═══════════════════════════════════════════
-- AUTO PARRY
-- ═══════════════════════════════════════════
local lastParry = 0
local lastPositions = {}

local function updateBallTracking(ball)
    lastPositions[ball] = { pos = ball.Position, tick = tick() }
end

local function calculateVelocity(ball)
    local data = lastPositions[ball]
    if not data then
        updateBallTracking(ball)
        return 0
    end

    local dt = tick() - data.tick
    if dt <= 0 then return 0 end

    local velocity = (data.pos - ball.Position).Magnitude / dt
    lastPositions[ball] = { pos = ball.Position, tick = tick() }
    return velocity
end

RunService.PreSimulation:Connect(function()
    if not Config.AutoParry then return end

    local character = Player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ball = getActiveBall()
    if not ball then return end

    local velocity = calculateVelocity(ball)
    if Config.BallSpeedCheck and velocity <= 0 then return end

    if not isTarget() then return end

    local distance = (hrp.Position - ball.Position).Magnitude
    local ping = getPing()

    -- Пинговая коррекция: расстояние сокращается на пройденное за пинг время
    if Config.PingBased then
        distance = distance - (velocity * (ping / 1000)) + Config.PingOffset
    end

    local timeToImpact = distance / velocity

    if timeToImpact <= Config.ParryThreshold then
        if tick() - lastParry >= Config.ParryCooldown then
            lastParry = tick()
            parry()
        end
    end
end)

Balls.ChildAdded:Connect(function(ball)
    if verifyBall(ball) then
        updateBallTracking(ball)

        ball:GetPropertyChangedSignal("Position"):Connect(function()
            if Config.BallESP then
                -- данные доступны через ESP-модуль
            end
        end)
    end
end)

-- ═══════════════════════════════════════════
-- ESP (Ball + Target Warning)
-- ═══════════════════════════════════════════
local espGui = Instance.new("ScreenGui")
espGui.Name = "BladeBallESP"
espGui.ResetOnSpawn = false
espGui.Parent = Player:WaitForChild("PlayerGui")

local function createESP()
    if not Config.BallESP then return end

    local ball = getActiveBall()
    if not ball then return end

    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local distance = (hrp.Position - ball.Position).Magnitude
    local velocity = calculateVelocity(ball)

    local screenPos, onScreen = Camera:WorldToViewportPoint(ball.Position)
    if not onScreen then return end

    local label = espGui:FindFirstChild("BallInfo")
    if not label then
        label = Instance.new("TextLabel")
        label.Name = "BallInfo"
        label.Size = UDim2.new(0, 200, 0, 60)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.TextStrokeTransparency = 0
        label.Parent = espGui
    end

    label.Position = UDim2.new(0, screenPos.X + 20, 0, screenPos.Y)

    local color = Config.TargetWarning and isTarget() and "🔴" or "🔵"
    label.TextColor3 = Config.TargetWarning
        and (isTarget() and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 160, 255))
        or Color3.fromRGB(255, 255, 255)

    label.Text = string.format(
        "%s BALL\nDist: %.1f\nSpeed: %.1f\nPing: %d ms",
        color, distance, velocity, math.floor(getPing())
    )
end

RunService.RenderStepped:Connect(createESP)

-- ═══════════════════════════════════════════
-- AUTO SPAM
-- ═══════════════════════════════════════════
local spamActive = false
local spamThread = nil

local function startSpam()
    if spamThread then return end
    spamActive = true
    spamThread = task.spawn(function()
        while spamActive do
            VirtualInputManager:SendKeyEvent(true, Config.SpamKey, false, game)
            task.wait(Config.SpamDelay)
            VirtualInputManager:SendKeyEvent(false, Config.SpamKey, false, game)
            task.wait(Config.SpamDelay)
        end
        spamThread = nil
    end)
end

local function stopSpam()
    spamActive = false
    if spamThread then
        task.cancel(spamThread)
        spamThread = nil
    end
end

-- ═══════════════════════════════════════════
-- UI — TAB: COMBAT
-- ═══════════════════════════════════════════
local CombatTab = Window:CreateTab("Combat", 4483362458)
CombatTab:CreateSection("Auto Parry")

CombatTab:CreateToggle({
    Name = "Enable Auto Parry",
    CurrentValue = Config.AutoParry,
    Flag = "AutoParryToggle",
    Callback = function(value)
        Config.AutoParry = value
    end
})

CombatTab:CreateToggle({
    Name = "Ping-Based Timing",
    CurrentValue = Config.PingBased,
    Flag = "PingBasedToggle",
    Callback = function(value)
        Config.PingBased = value
    end
})

CombatTab:CreateSlider({
    Name = "Parry Threshold (sec)",
    Range = {0.1, 1.0},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = Config.ParryThreshold,
    Flag = "ParryThresholdSlider",
    Callback = function(value)
        Config.ParryThreshold = value
    end
})

CombatTab:CreateSlider({
    Name = "Ping Offset (studs)",
    Range = {-10, 10},
    Increment = 0.5,
    Suffix = " studs",
    CurrentValue = Config.PingOffset,
    Flag = "PingOffsetSlider",
    Callback = function(value)
        Config.PingOffset = value
    end
})

CombatTab:CreateSlider({
    Name = "Parry Cooldown (sec)",
    Range = {0.01, 0.5},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = Config.ParryCooldown,
    Flag = "ParryCooldownSlider",
    Callback = function(value)
        Config.ParryCooldown = value
    end
})

-- ═══════════════════════════════════════════
-- UI — TAB: VISUALS
-- ═══════════════════════════════════════════
local VisualTab = Window:CreateTab("Visuals", 4483362458)
VisualTab:CreateSection("Ball ESP")

VisualTab:CreateToggle({
    Name = "Enable Ball ESP",
    CurrentValue = Config.BallESP,
    Flag = "BallESPToggle",
    Callback = function(value)
        Config.BallESP = value
        espGui.Enabled = value
    end
})

VisualTab:CreateToggle({
    Name = "Target Warning (Color)",
    CurrentValue = Config.TargetWarning,
    Flag = "TargetWarningToggle",
    Callback = function(value)
        Config.TargetWarning = value
    end
})

-- ═══════════════════════════════════════════
-- UI — TAB: AUTOMATION
-- ═══════════════════════════════════════════
local AutoTab = Window:CreateTab("Automation", 4483362458)
AutoTab:CreateSection("Auto Spam")

local spamKeyNames = {"F", "E", "Q", "R", "Space", "MouseButton1"}
local spamKeyMap = {
    F = Enum.KeyCode.F,
    E = Enum.KeyCode.E,
    Q = Enum.KeyCode.Q,
    R = Enum.KeyCode.R,
    Space = Enum.KeyCode.Space
}

AutoTab:CreateDropdown({
    Name = "Spam Key",
    Options = spamKeyNames,
    CurrentOption = {"F"},
    Flag = "SpamKeyDropdown",
    Callback = function(option)
        local key = type(option) == "table" and option[1] or option
        Config.SpamKey = spamKeyMap[key] or Enum.KeyCode.F
    end
})

AutoTab:CreateSlider({
    Name = "Spam Delay (sec)",
    Range = {0.01, 0.5},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = Config.SpamDelay,
    Flag = "SpamDelaySlider",
    Callback = function(value)
        Config.SpamDelay = value
    end
})

AutoTab:CreateToggle({
    Name = "Enable Auto Spam",
    CurrentValue = Config.AutoSpam,
    Flag = "AutoSpamToggle",
    Callback = function(value)
        Config.AutoSpam = value
        if value then startSpam() else stopSpam() end
    end
})

-- ═══════════════════════════════════════════
-- ХОТКЕЙ ДЛЯ БЫСТРОГО ВКЛЮЧЕНИЯ/ВЫКЛЮЧЕНИЯ
-- ═══════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    if input.KeyCode == Enum.KeyCode.LeftControl then
        Config.AutoParry = not Config.AutoParry
        Rayfield:Notify({
            Title = "Auto Parry",
            Content = Config.AutoParry and "Enabled" or "Disabled",
            Duration = 2
        })
    end
end)

-- ═══════════════════════════════════════════
-- УВЕДОМЛЕНИЕ О ЗАГРУЗКЕ
-- ═══════════════════════════════════════════
Rayfield:Notify({
    Title = "Blade Ball Script",
    Content = "Loaded successfully",
    Duration = 4
})

print("[OZZSE] Blade Ball script loaded")
