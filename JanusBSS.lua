--![ Janus BSS Ultimate v5.3 ]
--! Улучшено: более естественное и быстрое движение
--! Улучшено: стабильность и производительность
--! Добавлена защита от ошибок

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "BSS ULTIMATE v5.3",
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

local SlotToKey = {
    ["1"] = Enum.KeyCode.One, ["2"] = Enum.KeyCode.Two, ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four, ["5"] = Enum.KeyCode.Five, ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven
}

local Player = game.Players.LocalPlayer
local VIM = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Поля
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
for name in pairs(Fields) do table.insert(FieldNames, name) end
table.sort(FieldNames)

-- Табы
local MainTab = Window:CreateTab("Главная", 4483362458)
local FarmTab = Window:CreateTab("Автофарм", 4483362458)

-- Главная вкладка
MainTab:CreateToggle({ Name = "CFrame Speed", CurrentValue = false, Callback = function(v) Flags.Speed = v end })
MainTab:CreateSlider({ Name = "Множитель скорости", Range = {1, 10}, Increment = 0.5, CurrentValue = 1, Callback = function(v) Flags.SpeedVal = v end })
MainTab:CreateToggle({ 
    Name = "Auto-Dig", 
    CurrentValue = false, 
    Callback = function(v) 
        Flags.AutoDig = v 
        if not v then VIM:SendMouseButtonEvent(0,0,0,false,game,0) end 
    end 
})
MainTab:CreateDropdown({ Name = "Слот Плантера", Options = {"1","2","3","4","5","6","7"}, CurrentOption = {"1"}, Callback = function(opt) SelectedSlot = opt[1] end })
MainTab:CreateToggle({ Name = "Auto-Planter (Spam)", CurrentValue = false, Callback = function(v) Flags.AutoPlanter = v end })

-- Автофарм вкладка
FarmTab:CreateDropdown({ Name = "Поле", Options = FieldNames, CurrentOption = {"Sunflower Field"}, Callback = function(opt) SelectedField = opt[1] end })
FarmTab:CreateToggle({ Name = "Автофарм (Бег по полю)", CurrentValue = false, Callback = function(v) Flags.AutoFarm = v end })

-- ===================== ЛОГИКА =====================

-- Автофарм (естественное движение)
task.spawn(function()
    while true do
        task.wait(0.15)
        if not Flags.AutoFarm or not Player.Character then continue end
        
        local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
        local hum = Player.Character:FindFirstChild("Humanoid")
        if not hrp or not hum then continue end

        local center = Fields[SelectedField]
        if not center then continue end

        if (hrp.Position - center).Magnitude > 60 then
            hrp.CFrame = CFrame.new(center.X, center.Y + 5, center.Z)
            task.wait(0.6)
        else
            local offset = Vector3.new(math.random(-14,14), 0, math.random(-14,14))
            hum:MoveTo(center + offset)
        end
    end
end)

-- CFrame Speed (работает только когда автофарм выключен)
RunService.Heartbeat:Connect(function()
    if not Flags.Speed or Flags.AutoFarm then return end
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    local hum = Player.Character and Player.Character:FindFirstChild("Humanoid")
    if hrp and hum and hum.MoveDirection.Magnitude > 0 then
        hrp.CFrame += hum.MoveDirection * Flags.SpeedVal * 0.45
    end
end)

-- Auto Dig
task.spawn(function()
    while true do
        task.wait(0.15)
        if Flags.AutoDig and Player.Character and Player.Character:FindFirstChildOfClass("Tool") then
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end
    end
end)

-- Auto Planter
task.spawn(function()
    while true do
        task.wait(0.75)
        if not Flags.AutoPlanter or UIS:GetFocusedTextBox() then continue end

        local key = SlotToKey[SelectedSlot]
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, key, false, game)

        pcall(function()
            local hotbar = require(game.ReplicatedStorage.Libs.ClientStat).Get("Hotbar")
            local item = hotbar[tonumber(SelectedSlot)]
            if item then
                game.ReplicatedStorage.Events.PlayerAction:FireServer({Com = "UseItem", Item = item})
            end
        end)
    end
end)
