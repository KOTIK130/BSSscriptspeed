local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer

-- Настройки
local Flags = {
    AutoFarm = false,
    AutoDig = false,
    AutoConvert = false,
    AutoItem = false,
    ItemSlot = 1,
    ItemDelay = 0.6,
    CFrameSpeed = 60,
    FieldRadius = 45,
    HivePos = nil,
    FieldPos = nil
}

-- Ремоуты (поиск по игре)
local Remotes = {
    Click = ReplicatedStorage:FindFirstChild("ClickEvent", true),
    Actives = ReplicatedStorage:FindFirstChild("PlayerActivesCommand", true)
}

-- Функция обновления персонажа (чтобы скрипт не ломался при смерти)
local Character, HRP, Hum
local function updateChar()
    Character = Player.Character or Player.CharacterAdded:Wait()
    HRP = Character:WaitForChild("HumanoidRootPart")
    Hum = Character:WaitForChild("Humanoid")
end
updateChar()
Player.CharacterAdded:Connect(updateChar)

-- Точный парсер пыльцы (под формат со скриншота: 0/291,935,000)
local function getPollenPercent()
    local ok, result = pcall(function()
        local text = Player.PlayerGui.GameGui.BottomStat.PollenBar.TextLabel.Text
        -- Убираем пробелы и запятые
        text = string.gsub(text, "[,%s]", "")
        local cur, max = string.match(text, "(%d+)/(%d+)")
        if cur and max then
            local maxNum = tonumber(max)
            if maxNum == 0 then return 0 end
            return (tonumber(cur) / maxNum) * 100
        end
        return 0
    end)
    return ok and result or 0
end

-- Функция Tween-телепортации (для базы и обратно)
local function tweenTo(targetPos)
    if not HRP then return end
    local dist = (HRP.Position - targetPos).Magnitude
    local speed = 100 -- Скорость полета на базу
    local tweenInfo = TweenInfo.new(dist / speed, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(HRP, tweenInfo, {CFrame = CFrame.new(targetPos)})
    tween:Play()
    tween.Completed:Wait()
end

--------------------------------------------------------------------------------
-- ИНТЕРФЕЙС (Rayfield)
--------------------------------------------------------------------------------
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({Name = "ULTIMATE BSS FARM", ConfigurationSaving = {Enabled = false}})

local TabFarm = Window:CreateTab("Auto Farm", 4483362458)
local TabSet = Window:CreateTab("Positions", 4483362458)

-- Настройки Фарма
TabFarm:CreateToggle({Name = "Auto Farm (Field Tokens)", CurrentValue = false, Callback = function(v) Flags.AutoFarm = v end})
TabFarm:CreateToggle({Name = "Auto Dig", CurrentValue = false, Callback = function(v) Flags.AutoDig = v end})
TabFarm:CreateToggle({Name = "Auto Convert", CurrentValue = false, Callback = function(v) Flags.AutoConvert = v end})
TabFarm:CreateSlider({Name = "CFrame Walk Speed", Range = {20, 150}, Increment = 5, CurrentValue = 60, Callback = function(v) Flags.CFrameSpeed = v end})

TabFarm:CreateToggle({Name = "Auto Use Item", CurrentValue = false, Callback = function(v) Flags.AutoItem = v end})
TabFarm:CreateSlider({Name = "Item Slot", Range = {1, 7}, Increment = 1, CurrentValue = 1, Callback = function(v) Flags.ItemSlot = v end})

-- Установка координат
TabSet:CreateSection("Установи точки перед фармом!")
TabSet:CreateButton({Name = "1. Set Hive Point (Встань в соты улья)", Callback = function() 
    if HRP then Flags.HivePos = HRP.Position print("Улей установлен!") end 
end})
TabSet:CreateButton({Name = "2. Set Field Point (Встань в центр поля)", Callback = function() 
    if HRP then Flags.FieldPos = HRP.Position print("Поле установлено!") end 
end})

--------------------------------------------------------------------------------
-- ЛОГИКА
--------------------------------------------------------------------------------

local isConverting = false

-- 1. АВТО ДИГ (0.1s)
task.spawn(function()
    while task.wait(0.1) do
        if Flags.AutoDig and not isConverting and Character then
            pcall(function()
                if Remotes.Click then Remotes.Click:FireServer() end
            end)
        end
    end
end)

-- 2. АВТО ПРЕДМЕТЫ (0.6s)
task.spawn(function()
    while task.wait(Flags.ItemDelay) do
        if Flags.AutoItem and not isConverting then
            pcall(function()
                if Remotes.Actives then 
                    Remotes.Actives:InvokeServer("Use", Flags.ItemSlot) 
                end
            end)
        end
    end
end)

-- 3. АВТО КОНВЕРТАЦИЯ (Отдельный поток)
task.spawn(function()
    while task.wait(0.5) do
        if Flags.AutoFarm and Flags.AutoConvert and Flags.HivePos and Flags.FieldPos and not isConverting then
            if getPollenPercent() >= 99 then
                isConverting = true
                
                -- Tween на базу
                tweenTo(Flags.HivePos)
                task.wait(0.5)
                
                -- Нажимаем E для конвертации
                VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                
                -- Ждем пока пыльца не упадет
                repeat task.wait(0.5) until getPollenPercent() < 2 or not Flags.AutoFarm
                
                -- Tween обратно на поле
                if Flags.AutoFarm then
                    tweenTo(Flags.FieldPos)
                end
                isConverting = false
            end
        end
    end
end)

-- 4. ДВИЖЕНИЕ НА ПОЛЕ (CFrame + Прыжки/Парашют)
RunService.Heartbeat:Connect(function(dt)
    if not Flags.AutoFarm or isConverting or not Flags.FieldPos or not HRP or not Hum or Hum.Health <= 0 then return end

    -- Ищем ближайший токен
    local targetPos = nil
    local shortestDist = math.huge
    local collectibles = workspace:FindFirstChild("Collectibles")
    
    if collectibles then
        for _, token in pairs(collectibles:GetChildren()) do
            local pos = token:IsA("BasePart") and token.Position or (token:IsA("Model") and token.PrimaryPart and token.PrimaryPart.Position)
            if pos then
                -- Проверяем, что токен находится в пределах поля
                if (Vector3.new(pos.X, Flags.FieldPos.Y, pos.Z) - Flags.FieldPos).Magnitude <= Flags.FieldRadius then
                    local distToPlayer = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(HRP.Position.X, 0, HRP.Position.Z)).Magnitude
                    if distToPlayer < shortestDist then
                        shortestDist = distToPlayer
                        targetPos = pos
                    end
                end
            end
        end
    end

    -- Если токенов нет, идем в центр поля
    if not targetPos then
        targetPos = Flags.FieldPos
    end

    -- Логика движения по CFrame (только по осям X и Z)
    local pPos = HRP.Position
    local distXY = (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(pPos.X, 0, pPos.Z)).Magnitude

    if distXY > 1 then
        local moveDir = (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(pPos.X, 0, pPos.Z)).Unit
        
        -- Высчитываем новую позицию
        local newX = pPos.X + (moveDir.X * Flags.CFrameSpeed * dt)
        local newZ = pPos.Z + (moveDir.Z * Flags.CFrameSpeed * dt)
        
        -- Применяем CFrame, оставляя текущую высоту (Y) нетронутой. 
        -- Также поворачиваем персонажа лицом к цели.
        HRP.CFrame = CFrame.lookAt(Vector3.new(newX, pPos.Y, newZ), Vector3.new(targetPos.X, pPos.Y, targetPos.Z))
        
        -- Гасим инерцию роблокса по X и Z, но оставляем Y (чтобы работали прыжки и парашют)
        HRP.AssemblyLinearVelocity = Vector3.new(0, HRP.AssemblyLinearVelocity.Y, 0)
    end
end)
