--![ Janus BSS Ultimate v6.0 - The Token Vacuum ]
--! Метод: CFrame Targeting & Collectibles Scanner
--! Собирает жетоны, использует ползунок скорости, чистит всё поле.

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "BSS ULTIMATE v6.0",
   LoadingTitle = "Janus True Farm",
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

-- Координаты полей
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

local FieldNames = {}
for name, _ in pairs(Fields) do table.insert(FieldNames, name) end
table.sort(FieldNames)

local MainTab = Window:CreateTab("Главная", 4483362458)
local FarmTab = Window:CreateTab("Автофарм", 4483362458)

-- === ВКЛАДКА ГЛАВНАЯ ===
MainTab:CreateToggle({
   Name = "Ручной CFrame (Без фарма)",
   CurrentValue = false,
   Callback = function(Value) Flags.Speed = Value end,
})

MainTab:CreateSlider({
   Name = "Множитель скорости (Для всего)",
   Range = {1, 10},
   Increment = 0.5,
   CurrentValue = 1,
   Callback = function(Value) Flags.SpeedVal = Value end,
})

MainTab:CreateToggle({
   Name = "Auto-Dig (Лопата)",
   CurrentValue = false,
   Callback = function(Value) 
      Flags.AutoDig = Value 
      if not Value then VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0) end
   end,
})

MainTab:CreateDropdown({
   Name = "Слот Плантера",
   Options = {"1","2","3","4","5","6","7"},
   CurrentOption = {"1"},
   Callback = function(Option) SelectedSlot = Option[1] end,
})

MainTab:CreateToggle({
   Name = "Auto-Planter",
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
   Name = "TRUE AUTOFARM (Токены + Поле)",
   CurrentValue = false,
   Callback = function(Value) Flags.AutoFarm = Value end,
})

-- ==========================================
-- ЛОГИКА АВТОФАРМА (СКОРОСТЬ + ТОКЕНЫ)
-- ==========================================

task.spawn(function()
    while true do
        task.wait() -- Работает максимально быстро
        if Flags.AutoFarm and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = Player.Character.HumanoidRootPart
            local fieldCenter = Fields[SelectedField]
            
            -- 1. Возврат на поле, если улетел далеко
            if (hrp.Position - fieldCenter).Magnitude > 60 then
                hrp.CFrame = CFrame.new(fieldCenter + Vector3.new(0, 5, 0))
                task.wait(0.5)
            end

            -- 2. ИЩЕМ ТОКЕНЫ (Жетоны и ресурсы)
            local targetPos = nil
            local collectibles = workspace:FindFirstChild("Collectibles")
            
            if collectibles then
                for _, token in pairs(collectibles:GetChildren()) do
                    if token:IsA("BasePart") then
                        -- Проверяем, лежит ли токен на нашем поле (в радиусе 45 стадов)
                        if (token.Position - fieldCenter).Magnitude <= 45 then
                            targetPos = token.Position
                            break -- Нашли цель, выходим из цикла поиска
                        end
                    end
                end
            end

            -- 3. Если токенов нет — выбираем случайную точку для копки на поле
            if not targetPos then
                local rx = math.random(-35, 35)
                local rz = math.random(-35, 35)
                targetPos = fieldCenter + Vector3.new(rx, 0, rz)
            end

            -- 4. ДВИЖЕНИЕ С ИСПОЛЬЗОВАНИЕМ ТВОЕЙ СКОРОСТИ
            -- Убираем ось Y, чтобы персонаж не летал и не зарывался в землю
            targetPos = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z) 
            
            local timeout = 0
            -- Пока мы не достигли цели (расстояние > 3)
            while Flags.AutoFarm and (hrp.Position - targetPos).Magnitude > 3 and timeout < 30 do
                task.wait(0.01)
                
                -- Вычисляем вектор направления
                local direction = (targetPos - hrp.Position).Unit
                -- Применяем твой множитель скорости из слайдера!
                local moveSpeed = (Flags.SpeedVal * 0.5) + 0.3 
                
                -- Двигаем персонажа
                hrp.CFrame = hrp.CFrame + (direction * moveSpeed)
                -- Поворачиваем лицом к цели
                hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + direction)
                
                timeout = timeout + 1
            end
        end
    end
end)

-- Обычный спидхак для ручного бега (работает только если автофарм ВЫКЛЮЧЕН)
game:GetService("RunService").Heartbeat:Connect(function()
    if Flags.Speed and not Flags.AutoFarm and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            Player.Character.HumanoidRootPart.CFrame = Player.Character.HumanoidRootPart.CFrame + (hum.MoveDirection * (Flags.SpeedVal * 0.45))
        end
    end
end)

-- Автодиг
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

-- Плантер
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
                if item then game:GetService("ReplicatedStorage").Events.PlayerAction:FireServer({["Com"]="UseItem",["Item"]=item}) end
            end)
        end
    end
end)
