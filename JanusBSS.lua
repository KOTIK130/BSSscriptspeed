--![ Janus BSS Ultimate v3.3 - Raw Injector Input ]
--! Автор: Janus & Tesavek
--! Поддержка: CFrame Speed, Raw Auto-Dig (mouse1click), Auto-Planter (Custom Bind)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Player = Players.LocalPlayer

-- Уничтожаем старую версию
if CoreGui:FindFirstChild("JanusBSS_Ultimate") then
    CoreGui.JanusBSS_Ultimate:Destroy()
end

-- ==========================================
-- Настройки Автоматизации
-- ==========================================
local PLANTER_DELAY = 1.0
local CurrentBind = Enum.KeyCode.One
local isBinding = false

-- ==========================================
-- Создание GUI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JanusBSS_Ultimate"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -150)
MainFrame.Size = UDim2.new(0, 300, 0, 330)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local TopBar = Instance.new("Frame", MainFrame)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BorderSizePixel = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)

local TopBarFix = Instance.new("Frame", TopBar)
TopBarFix.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TopBarFix.Size = UDim2.new(1, 0, 0, 10)
TopBarFix.Position = UDim2.new(0, 0, 1, -10)
TopBarFix.BorderSizePixel = 0

local Title = Instance.new("TextLabel", TopBar)
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 1, 0)
Title.Font = Enum.Font.SourceSansBold
Title.Text = "⚡ JANUS BSS ULTIMATE v3.3 ⚡"
Title.TextColor3 = Color3.fromRGB(0, 255, 200)
Title.TextSize = 18

-- Custom Drag Logic
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- ==========================================
-- Элементы управления
-- ==========================================
local function createButton(text, yPos, height)
    height = height or 35
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, height)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 16
    btn.Text = text
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local SpeedToggle = createButton("CFrame Speed: OFF", 50)

-- Ползунок скорости
local SliderLabel = Instance.new("TextLabel", MainFrame)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Position = UDim2.new(0.05, 0, 0, 95)
SliderLabel.Size = UDim2.new(0.9, 0, 0, 20)
SliderLabel.Font = Enum.Font.SourceSansBold
SliderLabel.Text = "Speed Multiplier: 1.0"
SliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SliderLabel.TextSize = 14

local SliderBg = Instance.new("Frame", MainFrame)
SliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
SliderBg.Position = UDim2.new(0.05, 0, 0, 115)
SliderBg.Size = UDim2.new(0.9, 0, 0, 30)
Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(0, 6)

local SliderFill = Instance.new("Frame", SliderBg)
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
SliderFill.Size = UDim2.new(0.2, 0, 1, 0)
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(0, 6)

local SliderBtn = Instance.new("TextButton", SliderBg)
SliderBtn.BackgroundTransparency = 1
SliderBtn.Size = UDim2.new(1, 0, 1, 0)
SliderBtn.Text = ""

local AutoDigToggle = createButton("Auto Dig (mouse1click): OFF", 155)

-- Контейнер для Auto-Planter (Кнопка вкл/выкл + Кнопка бинда)
local PlanterFrame = Instance.new("Frame", MainFrame)
PlanterFrame.BackgroundTransparency = 1
PlanterFrame.Position = UDim2.new(0.05, 0, 0, 200)
PlanterFrame.Size = UDim2.new(0.9, 0, 0, 35)

local AutoPlanterToggle = Instance.new("TextButton", PlanterFrame)
AutoPlanterToggle.Size = UDim2.new(0.65, 0, 1, 0)
AutoPlanterToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
AutoPlanterToggle.TextColor3 = Color3.fromRGB(200, 200, 200)
AutoPlanterToggle.Font = Enum.Font.SourceSansBold
AutoPlanterToggle.TextSize = 16
AutoPlanterToggle.Text = "Auto Planter: OFF"
AutoPlanterToggle.AutoButtonColor = false
Instance.new("UICorner", AutoPlanterToggle).CornerRadius = UDim.new(0, 6)

local BindButton = Instance.new("TextButton", PlanterFrame)
BindButton.Size = UDim2.new(0.3, 0, 1, 0)
BindButton.Position = UDim2.new(0.7, 0, 0, 0)
BindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
BindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
BindButton.Font = Enum.Font.SourceSansBold
BindButton.TextSize = 14
BindButton.Text = "[" .. CurrentBind.Name .. "]"
BindButton.AutoButtonColor = false
Instance.new("UICorner", BindButton).CornerRadius = UDim.new(0, 6)

-- ==========================================
-- Игровая Логика и Функции
-- ==========================================
local Flags = {
    Speed = false,
    SpeedVal = 1.0,
    AutoDig = false,
    AutoPlanter = false
}

-- Логика ползунка
local isSliding = false
local function updateSlider(input)
    local relativeX = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
    SliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
    Flags.SpeedVal = math.floor((relativeX * 4.9 + 0.1) * 10) / 10 
    SliderLabel.Text = "Speed Multiplier: " .. tostring(Flags.SpeedVal)
end

SliderBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then 
        isSliding = true 
        updateSlider(input) 
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if isSliding and input.UserInputType == Enum.UserInputType.MouseMovement then updateSlider(input) end
end)

-- Обработчики кнопок
SpeedToggle.MouseButton1Click:Connect(function()
    Flags.Speed = not Flags.Speed
    SpeedToggle.Text = Flags.Speed and "CFrame Speed: ON" or "CFrame Speed: OFF"
    SpeedToggle.TextColor3 = Flags.Speed and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(200, 200, 200)
end)

AutoDigToggle.MouseButton1Click:Connect(function()
    Flags.AutoDig = not Flags.AutoDig
    AutoDigToggle.Text = Flags.AutoDig and "Auto Dig (mouse1click): ON" or "Auto Dig (mouse1click): OFF"
    AutoDigToggle.TextColor3 = Flags.AutoDig and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(200, 200, 200)
end)

AutoPlanterToggle.MouseButton1Click:Connect(function()
    Flags.AutoPlanter = not Flags.AutoPlanter
    AutoPlanterToggle.Text = Flags.AutoPlanter and "Auto Planter: ON" or "Auto Planter: OFF"
    AutoPlanterToggle.TextColor3 = Flags.AutoPlanter and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(200, 200, 200)
end)

-- Логика бинда клавиши
BindButton.MouseButton1Click:Connect(function()
    if isBinding then return end 
    isBinding = true
    BindButton.Text = "[...]"
    BindButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50) 
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if isBinding and input.UserInputType == Enum.UserInputType.Keyboard then
        CurrentBind = input.KeyCode
        BindButton.Text = "[" .. CurrentBind.Name .. "]"
        BindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        isBinding = false
        return 
    end

    if not gpe and input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- ==========================================
-- Рабочие Циклы
-- ==========================================

-- 1. CFrame Speed
RunService.RenderStepped:Connect(function()
    if Flags.Speed and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = Player.Character.HumanoidRootPart
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * Flags.SpeedVal)
        end
    end
end)

-- 2. Auto-Dig (Forced Tool Activation - БЕЗ привязки к курсору)
task.spawn(function()
    while task.wait(0.05) do -- Задержка между взмахами
        if Flags.AutoDig then
            local character = Player.Character
            if character then
                -- Ищем любой объект класса "Tool", который сейчас в руках
                for _, item in ipairs(character:GetChildren()) do
                    if item:IsA("Tool") then
                        -- Принудительно вызываем метод активации инструмента
                        item:Activate()
                        break -- Нашли инструмент, активировали, ждем следующий цикл
                    end
                end
            end
        end
    end
end)

-- 3. Auto-Planter
task.spawn(function()
    while task.wait(PLANTER_DELAY) do
        if Flags.AutoPlanter then
            VirtualInputManager:SendKeyEvent(true, CurrentBind, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, CurrentBind, false, game)
        end
    end
end)

print("[Janus] V3.3 Loaded. Raw Inputs Ready.")
