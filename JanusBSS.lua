--![ Janus BSS Ultimate v3.6 - Stable Build ]
--! Исправлено: Видимость текста, работа циклов, приоритет ввода

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Player = Players.LocalPlayer

-- Удаление старой версии
if CoreGui:FindFirstChild("JanusBSS_Ultimate") then
    CoreGui.JanusBSS_Ultimate:Destroy()
end

-- ==========================================
-- Конфигурация
-- ==========================================
local Flags = {
    Speed = false,
    SpeedVal = 1.0,
    AutoDig = false,
    AutoPlanter = false
}

local CurrentBind = Enum.KeyCode.One
local isBinding = false
local PLANTER_DELAY = 1.0

-- ==========================================
-- Создание GUI (High Visibility)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "JanusBSS_Ultimate"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -150)
MainFrame.Size = UDim2.new(0, 300, 0, 350)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 255, 200)

local function addStroke(obj)
    local stroke = Instance.new("UIStroke", obj)
    stroke.Thickness = 1
    stroke.Color3 = Color3.new(0, 0, 0)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Outline
end

local TopBar = Instance.new("Frame", MainFrame)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TopBar.Size = UDim2.new(1, 0, 0, 40)

local Title = Instance.new("TextLabel", TopBar)
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 1, 0)
Title.Font = Enum.Font.SourceSansBold
Title.Text = "JANUS BSS ULTIMATE v3.6"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20
addStroke(Title)

-- Drag Logic
local dragging, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- Хелпер кнопок
local function createButton(text, yPos)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 18
    btn.Text = text
    addStroke(btn)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    return btn
end

local SpeedBtn = createButton("Speed: OFF", 50)
local DigBtn = createButton("Auto-Dig: OFF", 160)

-- Слайдер (Текст теперь белый)
local SliderLabel = Instance.new("TextLabel", MainFrame)
SliderLabel.Text = "Speed Multiplier: 1.0"
SliderLabel.Position = UDim2.new(0.05, 0, 0, 95)
SliderLabel.Size = UDim2.new(0.9, 0, 0, 25)
SliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SliderLabel.Font = Enum.Font.SourceSansBold
SliderLabel.TextSize = 16
SliderLabel.BackgroundTransparency = 1
addStroke(SliderLabel)

local SliderBg = Instance.new("Frame", MainFrame)
SliderBg.Size = UDim2.new(0.9, 0, 0, 20)
SliderBg.Position = UDim2.new(0.05, 0, 0, 125)
SliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)

local SliderFill = Instance.new("Frame", SliderBg)
SliderFill.Size = UDim2.new(0.2, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 255, 200)

local SliderBtn = Instance.new("TextButton", SliderBg)
SliderBtn.Size = UDim2.new(1, 0, 1, 0)
SliderBtn.BackgroundTransparency = 1
SliderBtn.Text = ""

-- Плантер
local PlanterFrame = Instance.new("Frame", MainFrame)
PlanterFrame.BackgroundTransparency = 1
PlanterFrame.Position = UDim2.new(0.05, 0, 0, 215)
PlanterFrame.Size = UDim2.new(0.9, 0, 0, 40)

local PlanterToggle = Instance.new("TextButton", PlanterFrame)
PlanterToggle.Size = UDim2.new(0.65, 0, 1, 0)
PlanterToggle.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
PlanterToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
PlanterToggle.Font = Enum.Font.SourceSansBold
PlanterToggle.TextSize = 16
PlanterToggle.Text = "Planter: OFF"
addStroke(PlanterToggle)

local BindBtn = Instance.new("TextButton", PlanterFrame)
BindBtn.Size = UDim2.new(0.3, 0, 1, 0)
BindBtn.Position = UDim2.new(0.7, 0, 0, 0)
BindBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
BindBtn.TextColor3 = Color3.fromRGB(0, 255, 200)
BindBtn.Font = Enum.Font.SourceSansBold
BindBtn.TextSize = 16
BindBtn.Text = "[" .. CurrentBind.Name .. "]"
addStroke(BindBtn)

-- ==========================================
-- ЛОГИКА ПЕРЕКЛЮЧАТЕЛЕЙ
-- ==========================================

local function updateBtn(btn, state, text)
    btn.Text = text .. ": " .. (state and "ON" or "OFF")
    btn.BackgroundColor3 = state and Color3.fromRGB(0, 100, 80) or Color3.fromRGB(30, 30, 35)
end

SpeedBtn.MouseButton1Click:Connect(function()
    Flags.Speed = not Flags.Speed
    updateBtn(SpeedBtn, Flags.Speed, "Speed")
end)

DigBtn.MouseButton1Click:Connect(function()
    Flags.AutoDig = not Flags.AutoDig
    updateBtn(DigBtn, Flags.AutoDig, "Auto-Dig")
end)

PlanterToggle.MouseButton1Click:Connect(function()
    Flags.AutoPlanter = not Flags.AutoPlanter
    updateBtn(PlanterToggle, Flags.AutoPlanter, "Planter")
end)

-- Слайдер лоджик
local sliding = false
SliderBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
end)
RunService.RenderStepped:Connect(function()
    if sliding then
        local mousePos = UserInputService:GetMouseLocation().X
        local rel = math.clamp((mousePos - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
        SliderFill.Size = UDim2.new(rel, 0, 1, 0)
        Flags.SpeedVal = math.floor((rel * 10) * 10) / 10 -- До 10x скорости
        SliderLabel.Text = "Speed Multiplier: " .. tostring(Flags.SpeedVal)
    end
end)

-- Бинд
BindBtn.MouseButton1Click:Connect(function()
    isBinding = true
    BindBtn.Text = "..."
end)
UserInputService.InputBegan:Connect(function(i, g)
    if isBinding and i.UserInputType == Enum.UserInputType.Keyboard then
        CurrentBind = i.KeyCode
        BindBtn.Text = "[" .. i.KeyCode.Name .. "]"
        isBinding = false
    elseif not g and i.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- ==========================================
-- ОСНОВНЫЕ ПОТОКИ (FIXED)
-- ==========================================

-- 1. Скорость
RunService.Heartbeat:Connect(function()
    if Flags.Speed and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            Player.Character.HumanoidRootPart.CFrame = Player.Character.HumanoidRootPart.CFrame + (hum.MoveDirection * (Flags.SpeedVal / 2))
        end
    end
end)

-- 2. Умный Auto-Dig (Не блокирует мышь)
task.spawn(function()
    while true do
        task.wait(0.12) -- Оптимально для анимации BSS
        if Flags.AutoDig and not UserInputService:GetFocusedTextBox() then
            local char = Player.Character
            if char and char:FindFirstChildOfClass("Tool") then
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                task.wait(0.02)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end
        end
    end
end)

-- 3. Плантер
task.spawn(function()
    while true do
        task.wait(PLANTER_DELAY)
        if Flags.AutoPlanter then
            VirtualInputManager:SendKeyEvent(true, CurrentBind, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, CurrentBind, false, game)
        end
    end
end)

print("<!> Janus BSS v3.6: Loaded & Optimized.")
