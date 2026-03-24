--! [ JanusBSS GUI v3.0 - Cyber Style ]
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Player = game.Players.LocalPlayer

-- UI setup
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "JanusBSS_UI"

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 220, 0, 180)
Frame.Position = UDim2.new(0.05, 0, 0.05, 0)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Frame.BorderSizePixel = 0
Frame.Draggable = true

-- Скругление углов (UICorner)
local Corner = Instance.new("UICorner", Frame)
Corner.CornerRadius = UDim.new(0, 10)

-- Заголовок с градиентом
local Title = Instance.new("TextLabel", Frame)
Title.Text = "JANUS BSS // V3"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(0, 255, 255)
Title.Font = Enum.Font.CodeBold
Title.TextSize = 16

-- Ползунок скорости
local SliderBack = Instance.new("Frame", Frame)
SliderBack.Size = UDim2.new(0.8, 0, 0, 10)
SliderBack.Position = UDim2.new(0.1, 0, 0.4, 0)
SliderBack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
Instance.new("UICorner", SliderBack).CornerRadius = UDim.new(1, 0)

local SliderBar = Instance.new("Frame", SliderBack)
SliderBar.Size = UDim2.new(0.25, 0, 1, 0)
SliderBar.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
Instance.new("UICorner", SliderBar).CornerRadius = UDim.new(1, 0)

-- Логика ползунка
local SpeedValue = 0.5
SliderBack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mouse = Player:GetMouse()
        while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            local rel = (mouse.X - SliderBack.AbsolutePosition.X) / SliderBack.AbsoluteSize.X
            SpeedValue = math.clamp(rel * 2, 0, 2)
            SliderBar.Size = UDim2.new(math.clamp(rel, 0, 1), 0, 1, 0)
            RunService.RenderStepped:Wait()
        end
    end
end)

-- Переключатель
local ToggleBtn = Instance.new("TextButton", Frame)
ToggleBtn.Text = "ENABLE SPEED"
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0.6, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
ToggleBtn.TextColor3 = Color3.fromRGB(20, 20, 25)
ToggleBtn.Font = Enum.Font.CodeBold
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 5)

local SpeedEnabled = false
ToggleBtn.MouseButton1Click:Connect(function()
    SpeedEnabled = not SpeedEnabled
    ToggleBtn.BackgroundColor3 = SpeedEnabled and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(0, 255, 255)
    ToggleBtn.Text = SpeedEnabled and "SPEED ACTIVE" or "ENABLE SPEED"
end)

-- Движение
RunService.RenderStepped:Connect(function()
    if SpeedEnabled and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local HRP = Player.Character.HumanoidRootPart
        local Dir = Player.Character.Humanoid.MoveDirection
        if Dir.Magnitude > 0 then
            HRP.CFrame = HRP.CFrame + (Dir * SpeedValue)
        end
    end
end)

-- Клавиша скрытия (Insert)
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then
        Frame.Visible = not Frame.Visible
    end
end)
