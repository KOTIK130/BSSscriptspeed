--![ Janus BSS Ultimate v5.1 ]
--! Добавлено: Автофарм с выбором поля (Dropdown)
--! Добавлено: Логика движения по полю

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "BSS ULTIMATE v5.1",
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
local SelectedField = "Clover Field" -- Дефолтное поле
local SlotToKey = {["1"]=Enum.KeyCode.One, ["2"]=Enum.KeyCode.Two, ["3"]=Enum.KeyCode.Three, ["4"]=Enum.KeyCode.Four, ["5"]=Enum.KeyCode.Five, ["6"]=Enum.KeyCode.Six, ["7"]=Enum.KeyCode.Seven}

local Player = game.Players.LocalPlayer
local VIM = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")

-- Таблица координат полей (Центр каждого поля)
local Fields = {
    ["Clover Field"] = Vector3.new(174, 34, 189),
    ["Mushroom Field"] = Vector3.new(-221, 5, 116),
    ["Blue Flower Field"] = Vector3.new(113, 5, 101),
    ["Sunflower Field"] = Vector3.new(-208, 5, -185),
    ["Strawberry Field"] = Vector3.new(-169, 20, -3),
    ["Spider Field"] = Vector3.new(-38, 20, -5),
    ["Bamboo Rice Field"] = Vector3.new(93, 20, -48),
    ["Pine Tree Forest"] = Vector3.new(-190, 68, -150),
    ["Rose Field"] = Vector3.new(-322, 20, 124),
    ["Dandelion Field"] = Vector3.new(-30, 5, 225)
}

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
   Name = "Auto-Dig",
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
   Name = "Auto-Planter (0.8s)",
   CurrentValue = false,
   Callback = function(Value) Flags.AutoPlanter = Value end,
})

-- === ВКЛАДКА АВТОФАРМ ===
FarmTab:CreateDropdown({
   Name = "Выберите поле",
   Options = {"Clover Field", "Mushroom Field", "Blue Flower Field", "Sunflower Field", "Strawberry Field", "Spider Field", "Bamboo Rice Field", "Pine Tree Forest", "Rose Field", "Dandelion Field"},
   CurrentOption = {"Clover Field"},
   Callback = function(Option) SelectedField = Option[1] end,
})

FarmTab:CreateToggle({
   Name = "Включить Автофарм",
   CurrentValue = false,
   Callback = function(Value) 
      Flags.AutoFarm = Value 
      if Value then Flags.AutoDig = true end -- Автоматически копаем при фарме
   end,
})

-- ==========================================
-- ЛОГИКА ДВИЖЕНИЯ И ФАРМА
-- ==========================================

-- 1. Движение на поле и круги (AutoFarm)
task.spawn(function()
    local angle = 0
    while true do
        task.wait(0.01)
        if Flags.AutoFarm and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = Fields[SelectedField]
            local hrp = Player.Character.HumanoidRootPart
            
            -- Если мы далеко от поля — телепортируемся (безопасно)
            if (hrp.Position - targetPos).Magnitude > 50 then
                hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 10, 0))
                task.wait(0.5)
            end
            
            -- Рисуем круги на поле для сбора
            angle = angle + 0.05
            local offset = Vector3.new(math.cos(angle) * 15, 0, math.sin(angle) * 15)
            hrp.CFrame = CFrame.new(targetPos + offset)
            hrp.CFrame = CFrame.lookAt(hrp.Position, targetPos)
        end
    end
end)

-- 2. Скорость (Speed)
game:GetService("RunService").Heartbeat:Connect(function()
    if Flags.Speed and Flags.AutoFarm == false and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            Player.Character.HumanoidRootPart.CFrame = Player.Character.HumanoidRootPart.CFrame + (hum.MoveDirection * (Flags.SpeedVal * 0.45))
        end
    end
end)

-- 3. Автодиг
task.spawn(function()
    while true do
        task.wait(0.15)
        if Flags.AutoDig or Flags.AutoFarm then
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
        if Flags.AutoPlanter then
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
