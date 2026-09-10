-- ═══════════════════════════════════════════
-- Blade Ball Auto Parry (RemoteEvent)
-- ═══════════════════════════════════════════

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Balls = workspace:WaitForChild("Balls")
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- ═══ НАСТРОЙКИ ═══
local CONFIG = {
    PARRY_DISTANCE = 10,     -- дистанция срабатывания (studs)
    PARRY_COOLDOWN = 0.15,   -- пауза между парированиями
}

-- ═══ НАХОДИМ РЕМОУТ ПАРИРОВАНИЯ ═══
-- Пробуем несколько возможных названий
local ParryRemote = nil
local remoteNames = {"ParryButtonPress", "Parry", "Block", "ParryEvent"}

for _, name in ipairs(remoteNames) do
    local remote = Remotes:FindFirstChild(name)
    if remote and remote:IsA("RemoteEvent") then
        ParryRemote = remote
        print("[OZZSE] Found Parry Remote:", name)
        break
    end
end

if not ParryRemote then
    -- Если не нашли, пробуем поискать в других местах
    for _, obj in ipairs(Remotes:GetDescendants()) do
        if obj:IsA("RemoteEvent") and string.find(string.lower(obj.Name), "parry") then
            ParryRemote = obj
            print("[OZZSE] Found Parry Remote (search):", obj.Name)
            break
        end
    end
end

if not ParryRemote then
    warn("[OZZSE] Parry RemoteEvent not found! Check game version.")
    return
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
    ParryRemote:FireServer()
end

-- ═══ ОСНОВНОЙ ЦИКЛ ═══
local lastParry = 0

RunService.Heartbeat:Connect(function()
    if tick() - lastParry < CONFIG.PARRY_COOLDOWN then return end
    
    local character = Player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Ищем активный мяч, который летит на нас
    for _, ball in ipairs(Balls:GetChildren()) do
        if VerifyBall(ball) then
            -- Проверяем, летит ли мяч в нашу сторону (через Highlight)
            if IsTarget() then
                local distance = (hrp.Position - ball.Position).Magnitude
                
                if distance <= CONFIG.PARRY_DISTANCE then
                    lastParry = tick()
                    Parry()
                    break
                end
            end
        end
    end
end)

print("[OZZSE] Auto Parry loaded. Monitoring balls...")
