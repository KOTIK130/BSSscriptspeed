local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Hum = Character:WaitForChild("Humanoid")

-- Настройки по умолчанию
local Flags = {
    AutoFarm = false,
    AutoDig = false,
    AutoConvert = false,
    AutoUseItem = false,
    GlobalSpeed = 100,
    ItemSlot = 1,
    ItemDelay = 0.6,
    HivePos = nil,
    FieldPos = Vector3.new(336, 26, -198) -- Дефолт Паука
}

local Remotes = {
    Click = ReplicatedStorage:FindFirstChild("ClickEvent", true),
    Tool = ReplicatedStorage:FindFirstChild("toolClick", true),
    Token = ReplicatedStorage:FindFirstChild("tokenEvent", true),
    Actives = ReplicatedStorage:FindFirstChild("PlayerActivesCommand", true)
}

-- Вспомогательные функции
local function getPollen()
    local ok, res = pcall(function()
        local text = Player.PlayerGui.GameGui.BottomStat.PollenBar.TextLabel.Text:gsub(",", "")
        local cur, max = text:match("(%d+)/([%d%.]+)")
        return (tonumber(cur) / tonumber(max)) * 100
    end)
    return ok and res or 0
end

local function moveTo(targetPos, speed)
    local dist = (HRP.Position - targetPos).Magnitude
    local duration = dist / speed
    local tween = TweenService:Create(HRP, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
    tween:Play()
    return tween
end

--------------------------------------------------------------------------------
-- UI (Rayfield)
--------------------------------------------------------------------------------
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({Name = "JanusBSS ULTIMATE v7.0", ConfigurationSaving = {Enabled = false}})
local Tab = Window:CreateTab("Main Farm", 4483362458)

Tab:CreateToggle({Name = "Auto Farm (Tween & CFrame)", CurrentValue = false, Callback = function(v) Flags.AutoFarm = v end})
Tab:CreateToggle({Name = "Auto Dig", CurrentValue = false, Callback = function(v) Flags.AutoDig = v end})
Tab:CreateToggle({Name = "Auto Convert", CurrentValue = false, Callback = function(v) Flags.AutoConvert = v end})

Tab:CreateSlider({
    Name = "Movement Speed", 
    Range = {20, 300}, 
    Increment = 10, 
    CurrentValue = 100, 
    Callback = function(v) Flags.GlobalSpeed = v end
})

Tab:CreateButton({Name = "Set Hive Point (Stand at Hive)", Callback = function() Flags.HivePos = HRP.Position end})
Tab:CreateButton({Name = "Set Field Point (Spider)", Callback = function() Flags.FieldPos = HRP.Position end})

local Items = Window:CreateTab("Items", 4483362458)
Items:CreateToggle({Name = "Auto Use Item", CurrentValue = false, Callback = function(v) Flags.AutoUseItem = v end})
Items:CreateSlider({Name = "Item Slot", Range = {1, 7}, Increment = 1, CurrentValue = 1, Callback = function(v) Flags.ItemSlot = v end})

--------------------------------------------------------------------------------
-- ОСНОВНАЯ ЛОГИКА
--------------------------------------------------------------------------------

local isProcessing = false

-- 1. ЦИКЛ АВТО-ДИГА (0.1s)
task.spawn(function()
    while true do
        task.wait(0.1)
        if Flags.AutoDig and not isProcessing then
            pcall(function()
                Remotes.Click:FireServer()
                local tool = Character:FindFirstChildOfClass("Tool")
                if tool then Remotes.Tool:InvokeServer(tool) end
            end)
        end
    end
end)

-- 2. АВТО-ИСПОЛЬЗОВАНИЕ ПРЕДМЕТОВ (0.6s)
task.spawn(function()
    while true do
        task.wait(Flags.ItemDelay)
        if Flags.AutoUseItem and not isProcessing then
            pcall(function()
                Remotes.Actives:InvokeServer("Use", Flags.ItemSlot)
            end)
        end
    end
end)

-- 3. ГЛАВНЫЙ ЦИКЛ ФАРМА И ДВИЖЕНИЯ
RunService.Heartbeat:Connect(function(dt)
    if not Flags.AutoFarm or isProcessing then return end

    -- Проверка на заполненность рюкзака
    if Flags.AutoConvert and Flags.HivePos and getPollen() >= 98 then
        isProcessing = true
        local tween = moveTo(Flags.HivePos, Flags.GlobalSpeed)
        tween.Completed:Wait()
        
        -- Процесс конвертации
        task.wait(0.2)
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        repeat task.wait(1) until getPollen() < 5 or not Flags.AutoConvert
        
        -- Возврат на поле
        local returnTween = moveTo(Flags.FieldPos, Flags.GlobalSpeed)
        returnTween.Completed:Wait()
        isProcessing = false
        return
    end

    -- Поиск токенов на поле
    local collectibles = workspace:FindFirstChild("Collectibles")
    local targetToken = nil
    if collectibles then
        for _, v in pairs(collectibles:GetChildren()) do
            local pos = v:IsA("BasePart") and v.Position or (v:IsA("Model") and v.PrimaryPart and v.PrimaryPart.Position)
            if pos and (pos - Flags.FieldPos).Magnitude < 50 then
                targetToken = pos
                break -- Берем первый попавшийся на поле
            end
        end
    end

    -- Движение (CFrame Speed с учетом высоты прыжка/парашюта)
    local target = targetToken or (Flags.FieldPos + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20)))
    local moveDir = (target - HRP.Position).Unit
    
    -- Оставляем Y как есть, чтобы не мешать физике прыжка/парашюта
    local newVelocity = Vector3.new(moveDir.X * Flags.GlobalSpeed, HRP.AssemblyLinearVelocity.Y, moveDir.Z * Flags.GlobalSpeed)
    
    -- Если мы фармим, то двигаем CFrame плавно к цели
    if (target - HRP.Position).Magnitude > 2 then
        HRP.CFrame = CFrame.new(HRP.Position + (Vector3.new(moveDir.X, 0, moveDir.Z) * Flags.GlobalSpeed * dt), 
                     Vector3.new(target.X, HRP.Position.Y, target.Z))
    end
    
    -- Обнуляем горизонтальную инерцию, но сохраняем вертикальную
    HRP.AssemblyLinearVelocity = Vector3.new(0, HRP.AssemblyLinearVelocity.Y, 0)
end)

print("JanusBSS Remote v7.0 Fully Active")
