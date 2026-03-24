--! [ JanusBSS GUI v4.0 - Hardened ]
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "JanusBSS_UI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Frame = Instance.new("Frame", ScreenGui)
Frame.Name = "MainFrame"
Frame.Size = UDim2.new(0, 220, 0, 180)
Frame.Position = UDim2.new(0.5, -110, 0.5, -90)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)

-- Функция перетаскивания (Custom)
local Dragging, DragInput, DragStart, StartPos
Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Dragging = true
        DragStart = input.Position
        StartPos = Frame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and Dragging then
        local delta = input.Position - DragStart
        Frame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
end)

-- Заголовок
local Title = Instance.new("TextLabel", Frame)
Title.Text = "JANUS BSS"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(0, 255, 255)
Title.Font = Enum.Font.CodeBold
Title.TextSize = 18

-- Кнопка Toggle
local ToggleBtn = Instance.new("TextButton", Frame)
ToggleBtn.Text = "SPEED OFF"
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0.5, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 150)
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 5)

local SpeedEnabled = false
ToggleBtn.MouseButton1Click:Connect(function()
    SpeedEnabled = not SpeedEnabled
    ToggleBtn.Text = SpeedEnabled and "SPEED ON" or "SPEED OFF"
    ToggleBtn.BackgroundColor3 = SpeedEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(0, 150, 150)
end)

-- Перемещение
RunService.RenderStepped:Connect(function()
    if SpeedEnabled and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local HRP = Player.Character.HumanoidRootPart
        local Dir = Player.Character.Humanoid.MoveDirection
        if Dir.Magnitude > 0 then
            HRP.CFrame = HRP.CFrame + (Dir * 0.8)
        end
    end
end)

-- Скрытие
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then
        Frame.Visible = not Frame.Visible
    end
end)

print("[Janus] V4 Loaded and Forced.")
