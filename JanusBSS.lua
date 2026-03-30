-- ════════════════════════════════════════════════════
--   BSS ULTIMATE FARM  v15  |  Field Events + Remotes
-- ════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local VIM               = game:GetService("VirtualInputManager")

local Player  = Players.LocalPlayer
local PGui    = Player.PlayerGui

-- ─── Debug Log ──────────────────────────────────
local LOG_MAX = 200
local _logBuffer = {}

local function debugLog(msg)
    local ts = os.date("%H:%M:%S")
    local line = ("[%s] %s"):format(ts, tostring(msg))
    table.insert(_logBuffer, line)
    if #_logBuffer > LOG_MAX then
        table.remove(_logBuffer, 1)
    end
    warn("[BSS] " .. msg)
end

local function saveLog()
    local ok, err = pcall(function()
        local content = table.concat(_logBuffer, "\n")
        writefile("bss_debug_log.txt", content)
    end)
    return ok, err
end

-- ─── Конфиг ──────────────────────────────────────
local _converting = false

local CFG = {
    AutoFarm    = false,
    FieldPos    = nil,
    FieldRadius = 45,
    SnakeGap    = 8,

    AutoDig     = false,

    AutoConvert = false,
    HivePos     = nil,

    ItemSlots   = {
        [1] = { Enabled = false, Delay = 1 },
        [2] = { Enabled = false, Delay = 1 },
        [3] = { Enabled = false, Delay = 1 },
        [4] = { Enabled = false, Delay = 1 },
        [5] = { Enabled = false, Delay = 1 },
        [6] = { Enabled = false, Delay = 1 },
        [7] = { Enabled = false, Delay = 1 },
    },

    SpeedHack   = false,
    WalkSpeed   = 70,
}

-- ─── Ремоты ──────────────────────────────────────
local function findRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name, true)
    if r then
        debugLog("Remote OK: " .. name .. " (" .. r.ClassName .. ")")
    else
        debugLog("⚠ Remote NOT FOUND: " .. name)
    end
    return r
end

local R = {
    ToolClick            = findRemote("toolClick"),
    TornadoEvents        = findRemote("tornadoEvents"),
    CloudEvents          = findRemote("cloudEvents"),
    RemoveCorruption     = findRemote("removeCorruption"),
    SpawnSingleBloom     = findRemote("spawnSingleBloom"),
    PetalCollected       = findRemote("PetalCollected"),
    CreateDupedToken     = findRemote("createDupedToken"),
    PlayerActivesCommand = findRemote("PlayerActivesCommand"),
}

-- ─── Персонаж ────────────────────────────────────
local Char, HRP, Hum
local defaultSpeed = 16

local function loadChar()
    Char = Player.Character or Player.CharacterAdded:Wait()
    HRP  = Char:WaitForChild("HumanoidRootPart")
    Hum  = Char:WaitForChild("Humanoid")
    defaultSpeed = Hum.WalkSpeed
end
loadChar()

Player.CharacterAdded:Connect(function()
    task.wait(0.5)
    loadChar()
end)

-- ─── Pollen ──────────────────────────────────────
local _pollenCache = nil
local function findPollenLabel()
    if _pollenCache and _pollenCache.Parent then return _pollenCache end
    _pollenCache = nil
    local function scan(p, d)
        if d > 12 then return end
        for _, c in ipairs(p:GetChildren()) do
            if (c:IsA("TextLabel") or c:IsA("TextBox")) then
                local t = (c.Text or ""):gsub("[,%s]", "")
                local a, b = t:match("^(%d+)/(%d+)$")
                if a and b and tonumber(b) > 100000 then
                    _pollenCache = c; return c
                end
            end
            local f = scan(c, d + 1)
            if f then return f end
        end
    end
    return scan(PGui, 0)
end

local function getPollen()
    local ok, v = pcall(function()
        local lbl = findPollenLabel()
        if not lbl then return 0 end
        local t = lbl.Text:gsub("[,%s]", "")
        local cur, max = t:match("(%d+)/(%d+)")
        if not cur then return 0 end
        local m = tonumber(max)
        return m > 0 and (tonumber(cur) / m * 100) or 0
    end)
    return ok and v or 0
end

-- ─── Field Event System (shared state) ───────────
-- Используется сканером и змейкой для приоритетных событий на поле
local _eventTarget   = nil   -- Vector3: куда идти (событие на поле)
local _eventType     = ""    -- string: тип события (для дебага)
local _eventExpiry   = 0     -- tick(): когда событие истечёт

local function setFieldEvent(pos, eventType, duration)
    duration = duration or 5
    _eventTarget = pos
    _eventType   = eventType
    _eventExpiry = tick() + duration
    debugLog("🎯 Event: " .. eventType .. " at " .. tostring(pos))
end

local function clearFieldEvent()
    _eventTarget = nil
    _eventType   = ""
    _eventExpiry = 0
end

local function isNearField(pos)
    if not CFG.FieldPos then return false end
    local dx = pos.X - CFG.FieldPos.X
    local dz = pos.Z - CFG.FieldPos.Z
    return math.sqrt(dx*dx + dz*dz) < CFG.FieldRadius * 2
end

-- ─── UI ──────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Win = Rayfield:CreateWindow({
    Name = "BSS ULTIMATE FARM v15",
    ConfigurationSaving = { Enabled = false },
})

local TFarm  = Win:CreateTab("⚙ Farm",       4483362458)
local TItem  = Win:CreateTab("🎒 Items",     4483362458)
local TPos   = Win:CreateTab("📍 Positions", 4483362458)
local TDebug = Win:CreateTab("🐛 Debug",     4483362458)

local ParaStatus = TFarm:CreateParagraph({ Title = "Status", Content = "● Idle" })
local ParaPollen = TFarm:CreateParagraph({ Title = "Pollen", Content = "0.0%" })
local ParaEvent  = TFarm:CreateParagraph({ Title = "Field Event", Content = "—" })

local function setStatus(s)
    pcall(function() ParaStatus:Set({ Title = "Status", Content = s }) end)
end

-- ── Farm tab ──
TFarm:CreateSection("Auto Farm")

TFarm:CreateToggle({ Name = "Auto Farm (Snake + Field Events)", CurrentValue = false, Callback = function(v)
    CFG.AutoFarm = v
    setStatus(v and "● Farming..." or "● Idle")
end })

TFarm:CreateToggle({ Name = "Auto Dig", CurrentValue = false, Callback = function(v)
    CFG.AutoDig = v
end })

TFarm:CreateToggle({ Name = "Auto Convert  ⚠ нужны точки!", CurrentValue = false, Callback = function(v)
    CFG.AutoConvert = v
    if v and (not CFG.HivePos or not CFG.FieldPos) then
        Rayfield:Notify({ Title = "⚠ Внимание", Content = "Установи точки во вкладке Positions!", Duration = 5 })
    end
end })

TFarm:CreateSection("Speed Hack")

TFarm:CreateToggle({ Name = "Speed Hack (CFrame)", CurrentValue = false, Callback = function(v)
    CFG.SpeedHack = v
end })

TFarm:CreateSlider({ Name = "Speed", Range = { 16, 500 }, Increment = 1, CurrentValue = 70,
    Callback = function(v) CFG.WalkSpeed = v end
})

TFarm:CreateSection("Farm Settings")

TFarm:CreateSlider({ Name = "Field Radius", Range = { 10, 150 }, Increment = 5, CurrentValue = 45,
    Callback = function(v) CFG.FieldRadius = v end })

TFarm:CreateSlider({ Name = "Snake Gap (studs)", Range = { 2, 20 }, Increment = 1, CurrentValue = 8,
    Callback = function(v) CFG.SnakeGap = v end })

TFarm:CreateSection("ℹ Field Events (авто при AutoFarm)")
TFarm:CreateParagraph({ Title = "Включённые события", Content = "🌪 Tornado walk\n🥥 Auto Coconut use\n🌸 Bloom walk\n🪙 Duped Token collect\n🎯 Target Practice walk" })

-- ── Items tab ──
for i = 1, 7 do
    TItem:CreateSection("Slot " .. i)
    TItem:CreateToggle({ Name = "Slot " .. i .. " Enabled", CurrentValue = false, Callback = function(v)
        CFG.ItemSlots[i].Enabled = v
    end })
    TItem:CreateSlider({ Name = "Slot " .. i .. " Delay (sec)", Range = { 1, 300 }, Increment = 1, CurrentValue = 1,
        Callback = function(v) CFG.ItemSlots[i].Delay = v end })
end

-- ── Positions tab ──
TPos:CreateSection("⚠ Установи ДО фарма!")

local HivePara  = TPos:CreateParagraph({ Title = "Hive",  Content = "не установлен" })
local FieldPara = TPos:CreateParagraph({ Title = "Field", Content = "не установлен" })

TPos:CreateButton({ Name = "📍 Set Hive  (встань у улья)", Callback = function()
    if not HRP then return end
    CFG.HivePos = HRP.Position
    local p = CFG.HivePos
    HivePara:Set({ Title = "Hive ✓", Content = ("X:%.1f  Y:%.1f  Z:%.1f"):format(p.X, p.Y, p.Z) })
    Rayfield:Notify({ Title = "Улей ✓", Content = "Точка сохранена", Duration = 3 })
end })

TPos:CreateButton({ Name = "📍 Set Field  (встань в центр поля)", Callback = function()
    if not HRP then return end
    CFG.FieldPos = HRP.Position
    local p = CFG.FieldPos
    FieldPara:Set({ Title = "Field ✓", Content = ("X:%.1f  Y:%.1f  Z:%.1f"):format(p.X, p.Y, p.Z) })
    Rayfield:Notify({ Title = "Поле ✓", Content = "Точка сохранена", Duration = 3 })
end })

TPos:CreateSection("Пресеты полей")

TPos:CreateButton({ Name = "🕷 Spider Field (-46.6, 20.0, -10.2)", Callback = function()
    CFG.FieldPos = Vector3.new(-46.6, 20.0, -10.2)
    local p = CFG.FieldPos
    FieldPara:Set({ Title = "Field ✓ (Spider)", Content = ("X:%.1f  Y:%.1f  Z:%.1f"):format(p.X, p.Y, p.Z) })
    Rayfield:Notify({ Title = "🕷 Spider Field", Content = "Координаты установлены", Duration = 3 })
end })

TPos:CreateButton({ Name = "🗑 Сбросить точки", Callback = function()
    CFG.HivePos = nil; CFG.FieldPos = nil
    HivePara:Set({ Title = "Hive",  Content = "не установлен" })
    FieldPara:Set({ Title = "Field", Content = "не установлен" })
    Rayfield:Notify({ Title = "Сброс", Content = "Точки очищены", Duration = 3 })
end })

-- ── Debug tab ──
TDebug:CreateSection("Логирование")

local DebugPara = TDebug:CreateParagraph({ Title = "Лог", Content = "Последние записи появятся здесь" })

TDebug:CreateButton({ Name = "💾 Сохранить лог (.txt)", Callback = function()
    local ok, err = saveLog()
    if ok then
        Rayfield:Notify({ Title = "✅ Лог сохранён", Content = "Файл: workspace/bss_debug_log.txt\nСтрок: " .. #_logBuffer, Duration = 5 })
        debugLog("Лог сохранён в bss_debug_log.txt (" .. #_logBuffer .. " строк)")
    else
        Rayfield:Notify({ Title = "❌ Ошибка", Content = tostring(err), Duration = 5 })
    end
end })

TDebug:CreateButton({ Name = "🗑 Очистить лог", Callback = function()
    _logBuffer = {}
    Rayfield:Notify({ Title = "🗑 Очищено", Content = "Лог очищен", Duration = 3 })
end })

TDebug:CreateButton({ Name = "📋 Показать последние 10 записей", Callback = function()
    local start = math.max(1, #_logBuffer - 9)
    local lines = {}
    for i = start, #_logBuffer do
        table.insert(lines, _logBuffer[i])
    end
    local txt = #lines > 0 and table.concat(lines, "\n") or "Лог пуст"
    DebugPara:Set({ Title = "Лог (последние " .. #lines .. ")", Content = txt })
end })

-- Обновление поллена + event
task.spawn(function()
    while task.wait(0.8) do
        pcall(function()
            ParaPollen:Set({ Title = "Pollen", Content = ("%.1f%%"):format(getPollen()) })
            if _eventTarget then
                ParaEvent:Set({ Title = "Field Event", Content = "🎯 " .. _eventType })
            else
                ParaEvent:Set({ Title = "Field Event", Content = "—" })
            end
        end)
    end
end)

-- ════════════════════════════════════════════════════
--   МОДУЛИ — каждый полностью независим
-- ════════════════════════════════════════════════════

-- ── 1. SPEED HACK (CFrame) ─────────────────────────
do
    RunService.Heartbeat:Connect(function(dt)
        if not CFG.SpeedHack then return end
        if _converting then return end
        if CFG.AutoFarm then return end
        if not HRP or not Hum or Hum.Health <= 0 then return end

        local moveDir = Hum.MoveDirection
        if moveDir.Magnitude < 0.01 then
            pcall(function()
                HRP.AssemblyLinearVelocity  = Vector3.new(0, HRP.AssemblyLinearVelocity.Y, 0)
                HRP.AssemblyAngularVelocity = Vector3.zero
            end)
            return
        end

        local speed = CFG.WalkSpeed
        local step  = speed * dt
        local pos   = HRP.Position
        local newPos = pos + moveDir * step

        pcall(function()
            HRP.CFrame = CFrame.new(newPos, newPos + moveDir)
            HRP.AssemblyLinearVelocity  = Vector3.new(0, HRP.AssemblyLinearVelocity.Y, 0)
            HRP.AssemblyAngularVelocity = Vector3.zero
        end)
    end)
end

-- ── 2. AUTO DIG ───────────────────────────────────
task.spawn(function()
    while task.wait(0.1) do
        if CFG.AutoDig and R.ToolClick then
            pcall(function() R.ToolClick:InvokeServer() end)
        end
    end
end)

-- ── 3. AUTO ITEM ──────────────────────────────────
local SlotKeys = {
    [1] = Enum.KeyCode.One,
    [2] = Enum.KeyCode.Two,
    [3] = Enum.KeyCode.Three,
    [4] = Enum.KeyCode.Four,
    [5] = Enum.KeyCode.Five,
    [6] = Enum.KeyCode.Six,
    [7] = Enum.KeyCode.Seven,
}

for i = 1, 7 do
    task.spawn(function()
        while true do
            task.wait(CFG.ItemSlots[i].Delay)
            if CFG.ItemSlots[i].Enabled and not _converting then
                local key = SlotKeys[i]
                if key then
                    pcall(function()
                        VIM:SendKeyEvent(true,  key, false, game)
                        task.wait(0.05)
                        VIM:SendKeyEvent(false, key, false, game)
                    end)
                end
            end
        end
    end)
end

-- ── 4. AUTO CONVERT ───────────────────────────────
task.spawn(function()
    while task.wait(0.3) do
        if not CFG.AutoConvert then continue end
        if not CFG.HivePos then continue end
        if _converting then continue end
        if getPollen() < 99 then continue end

        _converting = true
        debugLog("Convert START — pollen: " .. ("%.1f%%"):format(getPollen()))
        setStatus("● конвертация")

        pcall(function()
            if not HRP then return end
            local dist = (HRP.Position - CFG.HivePos).Magnitude
            local t = TweenInfo.new(math.max(dist / 60, 0.1), Enum.EasingStyle.Linear)
            local tw = TweenService:Create(HRP, t, { CFrame = CFrame.new(CFG.HivePos) })
            tw:Play()
            tw.Completed:Wait()
        end)

        task.wait(0.3)

        VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.15)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)

        local waited = 0
        repeat task.wait(0.3); waited += 0.3
        until getPollen() < 3 or waited > 30

        if CFG.FieldPos then
            pcall(function()
                if not HRP then return end
                local dist = (HRP.Position - CFG.FieldPos).Magnitude
                local t = TweenInfo.new(math.max(dist / 60, 0.1), Enum.EasingStyle.Linear)
                local tw = TweenService:Create(HRP, t, { CFrame = CFrame.new(CFG.FieldPos) })
                tw:Play()
                tw.Completed:Wait()
            end)
        end

        _converting = false
        debugLog("Convert END — pollen: " .. ("%.1f%%"):format(getPollen()))
        setStatus(CFG.AutoFarm and "● Farming..." or (CFG.AutoConvert and "● Waiting..." or "● Idle"))
    end
end)

-- ── 5. AUTO FARM — Змейка + Field Events ──────────
do
    local snakeDir   = 1
    local snakeRow   = 0
    local targetPos  = nil
    local prevActive = false

    local function buildTarget()
        if not CFG.FieldPos then return nil end
        local c = CFG.FieldPos
        local r = CFG.FieldRadius
        return Vector3.new(c.X + snakeDir * r, c.Y, c.Z - r + snakeRow)
    end

    local function nextRow()
        snakeDir = -snakeDir
        snakeRow = snakeRow + CFG.SnakeGap
        if snakeRow > CFG.FieldRadius * 2 then
            snakeRow = 0
            debugLog("🐍 Snake: full cycle, restarting")
        end
        targetPos = buildTarget()
    end

    RunService.Heartbeat:Connect(function(dt)
        if not CFG.AutoFarm or _converting then
            if prevActive then
                prevActive = false
                targetPos  = nil
            end
            return
        end
        if not HRP or not Hum or Hum.Health <= 0 then return end
        if not CFG.FieldPos then return end

        -- Инициализация
        if not targetPos then
            snakeRow   = 0
            snakeDir   = 1
            targetPos  = buildTarget()
            prevActive = true
        end

        -- Выбираем цель: событие на поле ИЛИ змейка
        local currentTarget = targetPos

        -- Проверяем field event
        if _eventTarget then
            if tick() > _eventExpiry then
                clearFieldEvent()
            else
                currentTarget = _eventTarget
            end
        end

        if not currentTarget then return end

        local myPos = HRP.Position
        local dx = currentTarget.X - myPos.X
        local dz = currentTarget.Z - myPos.Z
        local dist = math.sqrt(dx * dx + dz * dz)

        -- Дошли до цели
        if dist < 2 then
            if _eventTarget then
                -- Достигли события — очищаем
                clearFieldEvent()
            else
                -- Достигли точки змейки — следующий ряд
                nextRow()
            end
            return
        end

        local speed = CFG.WalkSpeed
        local step  = math.min(speed * dt, dist)
        local nx, nz = dx / dist, dz / dist

        local newX = myPos.X + nx * step
        local newZ = myPos.Z + nz * step
        local newY = myPos.Y

        pcall(function()
            HRP.CFrame = CFrame.new(
                Vector3.new(newX, newY, newZ),
                Vector3.new(newX + nx, newY, newZ + nz)
            )
            HRP.AssemblyLinearVelocity  = Vector3.new(0, HRP.AssemblyLinearVelocity.Y, 0)
            HRP.AssemblyAngularVelocity = Vector3.zero
        end)
    end)
end

-- ── 6. FIELD EVENT SCANNER ────────────────────────
-- Сканирует workspace для событий на нашем поле
-- Автоматически активен когда AutoFarm = true
task.spawn(function()
    while task.wait(0.4) do
        if not CFG.AutoFarm or _converting then continue end
        if not CFG.FieldPos or not HRP then continue end

        -- Уже есть активное событие — не перебиваем
        if _eventTarget and tick() < _eventExpiry then continue end

        local myPos = HRP.Position

        -- ── 6a. TORNADO — workspace.Particles "Root"/"Plane" ──
        pcall(function()
            local particles = workspace:FindFirstChild("Particles")
            if not particles then return end
            for _, child in ipairs(particles:GetDescendants()) do
                if (child.Name == "Root" or child.Name == "Plane") and child:IsA("BasePart") then
                    local tPos = child.Position
                    if isNearField(tPos) then
                        setFieldEvent(
                            Vector3.new(tPos.X, myPos.Y, tPos.Z),
                            "🌪 Tornado",
                            3
                        )
                        return
                    end
                end
            end
        end)
        if _eventTarget then continue end

        -- ── 6b. COCONUT INDICATOR — workspace children ──
        -- Кокосы создают зелёный круг на поле (Part/MeshPart)
        pcall(function()
            for _, child in ipairs(workspace:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                    local name = child.Name:lower()
                    if name:find("coconut") or name:find("coco") then
                        local pos
                        if child:IsA("BasePart") then
                            pos = child.Position
                        elseif child:IsA("Model") and child.PrimaryPart then
                            pos = child.PrimaryPart.Position
                        elseif child:IsA("Model") then
                            local pp = child:FindFirstChildWhichIsA("BasePart")
                            if pp then pos = pp.Position end
                        end
                        if pos and isNearField(pos) then
                            setFieldEvent(
                                Vector3.new(pos.X, myPos.Y, pos.Z),
                                "🥥 Coconut",
                                4
                            )
                            return
                        end
                    end
                end
            end
        end)
        if _eventTarget then continue end

        -- ── 6c. TARGET PRACTICE (Precise Bee) — кружочки на поле ──
        -- Ищем объекты-мишени на нашем поле
        pcall(function()
            for _, child in ipairs(workspace:GetDescendants()) do
                if child:IsA("BasePart") then
                    local name = child.Name:lower()
                    if (name:find("target") or name:find("bullseye") or name:find("precise")) then
                        local tPos = child.Position
                        if isNearField(tPos) then
                            setFieldEvent(
                                Vector3.new(tPos.X, myPos.Y, tPos.Z),
                                "🎯 Target Practice",
                                3
                            )
                            return
                        end
                    end
                end
            end
        end)
        if _eventTarget then continue end

        -- ── 6d. BLOOM — workspace для bloom объектов ──
        pcall(function()
            for _, child in ipairs(workspace:GetDescendants()) do
                if child:IsA("BasePart") then
                    local name = child.Name:lower()
                    if name:find("bloom") and not name:find("remove") then
                        local bPos = child.Position
                        if isNearField(bPos) then
                            setFieldEvent(
                                Vector3.new(bPos.X, myPos.Y, bPos.Z),
                                "🌸 Bloom",
                                3
                            )
                            return
                        end
                    end
                end
            end
        end)
        if _eventTarget then continue end

        -- ── 6e. COLLECTIBLES (tokens, pollen packages, duped) ──
        -- Собираем ближайшие токены НЕ являющиеся ability tokens
        -- Ability tokens = "C" части в Collectibles (мы их НЕ трогаем)
        pcall(function()
            local collectibles = workspace:FindFirstChild("Collectibles")
            if not collectibles then return end

            local bestDist = 40
            local bestPos  = nil
            local bestName = ""

            for _, token in ipairs(collectibles:GetChildren()) do
                if not token:IsA("BasePart") then continue end

                local tokenName = token.Name
                -- Пропускаем ability tokens ("C") — по просьбе пользователя
                if tokenName == "C" then continue end

                local tPos = token.Position
                -- Токен на нашем поле?
                if not isNearField(tPos) then continue end

                -- Расстояние от игрока
                local d = (Vector3.new(tPos.X, 0, tPos.Z) - Vector3.new(myPos.X, 0, myPos.Z)).Magnitude
                if d < bestDist and d > 3 then
                    bestDist = d
                    bestPos  = tPos
                    bestName = tokenName
                end
            end

            if bestPos then
                setFieldEvent(
                    Vector3.new(bestPos.X, myPos.Y, bestPos.Z),
                    "🪙 Token: " .. bestName,
                    2
                )
            end
        end)
        if _eventTarget then continue end


    end
end)

-- ── 7. AUTO COCONUT USE ───────────────────────────
-- Автоматически использует кокос каждые 11 секунд через PlayerActivesCommand
task.spawn(function()
    while task.wait(11) do
        if not CFG.AutoFarm or _converting then continue end
        if not R.PlayerActivesCommand then continue end
        pcall(function()
            local args = { ["Name"] = "Coconut" }
            if R.PlayerActivesCommand:IsA("RemoteFunction") then
                R.PlayerActivesCommand:InvokeServer(args)
            else
                R.PlayerActivesCommand:FireServer(args)
            end
            debugLog("🥥 Auto Coconut used")
        end)
    end
end)

-- ── 8. REMOTE EVENT LISTENERS ─────────────────────
-- Слушаем серверные события для логирования и реакции
-- Все события автоматически активны (не нужны отдельные тогглы)

-- 8a. Tornado Events
if R.TornadoEvents and R.TornadoEvents:IsA("RemoteEvent") then
    R.TornadoEvents.OnClientEvent:Connect(function(...)
        local args = {...}
        debugLog("📡 tornadoEvents received: " .. #args .. " args")
        for i, v in ipairs(args) do
            debugLog("  arg[" .. i .. "] = " .. tostring(v))
        end
        -- Если аргумент — позиция (Vector3/CFrame), используем его
        for _, v in ipairs(args) do
            if typeof(v) == "Vector3" and isNearField(v) and CFG.AutoFarm then
                setFieldEvent(Vector3.new(v.X, HRP and HRP.Position.Y or v.Y, v.Z), "🌪 Tornado (remote)", 4)
                break
            elseif typeof(v) == "CFrame" and isNearField(v.Position) and CFG.AutoFarm then
                local p = v.Position
                setFieldEvent(Vector3.new(p.X, HRP and HRP.Position.Y or p.Y, p.Z), "🌪 Tornado (remote)", 4)
                break
            end
        end
    end)
end

-- 8b. Cloud Events (Coconut Combo position)
if R.CloudEvents and R.CloudEvents:IsA("RemoteEvent") then
    R.CloudEvents.OnClientEvent:Connect(function(...)
        local args = {...}
        debugLog("📡 cloudEvents received: " .. #args .. " args")
        for i, v in ipairs(args) do
            debugLog("  arg[" .. i .. "] = " .. tostring(v))
        end
        -- Попробуем извлечь позицию из аргументов
        for _, v in ipairs(args) do
            if typeof(v) == "Vector3" and isNearField(v) and CFG.AutoFarm then
                setFieldEvent(Vector3.new(v.X, HRP and HRP.Position.Y or v.Y, v.Z), "🥥 Coconut Combo (remote)", 5)
                break
            elseif typeof(v) == "CFrame" and isNearField(v.Position) and CFG.AutoFarm then
                local p = v.Position
                setFieldEvent(Vector3.new(p.X, HRP and HRP.Position.Y or p.Y, p.Z), "🥥 Coconut Combo (remote)", 5)
                break
            elseif type(v) == "table" then
                -- Может быть таблица с позицией
                if v.Position and typeof(v.Position) == "Vector3" and isNearField(v.Position) then
                    local p = v.Position
                    if CFG.AutoFarm then
                        setFieldEvent(Vector3.new(p.X, HRP and HRP.Position.Y or p.Y, p.Z), "🥥 Coconut Combo (remote)", 5)
                    end
                    break
                end
            end
        end
    end)
end

-- 8c. Remove Corruption
if R.RemoveCorruption and R.RemoveCorruption:IsA("RemoteEvent") then
    R.RemoveCorruption.OnClientEvent:Connect(function(...)
        debugLog("📡 removeCorruption received: " .. select("#", ...) .. " args")
    end)
end

-- 8e. Spawn Single Bloom
if R.SpawnSingleBloom and R.SpawnSingleBloom:IsA("RemoteEvent") then
    R.SpawnSingleBloom.OnClientEvent:Connect(function(...)
        local args = {...}
        debugLog("📡 spawnSingleBloom received: " .. #args .. " args")
        for _, v in ipairs(args) do
            if typeof(v) == "Vector3" and isNearField(v) and CFG.AutoFarm then
                setFieldEvent(Vector3.new(v.X, HRP and HRP.Position.Y or v.Y, v.Z), "🌸 Bloom (remote)", 4)
                break
            end
        end
    end)
end

-- 8f. Petal Collected
if R.PetalCollected and R.PetalCollected:IsA("RemoteEvent") then
    R.PetalCollected.OnClientEvent:Connect(function(...)
        debugLog("📡 PetalCollected received: " .. select("#", ...) .. " args")
    end)
end

-- 8d. Create Duped Token
if R.CreateDupedToken and R.CreateDupedToken:IsA("RemoteEvent") then
    R.CreateDupedToken.OnClientEvent:Connect(function(...)
        local args = {...}
        debugLog("📡 createDupedToken received: " .. #args .. " args")
        for _, v in ipairs(args) do
            if typeof(v) == "Vector3" and isNearField(v) and CFG.AutoFarm then
                setFieldEvent(Vector3.new(v.X, HRP and HRP.Position.Y or v.Y, v.Z), "🪙 Duped Token (remote)", 3)
                break
            end
        end
    end)
end

-- ════════════════════════════════════════════════════
debugLog("✅ v15 загружен — Field Events + Auto Remotes + Snake")
debugLog("Remotes found:")
for name, remote in pairs(R) do
    debugLog("  " .. name .. " = " .. tostring(remote ~= nil))
end
debugLog("Field events: Tornado, Coconut, Bloom, Tokens, Target Practice")
debugLog("Auto Coconut Use: every 11s via PlayerActivesCommand")
