--![ Janus BSS Ultimate v4.2 - The Final Fix ]
--! Auto-Dig: Пакетный метод (Не использует мышь)
--! Speed & Planter: Стабильные циклы

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "BSS ULTIMATE v4.2",
   LoadingTitle = "Janus System v4.2",
   LoadingSubtitle = "by Janus & Tesavek",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

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
   Callback = function(Value) Flags.Speed = Value end,
})

MainTab:CreateSlider({
   Name = "Множитель скорости",
   Range = {1, 10},
   Increment = 0.5,
   Suffix = "x",
   CurrentValue = 1,
   Callback = function(Value) Flags.SpeedVal = Value end,
})

-- 2. АВТОДИГ (ПАКЕТНЫЙ - МЫШЬ СВОБОДНА)
MainTab:CreateToggle({
   Name = "Auto-Dig (Packet Method)",
   CurrentValue = false,
   Callback = function(Value) Flags.AutoDig = Value end,
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
-- ЛОГИКА (БЕЗ КОНФЛИКТОВ)
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

-- ПАКЕТНЫЙ АВТОДИГ (Самый топ)
task.spawn(function()
    while true do
        task.wait(0.05) -- Очень быстрый сбор
        if Flags.AutoDig then
            local tool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("ClickEvent") then
                -- Отправляем сигнал активации напрямую, минуя клик мыши
                tool.ClickEvent:FireServer(Player:GetMouse().Hit.Position)
            elseif tool then
                -- Если специфического ивента нет, используем безопасную активацию
                tool:Activate()
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

Rayfield:Notify({
   Title = "Система готова",
   Content = "Автодиг больше не трогает твою мышь!",
   Duration = 5,
})
