--![ Janus BSS Ultimate v5.0 ]
--! Метод: Выбор слота через Dropdown (1-7)
--! Гарантированное нажатие через принудительный индекс.

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "BSS ULTIMATE v5.0",
   LoadingTitle = "Janus System [SELECTOR]",
   LoadingSubtitle = "by Janus & Tesavek",
   ConfigurationSaving = { Enabled = false }
})

local Flags = {
    Speed = false,
    SpeedVal = 1,
    AutoDig = false,
    AutoPlanter = false
}

-- Пременные для слота
local SelectedSlot = "1"
local SlotToKey = {
    ["1"] = Enum.KeyCode.One,
    ["2"] = Enum.KeyCode.Two,
    ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five,
    ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven
}

local Player = game.Players.LocalPlayer
local VIM = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")

local MainTab = Window:CreateTab("Главная", 4483362458)

-- 1. СКОРОСТЬ
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

-- 2. АВТОДИГ
MainTab:CreateToggle({
   Name = "Auto-Dig",
   CurrentValue = false,
   Callback = function(Value) 
      Flags.AutoDig = Value 
      if not Value then
          VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
      end
   end,
})

-- 3. ВЫБОР СЛОТА (Твой запрос)
MainTab:CreateDropdown({
   Name = "Выбери слот (1-7)",
   Options = {"1","2","3","4","5","6","7"},
   CurrentOption = {"1"},
   MultipleOptions = false,
   Callback = function(Option)
      SelectedSlot = Option[1]
      Rayfield:Notify({
         Title = "Слот изменен",
         Content = "Теперь спамим кнопку: " .. SelectedSlot,
         Duration = 2
      })
   end,
})

-- 4. ВКЛЮЧИТЕЛЬ ПЛАНТЕРА
MainTab:CreateToggle({
   Name = "Auto-Planter (Spam)",
   CurrentValue = false,
   Callback = function(Value) Flags.AutoPlanter = Value end,
})

-- ==========================================
-- ЛОГИКА
-- ==========================================

-- Скорость
game:GetService("RunService").Heartbeat:Connect(function()
    if Flags.Speed and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
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

-- ПЛАНТЕР (ЖЕСТКИЙ СПАМ ВЫБРАННОГО СЛОТА)
task.spawn(function()
    while true do
        task.wait(0.8) -- Твой кулдаун
        if Flags.AutoPlanter and not UIS:GetFocusedTextBox() then
            local KeyToPress = SlotToKey[SelectedSlot]
            
            -- Посылаем сигнал нажатия
            VIM:SendKeyEvent(true, KeyToPress, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, KeyToPress, false, game)
            
            -- На случай если VIM тупит, дублируем пакет использования
            pcall(function()
                local hotbar = require(game:GetService("ReplicatedStorage").Libs.ClientStat).Get("Hotbar")
                local item = hotbar[tonumber(SelectedSlot)]
                if item then
                    game:GetService("ReplicatedStorage").Events.PlayerAction:FireServer({
                        ["Com"] = "UseItem",
                        ["Item"] = item
                    })
                end
            end)
        end
    end
end)
