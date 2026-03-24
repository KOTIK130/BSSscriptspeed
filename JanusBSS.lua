--![ Janus BSS Ultimate v4.6 ]
--! Изменено: Кулдаун плантера установлен на 0.8

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "BSS ULTIMATE v4.6",
   LoadingTitle = "Janus System",
   LoadingSubtitle = "by Janus & Tesavek",
   ConfigurationSaving = { Enabled = false }
})

local Flags = {
    Speed = false,
    SpeedVal = 1,
    AutoDig = false,
    AutoPlanter = false
}

local CurrentKey = Enum.KeyCode.One
local Player = game.Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
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
          VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
      end
   end,
})

-- 3. ПЛАНТЕР (Кулдаун 0.8)
MainTab:CreateToggle({
   Name = "Auto-Planter",
   CurrentValue = false,
   Callback = function(Value) Flags.AutoPlanter = Value end,
})

MainTab:CreateKeybind({
   Name = "Клавиша Плантера",
   CurrentKeybind = "One",
   HoldToInteract = false,
   Callback = function(Key)
      if typeof(Key) == "EnumItem" then
          CurrentKey = Key
      elseif typeof(Key) == "string" then
          CurrentKey = Enum.KeyCode[Key]
      end
      
      Rayfield:Notify({
         Title = "Бинд обновлен",
         Content = "Кнопка: " .. tostring(CurrentKey.Name),
         Duration = 2
      })
   end,
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
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            end
        end
    end
end)

-- ПЛАНТЕР (КУЛДАУН 0.8)
task.spawn(function()
    while true do
        task.wait(0.8) -- Твой кулдаун
        if Flags.AutoPlanter and not UIS:GetFocusedTextBox() then
            VirtualInputManager:SendKeyEvent(true, CurrentKey, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, CurrentKey, false, game)
        end
    end
end)

print("Janus v4.6 Loaded. Planter cooldown: 0.8s")
