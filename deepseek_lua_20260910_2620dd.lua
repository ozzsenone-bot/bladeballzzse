--[[
    Blade Ball Automation Script
    Version: 1.0.0
    Features: Auto Parry, Ball Speed Detection, Spam Macro, Keybinds
    Environment: Remote (Loadstring-compatible)
]]

-- ============================================
-- SECTION 1: SERVICE INITIALIZATION
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============================================
-- SECTION 2: CONFIGURATION
-- ============================================

local Config = {
    -- Auto Parry Settings
    AutoParry = {
        Enabled = false,
        DistanceToParry = 0.5,      -- Время до столкновения (секунды)
        PingBased = false,           -- Учет пинга
        PingOffset = 0.05,           -- Компенсация пинга
        BallSpeedCheck = true,       -- Проверка скорости мяча
        MinBallSpeed = 50,           -- Минимальная скорость для активации
        Cooldown = 0.1,              -- Кулдаун между парированиями
    },
    
    -- Spam Macro Settings
    SpamMacro = {
        Enabled = false,
        Interval = 0.05,             -- Интервал между нажатиями
        Keybind = Enum.KeyCode.E,    -- Клавиша для спама
        MaxDuration = 5,             -- Максимальная длительность
    },
    
    -- Keybinds
    Keybinds = {
        ToggleGUI = Enum.KeyCode.RightShift,
        ToggleAutoParry = Enum.KeyCode.P,
        ToggleSpam = Enum.KeyCode.M,
    },
    
    -- GUI Settings
    GUI = {
        AccentColor = Color3.fromRGB(138, 43, 226),
        BackgroundColor = Color3.fromRGB(20, 20, 30),
        TextColor = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
    }
}

-- ============================================
-- SECTION 3: STATE MANAGEMENT
-- ============================================

local State = {
    ParryCooldown = 0,
    LastBallPosition = nil,
    BallVelocity = 0,
    IsSpamming = false,
    SpamConnection = nil,
    GUI = nil,
    MainFrame = nil,
}

-- ============================================
-- SECTION 4: UTILITY FUNCTIONS
-- ============================================

local function GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetHumanoidRootPart()
    local char = GetCharacter()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function IsTargeted()
    local char = LocalPlayer.Character
    if not char then return false end
    return char:FindFirstChild("Highlight") ~= nil
end

local function GetRealBall()
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return nil end
    
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if ball:IsA("BasePart") and ball:GetAttribute("realBall") == true then
            return ball
        end
    end
    return nil
end

local function GetPing()
    local stats = game:GetService("Stats")
    local ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    return ping / 1000 -- Конвертация в секунды
end

-- ============================================
-- SECTION 5: BALL TRACKING MODULE
-- ============================================

local BallTracker = {}
BallTracker.__index = BallTracker

function BallTracker.new()
    local self = setmetatable({}, BallTracker)
    self.LastPosition = nil
    self.LastTick = 0
    self.CurrentVelocity = 0
    self.Ball = nil
    return self
end

function BallTracker:Update()
    local ball = GetRealBall()
    if not ball then
        self.CurrentVelocity = 0
        return
    end
    
    self.Ball = ball
    local currentPos = ball.Position
    local currentTick = tick()
    
    if self.LastPosition and self.LastTick > 0 then
        local deltaTime = currentTick - self.LastTick
        if deltaTime > 0 then
            local distance = (currentPos - self.LastPosition).Magnitude
            self.CurrentVelocity = distance / deltaTime
        end
    end
    
    self.LastPosition = currentPos
    self.LastTick = currentTick
end

function BallTracker:GetTimeToImpact()
    local ball = self.Ball
    if not ball or self.CurrentVelocity == 0 then
        return math.huge
    end
    
    local hrp = GetHumanoidRootPart()
    if not hrp then return math.huge end
    
    local distance = (hrp.Position - ball.Position).Magnitude
    return distance / self.CurrentVelocity
end

function BallTracker:GetVelocity()
    return self.CurrentVelocity
end

-- ============================================
-- SECTION 6: AUTO PARRY ENGINE
-- ============================================

local AutoParry = {}
AutoParry.__index = AutoParry

function AutoParry.new(ballTracker)
    local self = setmetatable({}, AutoParry)
    self.BallTracker = ballTracker
    self.LastParryTime = 0
    return self
end

function AutoParry:ExecuteParry()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return end
    
    local parryButton = remotes:FindFirstChild("ParryButtonPress")
    if parryButton then
        parryButton:FireServer()
        self.LastParryTime = tick()
    end
end

function AutoParry:ShouldParry()
    if not Config.AutoParry.Enabled then return false end
    if not IsTargeted() then return false end
    
    -- Проверка кулдауна
    if tick() - self.LastParryTime < Config.AutoParry.Cooldown then
        return false
    end
    
    -- Проверка скорости мяча
    local velocity = self.BallTracker:GetVelocity()
    if Config.AutoParry.BallSpeedCheck and velocity < Config.AutoParry.MinBallSpeed then
        return false
    end
    
    -- Вычисление времени до столкновения
    local timeToImpact = self.BallTracker:GetTimeToImpact()
    
    -- Учет пинга
    local pingOffset = 0
    if Config.AutoParry.PingBased then
        pingOffset = GetPing() + Config.AutoParry.PingOffset
    end
    
    -- Проверка условия парирования
    local threshold = Config.AutoParry.DistanceToParry + pingOffset
    
    return timeToImpact <= threshold
end

function AutoParry:Update()
    if self:ShouldParry() then
        self:ExecuteParry()
    end
end

-- ============================================
-- SECTION 7: SPAM MACRO
-- ============================================

local SpamMacro = {}
SpamMacro.__index = SpamMacro

function SpamMacro.new()
    local self = setmetatable({}, SpamMacro)
    self.Connection = nil
    self.StartTime = 0
    return self
end

function SpamMacro:Start()
    if self.Connection then return end
    
    self.StartTime = tick()
    Config.SpamMacro.Enabled = true
    
    self.Connection = RunService.Heartbeat:Connect(function()
        if not Config.SpamMacro.Enabled then
            self:Stop()
            return
        end
        
        -- Проверка максимальной длительности
        if tick() - self.StartTime > Config.SpamMacro.MaxDuration then
            self:Stop()
            return
        end
        
        -- Отправка нажатия клавиши
        VirtualInputManager:SendKeyEvent(
            true, 
            Config.SpamMacro.Keybind, 
            false, 
            game
        )
        task.wait(Config.SpamMacro.Interval)
        VirtualInputManager:SendKeyEvent(
            false, 
            Config.SpamMacro.Keybind, 
            false, 
            game
        )
    end)
end

function SpamMacro:Stop()
    Config.SpamMacro.Enabled = false
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

function SpamMacro:Toggle()
    if Config.SpamMacro.Enabled then
        self:Stop()
    else
        self:Start()
    end
    return Config.SpamMacro.Enabled
end

-- ============================================
-- SECTION 8: GUI CREATION
-- ============================================

local function CreateGUI()
    -- Удаление существующего GUI
    local existingGUI = CoreGui:FindFirstChild("BladeBallAutomation")
    if existingGUI then
        existingGUI:Destroy()
    end
    
    -- Создание ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BladeBallAutomation"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    
    -- Основной фрейм
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 350, 0, 420)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -210)
    mainFrame.BackgroundColor3 = Config.GUI.BackgroundColor
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Скругление углов
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame
    
    -- Обводка
    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.GUI.AccentColor
    stroke.Thickness = 2
    stroke.Parent = mainFrame
    
    -- Заголовок
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 45)
    titleBar.BackgroundColor3 = Config.GUI.AccentColor
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    -- Маскировка нижних углов заголовка
    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0, 12)
    titleFix.Position = UDim2.new(0, 0, 1, -12)
    titleFix.BackgroundColor3 = Config.GUI.AccentColor
    titleFix.BorderSizePixel = 0
    titleFix.Parent = titleBar
    
    -- Текст заголовка
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "BLADE BALL AUTOMATION"
    titleLabel.TextColor3 = Config.GUI.TextColor
    titleLabel.Font = Config.GUI.Font
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- Кнопка закрытия
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 35, 0, 35)
    closeButton.Position = UDim2.new(1, -42, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Config.GUI.Font
    closeButton.TextSize = 16
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton
    
    -- Контейнер для контента
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, -20, 1, -60)
    contentFrame.Position = UDim2.new(0, 10, 0, 55)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    -- Секция Auto Parry
    local autoParrySection = Instance.new("Frame")
    autoParrySection.Size = UDim2.new(1, 0, 0, 100)
    autoParrySection.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    autoParrySection.BorderSizePixel = 0
    autoParrySection.Parent = contentFrame
    
    local sectionCorner = Instance.new("UICorner")
    sectionCorner.CornerRadius = UDim.new(0, 8)
    sectionCorner.Parent = autoParrySection
    
    local autoParryLabel = Instance.new("TextLabel")
    autoParryLabel.Size = UDim2.new(1, -20, 0, 25)
    autoParryLabel.Position = UDim2.new(0, 10, 0, 5)
    autoParryLabel.BackgroundTransparency = 1
    autoParryLabel.Text = "AUTO PARRY"
    autoParryLabel.TextColor3 = Config.GUI.AccentColor
    autoParryLabel.Font = Config.GUI.Font
    autoParryLabel.TextSize = 14
    autoParryLabel.TextXAlignment = Enum.TextXAlignment.Left
    autoParryLabel.Parent = autoParrySection
    
    -- Toggle кнопка Auto Parry
    local autoParryToggle = Instance.new("TextButton")
    autoParryToggle.Size = UDim2.new(1, -20, 0, 35)
    autoParryToggle.Position = UDim2.new(0, 10, 0, 35)
    autoParryToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    autoParryToggle.Text = "Auto Parry: OFF"
    autoParryToggle.TextColor3 = Config.GUI.TextColor
    autoParryToggle.Font = Config.GUI.Font
    autoParryToggle.TextSize = 14
    autoParryToggle.Parent = autoParrySection
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = autoParryToggle
    
    -- Ball Speed Display
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Name = "SpeedLabel"
    speedLabel.Size = UDim2.new(1, -20, 0, 25)
    speedLabel.Position = UDim2.new(0, 10, 0, 75)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "Ball Speed: 0 studs/s"
    speedLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    speedLabel.Font = Enum.Font.Gotham
    speedLabel.TextSize = 12
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.Parent = autoParrySection
    
    -- Секция Spam Macro
    local spamSection = Instance.new("Frame")
    spamSection.Size = UDim2.new(1, 0, 0, 80)
    spamSection.Position = UDim2.new(0, 0, 0, 110)
    spamSection.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    spamSection.BorderSizePixel = 0
    spamSection.Parent = contentFrame
    
    local spamCorner = Instance.new("UICorner")
    spamCorner.CornerRadius = UDim.new(0, 8)
    spamCorner.Parent = spamSection
    
    local spamLabel = Instance.new("TextLabel")
    spamLabel.Size = UDim2.new(1, -20, 0, 25)
    spamLabel.Position = UDim2.new(0, 10, 0, 5)
    spamLabel.BackgroundTransparency = 1
    spamLabel.Text = "SPAM MACRO"
    spamLabel.TextColor3 = Config.GUI.AccentColor
    spamLabel.Font = Config.GUI.Font
    spamLabel.TextSize = 14
    spamLabel.TextXAlignment = Enum.TextXAlignment.Left
    spamLabel.Parent = spamSection
    
    -- Toggle кнопка Spam
    local spamToggle = Instance.new("TextButton")
    spamToggle.Size = UDim2.new(1, -20, 0, 35)
    spamToggle.Position = UDim2.new(0, 10, 0, 35)
    spamToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    spamToggle.Text = "Spam Macro: OFF [M]"
    spamToggle.TextColor3 = Config.GUI.TextColor
    spamToggle.Font = Config.GUI.Font
    spamToggle.TextSize = 14
    spamToggle.Parent = spamSection
    
    local spamCorner2 = Instance.new("UICorner")
    spamCorner2.CornerRadius = UDim.new(0, 6)
    spamCorner2.Parent = spamToggle
    
    -- Секция Keybinds
    local keybindSection = Instance.new("Frame")
    keybindSection.Size = UDim2.new(1, 0, 0, 90)
    keybindSection.Position = UDim2.new(0, 0, 0, 200)
    keybindSection.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    keybindSection.BorderSizePixel = 0
    keybindSection.Parent = contentFrame
    
    local keybindCorner = Instance.new("UICorner")
    keybindCorner.CornerRadius = UDim.new(0, 8)
    keybindCorner.Parent = keybindSection
    
    local keybindLabel = Instance.new("TextLabel")
    keybindLabel.Size = UDim2.new(1, -20, 0, 25)
    keybindLabel.Position = UDim2.new(0, 10, 0, 5)
    keybindLabel.BackgroundTransparency = 1
    keybindLabel.Text = "KEYBINDS"
    keybindLabel.TextColor3 = Config.GUI.AccentColor
    keybindLabel.Font = Config.GUI.Font
    keybindLabel.TextSize = 14
    keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
    keybindLabel.Parent = keybindSection
    
    local keybindInfo = Instance.new("TextLabel")
    keybindInfo.Size = UDim2.new(1, -20, 1, -30)
    keybindInfo.Position = UDim2.new(0, 10, 0, 30)
    keybindInfo.BackgroundTransparency = 1
    keybindInfo.Text = "[P] — Toggle Auto Parry\n[M] — Toggle Spam Macro\n[RightShift] — Toggle GUI"
    keybindInfo.TextColor3 = Color3.fromRGB(180, 180, 180)
    keybindInfo.Font = Enum.Font.Gotham
    keybindInfo.TextSize = 12
    keybindInfo.TextXAlignment = Enum.TextXAlignment.Left
    keybindInfo.TextYAlignment = Enum.TextYAlignment.Top
    keybindInfo.Parent = keybindSection
    
    -- Функция перетаскивания окна
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Обработчики кнопок
    closeButton.MouseButton1Click:Connect(function()
        screenGui.Enabled = false
    end)
    
    autoParryToggle.MouseButton1Click:Connect(function()
        Config.AutoParry.Enabled = not Config.AutoParry.Enabled
        autoParryToggle.Text = "Auto Parry: " .. (Config.AutoParry.Enabled and "ON" or "OFF")
        autoParryToggle.BackgroundColor3 = Config.AutoParry.Enabled 
            and Color3.fromRGB(50, 150, 50) 
            or Color3.fromRGB(50, 50, 70)
    end)
    
    spamToggle.MouseButton1Click:Connect(function()
        local enabled = SpamMacroInstance:Toggle()
        spamToggle.Text = "Spam Macro: " .. (enabled and "ON" or "OFF") .. " [M]"
        spamToggle.BackgroundColor3 = enabled 
            and Color3.fromRGB(50, 150, 50) 
            or Color3.fromRGB(50, 50, 70)
    end)
    
    return screenGui, {
        SpeedLabel = speedLabel,
        AutoParryToggle = autoParryToggle,
        SpamToggle = spamToggle,
        MainFrame = mainFrame
    }
end

-- ============================================
-- SECTION 9: MAIN INITIALIZATION
-- ============================================

-- Создание экземпляров
local BallTrackerInstance = BallTracker.new()
local AutoParryInstance = AutoParry.new(BallTrackerInstance)
local SpamMacroInstance = SpamMacro.new()

-- Создание GUI
local GUIRefs = CreateGUI()
State.GUI = GUIRefs

-- Основной игровой цикл
local mainConnection = RunService.Heartbeat:Connect(function()
    -- Обновление трекера мяча
    BallTrackerInstance:Update()
    
    -- Обновление Auto Parry
    AutoParryInstance:Update()
    
    -- Обновление отображения скорости
    if GUIRefs.SpeedLabel then
        local velocity = math.floor(BallTrackerInstance:GetVelocity())
        GUIRefs.SpeedLabel.Text = string.format("Ball Speed: %d studs/s", velocity)
    end
end)

-- Обработка клавиш
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Toggle GUI
    if input.KeyCode == Config.Keybinds.ToggleGUI then
        if State.GUI then
            State.GUI.Enabled = not State.GUI.Enabled
        end
    end
    
    -- Toggle Auto Parry
    if input.KeyCode == Config.Keybinds.ToggleAutoParry then
        Config.AutoParry.Enabled = not Config.AutoParry.Enabled
        
        if GUIRefs.AutoParryToggle then
            GUIRefs.AutoParryToggle.Text = "Auto Parry: " .. (Config.AutoParry.Enabled and "ON" or "OFF")
            GUIRefs.AutoParryToggle.BackgroundColor3 = Config.AutoParry.Enabled 
                and Color3.fromRGB(50, 150, 50) 
                or Color3.fromRGB(50, 50, 70)
        end
    end
    
    -- Toggle Spam Macro
    if input.KeyCode == Config.Keybinds.ToggleSpam then
        local enabled = SpamMacroInstance:Toggle()
        
        if GUIRefs.SpamToggle then
            GUIRefs.SpamToggle.Text = "Spam Macro: " .. (enabled and "ON" or "OFF") .. " [M]"
            GUIRefs.SpamToggle.BackgroundColor3 = enabled 
                and Color3.fromRGB(50, 150, 50) 
                or Color3.fromRGB(50, 50, 70)
        end
    end
end)

-- Уведомление о загрузке
local StarterGui = game:GetService("StarterGui")
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Blade Ball Automation",
        Text = "Script loaded successfully! Press RightShift to toggle GUI.",
        Duration = 5,
        Icon = "rbxassetid://135351041318579"
    })
end)

-- ============================================
-- SECTION 10: CLEANUP HANDLER
-- ============================================

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    BallTrackerInstance.LastPosition = nil
    BallTrackerInstance.LastTick = 0
end)

-- Экспорт в глобальное окружение для loadstring
getgenv().BladeBallAutomation = {
    Config = Config,
    BallTracker = BallTrackerInstance,
    AutoParry = AutoParryInstance,
    SpamMacro = SpamMacroInstance,
    ToggleGUI = function()
        if GUIRefs then
            GUIRefs.Enabled = not GUIRefs.Enabled
        end
    end
}

print("[Blade Ball Automation] Script loaded successfully!")