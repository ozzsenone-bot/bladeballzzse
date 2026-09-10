--[[
    ═══════════════════════════════════════════════════════
    Blade Ball Script — OZZSE Edition
    UI: Rayfield | Auto Parry | ESP | Auto Spam
    ═══════════════════════════════════════════════════════
]]

-- ═══════════════════════════════════════════
-- UI ЗАГРУЗКА
-- ═══════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Blade Ball | OZZSE",
    LoadingTitle = "OZZSE Research Project",
    LoadingSubtitle = "Loading modules...",
    ConfigurationSaving = { Enabled = false },
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
local Balls = workspace:WaitForChild("Balls", 10)
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- ═══════════════════════════════════════════
-- КОНФИГ
-- ═══════════════════════════════════════════
local Config = {
    AutoParry       = true,
    PingBased       = true,
    PingOffset      = 0,
    ParryDistance   = 12,
    ParryCooldown   = 0.1,
    AutoSpam        = false,
    SpamKey         = Enum.KeyCode.F,
    SpamDelay       = 0.02,
    BallESP         = true,
    TargetWarning   = true,
}

-- ═══════════════════════════════════════════
-- УТИЛИТЫ
-- ═══════════════════════════════════════════
local function getPing()
    local ok, v = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and v or 0
end

local function verifyBall(ball)
    return typeof(ball) == "Instance"
        and ball:IsA("BasePart")
        and ball:IsDescendantOf(Balls)
        and ball:GetAttribute("realBall") == true
end

local function isTarget()
    local char = Player.Character
    if not char then return false end
    if char:FindFirstChild("Highlight") then return true end
    return false
end

-- ═══════════════════════════════════════════
-- ПОИСК РЕМОУТА ПАРИРОВАНИЯ
-- ═══════════════════════════════════════════
local ParryRemote = nil
if Remotes then
    for _, name in ipairs({"ParryButtonPress", "Parry", "Block", "Deflect", "ParryEvent"}) do
        local r = Remotes:FindFirstChild(name)
        if r and r:IsA("RemoteEvent") then
            ParryRemote = r
            break
        end
    end
    if not ParryRemote then
        for _, obj in ipairs(Remotes:GetDescendants()) do
            if obj:IsA("RemoteEvent") and string.find(string.lower(obj.Name), "parry") then
                ParryRemote = obj
                break
            end
        end
    end
end

-- ═══════════════════════════════════════════
-- ПАРИРОВАНИЕ (RemoteEvent + fallback клавиша)
-- ═══════════════════════════════════════════
local function pressKey(key)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, key, false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, key, false, game)
    end)
end

local function parry()
    if ParryRemote then
        pcall(function() ParryRemote:FireServer() end)
    end
    -- Дублируем нажатие клавиши для надёжности
    pressKey(Enum.KeyCode.F)
end

-- ═══════════════════════════════════════════
-- AUTO PARRY LOOP
-- ═══════════════════════════════════════════
local lastParry = 0

RunService.Heartbeat:Connect(function()
    if not Config.AutoParry then return end
    if tick() - lastParry < Config.ParryCooldown then return end

    local char = Player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ping = getPing()
    local dynamicDist = Config.ParryDistance

    if Config.PingBased then
        dynamicDist = Config.ParryDistance + (ping / 1000) * 30 + Config.PingOffset
    end

    for _, ball in ipairs(Balls:GetChildren()) do
        if verifyBall(ball) then
            local dist = (hrp.Position - ball.Position).Magnitude
            if dist <= dynamicDist then
                if not Config.TargetWarning or isTarget() or dist <= Config.ParryDistance then
                    lastParry = tick()
                    parry()
                    break
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- BALL ESP
-- ═══════════════════════════════════════════
local espGui = Instance.new("ScreenGui")
espGui.Name = "OZZSE_ESP"
espGui.ResetOnSpawn = false
espGui.Parent = Player:WaitForChild("PlayerGui")

RunService.RenderStepped:Connect(function()
    espGui.Enabled = Config.BallESP
    if not Config.BallESP then return end

    local old = espGui:FindFirstChild("BallInfo")
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ball = nil
    for _, b in ipairs(Balls:GetChildren()) do
        if verifyBall(b) then ball = b break end
    end
    if not ball then
        if old then old:Destroy() end
        return
    end

    local screenPos, onScreen = Camera:WorldToViewportPoint(ball.Position)
    if not onScreen then
        if old then old:Destroy() end
        return
    end

    local label = old
    if not label then
        label = Instance.new("TextLabel")
        label.Name = "BallInfo"
        label.Size = UDim2.new(0, 220, 0, 70)
        label.BackgroundTransparency = 0.4
        label.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        label.BorderSizePixel = 0
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.TextStrokeTransparency = 0.3
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = espGui
        local pad = Instance.new("UIPadding", label)
        pad.PaddingLeft = UDim.new(0, 6)
    end

    label.Position = UDim2.new(0, screenPos.X + 30, 0, screenPos.Y - 20)

    local dist = (hrp.Position - ball.Position).Magnitude
    local targeted = isTarget()

    if Config.TargetWarning then
        label.TextColor3 = targeted and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 180, 255)
    else
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

    label.Text = string.format(
        "[BALL]%s\nDist: %.1f studs\nPing: %d ms\nTarget: %s",
        targeted and " <<<" or "",
        dist,
        math.floor(getPing()),
        targeted and "YES" or "no"
    )
end)

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
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Config.SpamKey, false, game)
            end)
            task.wait(Config.SpamDelay)
            pcall(function()
                VirtualInputManager:SendKeyEvent(false, Config.SpamKey, false, game)
            end)
            task.wait(Config.SpamDelay)
        end
        spamThread = nil
    end)
end

local function stopSpam()
    spamActive = false
    if spamThread then
        pcall(task.cancel, spamThread)
        spamThread = nil
    end
end

-- ═══════════════════════════════════════════
-- UI — COMBAT
-- ═══════════════════════════════════════════
local CombatTab = Window:CreateTab("Combat", 4483362458)
CombatTab:CreateSection("Auto Parry")

CombatTab:CreateToggle({
    Name = "Enable Auto Parry",
    CurrentValue = Config.AutoParry,
    Flag = "AutoParry",
    Callback = function(v) Config.AutoParry = v end
})

CombatTab:CreateToggle({
    Name = "Ping-Based Timing",
    CurrentValue = Config.PingBased,
    Flag = "PingBased",
    Callback = function(v) Config.PingBased = v end
})

CombatTab:CreateSlider({
    Name = "Parry Distance (studs)",
    Range = {3, 40},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = Config.ParryDistance,
    Flag = "ParryDist",
    Callback = function(v) Config.ParryDistance = v end
})

CombatTab:CreateSlider({
    Name = "Ping Offset",
    Range = {-20, 20},
    Increment = 1,
    Suffix = " u",
    CurrentValue = Config.PingOffset,
    Flag = "PingOff",
    Callback = function(v) Config.PingOffset = v end
})

CombatTab:CreateSlider({
    Name = "Parry Cooldown",
    Range = {0.01, 0.5},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = Config.ParryCooldown,
    Flag = "ParryCD",
    Callback = function(v) Config.ParryCooldown = v end
})

-- ═══════════════════════════════════════════
-- UI — VISUALS
-- ═══════════════════════════════════════════
local VisualTab = Window:CreateTab("Visuals", 4483362458)
VisualTab:CreateSection("ESP")

VisualTab:CreateToggle({
    Name = "Ball ESP",
    CurrentValue = Config.BallESP,
    Flag = "BallESP",
    Callback = function(v) Config.BallESP = v end
})

VisualTab:CreateToggle({
    Name = "Target Warning (Color)",
    CurrentValue = Config.TargetWarning,
    Flag = "TargetWarn",
    Callback = function(v) Config.TargetWarning = v end
})

-- ═══════════════════════════════════════════
-- UI — AUTOMATION
-- ═══════════════════════════════════════════
local AutoTab = Window:CreateTab("Automation", 4483362458)
AutoTab:CreateSection("Auto Spam")

local spamKeys = {"F", "E", "Q", "R", "Space", "C", "V"}
local keyMap = {
    F = Enum.KeyCode.F, E = Enum.KeyCode.E, Q = Enum.KeyCode.Q,
    R = Enum.KeyCode.R, Space = Enum.KeyCode.Space, C = Enum.KeyCode.C, V = Enum.KeyCode.V
}

AutoTab:CreateDropdown({
    Name = "Spam Key",
    Options = spamKeys,
    CurrentOption = {"F"},
    Flag = "SpamKey",
    Callback = function(opt)
        local k = type(opt) == "table" and opt[1] or opt
        Config.SpamKey = keyMap[k] or Enum.KeyCode.F
    end
})

AutoTab:CreateSlider({
    Name = "Spam Delay",
    Range = {0.01, 0.3},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = Config.SpamDelay,
    Flag = "SpamDelay",
    Callback = function(v) Config.SpamDelay = v end
})

AutoTab:CreateToggle({
    Name = "Enable Auto Spam",
    CurrentValue = Config.AutoSpam,
    Flag = "AutoSpam",
    Callback = function(v)
        Config.AutoSpam = v
        if v then startSpam() else stopSpam() end
    end
})

-- ═══════════════════════════════════════════
-- ХОТКЕЙ: RightControl — toggle Auto Parry
-- ═══════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        Config.AutoParry = not Config.AutoParry
        Rayfield:Notify({
            Title = "Auto Parry",
            Content = Config.AutoParry and "ON" or "OFF",
            Duration = 1.5
        })
    end
end)

-- ═══════════════════════════════════════════
-- СТАРТ
-- ═══════════════════════════════════════════
Rayfield:Notify({
    Title = "OZZSE",
    Content = "Blade Ball loaded",
    Duration = 3
})

print("[OZZSE] Blade Ball script loaded. RightControl = toggle parry.")
