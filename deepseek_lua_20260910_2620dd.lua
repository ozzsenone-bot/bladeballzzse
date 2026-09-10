-- ═══════════════════════════════════════════
-- Blade Ball Auto Parry (Keypress via F)
-- ═══════════════════════════════════════════

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Balls = workspace:WaitForChild("Balls")

-- ═══ НАСТРОЙКИ ═══
local CONFIG = {
    PARRY_DISTANCE = 5,      -- дистанция в studs, при которой жать F (5 = метр)
    PARry_COOLDOWN = 0.1,    -- пауза между нажатиями
    PARRY_KEY = Enum.KeyCode.F,
    CHECK_INTERVAL = 1/60,   -- частота проверки (60 раз в сек)
}

-- ═══ ПРОВЕРКА МЯЧА ═══
local function VerifyBall(ball)
    return typeof(ball) == "Instance" 
        and ball:IsA("BasePart") 
        and ball:IsDescendantOf(Balls) 
        and ball:GetAttribute("realBall") == true
end

-- ═══ ПРОВЕРКА ЦЕЛИ ═══
local function IsTarget()
    -- Highlight появляется, когда мяч летит на тебя [citation:1][citation:5]
    return Player.Character and Player.Character:FindFirstChild("Highlight") ~= nil
end

-- ═══ ЭМУЛЯЦИЯ НАЖАТИЯ F ═══
local function Parry()
    -- Нажимаем F (true = зажатие)
    VirtualInputManager:SendKeyEvent(true, CONFIG.PARRY_KEY, false, game)
    task.wait(0.01)
    -- Отпускаем F (false = отпускание)
    VirtualInputManager:SendKeyEvent(false, CONFIG.PARRY_KEY, false, game)
end

-- ═══ ОСНОВНОЙ ЦИКЛ ═══
local lastParry = 0

RunService.Heartbeat:Connect(function()
    -- Проверка кулдауна
    if tick() - lastParry < CONFIG.PARRY_COOLDOWN then return end
    
    -- Проверка, что мы вообще в игре
    local character = Player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Ищем активный мяч
    for _, ball in ipairs(Balls:GetChildren()) do
        if VerifyBall(ball) and IsTarget() then
            -- Считаем расстояние от нас до мяча
            local distance = (hrp.Position - ball.Position).Magnitude
            
            -- Если мяч ближе чем PARRY_DISTANCE studs — жмём F
            if distance <= CONFIG.PARRY_DISTANCE then
                lastParry = tick()
                Parry()
                break
            end
        end
    end
end)

print("[OZZSE] Auto Parry loaded. Press F will be simulated.")
