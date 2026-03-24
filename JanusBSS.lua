--![ Janus BSS Ultimate v4.0 - Rayfield Edition ]
--! Только твои функции: Speed, Auto-Dig, Auto-Planter.
--! Используется стабильная библиотека Rayfield.

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "BSS ULTIMATE v4.0",
   LoadingTitle = "Janus Executor System",
   LoadingSubtitle = "by Janus & Tesavek",
   ConfigurationSaving = {
      Enabled = false
   },
   KeySystem = false
})

-- Переменные (Твои функции)
local Flags = {
    Speed = false,
    SpeedVal = 1,
    AutoDig = false,
    AutoPlanter = false
}
local CurrentBind = Enum.KeyCode.One
local Player = game.Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Вкладка
local MainTab = Window:CreateTab("Главная", 4483362458)

-- 1. СКОРОСТЬ
MainTab:CreateToggle({
   Name = "CFrame Speed",
   CurrentValue = false,
   Callback = function(Value)
      Flags.Speed = Value
   end,
})

MainTab:CreateSlider({
   Name = "Множитель скорости",
   Range = {1, 10},
   Increment = 0.5,
   Suffix = "x",
   CurrentValue = 1,
   Callback = function(Value)
      Flags.SpeedVal = Value
   end,
})

-- 2. АВТОДИГ
MainTab:CreateToggle({
   Name = "Auto-Dig (Умный)",
   CurrentValue = false,
   Callback = function(Value)
      Flags.AutoDig = Value
   end,
})

-- 3. ПЛАНТЕР
MainTab:CreateToggle({
   Name = "Auto-Planter",
   CurrentValue = false,
   Callback = function(Value)
      Flags.AutoPlanter = Value
   end,
})

MainTab:CreateKeybind({
   Name = "Клавиша для Плантера",
   CurrentKeybind = "One",
   HoldToInteract = false,
   Flag = "PlanterKey",
   Callback = function(Keybind)
      CurrentBind = Keybind
   end,
})

-- ==========================================
-- ЛОГИКА (ПОТОКИ)
-- ==========================================

-- Цикл Скорости
game:GetService("RunService").Heartbeat:Connect(function()
    if Flags.Speed and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local hum = Player.Character:FindFirstChild("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0 then
            Player.Character.HumanoidRootPart.CFrame = Player.Character.HumanoidRootPart.CFrame + (hum.MoveDirection * (Flags.SpeedVal * 0.5))
        end
    end
end)

-- Цикл Автодига (Использует Activate, чтобы не блокировать мышь)
task.spawn(function()
    while true do
        task.wait(0.1)
        if Flags.AutoDig then
            local tool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() end
        end
    end
end)

-- Цикл Плантера
task.spawn(function()
    while true do
        task.wait(1)
        if Flags.AutoPlanter then
            VirtualInputManager:SendKeyEvent(true, CurrentBind, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, CurrentBind, false, game)
        end
    end
end)

Rayfield:Notify({
   Title = "Скрипт Загружен!",
   Content = "Используй INSERT для скрытия меню.",
   Duration = 5,
   Image = 4483362458,
})
