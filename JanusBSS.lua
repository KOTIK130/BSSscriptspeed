--![ Janus BSS Ultimate - V2 FIXED FONT ]
--! Автор: Janus & Tesavek
--! Поддержка: CFrame Speed, Auto-Dig, Custom UI, Slider

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer

-- Уничтожаем старую версию, если скрипт запускается повторно
if CoreGui:FindFirstChild("JanusBSS_Ultimate") then
    CoreGui.JanusBSS_Ultimate:Destroy()
end

-- Основной GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JanusBSS_Ultimate"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Главное окно
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25) -- Глубокий темный
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -125)
MainFrame.Size = UDim2.new(0, 300, 0, 260)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

-- Верхняя панель (Для перетаскивания)
local TopBar = Instance.new("Frame")
TopBar.Parent = MainFrame
TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BorderSizePixel = 0
local TopCorner = Instance.new("UICorner", TopBar)
TopCorner.CornerRadius = UDim.new(0, 8)
local TopBarFix = Instance.new("Frame", TopBar) -- Убирает скругление снизу
TopBarFix.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TopBarFix.Size = UDim2.new(1, 0, 0, 10)
TopBarFix.Position = UDim2.new(0, 0, 1, -10)
TopBarFix.BorderSizePixel = 0

-- Заголовок (ИСПРАВЛЕН ШРИФТ)
local Title = Instance.new("TextLabel", TopBar)
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 1, 0)
Title.Font = Enum.Font.SourceSansBold -- ИСПРАВЛЕНО ЗДЕСЬ
Title.Text = "⚡ JANUS BSS ULTIMATE ⚡"
Title.TextColor3 = Color3.fromRGB(0, 255, 200) -- Неоновый бирюзовый
Title.TextSize = 18

-- ==========================================
-- Идеальная логика перетаскивания (Custom Drag)
-- ==========================================
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- ==========================================
-- Создание элементов управления
-- ==========================================
local function createButton(text, yPos)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.SourceSansBold -- ИСПРАВЛЕНО ЗДЕСЬ
    btn.TextSize = 16
    btn.Text = text
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local SpeedToggle = createButton("CFrame Speed: OFF", 60)
local AutoDigToggle = createButton("Auto Dig (Equip Tool): OFF", 200)

-- ==========================================
-- Ползунок скорости (Slider)
-- ==========================================
local SliderLabel = Instance.new("TextLabel", MainFrame)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Position = UDim2.new(0.05, 0, 0, 110)
SliderLabel.Size = UDim2.new(0.9, 0, 0, 20)
SliderLabel.Font = Enum.Font.SourceSansBold -- ИСПРАВЛЕНО ЗДЕСЬ
SliderLabel.Text = "Speed Multiplier: 1.0"
SliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SliderLabel.TextSize = 14

local SliderBg = Instance.new("Frame", MainFrame)
SliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
SliderBg.Position = UDim2.new(0.05, 0, 0, 135)
SliderBg.Size = UDim2.new(0.9, 0, 0, 35)
Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(0, 6)

local SliderFill = Instance.new("Frame", SliderBg)
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
SliderFill.Size = UDim2.new(0.2, 0, 1, 0) -- Дефолт 20% (Множитель 1.0)
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(0, 6)

local SliderBtn = Instance.new("TextButton", SliderBg)
SliderBtn.BackgroundTransparency = 1
SliderBtn.Size = UDim2.new(1, 0, 1, 0)
SliderBtn.Text = ""

-- ==========================================
-- Игровая Логика и Функции
-- ==========================================
local Flags = {
    Speed = false,
    SpeedVal = 1.0,
    AutoDig = false
}

-- Логика ползунка
local isSliding = false

-- Функция для обновления ползунка
local function updateSlider(input)
    local relativeX = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
    SliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
    
    -- Расчет скорости от 0.1 до 5.0
    Flags.SpeedVal = math.floor((relativeX * 4.9 + 0.1) * 10) / 10 
    SliderLabel.Text = "Speed Multiplier: " .. tostring(Flags.SpeedVal)
end

SliderBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then 
        isSliding = true 
        updateSlider(input) -- Обновляем при первом клике
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then 
        isSliding = false 
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isSliding and input.UserInputType == Enum.UserInputType.MouseMovement then
        updateSlider(input)
    end
end)

-- Логика кнопок
SpeedToggle.MouseButton1Click:Connect(function()
    Flags.Speed = not Flags.Speed
    SpeedToggle.Text = Flags.Speed and "CFrame Speed: ON" or "CFrame Speed: OFF"
    SpeedToggle.TextColor3 = Flags.Speed and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(200, 200, 200)
end)

AutoDigToggle.MouseButton1Click:Connect(function()
    Flags.AutoDig = not Flags.AutoDig
    AutoDigToggle.Text = Flags.AutoDig and "Auto Dig (Equip Tool): ON" or "Auto Dig (Equip Tool): OFF"
    AutoDigToggle.TextColor3 = Flags.AutoDig and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(200, 200, 200)
end)

-- Скрытие меню на Insert
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- ==========================================
-- Главные рабочие циклы (Обход античита BSS)
-- ==========================================

-- 1. Цикл скорости (выполняется каждый кадр)
RunService.RenderStepped:Connect(function()
    if Flags.Speed and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = Player.Character.HumanoidRootPart
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            -- Перемещаем физически, игнорируя WalkSpeed
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * Flags.SpeedVal)
        end
    end
end)

-- 2. Цикл авто-копания (Асинхронный поток)
task.spawn(function()
    while task.wait(0.1) do -- Кликает примерно 10 раз в секунду
        if Flags.AutoDig and Player.Character then
            -- Ищем инструмент в руках персонажа
            local tool = Player.Character:FindFirstChildOfClass("Tool")
            if tool then
                tool:Activate() -- Эмулирует клик левой кнопкой мыши по инструменту
            end
        end
    end
end)

print("[Janus] Ultimate GUI Loaded. Press INSERT to toggle visibility.")
