-- ════════════════════════════════════════════════════
--   BSS ULTIMATE FARM  v15  |  Все модули независимы
-- ════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
    AutoFarm     = false,
    FieldPos     = nil,
    FieldRadius  = 45,
    SnakeGap     = 8,

    AutoDig      = false,

    AutoConvert  = false,
    HivePos      = nil,
    ConvertSpeed = 80,   -- скорость полёта к улью и обратно (studs/sec)

    ItemSlots = {
        [1] = { Enabled = false, Delay = 1 },
        [2] = { Enabled = false, Delay = 1 },
        [3] = { Enabled = false, Delay = 1 },
        [4] = { Enabled = false, Delay = 1 },
        [5] = { Enabled = false, Delay = 1 },
        [6] = { Enabled = false, Delay = 1 },
        [7] = { Enabled = false, Delay = 1 },
    },

    SpeedHack  = false,
    WalkSpeed  = 70,
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
    ToolClick = findRemote("toolClick"),
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

-- ─── UI ──────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Win = Rayfield:CreateWindow({
    Name = "BSS ULTIMATE FARM",
    ConfigurationSaving = { Enabled = false },
})

local TFarm  = Win:CreateTab("⚙ Farm",       4483362458)
local TItem  = Win:CreateTab("🎒 Items",     4483362458)
local TPos   = Win:CreateTab("📍 Positions", 4483362458)
local TDebug = Win:CreateTab("🐛 Debug",     4483362458)

local ParaStatus = TFarm:CreateParagraph({ Title = "Status", Content = "● Idle" })
local ParaPollen = TFarm:CreateParagraph({ Title = "Pollen", Content = "0.0%" })

local function setStatus(s)
    pcall(function() ParaStatus:Set({ Title = "Status", Content = s }) end)
end

-- ── Farm tab ──
TFarm:CreateSection("Auto Farm")

TFarm:CreateToggle({ Name = "Auto Farm (Snake)", CurrentValue = false, Callback = function(v)
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

TFarm:CreateSection("Speed")

TFarm:CreateToggle({ Name = "Speed Hack (CFrame)", CurrentValue = false, Callback = function(v)
    CFG.SpeedHack = v
end })

TFarm:CreateSlider({ Name = "Farm Speed (studs/s)", Range = { 16, 500 }, Increment = 1, CurrentValue = 70,
    Callback = function(v) CFG.WalkSpeed = v end
})

TFarm:CreateSlider({ Name = "Convert Flight Speed (studs/s)", Range = { 20, 300 }, Increment = 5, CurrentValue = 80,
    Callback = function(v) CFG.ConvertSpeed = v end
})

TFarm:CreateSection("Farm Settings")

TFarm:CreateSlider({ Name = "Field Radius", Range = { 10, 150 }, Increment = 5, CurrentValue = 45,
    Callback = function(v) CFG.FieldRadius = v end })

TFarm:CreateSlider({ Name = "Snake Gap (studs)", Range = { 2, 20 }, Increment = 1, CurrentValue = 8,
    Callback = function(v) CFG.SnakeGap = v end })

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

-- Обновление поллена
task.spawn(function()
    while task.wait(0.8) do
        pcall(function()
            ParaPollen:Set({ Title = "Pollen", Content = ("%.1f%%"):format(getPollen()) })
        end)
    end
end)

-- ════════════════════════════════════════════════════
--   МОДУЛИ
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

        local step   = CFG.WalkSpeed * dt
        local pos    = HRP.Position
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
    [1] = Enum.KeyCode.One,   [2] = Enum.KeyCode.Two,
    [3] = Enum.KeyCode.Three, [4] = Enum.KeyCode.Four,
    [5] = Enum.KeyCode.Five,  [6] = Enum.KeyCode.Six,
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

-- ── 4. AUTO CONVERT (CFrame-полёт) ────────────────

-- Плавный CFrame-полёт к точке (task.wait(0.05) ≈ 20 fps)
local function flyTo(target, speed)
    while HRP do
        local pos  = HRP.Position
        local diff = target - pos
        local dist = diff.Magnitude
        if dist < 2 then break end
        local step = math.min(speed * 0.05, dist)
        local newPos = pos + diff.Unit * step
        pcall(function()
            HRP.CFrame = CFrame.new(newPos)
            HRP.AssemblyLinearVelocity  = Vector3.zero
            HRP.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.05)
    end
end

task.spawn(function()
    while task.wait(0.3) do
        if not CFG.AutoConvert then continue end
        if not CFG.HivePos    then continue end
        if _converting        then continue end
        if getPollen() < 99   then continue end

        _converting = true
        debugLog("Convert START — pollen: " .. ("%.1f%%"):format(getPollen()))
        setStatus("● конвертация → улей")

        -- Летим к улью
        flyTo(CFG.HivePos, CFG.ConvertSpeed)

        -- Нажимаем E один раз
        task.wait(0.1)
        pcall(function()
            VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
            task.wait(0.15)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
        task.wait(5)

        -- Летим обратно на поле
        if CFG.FieldPos then
            setStatus("● конвертация → поле")
            flyTo(CFG.FieldPos, CFG.ConvertSpeed)
        end

        _converting = false
        debugLog("Convert END")
        setStatus(CFG.AutoFarm and "● Farming..." or (CFG.AutoConvert and "● Waiting..." or "● Idle"))
    end
end)

-- ── 5. AUTO FARM — Змейка (Heartbeat + CFrame) ────
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

        if not targetPos then
            snakeRow   = 0
            snakeDir   = 1
            targetPos  = buildTarget()
            prevActive = true
        end
        if not targetPos then return end

        local myPos = HRP.Position
        local dx = targetPos.X - myPos.X
        local dz = targetPos.Z - myPos.Z
        local dist = math.sqrt(dx * dx + dz * dz)

        if dist < 2 then
            nextRow()
            return
        end

        local step = math.min(CFG.WalkSpeed * dt, dist)
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

-- ════════════════════════════════════════════════════
debugLog("✅ v15 загружен — CFrame Convert + Farm + SpeedHack")
debugLog("Remotes found:")
for name, remote in pairs(R) do
    debugLog("  " .. name .. " = " .. tostring(remote ~= nil))
end
