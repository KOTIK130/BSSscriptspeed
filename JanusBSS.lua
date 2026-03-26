--[[
    JanusBSS Remote v2.0
    
    1. Auto Convert - конвертация пыльцы в мёд
    2. Auto Farm - бегает по полю snake, собирает токены и пыльцу
    3. Auto Dig - автокопка
    4. Auto Use Item - использование предметов по слоту (0.6 сек)
    5. Speed - скорость ходьбы, прыжка, полёта
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

-- Player
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Find Remotes
local function findRemote(name, isFunction)
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v.Name == name then
            if isFunction and v:IsA("RemoteFunction") then
                return v
            elseif not isFunction and v:IsA("RemoteEvent") then
                return v
            end
        end
    end
    return nil
end

-- Remotes
local makeHoneyRemote = findRemote("makeHoney", false)
local clickEventRemote = findRemote("ClickEvent", false)
local toolClickRemote = findRemote("toolClick", true)
local tokenEventRemote = findRemote("tokenEvent", false)
local playerActivesCommand = findRemote("PlayerActivesCommand", true)

-- Flags
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

-- Spider Field snake points
local SpiderFieldPoints = {
    Vector3.new(318, 26, -180),
    Vector3.new(328, 26, -180),
    Vector3.new(338, 26, -180),
    Vector3.new(348, 26, -180),
    Vector3.new(358, 26, -180),
    Vector3.new(358, 26, -190),
    Vector3.new(348, 26, -190),
    Vector3.new(338, 26, -190),
    Vector3.new(328, 26, -190),
    Vector3.new(318, 26, -190),
    Vector3.new(318, 26, -200),
    Vector3.new(328, 26, -200),
    Vector3.new(338, 26, -200),
    Vector3.new(348, 26, -200),
    Vector3.new(358, 26, -200),
    Vector3.new(358, 26, -210),
    Vector3.new(348, 26, -210),
    Vector3.new(338, 26, -210),
    Vector3.new(328, 26, -210),
    Vector3.new(318, 26, -210),
    Vector3.new(318, 26, -220),
    Vector3.new(328, 26, -220),
    Vector3.new(338, 26, -220),
    Vector3.new(348, 26, -220),
    Vector3.new(358, 26, -220),
}

local SpiderFieldCenter = Vector3.new(336, 26, -198)

-- Variables
local patrolIndex = 1
local patrolDir = 1
local isConverting = false
local farmPosition = nil

-- Respawn handler
Player.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end)

--------------------------------------------------------------------------------
-- UTILITY
--------------------------------------------------------------------------------

local function getPollenPercent()
    local playerGui = Player:FindFirstChild("PlayerGui")
    if not playerGui then return 0 end
    
    local gameGui = playerGui:FindFirstChild("GameGui")
    if not gameGui then return 0 end
    
    local bottomStat = gameGui:FindFirstChild("BottomStat")
    if not bottomStat then return 0 end
    
    for _, child in pairs(bottomStat:GetDescendants()) do
        if child:IsA("TextLabel") and child.Text:find("/") then
            local text = child.Text
            local current, max = text:match("([%d,]+)/([%d,]+)")
            if current and max then
                current = tonumber(current:gsub(",", "")) or 0
                max = tonumber(max:gsub(",", "")) or 1
                return (current / max) * 100
            end
        end
    end
    
    return 0
end

local function teleportTo(position)
    if HumanoidRootPart then
        HumanoidRootPart.CFrame = CFrame.new(position)
    end
end

local function distanceTo(position)
    if not HumanoidRootPart then return 999 end
    return (HumanoidRootPart.Position - position).Magnitude
end

local function pressKey(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function collectTokens()
    if not tokenEventRemote then return end
    
    local collectibles = workspace:FindFirstChild("Collectibles")
    if not collectibles then return end
    
    for _, token in pairs(collectibles:GetChildren()) do
        local tokenPos
        if token:IsA("Model") then
            local primary = token.PrimaryPart or token:FindFirstChildWhichIsA("BasePart")
            if primary then tokenPos = primary.Position end
        elseif token:IsA("BasePart") then
            tokenPos = token.Position
        end
        
        if tokenPos and distanceTo(tokenPos) < 40 then
            pcall(function()
                tokenEventRemote:FireServer(token)
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- 1. AUTO CONVERT
--------------------------------------------------------------------------------

local function doConvert()
    if not Flags.ConvertPoint then return end
    if isConverting then return end
    
    isConverting = true
    farmPosition = HumanoidRootPart.Position
    
    teleportTo(Flags.ConvertPoint)
    task.wait(0.5)
    
    pressKey(Enum.KeyCode.E)
    
    task.wait(9.5)
    
    if farmPosition then
        teleportTo(farmPosition)
    end
    
    patrolIndex = 1
    isConverting = false
end

--------------------------------------------------------------------------------
-- 2. AUTO FARM
--------------------------------------------------------------------------------

local function getNextPoint()
    local point = SpiderFieldPoints[patrolIndex]
    
    patrolIndex = patrolIndex + patrolDir
    if patrolIndex > #SpiderFieldPoints then
        patrolIndex = #SpiderFieldPoints
        patrolDir = -1
    elseif patrolIndex < 1 then
        patrolIndex = 1
        patrolDir = 1
    end
    
    return point
end

local function farmStep(dt)
    if isConverting then return end
    
    local pollenPercent = getPollenPercent()
    if pollenPercent >= 95 and Flags.AutoConvert and Flags.ConvertPoint then
        doConvert()
        return
    end
    
    local targetPoint = getNextPoint()
    if not targetPoint then return end
    
    local currentPos = HumanoidRootPart.Position
    local direction = (targetPoint - currentPos)
    local distance = direction.Magnitude
    
    if distance > 2 then
        direction = direction.Unit
        local moveSpeed = Flags.Speed * dt
        local newPos = currentPos + direction * math.min(moveSpeed, distance)
        newPos = Vector3.new(newPos.X, targetPoint.Y, newPos.Z)
        
        HumanoidRootPart.CFrame = CFrame.new(newPos, newPos + direction)
        HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
    
    collectTokens()
end

--------------------------------------------------------------------------------
-- 3. AUTO DIG
--------------------------------------------------------------------------------

local function autoDig()
    if clickEventRemote then
        pcall(function()
            clickEventRemote:FireServer()
        end)
    end
    
    if toolClickRemote then
        pcall(function()
            local tool = Character:FindFirstChildOfClass("Tool")
            if tool then
                toolClickRemote:InvokeServer(tool)
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- 4. AUTO USE ITEM
--------------------------------------------------------------------------------

local function useItem()
    local slot = Flags.ItemSlot
    if not slot or slot < 1 then return end
    
    if playerActivesCommand then
        pcall(function()
            playerActivesCommand:InvokeServer("Use", slot)
        end)
    end
    
    local keyMap = {
        [1] = Enum.KeyCode.One,
        [2] = Enum.KeyCode.Two,
        [3] = Enum.KeyCode.Three,
        [4] = Enum.KeyCode.Four,
        [5] = Enum.KeyCode.Five,
        [6] = Enum.KeyCode.Six,
        [7] = Enum.KeyCode.Seven,
    }
    
    if keyMap[slot] then
        pressKey(keyMap[slot])
    end
end

--------------------------------------------------------------------------------
-- 5. SPEED
--------------------------------------------------------------------------------

local function applySpeed()
    if not Humanoid then return end
    
    if Flags.SpeedEnabled then
        Humanoid.WalkSpeed = Flags.Speed
        Humanoid.JumpPower = Flags.JumpPower
    else
        Humanoid.WalkSpeed = 16
        Humanoid.JumpPower = 50
    end
end

local function speedBoost(dt)
    if not Flags.SpeedEnabled then return end
    if not HumanoidRootPart then return end
    if Flags.AutoFarm then return end
    
    local moveDir = Humanoid.MoveDirection
    if moveDir.Magnitude > 0.1 then
        local boost = moveDir * Flags.Speed * dt * 0.5
        HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + Vector3.new(boost.X, 0, boost.Z)
    else
        local vel = HumanoidRootPart.AssemblyLinearVelocity
        HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
    end
end

--------------------------------------------------------------------------------
-- UI (Orion Library)
--------------------------------------------------------------------------------

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmaneon/Script/refs/heads/main/OrionLib.lua"))()

local Window = OrionLib:MakeWindow({
    Name = "JanusBSS Remote v2.0",
    HidePremium = true,
    SaveConfig = false,
    IntroEnabled = false
})

-- Farm Tab
local FarmTab = Window:MakeTab({
    Name = "Farm",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

FarmTab:AddToggle({
    Name = "Auto Farm (Snake)",
    Default = false,
    Callback = function(val)
        Flags.AutoFarm = val
        patrolIndex = 1
        patrolDir = 1
    end
})

FarmTab:AddToggle({
    Name = "Auto Dig",
    Default = false,
    Callback = function(val)
        Flags.AutoDig = val
    end
})

FarmTab:AddToggle({
    Name = "Auto Convert",
    Default = false,
    Callback = function(val)
        Flags.AutoConvert = val
    end
})

FarmTab:AddButton({
    Name = "Set Convert Point",
    Callback = function()
        Flags.ConvertPoint = HumanoidRootPart.Position
        OrionLib:MakeNotification({
            Name = "Convert Point Set",
            Content = string.format("Saved: (%.0f, %.0f, %.0f)", Flags.ConvertPoint.X, Flags.ConvertPoint.Y, Flags.ConvertPoint.Z),
            Time = 3
        })
    end
})

FarmTab:AddButton({
    Name = "TP to Spider Field",
    Callback = function()
        teleportTo(SpiderFieldCenter)
    end
})

-- Items Tab
local ItemsTab = Window:MakeTab({
    Name = "Items",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

ItemsTab:AddToggle({
    Name = "Auto Use Item",
    Default = false,
    Callback = function(val)
        Flags.AutoUseItem = val
    end
})

ItemsTab:AddSlider({
    Name = "Item Slot",
    Min = 1,
    Max = 7,
    Default = 1,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    Callback = function(val)
        Flags.ItemSlot = val
    end
})

-- Speed Tab
local SpeedTab = Window:MakeTab({
    Name = "Speed",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

SpeedTab:AddToggle({
    Name = "Speed Enabled",
    Default = false,
    Callback = function(val)
        Flags.SpeedEnabled = val
        applySpeed()
    end
})

SpeedTab:AddSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 500,
    Default = 100,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    Callback = function(val)
        Flags.Speed = val
        applySpeed()
    end
})

SpeedTab:AddSlider({
    Name = "Jump Power",
    Min = 50,
    Max = 500,
    Default = 100,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    Callback = function(val)
        Flags.JumpPower = val
        applySpeed()
    end
})

--------------------------------------------------------------------------------
-- MAIN LOOPS
--------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function(dt)
    if Flags.AutoFarm then
        farmStep(dt)
    end
    speedBoost(dt)
end)

task.spawn(function()
    while true do
        if Flags.AutoDig then
            autoDig()
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if Flags.AutoUseItem then
            useItem()
        end
        task.wait(0.6)
    end
end)

task.spawn(function()
    while true do
        if Flags.SpeedEnabled then
            applySpeed()
        end
        task.wait(0.5)
    end
end)

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

OrionLib:Init()

print("JanusBSS Remote v2.0 Loaded")
print("1. Auto Farm - snake по Spider Field")
print("2. Auto Convert - TP на точку, E, ждать, вернуться")
print("3. Auto Dig - копка через remote")
print("4. Auto Use Item - предметы с 0.6s")
print("5. Speed - ходьба/прыжок/полёт")
