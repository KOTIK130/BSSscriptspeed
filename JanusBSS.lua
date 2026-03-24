--! [ JanusBSS Core Script ]
-- Скрипт для Bee Swarm Simulator
-- Подключается через: loadstring(game:HttpGet("ССЫЛКА_НА_RAW_ФАЙЛ"))()

local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Player = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- 1. Создание GUI
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "JanusBSS_UI"

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 240, 0, 200)
Frame.Position = UDim2.new(0.05, 0, 0.05, 0)
Frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Frame.BorderSizePixel = 0
Frame.Draggable = true

local Title = Instance.new("TextLabel", Frame)
Title.Text = "JANUS BSS [ACTIVE]"
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Title.TextColor3 = Color3.new(1, 1, 1)

-- 2. Переменные состояния
local SpeedEnabled = false
local SpeedMultiplier = 0.8

-- 3. Кнопки управления
local function CreateButton(text, pos, callback)
    local btn = Instance.new("TextButton", Frame)
    btn.Text = text
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.Position = pos
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

CreateButton("Toggle Speed (CFrame)", UDim2.new(0.05, 0, 0.25, 0), function()
    SpeedEnabled = not SpeedEnabled
    print("Speed: " .. (SpeedEnabled and "ON" or "OFF"))
end)

CreateButton("Speed +0.1", UDim2.new(0.05, 0, 0.55, 0), function()
    SpeedMultiplier = SpeedMultiplier + 0.1
    print("Multiplier: " .. SpeedMultiplier)
end)

-- 4. Игровой цикл для перемещения
RunService.RenderStepped:Connect(function()
    if SpeedEnabled and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local HRP = Player.Character.HumanoidRootPart
        local Humanoid = Player.Character.Humanoid
        
        -- Перемещение через CFrame (самый надежный метод для BSS)
        if Humanoid.MoveDirection.Magnitude > 0 then
            HRP.CFrame = HRP.CFrame + (Humanoid.MoveDirection * SpeedMultiplier)
        end
    end
end)

print("[Janus] BSS Core Loaded successfully.")
