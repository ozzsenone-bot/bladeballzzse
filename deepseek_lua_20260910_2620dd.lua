-- ═══════════════════════════════════════════
-- Blade Ball Script v2
-- UI загружается первым, с защитой от падения
-- ═══════════════════════════════════════════

-- Загружаем UI с pcall, чтобы увидеть ошибку
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then
    warn("[OZZSE] Rayfield load failed. Trying alternative...")
    -- Альтернативный загрузчик
    success, Rayfield = pcall(function()
        return loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()
    end)
end

if not Rayfield then
    warn("[OZZSE] FATAL: Could not load UI library. Check executor UNC support.")
    return
end

-- Дальше создаём окно
local Window = Rayfield:CreateWindow({
    Name = "Blade Ball | OZZSE",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by OZZSE",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

-- ═══ СЕРВИСЫ ═══
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Balls = workspace:WaitForChild("Balls", 10)
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- ═══ НАСТРОЙКИ ═══
local CONFIG = {
    AutoParry = true,
    ParryDistance = 10,
    ParryCooldown = 0.1,
}

-- ═══ ПОИСК РЕМОУТА ═══
local ParryRemote = nil
for _, name in ipairs({"ParryButtonPress", "Parry", "Block"}) do
    local r = Remotes and Remotes:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then
        ParryRemote = r
        break
    end
end

-- ═══ ПРОВЕРКА МЯЧА ═══
local function VerifyBall(ball)
    return typeof(ball) == "Instance"
        and ball:IsA("BasePart")
        and ball:IsDescendantOf(Balls)
        and ball:GetAttribute("realBall") == true
end

-- ═══ ПРОВЕРКА ЦЕЛИ ═══
local function IsTarget()
    return Player.Character and Player.Character:FindFirstChild("Highlight") ~= nil
end

-- ═══ ПАРИРОВАНИЕ ═══
local function Parry()
    if ParryRemote then
        ParryRemote:FireServer()
    else
        -- Fallback через эмуляцию мыши
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
end

-- ═══ ОСНОВНОЙ ЦИКЛ ═══
local lastParry = 0

RunService.Heartbeat:Connect(function()
    if not CONFIG.AutoParry then return end
    if tick() - lastParry < CONFIG.ParryCooldown then return end

    local char = Player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, ball in ipairs(Balls:GetChildren()) do
        if VerifyBall(ball) and IsTarget() then
            local dist = (hrp.Position - ball.Position).Magnitude
            if dist <= CONFIG.ParryDistance then
                lastParry = tick()
                Parry()
                break
            end
        end
    end
end)

-- ═══ UI ═══
local Tab = Window:CreateTab("Combat", 4483362458)
Tab:CreateSection("Auto Parry")

Tab:CreateToggle({
    Name = "Enable Auto Parry",
    CurrentValue = CONFIG.AutoParry,
    Flag = "AutoParry",
    Callback = function(v) CONFIG.AutoParry = v end
})

Tab:CreateSlider({
    Name = "Parry Distance",
    Range = {1, 30},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = CONFIG.ParryDistance,
    Flag = "ParryDist",
    Callback = function(v) CONFIG.ParryDistance = v end
})

Rayfield:Notify({
    Title = "OZZSE",
    Content = "Blade Ball script loaded",
    Duration = 3
})
