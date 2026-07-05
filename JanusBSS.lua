-- ════════════════════════════════════════════════════
--   BSS ULTIMATE FARM  v17  |  Все модули независимы
--   Новое в v17: SMART FARM — сбор токенов способностей
--   с карты (workspace.Collectibles), приоритеты, база
--   токенов с автообучением, змейка как fallback
-- ════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local VIM               = game:GetService("VirtualInputManager")

local Player  = Players.LocalPlayer
local PGui    = Player:WaitForChild("PlayerGui")

-- ─── Утилиты окружения (executor может не иметь всех функций) ──
local hasWriteFile = type(writefile) == "function"
local hasReadFile  = type(readfile)  == "function"
local hasIsFile    = type(isfile)    == "function"

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
    warn("[BSS] " .. tostring(msg))
end

local function saveLog()
    if not hasWriteFile then
        return false, "writefile недоступен в этом executor"
    end
    return pcall(function()
        writefile("bss_debug_log.txt", table.concat(_logBuffer, "\n"))
    end)
end

-- ─── Конфиг ──────────────────────────────────────
local _converting = false

local CFG = {
    AutoFarm     = false,
    FieldPos     = nil,
    FieldRadius  = 45,
    SnakeGap     = 8,

    -- Smart Farm (сбор токенов)
    TokenFarm       = true,   -- собирать токены вместо тупой змейки
    TokenRadius     = 50,     -- радиус поиска токенов от центра поля
    TokenTimeout    = 6,      -- сек на попытку добежать до токена, потом blacklist
    TokenAbilityPri = true,   -- приоритет токенам способностей над обычными

    AutoDig      = false,

    AutoConvert  = false,
    HivePos      = nil,
    ConvertSpeed = 80,
    ConvertPollen = 99,   -- порог % для старта конвертации
    ConvertWait   = 15,   -- сек ожидания у улья

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

    AntiAFK    = true,
}

-- ─── Persist config (позиции + настройки) ────────
local CFG_FILE = "bss_config.json"

local function saveConfig()
    if not hasWriteFile then return end
    pcall(function()
        local data = {
            FieldRadius = CFG.FieldRadius, SnakeGap = CFG.SnakeGap,
            ConvertSpeed = CFG.ConvertSpeed, ConvertPollen = CFG.ConvertPollen,
            ConvertWait = CFG.ConvertWait, WalkSpeed = CFG.WalkSpeed,
            TokenRadius = CFG.TokenRadius, TokenTimeout = CFG.TokenTimeout,
            HivePos  = CFG.HivePos  and {CFG.HivePos.X,  CFG.HivePos.Y,  CFG.HivePos.Z}  or nil,
            FieldPos = CFG.FieldPos and {CFG.FieldPos.X, CFG.FieldPos.Y, CFG.FieldPos.Z} or nil,
        }
        writefile(CFG_FILE, game:GetService("HttpService"):JSONEncode(data))
    end)
end

local function loadConfig()
    if not (hasReadFile and hasIsFile and isfile(CFG_FILE)) then return end
    pcall(function()
        local data = game:GetService("HttpService"):JSONDecode(readfile(CFG_FILE))
        if data.FieldRadius   then CFG.FieldRadius   = data.FieldRadius end
        if data.SnakeGap      then CFG.SnakeGap      = data.SnakeGap end
        if data.ConvertSpeed  then CFG.ConvertSpeed  = data.ConvertSpeed end
        if data.ConvertPollen then CFG.ConvertPollen = data.ConvertPollen end
        if data.ConvertWait   then CFG.ConvertWait   = data.ConvertWait end
        if data.WalkSpeed     then CFG.WalkSpeed     = data.WalkSpeed end
        if data.TokenRadius   then CFG.TokenRadius   = data.TokenRadius end
        if data.TokenTimeout  then CFG.TokenTimeout  = data.TokenTimeout end
        if data.HivePos  then CFG.HivePos  = Vector3.new(unpack(data.HivePos)) end
        if data.FieldPos then CFG.FieldPos = Vector3.new(unpack(data.FieldPos)) end
        debugLog("Конфиг загружен из " .. CFG_FILE)
    end)
end
loadConfig()

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
    HRP  = Char:WaitForChild("HumanoidRootPart", 10)
    Hum  = Char:WaitForChild("Humanoid", 10)
    if Hum then defaultSpeed = Hum.WalkSpeed end
    debugLog("Персонаж загружен")
end
loadChar()

Player.CharacterAdded:Connect(function()
    -- при смерти/респавне прерываем активные операции, чтобы не летать в пустоту
    _converting = false
    task.wait(0.5)
    loadChar()
end)

-- быстрая проверка «жив ли персонаж»
local function alive()
    return HRP and HRP.Parent and Hum and Hum.Health > 0
end

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
                    _pollenCache = c
                    return c
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

-- ════════════════════════════════════════════════════
--   TOKEN SYSTEM — «зрение» токенов на карте
--   Все токены — это BasePart'ы в workspace.Collectibles.
--   Тип токена определяется текстурой его декали.
-- ════════════════════════════════════════════════════

-- Известные текстуры токенов способностей (можно дополнять).
-- Всё, чего нет в списке, скрипт запишет в базу как "Unknown"
-- и вы сможете назвать его сами, посмотрев лог.
local KNOWN_TOKENS = {
    -- textureId (только цифры) = { name, priority }
    -- priority: 3 = топ (бустеры сбора), 2 = способность, 1 = обычный
    ["1629547638"]  = { name = "Honey Token",    pri = 1 },
    ["2528381164"]  = { name = "Treat",          pri = 1 },
    ["1442764398"]  = { name = "Haste",          pri = 3 },
    ["1442700745"]  = { name = "Focus",          pri = 3 },
    ["2028574353"]  = { name = "Pulse",          pri = 2 },
    ["1874704640"]  = { name = "Inspire",        pri = 2 },
    ["3898309458"]  = { name = "Token Link",     pri = 3 },
    ["1629649299"]  = { name = "Buzz Bomb",      pri = 2 },
    ["1629651086"]  = { name = "Rage",           pri = 2 },
}

-- База токенов: textureId -> { name, pri, count, lastSeen }
local TOKEN_DB_FILE = "bss_tokens.json"
local TokenDB = {}
local TokenStats = { collected = 0, sessionStart = os.time() }

local function loadTokenDB()
    if not (hasReadFile and hasIsFile and isfile(TOKEN_DB_FILE)) then return end
    pcall(function()
        TokenDB = HttpService:JSONDecode(readfile(TOKEN_DB_FILE)) or {}
        local n = 0
        for _ in pairs(TokenDB) do n = n + 1 end
        debugLog("TokenDB загружена: " .. n .. " типов токенов")
    end)
end
loadTokenDB()

local function saveTokenDB()
    if not hasWriteFile then return end
    pcall(function()
        writefile(TOKEN_DB_FILE, HttpService:JSONEncode(TokenDB))
    end)
end

-- нормализуем "rbxassetid://12345" / "http://...id=12345" -> "12345"
local function textureToId(tex)
    if not tex or tex == "" then return nil end
    return tex:match("(%d+)%s*$") or tex:match("id=(%d+)") or tex
end

-- получить инфо о токене (и обучить базу, если новый)
local function classifyToken(part)
    local decal = part:FindFirstChildWhichIsA("Decal")
    local id = decal and textureToId(decal.Texture) or "no_texture"

    local known = KNOWN_TOKENS[id]
    local entry = TokenDB[id]
    if not entry then
        entry = {
            name = known and known.name or ("Unknown (" .. id .. ")"),
            pri  = known and known.pri or 1,
            count = 0,
            lastSeen = os.time(),
        }
        TokenDB[id] = entry
        if not known then
            debugLog("🆕 Новый тип токена в базе: " .. id)
        end
    end
    entry.lastSeen = os.time()
    return id, entry
end

-- временный blacklist недостижимых токенов (instance -> expireTime)
local _tokenBlacklist = setmetatable({}, { __mode = "k" })

local function getCollectiblesFolder()
    return Workspace:FindFirstChild("Collectibles")
end

-- найти лучший токен: score = приоритет * 1000 - дистанция
local function findBestToken()
    local folder = getCollectiblesFolder()
    if not folder or not alive() then return nil end

    local center = CFG.FieldPos or HRP.Position
    local myPos  = HRP.Position
    local now    = os.clock()
    local best, bestScore = nil, -math.huge

    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") then
            local bl = _tokenBlacklist[part]
            if not (bl and bl > now) then
                -- токен должен быть в зоне поля
                local flat = part.Position - center
                local fieldDist = Vector3.new(flat.X, 0, flat.Z).Magnitude
                if fieldDist <= CFG.TokenRadius then
                    local _, info = classifyToken(part)
                    local pri = CFG.TokenAbilityPri and info.pri or 1
                    local dist = (part.Position - myPos).Magnitude
                    local score = pri * 1000 - dist
                    if score > bestScore then
                        bestScore = score
                        best = part
                    end
                end
            end
        end
    end
    return best
end

-- ─── UI ──────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Win = Rayfield:CreateWindow({
    Name = "BSS ULTIMATE FARM v16",
    ConfigurationSaving = { Enabled = false },
})

local TFarm  = Win:CreateTab("⚙ Farm",       4483362458)
local TToken = Win:CreateTab("🎯 Tokens",    4483362458)
local TItem  = Win:CreateTab("🎒 Items",     4483362458)
local TPos   = Win:CreateTab("📍 Positions", 4483362458)
local TDebug = Win:CreateTab("🐛 Debug",     4483362458)

local ParaStatus = TFarm:CreateParagraph({ Title = "Status", Content = "● Idle" })
local ParaPollen = TFarm:CreateParagraph({ Title = "Pollen", Content = "0.0%" })

local _lastStatus = nil
local function setStatus(s)
    if s == _lastStatus then return end -- не спамим UI каждый кадр
    _lastStatus = s
    pcall(function()
        ParaStatus:Set({ Title = "Status", Content = s })
    end)
end

-- ── Farm tab ──
TFarm:CreateSection("Auto Farm")

TFarm:CreateToggle({
    Name = "Auto Farm (Snake)",
    CurrentValue = false,
    Callback = function(v)
        CFG.AutoFarm = v
        setStatus(v and "● Farming..." or "● Idle")
    end
})

TFarm:CreateToggle({
    Name = "Auto Dig",
    CurrentValue = false,
    Callback = function(v) CFG.AutoDig = v end
})

TFarm:CreateToggle({
    Name = "Auto Convert  ⚠ нужны точки!",
    CurrentValue = false,
    Callback = function(v)
        CFG.AutoConvert = v
        if v and (not CFG.HivePos or not CFG.FieldPos) then
            Rayfield:Notify({
                Title = "⚠ Внимание",
                Content = "Установи точки во вкладке Positions!",
                Duration = 5
            })
        end
    end
})

TFarm:CreateSection("Speed")

TFarm:CreateToggle({
    Name = "Speed Hack (CFrame)",
    CurrentValue = false,
    Callback = function(v) CFG.SpeedHack = v end
})

TFarm:CreateSlider({
    Name = "Farm Speed (studs/s)",
    Range = { 16, 500 }, Increment = 1, CurrentValue = CFG.WalkSpeed,
    Callback = function(v) CFG.WalkSpeed = v; saveConfig() end
})

TFarm:CreateSlider({
    Name = "Convert Flight Speed (studs/s)",
    Range = { 20, 300 }, Increment = 5, CurrentValue = CFG.ConvertSpeed,
    Callback = function(v) CFG.ConvertSpeed = v; saveConfig() end
})

TFarm:CreateSlider({
    Name = "Convert Pollen Threshold (%)",
    Range = { 50, 100 }, Increment = 1, CurrentValue = CFG.ConvertPollen,
    Callback = function(v) CFG.ConvertPollen = v; saveConfig() end
})

TFarm:CreateSlider({
    Name = "Convert Wait at Hive (sec)",
    Range = { 3, 60 }, Increment = 1, CurrentValue = CFG.ConvertWait,
    Callback = function(v) CFG.ConvertWait = v; saveConfig() end
})

TFarm:CreateSection("Farm Settings")

TFarm:CreateSlider({
    Name = "Field Radius",
    Range = { 10, 150 }, Increment = 5, CurrentValue = CFG.FieldRadius,
    Callback = function(v) CFG.FieldRadius = v; saveConfig() end
})

TFarm:CreateSlider({
    Name = "Snake Gap (studs)",
    Range = { 2, 20 }, Increment = 1, CurrentValue = CFG.SnakeGap,
    Callback = function(v) CFG.SnakeGap = v; saveConfig() end
})

TFarm:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = CFG.AntiAFK,
    Callback = function(v) CFG.AntiAFK = v end
})

-- ── Tokens tab ──
TToken:CreateSection("Smart Farm — сбор токенов")

local TokenStatsPara = TToken:CreateParagraph({
    Title = "Собрано за сессию", Content = "0 токенов"
})

TToken:CreateToggle({
    Name = "Collect Tokens (умный фарм)",
    CurrentValue = CFG.TokenFarm,
    Callback = function(v) CFG.TokenFarm = v end
})

TToken:CreateToggle({
    Name = "Приоритет токенам способностей",
    CurrentValue = CFG.TokenAbilityPri,
    Callback = function(v) CFG.TokenAbilityPri = v end
})

TToken:CreateSlider({
    Name = "Token Search Radius (studs)",
    Range = { 10, 120 }, Increment = 5, CurrentValue = CFG.TokenRadius,
    Callback = function(v) CFG.TokenRadius = v; saveConfig() end
})

TToken:CreateSlider({
    Name = "Token Reach Timeout (sec)",
    Range = { 2, 15 }, Increment = 1, CurrentValue = CFG.TokenTimeout,
    Callback = function(v) CFG.TokenTimeout = v; saveConfig() end
})

TToken:CreateSection("База токенов")

local TokenDBPara = TToken:CreateParagraph({
    Title = "TokenDB", Content = "Нажми «Показать базу»"
})

TToken:CreateButton({
    Name = "📊 Показать базу токенов",
    Callback = function()
        local rows = {}
        for id, e in pairs(TokenDB) do
            table.insert(rows, { id = id, e = e })
        end
        table.sort(rows, function(a, b) return a.e.count > b.e.count end)
        local lines = {}
        for i = 1, math.min(#rows, 12) do
            local r = rows[i]
            table.insert(lines, ("%s — x%d (pri %d)"):format(r.e.name, r.e.count, r.e.pri))
        end
        TokenDBPara:Set({
            Title = "TokenDB (" .. #rows .. " типов)",
            Content = #lines > 0 and table.concat(lines, "\n") or "База пуста — включи фарм",
        })
    end
})

TToken:CreateButton({
    Name = "💾 Сохранить базу (.json)",
    Callback = function()
        saveTokenDB()
        Rayfield:Notify({ Title = "TokenDB", Content = "Сохранено в " .. TOKEN_DB_FILE, Duration = 3 })
    end
})

TToken:CreateButton({
    Name = "🗑 Очистить базу",
    Callback = function()
        TokenDB = {}
        saveTokenDB()
        Rayfield:Notify({ Title = "TokenDB", Content = "База очищена", Duration = 3 })
    end
})

-- ── Items tab ──
for i = 1, 7 do
    TItem:CreateSection("Slot " .. i)
    TItem:CreateToggle({
        Name = "Slot " .. i .. " Enabled",
        CurrentValue = false,
        Callback = function(v) CFG.ItemSlots[i].Enabled = v end
    })
    TItem:CreateSlider({
        Name = "Slot " .. i .. " Delay (sec)",
        Range = { 1, 300 }, Increment = 1, CurrentValue = 1,
        Callback = function(v) CFG.ItemSlots[i].Delay = v end
    })
end

-- ── Positions tab ──
TPos:CreateSection("⚠ Установи ДО фарма!")

local HivePara  = TPos:CreateParagraph({ Title = "Hive",  Content = "не установлен" })
local FieldPara = TPos:CreateParagraph({ Title = "Field", Content = "не установлен" })

local function refreshPosParas()
    if CFG.HivePos then
        local p = CFG.HivePos
        HivePara:Set({ Title = "Hive ✓", Content = ("X:%.1f  Y:%.1f  Z:%.1f"):format(p.X, p.Y, p.Z) })
    else
        HivePara:Set({ Title = "Hive", Content = "не установлен" })
    end
    if CFG.FieldPos then
        local p = CFG.FieldPos
        FieldPara:Set({ Title = "Field ✓", Content = ("X:%.1f  Y:%.1f  Z:%.1f"):format(p.X, p.Y, p.Z) })
    else
        FieldPara:Set({ Title = "Field", Content = "не установлен" })
    end
end
refreshPosParas()  -- показать загруженные из конфига точки

TPos:CreateButton({
    Name = "📍 Set Hive  (встань у улья)",
    Callback = function()
        if not HRP then return end
        CFG.HivePos = HRP.Position
        refreshPosParas(); saveConfig()
        Rayfield:Notify({ Title = "Улей ✓", Content = "Точка сохранена", Duration = 3 })
    end
})

TPos:CreateButton({
    Name = "📍 Set Field  (встань в центр поля)",
    Callback = function()
        if not HRP then return end
        CFG.FieldPos = HRP.Position
        refreshPosParas(); saveConfig()
        Rayfield:Notify({ Title = "Поле ✓", Content = "Точка сохранена", Duration = 3 })
    end
})

TPos:CreateButton({
    Name = "🗑 Сбросить точки",
    Callback = function()
        CFG.HivePos = nil
        CFG.FieldPos = nil
        refreshPosParas(); saveConfig()
        Rayfield:Notify({ Title = "Сброс", Content = "Точки очищены", Duration = 3 })
    end
})

-- ── Debug tab ──
TDebug:CreateSection("Логирование")

local DebugPara = TDebug:CreateParagraph({
    Title = "Лог", Content = "Последние записи появятся здесь"
})

TDebug:CreateButton({
    Name = "💾 Сохранить лог (.txt)",
    Callback = function()
        local ok, err = saveLog()
        if ok then
            Rayfield:Notify({ Title = "✅ Лог сохранён",
                Content = "Файл: bss_debug_log.txt\nСтрок: " .. #_logBuffer, Duration = 5 })
            debugLog("Лог сохранён (" .. #_logBuffer .. " строк)")
        else
            Rayfield:Notify({ Title = "❌ Ошибка", Content = tostring(err), Duration = 5 })
        end
    end
})

TDebug:CreateButton({
    Name = "🗑 Очистить лог",
    Callback = function()
        _logBuffer = {}
        Rayfield:Notify({ Title = "🗑 Очищено", Content = "Лог очищен", Duration = 3 })
    end
})

TDebug:CreateButton({
    Name = "📋 Показать последние 10 записей",
    Callback = function()
        local start = math.max(1, #_logBuffer - 9)
        local lines = {}
        for i = start, #_logBuffer do table.insert(lines, _logBuffer[i]) end
        local txt = #lines > 0 and table.concat(lines, "\n") or "Лог пуст"
        DebugPara:Set({ Title = "Лог (последние " .. #lines .. ")", Content = txt })
    end
})

-- Обновление поллена в UI
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

-- ── 0. ANTI-AFK ────────────────────────────────────
do
    local VirtualUser = game:GetService("VirtualUser")
    Player.Idled:Connect(function()
        if not CFG.AntiAFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        debugLog("Anti-AFK: сброшен таймер бездействия")
    end)
end

-- ── 1. SPEED HACK (CFrame) ─────────────────────────
do
    RunService.Heartbeat:Connect(function(dt)
        if not CFG.SpeedHack then return end
        if _converting or CFG.AutoFarm then return end
        if not alive() then return end

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
        if CFG.AutoDig and not _converting and R.ToolClick then
            pcall(function() R.ToolClick:InvokeServer() end)
        end
    end
end)

-- ── 3. AUTO ITEM ──────────────────────────────────
-- Ждём малыми интервалами, чтобы мгновенно реагировать на смену Delay/Enabled
local SlotKeys = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
    Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven,
}

for i = 1, 7 do
    task.spawn(function()
        while true do
            local waited = 0
            local target = CFG.ItemSlots[i].Delay
            -- дробим ожидание, чтобы изменения Delay применялись сразу
            while waited < target do
                task.wait(0.25)
                waited = waited + 0.25
                target = CFG.ItemSlots[i].Delay
                if not CFG.ItemSlots[i].Enabled then break end
            end
            if CFG.ItemSlots[i].Enabled and not _converting then
                local key = SlotKeys[i]
                pcall(function()
                    VIM:SendKeyEvent(true,  key, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, key, false, game)
                end)
            end
        end
    end)
end

-- ── 4. AUTO CONVERT (CFrame-полёт с noclip и анти-стаком) ──

local function setNoclip(state)
    if not Char then return end
    for _, v in ipairs(Char:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = not state
        end
    end
end

-- единая функция полёта: framerate-независимая, с таймаутом от застревания
local function flyTo(target, speed, faceTarget)
    local timeout = 20                 -- сек макс. на перелёт
    local elapsed = 0
    local lastPos = HRP and HRP.Position
    local stuckTime = 0

    while alive() do
        local pos  = HRP.Position
        local diff = target - pos
        local dist = diff.Magnitude
        if dist < 2 then break end

        local dt = RunService.Heartbeat:Wait()
        elapsed = elapsed + dt
        if elapsed > timeout then
            debugLog("⚠ flyTo timeout — телепорт в точку")
            pcall(function() HRP.CFrame = CFrame.new(target) end)
            break
        end

        -- детект застревания: почти не двигаемся, но не у цели
        if (pos - lastPos).Magnitude < 0.05 then
            stuckTime = stuckTime + dt
            if stuckTime > 1.5 then
                debugLog("⚠ flyTo stuck — телепорт в точку")
                pcall(function() HRP.CFrame = CFrame.new(target) end)
                break
            end
        else
            stuckTime = 0
        end
        lastPos = pos

        local step   = math.min(speed * dt, dist)
        local newPos = pos + diff.Unit * step
        local lookAt = faceTarget and Vector3.new(target.X, newPos.Y, target.Z) or (newPos + diff.Unit)

        pcall(function()
            HRP.CFrame = CFrame.new(newPos, lookAt)
            HRP.AssemblyLinearVelocity  = Vector3.zero
            HRP.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

task.spawn(function()
    while task.wait(0.3) do
        if not CFG.AutoConvert then continue end
        if not CFG.HivePos then continue end
        if _converting then continue end
        if not alive() then continue end
        if getPollen() < CFG.ConvertPollen then continue end

        _converting = true
        debugLog("Convert START — pollen: " .. ("%.1f%%"):format(getPollen()))
        setStatus("● конвертация → улей")

        setNoclip(true)
        flyTo(CFG.HivePos, CFG.ConvertSpeed, true)

        -- Нажимаем E один раз (сдать пыльцу)
        task.wait(0.1)
        pcall(function()
            VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
            task.wait(0.15)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)

        -- Ждём завершения конвертации (настраивается слайдером)
        setStatus("● сдаю пыльцу...")
        task.wait(CFG.ConvertWait)

        -- Возврат на поле
        if CFG.FieldPos and alive() then
            setStatus("● возврат на поле")
            flyTo(CFG.FieldPos, CFG.ConvertSpeed, true)
        end
        setNoclip(false)

        _converting = false
        debugLog("Convert END")
        setStatus(CFG.AutoFarm and "● Farming..." or "● Idle")
    end
end)

-- ── 5. SMART FARM — Токены > Змейка (Heartbeat + CFrame) ──
do
    local snakeDir   = 1
    local snakeRow   = 0
    local targetPos  = nil
    local prevActive = false

    -- состояние погони за токеном
    local chaseToken  = nil    -- BasePart токена
    local chaseStart  = 0      -- os.clock() начала погони
    local lastScan    = 0      -- троттлинг сканирования
    local lastDBSave  = os.clock()

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
        end
        targetPos = buildTarget()
    end

    local function onTokenCollected(part)
        local id = classifyToken(part)
        local entry = TokenDB[id]
        if entry then entry.count = entry.count + 1 end
        TokenStats.collected = TokenStats.collected + 1
        pcall(function()
            TokenStatsPara:Set({
                Title = "Собрано за сессию",
                Content = TokenStats.collected .. " токенов | последний: "
                    .. (entry and entry.name or "?"),
            })
        end)
    end

    -- шаг движения по XZ к точке; возвращает оставшуюся дистанцию
    local function stepTowards(dest, dt)
        local myPos = HRP.Position
        local dx, dz = dest.X - myPos.X, dest.Z - myPos.Z
        local dist = math.sqrt(dx * dx + dz * dz)
        if dist < 0.5 then return dist end

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
        return dist - step
    end

    RunService.Heartbeat:Connect(function(dt)
        if not CFG.AutoFarm or _converting then
            if prevActive then
                prevActive = false
                targetPos  = nil
                chaseToken = nil
            end
            return
        end
        if not alive() or not CFG.FieldPos then return end

        if not prevActive then
            snakeRow   = 0
            snakeDir   = 1
            targetPos  = buildTarget()
            prevActive = true
        end

        local now = os.clock()

        -- автосохранение базы токенов раз в 60 сек
        if now - lastDBSave > 60 then
            lastDBSave = now
            saveTokenDB()
        end

        -- ── Режим 1: погоня за токеном ──
        if CFG.TokenFarm then
            -- проверяем текущую цель
            if chaseToken then
                if not chaseToken.Parent then
                    -- токен исчез = собран (или истёк)
                    onTokenCollected(chaseToken)
                    chaseToken = nil
                elseif now - chaseStart > CFG.TokenTimeout then
                    -- не смогли дойти — в blacklist на 10 сек
                    _tokenBlacklist[chaseToken] = now + 10
                    debugLog("⏱ Токен недостижим, blacklist")
                    chaseToken = nil
                end
            end

            -- ищем новую цель (скан не чаще 4 раз/сек)
            if not chaseToken and now - lastScan > 0.25 then
                lastScan = now
                local best = findBestToken()
                if best then
                    chaseToken = best
                    chaseStart = now
                end
            end

            if chaseToken then
                setStatus("● Farming → токен")
                stepTowards(chaseToken.Position, dt)
                return -- токены в приоритете над змейкой
            end
        end

        -- ── Режим 2: змейка (fallback, когда токенов нет) ──
        if not targetPos then return end
        setStatus("● Farming (snake)")

        local remaining = stepTowards(targetPos, dt)
        if remaining < 2 then
            nextRow()
        end
    end)
end

-- ════════════════════════════════════════════════════
debugLog("✅ v17 загружен — Smart Farm (токены) + Convert + SpeedHack + AntiAFK + Persist")
debugLog("Collectibles folder: " .. tostring(getCollectiblesFolder() ~= nil))
for name, remote in pairs(R) do
    debugLog("  " .. name .. " = " .. tostring(remote ~= nil))
end
