--![ Janus BSS Ultimate v3.8 - High Visibility & Compatibility Fix ]
--! Автор: Janus & Tesavek
--! Статус: ULTRA-COMPATIBLE (Убраны UIStroke, UICorner и сложная логика)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Player = Players.LocalPlayer

-- Очистка старых сессий ( image_0.png )
if CoreGui:FindFirstChild("Janus_Ultimatum") then
    CoreGui.Janus_Ultimatum:Destroy()
end

-- ==========================================
-- КОНФИГУРАЦИЯ
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
-- ГРАФИКА (Самая простая, гарантированно рабочая)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "Janus_Ultimatum"
ScreenGui.ResetOnSpawn = false

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Main.Position = UDim2.new(0.5, -130, 0.5, -160)
Main.Size = UDim2.new(0, 260, 0, 360) -- Увеличили под огромные кнопки
Main.BorderSizePixel = 3
Main.BorderColor3 = Color3.fromRGB(255, 255, 255) -- Четкая белая рамка

-- Заголовок (image_0.png fix: Огромный белый текст)
local Header = Instance.new("TextLabel", Main)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Header.Text = "BSS ULTIMATUM V3.8"
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.Font = Enum.Font.SourceSansBold
Header.TextSize = 24 -- Максимальная читаемость

-- Логика перетаскивания (image_0.png fix: Dragging)
local dragStart, startPos, dragging
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = input.Position startPos = Main.Position end
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

-- Хелпер кнопок (image_0.png fix: Большие, Белые, Контрастные)
local function makeBtn(text, y, flag)
    local b = Instance.new("TextButton", Main)
    b.Size = UDim2.new(0.9, 0, 0, 45) -- Кнопка стала больше
    b.Position = UDim2.new(0.05, 0, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    b.Text = text .. ": OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255) -- Pure white
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 20 -- Огромный текст
    b.BorderSizePixel = 1
    b.BorderColor3 = Color3.fromRGB(255, 255, 255)

    b.MouseButton1Click:Connect(function()
        Flags[flag] = not Flags[flag]
        b.Text = text .. ": " .. (Flags[flag] and "ON" or "OFF")
        b.BackgroundColor3 = Flags[flag] and Color3.fromRGB(0, 120, 80) or Color3.fromRGB(40, 40, 40)
    end)
    return b
end

local SpeedToggle = makeBtn("CFrame Speed", 50, "Speed")

-- Слайдер Скорости (image_0.png fix: Читаемость)
local SLabel = Instance.new("TextLabel", Main)
SLabel.Text = "SPEED: 1.0"
SLabel.Position = UDim2.new(0.05, 0, 0, 100)
SLabel.Size = UDim2.new(0.9, 0, 0, 20)
SLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SLabel.Font = Enum.Font.SourceSansBold
SLabel.TextSize = 18 -- Большой шрифт
SLabel.BackgroundTransparency = 1

local SBar = Instance.new("Frame", Main)
SBar.Size = UDim2.new(0.9, 0, 0, 20) -- Слайдер стал толще
SBar.Position = UDim2.new(0.05, 0, 0, 125)
SBar.BackgroundColor3 = Color3.fromRGB(55, 55, 55)

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
            Flags.SpeedVal = math.floor((rel * 10) * 10) / 10 -- До 10x
            SLabel.Text = "SPEED: " .. tostring(Flags.SpeedVal)
        end)
    end
end)

local DigToggle = makeBtn("Auto-Dig", 160, "AutoDig")

-- Плантер (image_0.png fix: Огромный шрифт бинда)
local PFrame = Instance.new("Frame", Main)
PFrame.BackgroundTransparency = 1
PFrame.Position = UDim2.new(0.05, 0, 0, 215)
PFrame.Size = UDim2.new(0.9, 0, 0, 45)

local PToggle = Instance.new("TextButton", PFrame)
PToggle.Size = UDim2.new(0.6, 0, 1, 0)
PToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
PToggle.Text = "Planter: OFF"
PToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
PToggle.Font = Enum.Font.SourceSansBold
PToggle.TextSize = 18
PToggle.BorderSizePixel = 1
PToggle.BorderColor3 = Color3.fromRGB(255, 255, 255)

local PBind = Instance.new("TextButton", PFrame)
PBind.Size = UDim2.new(0.35, 0, 1, 0)
PBind.Position = UDim2.new(0.65, 0, 0, 0)
PBind.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
PBind.Text = "[" .. CurrentBind.Name .. "]"
PBind.TextColor3 = Color3.fromRGB(0, 255, 150) -- Яркий бинд
PBind.Font = Enum.Font.SourceSansBold
PBind.TextSize = 16 -- Огромный бинд
PBind.BorderSizePixel = 1
PBind.BorderColor3 = Color3.fromRGB(255, 255, 255)

-- Логика Planter
PToggle.MouseButton1Click:Connect(function()
    Flags.AutoPlanter = not Flags.AutoPlanter
    PToggle.Text = "Planter: " .. (Flags.AutoPlanter and "ON" or "OFF")
    PToggle.BackgroundColor3 = Flags.AutoPlanter and Color3.fromRGB(0, 120, 80) or Color3.fromRGB(40, 40, 40)
end)
PBind.MouseButton1Click:Connect(function()
    isBinding = true PBind.Text = "..."
end)
UserInputService.InputBegan:Connect(function(input, gpe)
    if isBinding then CurrentBind = input.KeyCode PBind.Text = "[" .. input.KeyCode.Name .. "]" isBinding = false
    elseif not gpe and input.KeyCode == Enum.KeyCode.Insert then Main.Visible = not Main.Visible end
end)

-- ==========================================
-- ЛОГИКА (Independent Loops)
-- ==========================================
RunService.Heartbeat:Connect(function()
    if Flags.Speed and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            Player.Character.HumanoidRootPart.CFrame = Player.Character.HumanoidRootPart.CFrame + (hum.MoveDirection * (Flags.SpeedVal * 0.5))
        end
    end
end)
task.spawn(function()
    while true do task.wait(0.1) if Flags.AutoDig then local char = Player.Character local tool = char and char:FindFirstChildOfClass("Tool") if tool then tool:Activate() end end end
end)
task.spawn(function()
    while true do task.wait(1) if Flags.AutoPlanter then VirtualInputManager:SendKeyEvent(true, CurrentBind, false, game) task.wait(0.05) VirtualInputManager:SendKeyEvent(false, CurrentBind, false, game) end end
end)

print("[Janus ULTRA] v3.8 Deployed. Compatibility Guaranteed. INSERT to toggle.")
