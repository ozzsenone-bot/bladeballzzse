local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Balls = workspace:WaitForChild("Balls")

local ParryRemote = Remotes:WaitForChild("ParryButtonPress")

local function verifyBall(ball)
    return typeof(ball) == "Instance" 
        and ball:IsA("BasePart") 
        and ball:IsDescendantOf(Balls) 
        and ball:GetAttribute("realBall") == true
end

local function isTarget()
    return Player.Character and Player.Character:FindFirstChild("Highlight") ~= nil
end

local function parry()
    ParryRemote:FireServer()
end

-- Отслеживание позиции мяча для расчёта скорости
local lastPos = {}
local lastTick = {}

local function onBallAdded(ball)
    if not verifyBall(ball) then return end
    
    lastPos[ball] = ball.Position
    lastTick[ball] = tick()
    
    ball:GetPropertyChangedSignal("Position"):Connect(function()
        if not isTarget() then return end
        
        local now = tick()
        local dt = now - lastTick[ball]
        if dt < 1/60 then return end -- не чаще 60 раз в секунду
        
        local distance = (ball.Position - workspace.CurrentCamera.Focus.Position).Magnitude
        local velocity = (lastPos[ball] - ball.Position).Magnitude / dt
        
        lastPos[ball] = ball.Position
        lastTick[ball] = now
        
        if velocity > 0 and (distance / velocity) <= 0.3 then
            parry()
        end
    end)
end

for _, ball in ipairs(Balls:GetChildren()) do
    onBallAdded(ball)
end

Balls.ChildAdded:Connect(onBallAdded)
