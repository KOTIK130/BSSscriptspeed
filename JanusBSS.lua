--![ Janus BSS Ultimate v3.4 - Clean Injection ]
--! Автор: Janus & Tesavek
--! Функционал: Speed, Auto-Dig (Fixed), Auto-Planter (Custom Bind)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Player = Players.LocalPlayer

-- Очистка
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

local PLANTER_DELAY = 1.0
local CurrentBind = Enum.KeyCode.One
local isBinding = false

-- ==========================================
-- GUI (Твой оригинальный стиль)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "JanusBSS_Ultimate"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -150)
MainFrame.Size = UDim2.new(0, 300, 0, 330)
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local TopBar = Instance.new("Frame", MainFrame)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TopBar.Size = UDim2.new(1, 0, 0, 40)
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", TopBar)
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 1, 0)
Title.Font = Enum.Font.SourceSansBold
Title.Text = "⚡ JANUS BSS ULTIMATE v3.4 ⚡"
Title.TextColor3 = Color3.fromRGB(0, 255, 200)
Title.TextSize = 18

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

local function createButton(text, yPos)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.SourceSansBold
    btn.Text = text
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

-- Элементы управления
local SpeedToggle = createButton("CFrame Speed: OFF", 50)
local AutoDigToggle = createButton("Auto Dig (Fixed): OFF", 155)

-- Слайдер скорости
local SliderLabel = Instance.new("TextLabel", MainFrame)
SliderLabel.Text = "Speed Multiplier: 1.0"
SliderLabel.Position = UDim2.new(0.05, 0, 0, 95)
SliderLabel.Size = UDim2.new(0.9, 0, 0, 20)
SliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SliderLabel.BackgroundTransparency = 1

local SliderBg = Instance.new("Frame", MainFrame)
SliderBg.Size = UDim2.new(0.9, 0, 0, 30)
SliderBg.Position = UDim2.new(0.05, 0, 0, 115)
SliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
Instance.new("UICorner", SliderBg).CornerRadius = UDim.new(0, 6)

local SliderFill = Instance.new("Frame", SliderBg)
SliderFill.Size = UDim2.new(0.2, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(0, 6)

local SliderBtn = Instance.new("TextButton", SliderBg)
SliderBtn.Size = UDim2.new(1, 0, 1, 0)
SliderBtn.BackgroundTransparency = 1
SliderBtn.Text = ""

-- Контейнер Planter
local PlanterFrame = Instance.new("Frame", MainFrame)
PlanterFrame.BackgroundTransparency = 1
PlanterFrame.Position = UDim2.new(0.05, 0, 0, 200)
PlanterFrame.Size = UDim2.new(0.9, 0, 0, 35)

local AutoPlanterToggle = Instance.new("TextButton", PlanterFrame)
AutoPlanterToggle.Size = UDim2.new(0.65, 0, 1, 0)
AutoPlanterToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
AutoPlanterToggle.TextColor3 = Color3.fromRGB(200, 200, 200)
AutoPlanterToggle.Text = "Auto Planter: OFF"
AutoPlanterToggle.Font = Enum.Font.SourceSansBold
Instance.new("UICorner", AutoPlanterToggle).CornerRadius = UDim.new(0, 6)

local BindButton = Instance.new("TextButton", PlanterFrame)
BindButton.Size = UDim2.new(0.3, 0, 1, 0)
BindButton.Position = UDim2.new(0.7, 0, 0, 0)
BindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
BindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
BindButton.Text = "[" .. CurrentBind.Name .. "]"
Instance.new("UICorner", BindButton).CornerRadius = UDim.new(0, 6)

-- ==========================================
-- ЛОГИКА
-- ==========================================

-- Слайдер
local isSliding = false
local function updateSlider(input)
    local rel = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
    SliderFill.Size = UDim2.new(rel, 0, 1, 0)
    Flags.SpeedVal = math.floor((rel * 4.9 + 0.1) * 10) / 10
    SliderLabel.Text = "Speed Multiplier: " .. tostring(Flags.SpeedVal)
end

SliderBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = true updateSlider(input) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if isSliding and input.UserInputType == Enum.UserInputType.MouseMovement then updateSlider(input) end
end)

-- Переключатели
SpeedToggle.MouseButton1Click:Connect(function()
    Flags.Speed = not Flags.Speed
    SpeedToggle.Text = "CFrame Speed: " .. (Flags.Speed and "ON" or "OFF")
    SpeedToggle.TextColor3 = Flags.Speed and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(200, 200, 200)
end)

AutoDigToggle.MouseButton1Click:Connect(function()
    Flags.AutoDig = not Flags.AutoDig
    AutoDigToggle.Text = "Auto Dig (Fixed): " .. (Flags.AutoDig and "ON" or "OFF")
    AutoDigToggle.TextColor3 = Flags.AutoDig and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(200, 200, 200)
end)

AutoPlanterToggle.MouseButton1Click:Connect(function()
    Flags.AutoPlanter = not Flags.AutoPlanter
    AutoPlanterToggle.Text = "Auto Planter: " .. (Flags.AutoPlanter and "ON" or "OFF")
    AutoPlanterToggle.TextColor3 = Flags.AutoPlanter and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(200, 200, 200)
end)

BindButton.MouseButton1Click:Connect(function()
    isBinding = true
    BindButton.Text = "[...]"
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if isBinding and input.UserInputType == Enum.UserInputType.Keyboard then
        CurrentBind = input.KeyCode
        BindButton.Text = "[" .. CurrentBind.Name .. "]"
        isBinding = false
    elseif not gpe and input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- РАБОЧИЕ ЦИКЛЫ
RunService.RenderStepped:Connect(function()
    if Flags.Speed and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = Player.Character.HumanoidRootPart
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * Flags.SpeedVal)
        end
    end
end)

task.spawn(function()
    while task.wait(0.01) do
        if Flags.AutoDig then
            local character = Player.Character
            if character and character:FindFirstChildOfClass("Tool") then
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(PLANTER_DELAY) do
        if Flags.AutoPlanter then
            VirtualInputManager:SendKeyEvent(true, CurrentBind, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, CurrentBind, false, game)
        end
    end
end)

print("[Janus] Clean v3.4 Loaded.")
