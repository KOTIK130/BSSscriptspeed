local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Hum = Character:WaitForChild("Humanoid")

-- ТЕ САМЫЕ КООРДИНАТЫ ЦЕНТРА ПАУКА
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

-- Анализ рюкзака (Безусловный приоритет)
local function getPollenPercent()
    local ok, res = pcall(function()
        local bar = Player.PlayerGui.GameGui.BottomStat.PollenBar.TextLabel
        local text = bar.Text:gsub(",", "")
        local cur, max = text:match("(%d+)/(%d+)")
        return (tonumber(cur) / tonumber(max)) * 100
    end)
    return ok and res or 0
end

-- Поиск токена строго на поле
local function getBestToken()
    local coll = workspace:FindFirstChild("Collectibles")
    if not coll then return nil end
    local closest, minDist = nil, 60 
    for _, t in pairs(coll:GetChildren()) do
        local pos = t:IsA("BasePart") and t.Position or (t:IsA("Model") and t.PrimaryPart and t.PrimaryPart.Position)
        if pos and (pos - SpiderCenter).Magnitude < 50 then -- Граница поля
            local d = (HRP.Position - pos).Magnitude
            if d < minDist then minDist = d; closest = pos end
        end
    end
    return closest
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({Name = "JanusBSS Remote v5.0", ConfigurationSaving = {Enabled = false}})
local Tab = Window:CreateTab("Main", 4483362458)

Tab:CreateToggle({Name = "Auto Farm (CFrame + Tokens)", CurrentValue = false, Callback = function(v) Flags.AutoFarm = v end})
Tab:CreateToggle({Name = "Auto Dig", CurrentValue = false, Callback = function(v) Flags.AutoDig = v end})
Tab:CreateToggle({Name = "Auto Convert", CurrentValue = false, Callback = function(v) Flags.AutoConvert = v end})
Tab:CreateSlider({Name = "Global Speed", Range = {20, 400}, Increment = 5, CurrentValue = 100, Callback = function(v) Flags.GlobalSpeed = v end})
Tab:CreateButton({Name = "Set Hive Point", Callback = function() Flags.ConvertPoint = HRP.Position end})

local Items = Window:CreateTab("Items", 4483362458)
Items:CreateToggle({Name = "Auto Use Item", CurrentValue = false, Callback = function(v) Flags.AutoUseItem = v end})
Items:CreateSlider({Name = "Slot", Range = {1, 7}, Increment = 1, CurrentValue = 1, Callback = function(v) Flags.ItemSlot = v end})

--------------------------------------------------------------------------------
-- ЛОГИКА (CFrame & Hard Priority)
--------------------------------------------------------------------------------

local currentTarget = nil
local isConverting = false

RunService.Heartbeat:Connect(function(dt)
    if not Flags.AutoFarm or not HRP then return end

    -- 1. ЖЕСТКАЯ ПРОВЕРКА КОНВЕРТАЦИИ (ПРИОРИТЕТ №1)
    if Flags.AutoConvert and Flags.ConvertPoint and getPollenPercent() >= 99 then
        isConverting = true
        HRP.CFrame = CFrame.new(Flags.ConvertPoint)
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        
        -- Цикл ожидания очистки рюкзака
        repeat task.wait(0.5) until getPollenPercent() < 5 or not Flags.AutoConvert
        isConverting = false
        return
    end

    -- 2. ДВИЖЕНИЕ CFRAME (БЕЗ СКОЛЬЖЕНИЯ)
    if not isConverting then
        local tokenPos = getBestToken()
        -- Если токена нет, просто летаем вокруг центра поля
        local targetPos = tokenPos or (SpiderCenter + Vector3.new(math.random(-30,30), 0, math.random(-30,30)))
        
        local direction = (targetPos - HRP.Position)
        if direction.Magnitude > 1 then
            local moveStep = direction.Unit * Flags.GlobalSpeed * dt
            -- Применяем CFrame перемещение (мгновенная остановка, никакого заноса)
            HRP.CFrame = CFrame.new(HRP.Position + moveStep, Vector3.new(targetPos.X, HRP.Position.Y, targetPos.Z))
        end

        -- Сбор токенов через Remote в радиусе
        local coll = workspace:FindFirstChild("Collectibles")
        if coll and Remotes.Token then
            for _, t in pairs(coll:GetChildren()) do
                local p = t:IsA("BasePart") and t.Position or (t:IsA("Model") and t.PrimaryPart and t.PrimaryPart.Position)
                if p and (HRP.Position - p).Magnitude < 30 then
                    pcall(function() Remotes.Token:FireServer(t) end)
                end
            end
        end
    end
end)

-- Автодиг и Предметы (0.6s)
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

task.spawn(function()
    while true do
        task.wait(0.6)
        if Flags.AutoUseItem and Remotes.Actives then
            pcall(function() Remotes.Actives:InvokeServer("Use", Flags.ItemSlot) end)
        end
    end
end)

print("JanusBSS v5.0 - Координаты Паука и CFrame Speed исправлены.")
