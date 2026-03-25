--![ Janus BSS Ultimate v5.2 ]
--! Исправлено: Естественный бег по полю вместо "мельницы"
--! Исправлено: Автодиг полностью независим от автофарма
--! Добавлены все 17 основных полей

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "BSS ULTIMATE v5.2",
   LoadingTitle = "Janus Farm System",
   LoadingSubtitle = "by Janus & Tesavek",
   ConfigurationSaving = { Enabled = false }
})

local Flags = {
    Speed = false,
    SpeedVal = 1,
    AutoDig = false,
    AutoPlanter = false,
    AutoFarm = false
}

local SelectedSlot = "1"
local SelectedField = "Sunflower Field"
local SlotToKey = {["1"]=Enum.KeyCode.One, ["2"]=Enum.KeyCode.Two, ["3"]=Enum.KeyCode.Three, ["4"]=Enum.KeyCode.Four, ["5"]=Enum.KeyCode.Five, ["6"]=Enum.KeyCode.Six, ["7"]=Enum.KeyCode.Seven}

local Player = game.Players.LocalPlayer
local VIM = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")

-- ВСЕ ПОЛЯ В ИГРЕ (Координаты центров)
local Fields = {
    ["Dandelion Field"] = Vector3.new(-30, 5, 225),
    ["Sunflower Field"] = Vector3.new(-208, 5, -185),
    ["Mushroom Field"] = Vector3.new(-221, 5, 116),
    ["Blue Flower Field"] = Vector3.new(113, 5, 101),
    ["Clover Field"] = Vector3.new(174, 34, 189),
    ["Spider Field"] = Vector3.new(-38, 20, -5),
    ["Strawberry Field"] = Vector3.new(-169, 20, -3),
    ["Bamboo Field"] = Vector3.new(93, 20, -48),
    ["Pineapple Patch"] = Vector3.new(262, 20, -42),
    ["Stump Field"] = Vector3.new(421, 95, -174),
    ["Cactus Field"] = Vector3.new(-194, 68, -107),
    ["Pumpkin Patch"] = Vector3.new(-194, 68, -182),
    ["Pine Tree Forest"] = Vector3.new(-318, 68, -150),
    ["Rose Field"] = Vector3.new(-322, 20, 124),
    ["Mountain Top Field"] = Vector3.new(76, 226, -122),
    ["Coconut Field"] = Vector3.new(-255, 71, 464),
    ["Pepper Patch"] = Vector3.new(477, 113, 22)
}

-- Генерируем список полей для Dropdown
local FieldNames = {}
for name, _ in pairs(Fields) do table.insert(FieldNames, name) end
table.sort(FieldNames) -- Сортируем по алфавиту

local MainTab = Window:CreateTab("Главная", 4483362458)
local FarmTab = Window:CreateTab("Автофарм", 4483362458)

-- === ВКЛАДКА ГЛАВНАЯ ===
MainTab:CreateToggle({
   Name = "CFrame Speed",
   CurrentValue = false,
   Callback = function(Value) Flags.Speed = Value end,
})

MainTab:CreateSlider({
   Name = "Множитель скорости",
   Range = {1, 10},
   Increment = 0.5,
   CurrentValue = 1,
   Callback = function(Value) Flags.SpeedVal = Value end,
})

MainTab:CreateToggle({
   Name = "Auto-Dig (Копать)",
   CurrentValue = false,
   Callback = function(Value) 
      Flags.AutoDig = Value 
      if not Value then VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0) end
   end,
})

MainTab:CreateDropdown({
   Name = "Выбери слот Плантера",
   Options = {"1","2","3","4","5","6","7"},
   CurrentOption = {"1"},
   Callback = function(Option) SelectedSlot = Option[1] end,
})

MainTab:CreateToggle({
   Name = "Auto-Planter (Spam)",
   CurrentValue = false,
   Callback = function(Value) Flags.AutoPlanter = Value end,
})

-- === ВКЛАДКА АВТОФАРМ ===
FarmTab:CreateDropdown({
   Name = "Выберите поле",
   Options = FieldNames,
   CurrentOption = {"Sunflower Field"},
   Callback = function(Option) SelectedField = Option[1] end,
})

FarmTab:CreateToggle({
   Name = "Включить Автофарм (Бег)",
   CurrentValue = false,
   Callback = function(Value) Flags.AutoFarm = Value end,
})

-- ==========================================
-- ЛОГИКА
-- ==========================================

-- 1. УМНОЕ ДВИЖЕНИЕ НА ПОЛЕ (WALKING)
task.spawn(function()
    while true do
        task.wait(0.1)
        if Flags.AutoFarm and Player.Character then
            local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
            local hum = Player.Character:FindFirstChild("Humanoid")
            
            if hrp and hum then
                local center = Fields[SelectedField]
                
                -- Если мы далеко от поля (больше 60 стадов) — телепортируемся в центр
                if (hrp.Position - center).Magnitude > 60 then
                    hrp.CFrame = CFrame.new(center + Vector3.new(0, 5, 0))
                    task.wait(0.5) -- Даем прогрузиться
                else
                    -- Генерируем случайную точку в радиусе 15 стадов от центра поля
                    local randomX = center.X + math.random(-15, 15)
                    local randomZ = center.Z + math.random(-15, 15)
                    local targetPos = Vector3.new(randomX, center.Y, randomZ)
                    
                    -- Заставляем персонажа ИДТИ к этой точке
                    hum:MoveTo(targetPos)
                    
                    -- Ждем, пока он дойдет (максимум 2 секунды, чтобы не застрял)
                    local reached = false
                    local connection
                    connection = hum.MoveToFinished:Connect(function() reached = true end)
                    
                    local timeout = 0
                    while not reached and timeout < 20 and Flags.AutoFarm do
                        task.wait(0.1)
                        timeout = timeout + 1
                    end
                    
                    if connection then connection:Disconnect() end
                end
            end
        end
    end
end)

-- 2. Скорость (только когда фарм выключен, чтобы не ломать ходьбу)
game:GetService("RunService").Heartbeat:Connect(function()
    if Flags.Speed and not Flags.AutoFarm and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            Player.Character.HumanoidRootPart.CFrame = Player.Character.HumanoidRootPart.CFrame + (hum.MoveDirection * (Flags.SpeedVal * 0.45))
        end
    end
end)

-- 3. Автодиг (Независимый)
task.spawn(function()
    while true do
        task.wait(0.2)
        if Flags.AutoDig then
            if Player.Character and Player.Character:FindFirstChildOfClass("Tool") then
                VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            end
        end
    end
end)

-- 4. Плантер
task.spawn(function()
    while true do
        task.wait(0.8)
        if Flags.AutoPlanter and not UIS:GetFocusedTextBox() then
            local KeyToPress = SlotToKey[SelectedSlot]
            VIM:SendKeyEvent(true, KeyToPress, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, KeyToPress, false, game)
            
            pcall(function()
                local hotbar = require(game:GetService("ReplicatedStorage").Libs.ClientStat).Get("Hotbar")
                local item = hotbar[tonumber(SelectedSlot)]
                if item then
                    game:GetService("ReplicatedStorage").Events.PlayerAction:FireServer({["Com"]="UseItem",["Item"]=item})
                end
            end)
        end
    end
end)
