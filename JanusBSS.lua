local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Hum = Character:WaitForChild("Humanoid")

-- Координаты центра Spider Field из твоего исходника
local SpiderCenter = Vector3.new(336, 26, -198)

local Flags = {
    AutoFarm = false,
    AutoDig = false,
    AutoConvert = false,
    AutoUseItem = false,
    GlobalSpeed = 100,
    ItemSlot = 1,
    ConvertPoint = nil
}

-- Remotes
local function findRemote(name) return ReplicatedStorage:FindFirstChild(name, true) end
local Remotes = {
    Click = findRemote("ClickEvent"),
    Tool = findRemote("toolClick"),
    Token = findRemote("tokenEvent"),
    Actives = findRemote("PlayerActivesCommand")
}

-- Максимально жесткий парсинг рюкзака
local function getPollenPercent()
    local ok, res = pcall(function()
        local label = Player.PlayerGui.GameGui.BottomStat.PollenBar.TextLabel
        local text = label.Text:gsub(",", "")
        local cur, max = text:match("(%d+)/(%d+)")
        return (tonumber(cur) / tonumber(max)) * 100
    end)
    return ok and res or 0
end

-- Поиск токена строго в зоне Паука
local function getBestToken()
    local coll = workspace:FindFirstChild("Collectibles")
    if not coll then return nil end
    local closest, minDist = nil, 60 
    for _, t in pairs(coll:GetChildren()) do
        local pos = t:IsA("BasePart") and t.Position or (t:IsA("Model") and t.PrimaryPart and t.PrimaryPart.Position)
        if pos and (pos - SpiderCenter).Magnitude < 55 then
            local d = (HRP.Position - pos).Magnitude
            if d < minDist then minDist = d; closest = pos end
        end
    end
    return closest
end

--------------------------------------------------------------------------------
-- UI (RayField)
--------------------------------------------------------------------------------
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({Name = "JanusBSS Remote v5.0", ConfigurationSaving = {Enabled = false}})
local Tab = Window:CreateTab("Control", 4483362458)

Tab:CreateToggle({Name = "Auto Farm (CFrame)", CurrentValue = false, Callback = function(v) Flags.AutoFarm = v end})
Tab:CreateToggle({Name = "Auto Dig", CurrentValue = false, Callback = function(v) Flags.AutoDig = v end})
Tab:CreateToggle({Name = "Auto Convert (Hard Priority)", CurrentValue = false, Callback = function(v) Flags.AutoConvert = v end})

Tab:CreateSlider({
    Name = "Global Speed (CFrame)", 
    Range = {20, 500}, 
    Increment = 5, 
    CurrentValue = 100, 
    Callback = function(v) 
        Flags.GlobalSpeed = v 
        Hum.WalkSpeed = v -- Для обычного бега тоже
        Hum.JumpPower = v
    end
})

Tab:CreateButton({Name = "Set Hive Point", Callback = function() Flags.ConvertPoint = HRP.Position end})

local Items = Window:CreateTab("Items", 4483362458)
Items:CreateToggle({Name = "Auto Use Item", CurrentValue = false, Callback = function(v) Flags.AutoUseItem = v end})
Items:CreateSlider({Name = "Slot", Range = {1, 7}, Increment = 1, CurrentValue = 1, Callback = function(v) Flags.ItemSlot = v end})

--------------------------------------------------------------------------------
-- ЛОГИКА ДВИЖЕНИЯ (HEARTBEAT + CFRAME)
--------------------------------------------------------------------------------

local isConverting = false
local randomTarget = SpiderCenter

RunService.Heartbeat:Connect(function(dt)
    if not Flags.AutoFarm or not HRP then return end

    -- 1. ХАРД-ПРИОРИТЕТ: КОНВЕРТАЦИЯ (ПРЕРЫВАЕТ ВСЁ)
    if Flags.AutoConvert and Flags.ConvertPoint and getPollenPercent() >= 99 then
        if not isConverting then
            isConverting = true
            -- Мгновенно в улей через CFrame
            HRP.CFrame = CFrame.new(Flags.ConvertPoint)
            task.wait(0.3)
            VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.1)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            
            -- Не возвращаемся, пока не опустеет
            repeat task.wait(0.5) until getPollenPercent() < 5 or not Flags.AutoConvert
            isConverting = false
        end
        return
    end

    -- 2. ФАРМ НА ПОЛЕ (CFRAME MOVEMENT)
    if not isConverting then
        local tokenPos = getBestToken()
        
        -- Если токена нет, выбираем новую рандомную точку на поле раз в секунду
        if not tokenPos and (HRP.Position - randomTarget).Magnitude < 5 then
            randomTarget = SpiderCenter + Vector3.new(math.random(-45, 45), 0, math.random(-45, 45))
        end
        
        local targetPos = tokenPos or randomTarget
        local direction = (targetPos - HRP.Position)
        
        if direction.Magnitude > 1 then
            local moveStep = direction.Unit * Flags.GlobalSpeed * dt
            -- ЖЕСТКИЙ CFRAME: персонаж перемещается по координатам, игнорируя физику и скольжение
            HRP.CFrame = CFrame.new(HRP.Position + moveStep, Vector3.new(targetPos.X, HRP.Position.Y, targetPos.Z))
            HRP.AssemblyLinearVelocity = Vector3.new(0,0,0) -- Убиваем инерцию
        end

        -- Сбор токенов в радиусе (Remote)
        local coll = workspace:FindFirstChild("Collectibles")
        if coll and Remotes.Token then
            for _, t in pairs(coll:GetChildren()) do
                local p = t:IsA("BasePart") and t.Position or (t:IsA("Model") and t.PrimaryPart and t.PrimaryPart.Position)
                if p and (HRP.Position - p).Magnitude < 35 then
                    pcall(function() Remotes.Token:FireServer(t) end)
                end
            end
        end
    end
end)

-- Автодиг
task.spawn(function()
    while true do
        task.wait(0.1)
        if Flags.AutoDig then
            pcall(function()
                if Remotes.Click then Remotes.Click:FireServer() end
                local t = Character:FindFirstChildOfClass("Tool")
                if t and Remotes.Tool then Remotes.Tool:InvokeServer(t) end
            end)
        end
    end
end)

-- Предметы (0.6s)
task.spawn(function()
    while true do
        task.wait(0.6)
        if Flags.AutoUseItem and Remotes.Actives then
            pcall(function() Remotes.Actives:InvokeServer("Use", Flags.ItemSlot) end)
        end
    end
end)

print("JanusBSS Remote v5.0 Loaded. CFrame Speed & Hard Priority active.")
