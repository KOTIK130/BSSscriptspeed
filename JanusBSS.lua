--![ Janus BSS Ultimate v4.9 - Internal Bypass ]
--! Метод: Прямой вызов функций игрового клиента.
--! Больше никакого VirtualInputManager для биндов.

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "BSS ULTIMATE v4.9",
   LoadingTitle = "Janus System [INTERNAL]",
   LoadingSubtitle = "by Janus & Tesavek",
   ConfigurationSaving = { Enabled = false }
})

local Flags = {
    Speed = false,
    SpeedVal = 1,
    AutoDig = false,
    AutoPlanter = false
}

-- Теперь мы храним не клавишу, а НОМЕР слота (1, 2, 3... 6)
local SlotNumber = 1

local Player = game.Players.LocalPlayer
local VIM = game:GetService("VirtualInputManager")

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

-- 3. ПЛАНТЕР (Через слот)
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
      -- Конвертируем название клавиши в число для слота
      local keyName = tostring(Key.Name)
      local numMap = {["One"]=1, ["Two"]=2, ["Three"]=3, ["Four"]=4, ["Five"]=5, ["Six"]=6}
      
      SlotNumber = numMap[keyName] or 1
      
      Rayfield:Notify({
         Title = "СЛОТ УСТАНОВЛЕН",
         Content = "Используем слот №" .. tostring(SlotNumber),
         Duration = 2
      })
   end,
})

-- ==========================================
-- ЛОГИКА (БЕЗ ЭМУЛЯЦИИ КЛАВИАТУРЫ)
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

-- ПЛАНТЕР (ПРЯМОЙ ВЫЗОВ ИЗ МОДУЛЯ ИГРЫ)
task.spawn(function()
    local clientStat = require(game:GetService("ReplicatedStorage").Libs.ClientStat)
    while true do
        task.wait(0.8)
        if Flags.AutoPlanter then
            -- Вызываем функцию использования предмета из слота напрямую
            -- Это обходит все баги твоего экзекутора с клавиатурой
            local item = clientStat.Get("Hotbar")[SlotNumber]
            if item then
                game:GetService("ReplicatedStorage").Events.PlayerAction:FireServer({
                    ["Com"] = "UseItem",
                    ["Item"] = item
                })
            end
        end
    end
end)
