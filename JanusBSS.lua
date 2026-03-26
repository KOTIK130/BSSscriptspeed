--[[
    JanusBSS Remote v2.1 [FINAL REMOTE REPAIR]
    - Исправлено движение (теперь не кидает в пустоту)
    - Починен Auto-Dig (двойной метод)
    - Добавлен рабочий слайдер скорости
    - Фикс конвертации
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Hum = Character:WaitForChild("Humanoid")

-- Переподключение при респавне
Player.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    Hum = char:WaitForChild("Humanoid")
end)

-- Поиск Remotes
local function findRemote(name)
    return ReplicatedStorage:FindFirstChild(name, true)
end

local Remotes = {
    Click = findRemote("ClickEvent"),
    Tool = findRemote("toolClick"),
    Token = findRemote("tokenEvent"),
    Actives = findRemote("PlayerActivesCommand")
}

local Flags = {
    AutoFarm = false,
    AutoDig = false,
    AutoConvert = false,
    Speed = 50, -- Дефолтная скорость для фарма
    ConvertPoint = nil
}

-- Координаты для Spider Field (Змейка)
local Points = {
    Vector3.new(318, 26, -180), Vector3.new(358, 26, -180),
    Vector3.new(358, 26, -195), Vector3.new(318, 26, -195),
    Vector3.new(318, 26, -210), Vector3.new(358, 26, -210)
}

local pIndex = 1
local pDir = 1
local converting = false

--------------------------------------------------------------------------------
-- ФУНКЦИИ
--------------------------------------------------------------------------------

local function getPollen()
    pcall(function()
        local gui = Player.PlayerGui.GameGui.BottomStat.PollenBar
        local text = gui.TextLabel.Text -- Обычно формат "1,000 / 5,000"
        local cur, max = text:match("([%d,]+)%s*/%s*([%d,]+)")
        cur = tonumber(cur:gsub(",", ""))
        max = tonumber(max:gsub(",", ""))
        return (cur / max) * 100
    end)
    return 0
end

local function collectTokens()
    local coll = workspace:FindFirstChild("Collectibles")
    if coll and Remotes.Token then
        for _, t in pairs(coll:GetChildren()) do
            if t:IsA("BasePart") and (HRP.Position - t.Position).Magnitude < 35 then
                Remotes.Token:FireServer(t)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- UI (RayField)
--------------------------------------------------------------------------------

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "JanusBSS Remote v2.1",
    LoadingTitle = "Remote Fix Edition",
    ConfigurationSaving = { Enabled = false }
})

local Main = Window:CreateTab("Farm", 4483362458)

Main:CreateToggle({
    Name = "Auto Farm (Snake)",
    CurrentValue = false,
    Callback = function(v) Flags.AutoFarm = v end
})

Main:CreateToggle({
    Name = "Auto Dig (Remote)",
    CurrentValue = false,
    Callback = function(v) Flags.AutoDig = v end
})

Main:CreateToggle({
    Name = "Auto Convert",
    CurrentValue = false,
    Callback = function(v) Flags.AutoConvert = v end
})

Main:CreateButton({
    Name = "Set Hive Point (Точка улья)",
    Callback = function() 
        Flags.ConvertPoint = HRP.Position 
        Rayfield:Notify({Title = "Сохранено", Content = "Точка улья установлена!"})
    end
})

Main:CreateSlider({
    Name = "Фарм Скорость",
    Range = {16, 200},
    Increment = 5,
    CurrentValue = 50,
    Callback = function(v) Flags.Speed = v end
})

--------------------------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ (HEARTBEAT)
--------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function(dt)
    if Flags.AutoFarm and not converting and HRP then
        -- 1. Проверка рюкзака
        if Flags.AutoConvert and Flags.ConvertPoint and getPollen() > 95 then
            converting = true
            local oldPos = HRP.Position
            HRP.CFrame = CFrame.new(Flags.ConvertPoint)
            task.wait(0.5)
            VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.1)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            
            -- Ждем пока пыльца уйдет (упрощенно 10 сек)
            task.wait(10)
            HRP.CFrame = CFrame.new(oldPos)
            converting = false
            return
        end

        -- 2. Движение Snake
        local target = Points[pIndex]
        local dist = (target - HRP.Position).Magnitude
        
        if dist > 2 then
            local moveDir = (target - HRP.Position).Unit
            -- Используем скорость из слайдера
            HRP.CFrame = HRP.CFrame + (moveDir * Flags.Speed * dt)
            HRP.CFrame = CFrame.lookAt(HRP.Position, target)
        else
            pIndex = pIndex + pDir
            if pIndex > #Points or pIndex < 1 then
                pDir = -pDir
                pIndex = pIndex + (pDir * 2)
            end
        end
        
        collectTokens()
    end
end)

-- Цикл копки (Remote Spam)
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

print("JanusBSS Remote v2.1 Loaded!")
