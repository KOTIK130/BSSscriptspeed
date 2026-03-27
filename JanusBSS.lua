-- ════════════════════════════════════════════════════
--   BSS ULTIMATE FARM  v6  |  Все модули независимы
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
        local filename = "bss_debug_log.txt"
        writefile(filename, content)
        return filename
    end)
    return ok, err
end

-- ─── Конфиг ──────────────────────────────────────
local CFG = {
    AutoFarm    = false,
    FieldPos    = nil,
    FieldRadius = 45,
    FarmSpeed   = 60,

    AutoDig     = false,

    AutoConvert = false,
    HivePos     = nil,

    AutoItem    = false,
    ItemSlot    = 1,

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
    ToolClick       = findRemote("toolClick"),
    AbilityEvent    = findRemote("playerAbilityEvent"),
    TokenEvent      = findRemote("tokenEvent"),
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
    if CFG.SpeedHack and Hum then
        Hum.WalkSpeed = CFG.WalkSpeed
    end
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

-- ─── Сканирование токенов ─────────────────────────
-- Токены в BSS = маленькие Part (Size < 2) + CanCollide=false + прямые дети workspace
-- Сбор через firetouchinterest (касание), не ремоты
local _tokCache = {}      -- {Part instances}
local _tokBlacklist = {}  -- {[Part] = tick()} — кулдаун 3 сек

task.spawn(function()
    while task.wait(1) do
        if not CFG.AutoFarm then continue end
        if not CFG.FieldPos then continue end

        local fp = CFG.FieldPos
        local rr = CFG.FieldRadius * CFG.FieldRadius
        local result = {}
        local now = tick()

        -- Чистим старые записи из блеклиста
        for part, t in pairs(_tokBlacklist) do
            if now - t > 3 then _tokBlacklist[part] = nil end
        end

        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("BasePart")
                and child.Name == "Part"
                and not child.CanCollide
                and child.Size.X < 2 and child.Size.Y < 2 and child.Size.Z < 2
                and not _tokBlacklist[child]
            then
                local pos = child.Position
                local dx = pos.X - fp.X; local dz = pos.Z - fp.Z
                if dx*dx + dz*dz <= rr then
                    table.insert(result, child)
                end
            end
        end

        if #result ~= #_tokCache then
            debugLog("Tokens: " .. #result .. " | blacklisted: " .. (function() local n=0 for _ in pairs(_tokBlacklist) do n+=1 end return n end)())
        end
        _tokCache = result
    end
end)

-- ─── UI ──────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Win = Rayfield:CreateWindow({
    Name = "BSS ULTIMATE FARM",
    ConfigurationSaving = { Enabled = false },
})

local TFarm  = Win:CreateTab("⚙ Farm",        4483362458)
local TItem  = Win:CreateTab("🎒 Items",      4483362458)
local TPos   = Win:CreateTab("📍 Positions",  4483362458)
local TDebug = Win:CreateTab("🐛 Debug",      4483362458)

local ParaStatus = TFarm:CreateParagraph({ Title = "Status", Content = "● Idle" })
local ParaPollen = TFarm:CreateParagraph({ Title = "Pollen", Content = "0.0%" })

local function setStatus(s)
    pcall(function() ParaStatus:Set({ Title = "Status", Content = s }) end)
end

-- ── Farm tab ──
TFarm:CreateSection("Auto Farm")

TFarm:CreateToggle({ Name = "Auto Farm (Tokens)", CurrentValue = false, Callback = function(v)
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

TFarm:CreateToggle({ Name = "Speed Hack", CurrentValue = false, Callback = function(v)
    CFG.SpeedHack = v
    if Hum then
        Hum.WalkSpeed = v and CFG.WalkSpeed or defaultSpeed
    end
end })

TFarm:CreateSlider({ Name = "WalkSpeed", Range = { 16, 500 }, Increment = 1, CurrentValue = 70,
    Callback = function(v)
        CFG.WalkSpeed = v
        if CFG.SpeedHack and Hum then
            Hum.WalkSpeed = v
        end
    end
})

TFarm:CreateSection("Farm Settings")

TFarm:CreateSlider({ Name = "Farm Move Speed (studs/s)", Range = { 10, 300 }, Increment = 5, CurrentValue = 60,
    Callback = function(v) CFG.FarmSpeed = v end })

TFarm:CreateSlider({ Name = "Field Radius", Range = { 10, 150 }, Increment = 5, CurrentValue = 45,
    Callback = function(v) CFG.FieldRadius = v end })

-- ── Items tab ──
TItem:CreateSection("Auto Use Item")

TItem:CreateToggle({ Name = "Auto Use Item", CurrentValue = false, Callback = function(v)
    CFG.AutoItem = v
end })

TItem:CreateSlider({ Name = "Slot (1–7)", Range = { 1, 7 }, Increment = 1, CurrentValue = 1,
    Callback = function(v) CFG.ItemSlot = v end })

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
    _tokCache = {}
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
--   МОДУЛИ — каждый полностью независим
-- ════════════════════════════════════════════════════

-- ── 1. SPEED HACK ─────────────────────────────────
task.spawn(function()
    while task.wait(0.5) do
        if CFG.SpeedHack and Hum then
            pcall(function() Hum.WalkSpeed = CFG.WalkSpeed end)
        end
    end
end)

-- ── 2. AUTO DIG ───────────────────────────────────
task.spawn(function()
    while task.wait(0.1) do
        if CFG.AutoDig and R.ToolClick then
            pcall(function() R.ToolClick:InvokeServer() end)
        end
    end
end)

-- ── 3. AUTO ITEM ──────────────────────────────────
-- Симулируем нажатие клавиш 1–7 через VirtualInputManager
local SlotKeys = {
    [1] = Enum.KeyCode.One,
    [2] = Enum.KeyCode.Two,
    [3] = Enum.KeyCode.Three,
    [4] = Enum.KeyCode.Four,
    [5] = Enum.KeyCode.Five,
    [6] = Enum.KeyCode.Six,
    [7] = Enum.KeyCode.Seven,
}

task.spawn(function()
    while task.wait(0.7) do
        if CFG.AutoItem and not _converting then
            local key = SlotKeys[CFG.ItemSlot]
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

-- ── 4. AUTO CONVERT ───────────────────────────────
local _converting = false
task.spawn(function()
    while task.wait(0.3) do
        if not CFG.AutoConvert then continue end
        if not CFG.HivePos then continue end
        if _converting then continue end
        if getPollen() < 99 then continue end

        _converting = true
        debugLog("Convert START — pollen: " .. ("%.1f%%"):format(getPollen()))
        setStatus("● Converting...")

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

-- ── 5. AUTO FARM ──────────────────────────────────
-- Heartbeat читает готовый кэш, движется к ближайшему токену
-- Сбор через firetouchinterest (симуляция Touched)
local _hasFTI = typeof(firetouchinterest) == "function"
debugLog("firetouchinterest: " .. tostring(_hasFTI))

RunService.Heartbeat:Connect(function(dt)
    if not CFG.AutoFarm then return end
    if _converting then return end
    if not HRP or not Hum or Hum.Health <= 0 then return end
    if not CFG.FieldPos then return end

    local tokens = _tokCache
    if #tokens == 0 then return end

    -- Найти ближайший токен (теперь Part instance)
    local target = nil
    local bestD  = math.huge
    local px = HRP.Position.X
    local pz = HRP.Position.Z

    for _, part in ipairs(tokens) do
        if part and part.Parent then
            local pos = part.Position
            local dx = pos.X - px
            local dz = pos.Z - pz
            local d  = dx * dx + dz * dz
            if d < bestD then
                bestD  = d
                target = part
            end
        end
    end

    if not target then return end

    local tPos = target.Position
    local cur  = HRP.Position
    local dx   = tPos.X - cur.X
    local dz   = tPos.Z - cur.Z
    local dist = math.sqrt(dx * dx + dz * dz)

    if dist > 1 then
        -- Двигаемся к токену
        local inv  = 1 / dist
        local step = math.min(CFG.FarmSpeed * dt, dist)
        local nx   = cur.X + dx * inv * step
        local nz   = cur.Z + dz * inv * step

        HRP.CFrame = CFrame.lookAt(
            Vector3.new(nx, cur.Y, nz),
            Vector3.new(tPos.X, cur.Y, tPos.Z)
        )

        local vy = HRP.AssemblyLinearVelocity.Y
        HRP.AssemblyLinearVelocity = Vector3.new(0, vy, 0)
    else
        -- Рядом — телепорт прямо на токен + firetouchinterest
        HRP.CFrame = CFrame.new(tPos.X, cur.Y, tPos.Z)

        if _hasFTI then
            pcall(function()
                firetouchinterest(HRP, target, 0)  -- Touch begin
                firetouchinterest(HRP, target, 1)  -- Touch end
            end)
        end

        -- Блеклист чтобы не спамить один токен
        _tokBlacklist[target] = tick()
        debugLog("Token touched @ " .. math.floor(tPos.X) .. "," .. math.floor(tPos.Z) .. " | left: " .. #tokens)
    end
end)

-- ════════════════════════════════════════════════════
debugLog("✅ Скрипт загружен! v8.1 — firetouchinterest + blacklist")
debugLog("Remotes: ToolClick=" .. tostring(R.ToolClick ~= nil) .. ", AbilityEvent=" .. tostring(R.AbilityEvent ~= nil) .. ", TokenEvent=" .. tostring(R.TokenEvent ~= nil))
