--[[
    JanusBSS Remote v2.0 - FIXED
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
-- Исправлено: не ждем бесконечно, если персонаж уже есть
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Фикс для повторного спавна
Player.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end)

-- Поиск Ремоутов (твоя функция без изменений)
local function findRemote(name, isFunction)
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v.Name == name then
            if isFunction and v:IsA("RemoteFunction") then return v
            elseif not isFunction and v:IsA("RemoteEvent") then return v end
        end
    end
    return nil
end

local makeHoneyRemote = findRemote("makeHoney", false)
local clickEventRemote = findRemote("ClickEvent", false)
local toolClickRemote = findRemote("toolClick", true)
local tokenEventRemote = findRemote("tokenEvent", false)
local playerActivesCommand = findRemote("PlayerActivesCommand", true)

local Flags = {
    AutoConvert = false,
    AutoFarm = false,
    AutoDig = false,
    AutoUseItem = false,
    SpeedEnabled = false,
    Speed = 100,
    JumpPower = 100,
    ItemSlot = 1,
    ConvertPoint = nil,
}

-- Точки для Spider Field
local SpiderFieldPoints = {
    Vector3.new(318, 26, -180), Vector3.new(328, 26, -180), Vector3.new(338, 26, -180),
    Vector3.new(348, 26, -180), Vector3.new(358, 26, -180), Vector3.new(358, 26, -190),
    Vector3.new(348, 26, -190), Vector3.new(338, 26, -190), Vector3.new(328, 26, -190),
    Vector3.new(318, 26, -190), Vector3.new(318, 26, -200), Vector3.new(328, 26, -200),
    Vector3.new(338, 26, -200), Vector3.new(348, 26, -200), Vector3.new(358, 26, -200)
}

local patrolIndex = 1
local patrolDir = 1
local isConverting = false
local farmPosition = nil

--------------------------------------------------------------------------------
-- UTILITY (Твои функции)
--------------------------------------------------------------------------------

local function getPollenPercent()
    local playerGui = Player:FindFirstChild("PlayerGui")
    local gameGui = playerGui and playerGui:FindFirstChild("GameGui")
    local bottomStat = gameGui and gameGui:FindFirstChild("BottomStat")
    if not bottomStat then return 0 end
    
    for _, child in pairs(bottomStat:GetDescendants()) do
        if child:IsA("TextLabel") and child.Text:find("/") then
            local current, max = child.Text:match("([%d,]+)/([%d,]+)")
            if current and max then
                return (tonumber(current:gsub(",", "")) / tonumber(max:gsub(",", ""))) * 100
            end
        end
    end
    return 0
end

local function teleportTo(pos) if HumanoidRootPart then HumanoidRootPart.CFrame = CFrame.new(pos) end end

local function pressKey(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function collectTokens()
    if not tokenEventRemote then return end
    local coll = workspace:FindFirstChild("Collectibles")
    if not coll then return end
    for _, t in pairs(coll:GetChildren()) do
        local p = t:IsA("BasePart") and t.Position or (t:IsA("Model") and t.PrimaryPart and t.PrimaryPart.Position)
        if p and (HumanoidRootPart.Position - p).Magnitude < 40 then
            pcall(function() tokenEventRemote:FireServer(t) end)
        end
    end
end

--------------------------------------------------------------------------------
-- UI (RayField) - ОПТИМИЗИРОВАНО
--------------------------------------------------------------------------------

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "JanusBSS Remote v2.0",
    LoadingTitle = "JanusBSS Loader",
    LoadingSubtitle = "by Janus",
    ConfigurationSaving = { Enabled = false }
})

local FarmTab = Window:CreateTab("Farm", 4483362458)

FarmTab:CreateToggle({
    Name = "Auto Farm (Snake)",
    CurrentValue = false,
    Callback = function(val) Flags.AutoFarm = val; patrolIndex = 1 end
})

FarmTab:CreateToggle({
    Name = "Auto Dig",
    CurrentValue = false,
    Callback = function(val) Flags.AutoDig = val end
})

FarmTab:CreateToggle({
    Name = "Auto Convert",
    CurrentValue = false,
    Callback = function(val) Flags.AutoConvert = val end
})

FarmTab:CreateButton({
    Name = "Set Convert Point",
    Callback = function()
        Flags.ConvertPoint = HumanoidRootPart.Position
        Rayfield:Notify({Title = "Point Set!", Content = "Convert point saved.", Duration = 2})
    end
})

local ItemsTab = Window:CreateTab("Items", 4483362458)
ItemsTab:CreateToggle({
    Name = "Auto Use Item",
    CurrentValue = false,
    Callback = function(val) Flags.AutoUseItem = val end
})

ItemsTab:CreateSlider({
    Name = "Item Slot",
    Range = {1, 7},
    Increment = 1,
    CurrentValue = 1,
    Callback = function(val) Flags.ItemSlot = val end
})

local SpeedTab = Window:CreateTab("Speed", 4483362458)
SpeedTab:CreateToggle({
    Name = "Speed Enabled",
    CurrentValue = false,
    Callback = function(val) 
        Flags.SpeedEnabled = val 
        if not val then 
            Humanoid.WalkSpeed = 16 
            Humanoid.JumpPower = 50 
        end
    end
})

--------------------------------------------------------------------------------
-- ЛОГИКА (ВЫНЕСЕНА В ОДИН ПОТОК ДЛЯ СТАБИЛЬНОСТИ)
--------------------------------------------------------------------------------

-- Автофарм и Спидбуст
RunService.Heartbeat:Connect(function(dt)
    if Flags.AutoFarm and not isConverting and HumanoidRootPart then
        -- Проверка на конвертацию
        if Flags.AutoConvert and Flags.ConvertPoint and getPollenPercent() >= 95 then
            isConverting = true
            farmPosition = HumanoidRootPart.Position
            teleportTo(Flags.ConvertPoint)
            task.wait(0.5)
            pressKey(Enum.KeyCode.E)
            task.wait(9.5)
            teleportTo(farmPosition)
            isConverting = false
            return
        end

        -- Движение Snake
        local target = SpiderFieldPoints[patrolIndex]
        if target then
            local direction = (target - HumanoidRootPart.Position)
            if direction.Magnitude > 2 then
                local move = direction.Unit * Flags.Speed * dt
                HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position + move, target)
            else
                patrolIndex = patrolIndex + patrolDir
                if patrolIndex > #SpiderFieldPoints or patrolIndex < 1 then
                    patrolDir = -patrolDir
                    patrolIndex = patrolIndex + (patrolDir * 2)
                end
            end
        end
        collectTokens()
    end

    -- Спидхак (если не на фарме)
    if Flags.SpeedEnabled and not Flags.AutoFarm and Humanoid.MoveDirection.Magnitude > 0 then
        local b = Humanoid.MoveDirection * Flags.Speed * dt * 0.5
        HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + Vector3.new(b.X, 0, b.Z)
    end
end)

-- Вспомогательные циклы
task.spawn(function()
    while task.wait(0.1) do
        if Flags.AutoDig then
            pcall(function() 
                if clickEventRemote then clickEventRemote:FireServer() end
                local t = Character:FindFirstChildOfClass("Tool")
                if t and toolClickRemote then toolClickRemote:InvokeServer(t) end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.6) do
        if Flags.AutoUseItem and playerActivesCommand then
            pcall(function() playerActivesCommand:InvokeServer("Use", Flags.ItemSlot) end)
            local keys = {[1]=Enum.KeyCode.One,[2]=Enum.KeyCode.Two,[3]=Enum.KeyCode.Three,[4]=Enum.KeyCode.Four,[5]=Enum.KeyCode.Five,[6]=Enum.KeyCode.Six,[7]=Enum.KeyCode.Seven}
            if keys[Flags.ItemSlot] then pressKey(keys[Flags.ItemSlot]) end
        end
    end
end)

print("JanusBSS Remote v2.0 - LOADED")
