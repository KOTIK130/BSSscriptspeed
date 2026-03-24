--![ Janus BSS Ultimate v4.3 - God Method ]
--! Используется зажатие Mouse1 (как в оригинале игры)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "BSS ULTIMATE v4.3",
   LoadingTitle = "Janus System",
   LoadingSubtitle = "by Janus & Tesavek",
   ConfigurationSaving = { Enabled = false }
})

local Flags = { Speed = false, SpeedVal = 1, AutoDig = false, AutoPlanter = false }
local CurrentBind = Enum.KeyCode.One
local VirtualInputManager = game:GetService("VirtualInputManager")
local Player = game.Players.LocalPlayer

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

-- 2. АВТОДИГ (МЕТОД ЗАЖАТИЯ)
MainTab:CreateToggle({
   Name = "Auto-Dig (HOLD METHOD)",
   CurrentValue = false,
   Callback = function(Value) 
      Flags.AutoDig = Value 
      if not Value then
          -- При выключении принудительно отжимаем кнопку
          VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
      end
   end,
})

-- 3. ПЛАНТЕР
MainTab:CreateToggle({
   Name = "Auto-Planter",
   CurrentValue = false,
   Callback = function(Value) Flags.AutoPlanter = Value end,
})

MainTab:CreateKeybind({
   Name = "Клавиша для Плантера",
   CurrentKeybind = "One",
   HoldToInteract = false,
   Callback = function(Key) CurrentBind = Key end,
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

-- УЛЬТИМАТИВНЫЙ АВТОДИГ (HOLD)
task.spawn(function()
    while true do
        task.wait(0.2)
        if Flags.AutoDig then
            -- Проверяем, держит ли персонаж инструмент
            local tool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
            if tool then
                -- Мы «зажимаем» кнопку. Это заставляет персонажа копать непрерывно.
                -- Мы делаем это в цикле на случай, если игра «сбросит» нажатие.
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            end
        end
    end
end)

-- Плантер
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
