--![ Janus BSS Ultimate v3.9 - Last Hope Edition ]
--! Если это не сработает, значит твой экзекутор не рисует GUI.

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Player = Players.LocalPlayer

-- Полная очистка перед запуском
for _, v in pairs(CoreGui:GetChildren()) do
    if v.Name == "Janus_Final" then v:Destroy() end
end

local Flags = { Speed = false, SpeedVal = 1.0, AutoDig = false, AutoPlanter = false }
local CurrentBind = Enum.KeyCode.One
local isBinding = false

-- Создаем GUI (Уровень: Каменный век)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Janus_Final"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Parent = ScreenGui
Main.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
Main.BorderSizePixel = 4
Main.BorderColor3 = Color3.new(1, 1, 1)
Main.Position = UDim2.new(0.5, -125, 0.5, -150)
Main.Size = UDim2.new(0, 250, 0, 300)
Main.Active = true
Main.Draggable = true -- Самый простой способ перемещения

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Parent = Main
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
Title.Text = "JANUS BSS V3.9"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 20
Title.Font = Enum.Font.SourceSansBold

-- ФУНКЦИЯ СОЗДАНИЯ КНОПОК (БЕЗ ВЛОЖЕНИЙ)
local function CreateButton(name, text, y, callback)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Parent = Main
    b.Size = UDim2.new(0.8, 0, 0, 40)
    b.Position = UDim2.new(0.1, 0, 0, y)
    b.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 18
    b.Font = Enum.Font.SourceSansBold
    b.BorderSizePixel = 2
    b.MouseButton1Click:Connect(callback)
    return b
end

-- 1. СКОРОСТЬ
local SpeedBtn = CreateButton("SpeedBtn", "Speed: OFF", 50, function()
    Flags.Speed = not Flags.Speed
    local b = Main:FindFirstChild("SpeedBtn")
    b.Text = "Speed: " .. (Flags.Speed and "ON" or "OFF")
    b.BackgroundColor3 = Flags.Speed and Color3.new(0, 0.5, 0) or Color3.new(0.3, 0.3, 0.3)
end)

-- 2. АВТОДИГ
local DigBtn = CreateButton("DigBtn", "Auto-Dig: OFF", 100, function()
    Flags.AutoDig = not Flags.AutoDig
    local b = Main:FindFirstChild("DigBtn")
    b.Text = "Auto-Dig: " .. (Flags.AutoDig and "ON" or "OFF")
    b.BackgroundColor3 = Flags.AutoDig and Color3.new(0, 0.5, 0) or Color3.new(0.3, 0.3, 0.3)
end)

-- 3. ПЛАНТЕР
local PlanterBtn = CreateButton("PlanterBtn", "Planter: OFF", 150, function()
    Flags.AutoPlanter = not Flags.AutoPlanter
    local b = Main:FindFirstChild("PlanterBtn")
    b.Text = "Planter: " .. (Flags.AutoPlanter and "ON" or "OFF")
    b.BackgroundColor3 = Flags.AutoPlanter and Color3.new(0, 0.5, 0) or Color3.new(0.3, 0.3, 0.3)
end)

-- 4. БИНД
local BindBtn = CreateButton("BindBtn", "Bind: ["..CurrentBind.Name.."]", 200, function()
    isBinding = true
    Main:FindFirstChild("BindBtn").Text = "..."
end)

-- Управление биндом и INSERT
UserInputService.InputBegan:Connect(function(input, gpe)
    if isBinding then
        CurrentBind = input.KeyCode
        Main:FindFirstChild("BindBtn").Text = "Bind: ["..input.KeyCode.Name.."]"
        isBinding = false
    elseif not gpe and input.KeyCode == Enum.KeyCode.Insert then
        Main.Visible = not Main.Visible
    end
end)

-- ==========================================
-- ЦИКЛЫ (ВЫНЕСЕНЫ ИЗ ГУИ)
-- ==========================================
RunService.Heartbeat:Connect(function()
    if Flags.Speed and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            Player.Character.HumanoidRootPart.CFrame = Player.Character.HumanoidRootPart.CFrame + (hum.MoveDirection * 0.5)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.15)
        if Flags.AutoDig then
            local tool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() end
        end
    end
end)

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

print("Janus v3.9 Loaded. Look at your screen.")
