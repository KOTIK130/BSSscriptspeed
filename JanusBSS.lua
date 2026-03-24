--! [ JanusBSS GUI v5.0 - Ultra Stable ]
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Player = game.Players.LocalPlayer

local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "JanusBSS_UI"

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 200, 0, 150)
Frame.Position = UDim2.new(0.5, -100, 0.5, -75) -- Центр экрана
Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Frame.Active = true
Frame.Draggable = true 

local Title = Instance.new("TextLabel", Frame)
Title.Text = "JANUS BSS"
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.SourceSansBold -- Универсальный шрифт
Title.TextSize = 14

local ToggleBtn = Instance.new("TextButton", Frame)
ToggleBtn.Text = "SPEED: OFF"
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0.4, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
ToggleBtn.Font = Enum.Font.SourceSansBold

local SpeedEnabled = false
ToggleBtn.MouseButton1Click:Connect(function()
    SpeedEnabled = not SpeedEnabled
    ToggleBtn.Text = SpeedEnabled and "SPEED: ON" or "SPEED: OFF"
end)

-- Движение
RunService.RenderStepped:Connect(function()
    if SpeedEnabled and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local HRP = Player.Character.HumanoidRootPart
        local Dir = Player.Character.Humanoid.MoveDirection
        if Dir.Magnitude > 0 then
            HRP.CFrame = HRP.CFrame + (Dir * 0.8)
        end
    end
end)

-- Скрытие на Insert
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then
        Frame.Visible = not Frame.Visible
    end
end)

print("[Janus] V5 loaded successfully with stable font.")
