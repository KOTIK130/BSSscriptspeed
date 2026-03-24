--![ Janus BSS Ultimate v3.7 - The Fix ]
--! Автор: Janus & Tesavek
--! Статус: Исправлено всё.

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Player = Players.LocalPlayer

-- Удаление старья
if CoreGui:FindFirstChild("Janus_Fixed") then
    CoreGui.Janus_Fixed:Destroy()
end

-- ==========================================
-- СОСТОЯНИЕ (Flags)
-- ==========================================
local Flags = {
    Speed = false,
    SpeedVal = 1.0,
    AutoDig = false,
    AutoPlanter = false
}
local CurrentBind = Enum.KeyCode.One
local isBinding = false

-- ==========================================
-- ГРАФИКА (Normal High-Contrast UI)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "Janus_Fixed"

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Main.Position = UDim2.new(0.5, -130, 0.5, -150)
Main.Size = UDim2.new(0, 260, 0, 320)
Main.BorderSizePixel = 2
Main.BorderColor3 = Color3.fromRGB(0, 255, 150) -- Яркая рамка

-- Закругление
local Corner = Instance.new("UICorner", Main)
Corner.CornerRadius = UDim.new(0, 10)

-- Заголовок
local Header = Instance.new("TextLabel", Main)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Header.Text = "BSS ULTIMATE V3.7"
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.Font = Enum.Font.SourceSansBold
Header.TextSize = 22
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

-- Драг (Перетаскивание)
local dragStart, startPos, dragging
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- Функции создания кнопок
local function makeBtn(text, y, flag)
    local b = Instance.new("TextButton", Main)
    b.Size = UDim2.new(0.9, 0, 0, 40)
    b.Position = UDim2.new(0.05, 0, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    b.Text = text .. ": OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 18
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    
    local stroke = Instance.new("UIStroke", b)
    stroke.Color3 = Color3.new(0,0,0)
    stroke.Thickness = 1.5

    b.MouseButton1Click:Connect(function()
        Flags[flag] = not Flags[flag]
        b.Text = text .. ": " .. (Flags[flag] and "ON" or "OFF")
        b.BackgroundColor3 = Flags[flag] and Color3.fromRGB(0, 120, 80) or Color3.fromRGB(35, 35, 35)
    end)
    return b
end

local SpeedToggle = makeBtn("CFrame Speed", 50, "Speed")

-- Слайдер Скорости
local SLabel = Instance.new("TextLabel", Main)
SLabel.Text = "SPEED MULTIPLIER: 1.0"
SLabel.Position = UDim2.new(0.05, 0, 0, 95)
SLabel.Size = UDim2.new(0.9, 0, 0, 20)
SLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SLabel.Font = Enum.Font.SourceSansBold
SLabel.TextSize = 14
SLabel.BackgroundTransparency = 1

local SBar = Instance.new("Frame", Main)
SBar.Size = UDim2.new(0.9, 0, 0, 10)
SBar.Position = UDim2.new(0.05, 0, 0, 120)
SBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)

local SFill = Instance.new("Frame", SBar)
SFill.Size = UDim2.new(0.1, 0, 1, 0)
SFill.BackgroundColor3 = Color3.fromRGB(0, 255, 150)

local SBtn = Instance.new("TextButton", SBar)
SBtn.Size = UDim2.new(1, 0, 1, 0)
SBtn.BackgroundTransparency = 1
SBtn.Text = ""

SBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local con
        con = RunService.RenderStepped:Connect(function()
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then con:Disconnect() return end
            local rel = math.clamp((UserInputService:GetMouseLocation().X - SBar.AbsolutePosition.X) / SBar.AbsoluteSize.X, 0, 1)
            SFill.Size = UDim2.new(rel, 0, 1, 0)
            Flags.SpeedVal = math.floor((rel * 10) * 10) / 10
            SLabel.Text = "SPEED MULTIPLIER: " .. tostring(Flags.SpeedVal)
        end)
    end
end)

local DigToggle = makeBtn("Auto-Dig", 145, "AutoDig")

-- Плантер Блок
local PFrame = Instance.new("Frame", Main)
PFrame.BackgroundTransparency = 1
PFrame.Position = UDim2.new(0.05, 0, 0, 200)
PFrame.Size = UDim2.new(0.9, 0, 0, 40)

local PToggle = Instance.new("TextButton", PFrame)
PToggle.Size = UDim2.new(0.65, 0, 1, 0)
PToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
PToggle.Text = "Planter: OFF"
PToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
PToggle.Font = Enum.Font.SourceSansBold
PToggle.TextSize = 16
Instance.new("UICorner", PToggle).CornerRadius = UDim.new(0, 6)

local PBind = Instance.new("TextButton", PFrame)
PBind.Size = UDim2.new(0.3, 0, 1, 0)
PBind.Position = UDim2.new(0.7, 0, 0, 0)
PBind.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
PBind.Text = "[" .. CurrentBind.Name .. "]"
PBind.TextColor3 = Color3.fromRGB(0, 255, 150)
PBind.Font = Enum.Font.SourceSansBold
PBind.TextSize = 14
Instance.new("UICorner", PBind).CornerRadius = UDim.new(0, 6)

-- Логика Биндов
PToggle.MouseButton1Click:Connect(function()
    Flags.AutoPlanter = not Flags.AutoPlanter
    PToggle.Text = "Planter: " .. (Flags.AutoPlanter and "ON" or "OFF")
    PToggle.BackgroundColor3 = Flags.AutoPlanter and Color3.fromRGB(0, 120, 80) or Color3.fromRGB(35, 35, 35)
end)

PBind.MouseButton1Click:Connect(function()
    isBinding = true
    PBind.Text = "..."
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if isBinding then
        CurrentBind = input.KeyCode
        PBind.Text = "[" .. input.KeyCode.Name .. "]"
        isBinding = false
    elseif not gpe and input.KeyCode == Enum.KeyCode.Insert then
        Main.Visible = not Main.Visible
    end
end)

-- ==========================================
-- ЛОГИКА (Independent Loops)
-- ==========================================

-- 1. Скоррость (Heartbeat - Самая стабильная)
RunService.Heartbeat:Connect(function()
    if Flags.Speed and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = Player.Character.HumanoidRootPart
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (Flags.SpeedVal * 0.5))
        end
    end
end)

-- 2. Auto-Dig (БЕЗ блокировки мыши)
task.spawn(function()
    while true do
        task.wait(0.1) -- Стандартный кулдаун BSS
        if Flags.AutoDig then
            local char = Player.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                tool:Activate() -- Внутренний метод активации, не мешает мышке
            end
        end
    end
end)

-- 3. Плантер
task.spawn(function()
    while true do
        task.wait(1)
        if Flags.AutoPlanter then
            VirtualInputManager:SendKeyEvent(true, CurrentBind, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, CurrentBind, false, game)
        end
    end
end)

print("[Janus Fix] v3.7 Deployed. GUI Visible. Input Clean.")
