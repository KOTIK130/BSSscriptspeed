local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Hum = Character:WaitForChild("Humanoid")

-- Фикс респавна
Player.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Hum = char:WaitForChild("Humanoid")
end)

-- Координаты Spider Field
local SpiderCenter = Vector3.new(336, 26, -198)

-- Настройки (Flags)
local Flags = {
    AutoFarm = false,
    AutoDig = false,
    AutoConvert = false,
    AutoUseItem = false,
    ItemSlot = 1,
    GlobalSpeed = 100,
    ConvertPoint = nil
}

-- Поиск Remotes
local function findRemote(name) return ReplicatedStorage:FindFirstChild(name, true) end
local Remotes = {
    Click = findRemote("ClickEvent"),
    Tool = findRemote("toolClick"),
    Token = findRemote("tokenEvent"),
    Actives = findRemote("PlayerActivesCommand")
}

--------------------------------------------------------------------------------
-- ЛОГИКА ПЕРЕМЕЩЕНИЯ (TWEEN)
--------------------------------------------------------------------------------

local function tweenTo(targetPos)
    if not HRP then return end
    local distance = (HRP.Position - targetPos).Magnitude
    local duration = distance / Flags.GlobalSpeed
    local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    
    -- Поворачиваем персонажа в сторону цели
    local targetCFrame = CFrame.new(targetPos, Vector3.new(targetPos.X, HRP.Position.Y, targetPos.Z))
    
    local tween = TweenService:Create(HRP, info, {CFrame = targetCFrame})
    tween:Play()
    return tween
end

--------------------------------------------------------------------------------
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
--------------------------------------------------------------------------------

-- Поиск ближайшего токена на поле
local function getNearestToken()
    local coll = workspace:FindFirstChild("Collectibles")
    if not coll then return nil end
    local closest, minDist = nil, 50 -- Радиус поиска на поле
    
    for _, t in pairs(coll:GetChildren()) do
        local pos = t:IsA("BasePart") and t.Position or (t:IsA("Model") and t.PrimaryPart and t.PrimaryPart.Position)
        if pos and (pos - SpiderCenter).Magnitude < 60 then
            local d = (HRP.Position - pos).Magnitude
            if d < minDist then
                minDist = d
                closest = pos
            end
        end
    end
    return closest
end

-- Сбор всех токенов в радиусе через Remote
local function collectTokensRemote()
    local coll = workspace:FindFirstChild("Collectibles")
    if coll and Remotes.Token then
        for _, t in pairs(coll:GetChildren()) do
            local pos = t:IsA("BasePart") and t.Position or (t:IsA("Model") and t.PrimaryPart and t.PrimaryPart.Position)
            if pos and (HRP.Position - pos).Magnitude < 40 then
                pcall(function() Remotes.Token:FireServer(t) end)
            end
        end
    end
end

-- Проверка пыльцы (через GUI)
local function getPollenPercent()
    local ok, res = pcall(function()
        local label = Player.PlayerGui.GameGui.BottomStat.PollenBar.TextLabel
        local cur, max = label.Text:match("([%d,]+)%s*/%s*([%d,]+)")
        return (tonumber(cur:gsub(",", "")) / tonumber(max:gsub(",", ""))) * 100
    end)
    return ok and res or 0
end

--------------------------------------------------------------------------------
-- ИНТЕРФЕЙС (RAYFIELD)
--------------------------------------------------------------------------------

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "JanusBSS Remote v3.0",
    LoadingTitle = "Dynamic Tween Edition",
    ConfigurationSaving = { Enabled = false }
})

local Tab = Window:CreateTab("Farm & Settings", 4483362458)

Tab:CreateToggle({
    Name = "Auto Farm (Tween / Token Focus)",
    CurrentValue = false,
    Callback = function(v) Flags.AutoFarm = v end
})

Tab:CreateToggle({
    Name = "Auto Dig (Remote)",
    CurrentValue = false,
    Callback = function(v) Flags.AutoDig = v end
})

Tab:CreateToggle({
    Name = "Auto Convert",
    CurrentValue = false,
    Callback = function(v) Flags.AutoConvert = v end
})

Tab:CreateSlider({
    Name = "Global Speed",
    Range = {16, 500},
    Increment = 5,
    CurrentValue = 100,
    Callback = function(v) 
        Flags.GlobalSpeed = v
        if Hum then 
            Hum.WalkSpeed = v 
            Hum.JumpPower = v
        end
    end
})

Tab:CreateButton({
    Name = "Set Convert Point (Hive)",
    Callback = function() 
        Flags.ConvertPoint = HRP.Position 
        Rayfield:Notify({Title = "Saved", Content = "Hive position set!", Duration = 2})
    end
})

local ItemsTab = Window:CreateTab("Items", 4483362458)

ItemsTab:CreateToggle({
    Name = "Auto Use Item",
    CurrentValue = false,
    Callback = function(v) Flags.AutoUseItem = v end
})

ItemsTab:CreateSlider({
    Name = "Item Slot",
    Range = {1, 7},
    Increment = 1,
    CurrentValue = 1,
    Callback = function(v) Flags.ItemSlot = v end
})

--------------------------------------------------------------------------------
-- ОСНОВНЫЕ ПОТОКИ (LOOPS)
--------------------------------------------------------------------------------

-- Цикл Фарма (Движение)
task.spawn(function()
    while true do
        task.wait(0.1)
        if Flags.AutoFarm and HRP then
            -- 1. Проверка на конвертацию
            if Flags.AutoConvert and Flags.ConvertPoint and getPollenPercent() >= 95 then
                local lastFieldPos = HRP.Position
                local t = tweenTo(Flags.ConvertPoint)
                if t then t.Completed:Wait() end
                
                -- Конвертация (E)
                VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                
                -- Ждем очистки рюкзака (Remote BSS обычно чистит за 5-15 сек)
                repeat task.wait(1) until getPollenPercent() < 5 or not Flags.AutoConvert
                
                local tBack = tweenTo(lastFieldPos)
                if tBack then tBack.Completed:Wait() end
            end

            -- 2. Логика движения к токенам
            local tokenPos = getNearestToken()
            local moveTarget = tokenPos or (SpiderCenter + Vector3.new(math.random(-45, 45), 0, math.random(-45, 45)))
            
            local farmTween = tweenTo(moveTarget)
            if farmTween then 
                farmTween.Completed:Wait() 
            end
            
            collectTokensRemote() -- Собираем через remote после каждого "шага"
        end
    end
end)

-- Цикл Копки
task.spawn(function()
    while true do
        task.wait(0.1)
        if Flags.AutoDig then
            pcall(function()
                if Remotes.Click then Remotes.Click:FireServer() end
                local tool = Character:FindFirstChildOfClass("Tool")
                if tool and Remotes.Tool then Remotes.Tool:InvokeServer(tool) end
            end)
        end
    end
end)

-- Цикл Предметов (0.6 сек)
task.spawn(function()
    while true do
        task.wait(0.6)
        if Flags.AutoUseItem and Remotes.Actives then
            pcall(function() Remotes.Actives:InvokeServer("Use", Flags.ItemSlot) end)
        end
    end
end)

print("JanusBSS Remote v3.0 Final Loaded!")
