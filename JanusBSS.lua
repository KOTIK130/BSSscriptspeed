-- ============================================================
--   JanusBSS AutoFarm v14.0  |  Smart Roam AI + Debug Log
-- ============================================================

-- ╔══════════════════════════════════════════════════════════╗
-- ║                    КОНФИГИ (CONFIG)                      ║
-- ╚══════════════════════════════════════════════════════════╝

local DEFAULT_FIELD   = "Sunflower Field"
local DEFAULT_PATTERN = "Snake"   -- "Snake" | "Roam"
local ROUTE_FILE      = "JanusBSS_FieldRoutes.json"

-- Интервалы (секунды)
local FARM_INTERVAL         = 0.08   -- главный тик фарма
local TARGET_SCAN_INTERVAL  = 0.20   -- как часто искать токены
local MOVE_COMMAND_INTERVAL = 0.18   -- минимум между MoveTo
local DIG_INTERVAL          = 0.12   -- интервал авто-копания
local PLANTER_MIN_WAIT      = 2.0    -- мин. пауза плантера
local PLANTER_MAX_WAIT      = 3.0    -- макс. пауза плантера

-- Расстояния
local PATROL_REACH_DISTANCE = 4      -- точка патруля достигнута
local TOKEN_REACH_DISTANCE  = 3.5    -- токен подобран
local FIELD_REENTER_PADDING = 3      -- отступ выхода из поля
local CLUSTER_RADIUS        = 10     -- радиус кластера токенов

-- Застревание
local STUCK_TIMEOUT         = 3.5    -- сек без движения → застрял
local STUCK_MIN_MOVE        = 0.6    -- studs — мин. движение

-- Roam AI
local ROAM_CELL_SIZE        = 12     -- размер ячейки heat-map (studs)
local ROAM_HEAT_DECAY       = 0.85   -- множитель остывания (за визит)
local ROAM_WANDER_BIAS      = 0.35   -- вес случайности vs холодной ячейки
local ROAM_RESCAN_DIST      = 3.0    -- ближе этого → выбрать новую цель
local ROAM_BOUNDARY_MARGIN  = 5      -- отступ от края поля для wandering

-- Авто-конвертация (улей)
local HIVE_WAIT_MIN         = 5.0
local HIVE_WAIT_MAX         = 7.0
local POLLEN_CHECK_INTERVAL = 1.0

-- Прочее
local TELEPORT_HEIGHT       = 3
local MAX_LOG_LINES         = 80     -- макс. строк в дебаг-логе

-- ============================================================
--   Сервисы
-- ============================================================

local Rayfield    = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local VIM         = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer

-- ============================================================
--   Поля BSS
-- ============================================================

local Fields = {
    ["Dandelion Field"]    = { center = Vector3.new(-43,   4,  220), size = Vector3.new(70, 8, 70) },
    ["Sunflower Field"]    = { center = Vector3.new(-209,  4, -186), size = Vector3.new(70, 8, 70) },
    ["Mushroom Field"]     = { center = Vector3.new(-220,  4,  116), size = Vector3.new(70, 8, 70) },
    ["Blue Flower Field"]  = { center = Vector3.new( 115,  4,  100), size = Vector3.new(70, 8, 70) },
    ["Clover Field"]       = { center = Vector3.new( 175, 34,  190), size = Vector3.new(70, 8, 70) },
    ["Spider Field"]       = { center = Vector3.new( -38, 20,   -5), size = Vector3.new(70, 8, 70) },
    ["Strawberry Field"]   = { center = Vector3.new(-170, 20,   -3), size = Vector3.new(70, 8, 70) },
    ["Bamboo Field"]       = { center = Vector3.new(  93, 20,  -48), size = Vector3.new(70, 8, 70) },
    ["Pineapple Patch"]    = { center = Vector3.new( 262, 20,  -42), size = Vector3.new(70, 8, 70) },
    ["Stump Field"]        = { center = Vector3.new( 421, 97, -174), size = Vector3.new(78, 8, 78) },
    ["Cactus Field"]       = { center = Vector3.new(-194, 69, -107), size = Vector3.new(70, 8, 70) },
    ["Pumpkin Patch"]      = { center = Vector3.new(-194, 69, -182), size = Vector3.new(70, 8, 70) },
    ["Pine Tree Forest"]   = { center = Vector3.new(-318, 69, -150), size = Vector3.new(80, 8, 80) },
    ["Rose Field"]         = { center = Vector3.new(-322, 20,  124), size = Vector3.new(70, 8, 70) },
    ["Mountain Top Field"] = { center = Vector3.new(  76,228, -122), size = Vector3.new(85, 8, 85) },
    ["Coconut Field"]      = { center = Vector3.new(-255, 72,  464), size = Vector3.new(95, 8, 95) },
    ["Pepper Patch"]       = { center = Vector3.new( 477,115,   22), size = Vector3.new(80, 8, 80) },
}

local FieldNames = {}
for name in pairs(Fields) do FieldNames[#FieldNames + 1] = name end
table.sort(FieldNames)

local PatternNames = { "Snake", "Roam" }

-- ============================================================
--   Флаги
-- ============================================================

local Flags = {
    AutoFarm    = false,
    AutoDig     = false,
    EnableSpeed = false,
    AutoPlanter = false,
    AutoHive    = false,
    DebugLog    = false,
    Speed       = 35,
}

local SelectedField   = DEFAULT_FIELD
local SelectedSlot    = "1"
local SelectedPattern = DEFAULT_PATTERN

-- ============================================================
--   Хранилище маршрутов + улей
-- ============================================================

local RouteStore = { routes = {}, hivePoint = nil }

local function serializeV3(p)
    return { x = math.floor(p.X*100)/100, y = math.floor(p.Y*100)/100, z = math.floor(p.Z*100)/100 }
end

local function deserializeV3(d)
    if type(d) ~= "table" then return nil end
    if type(d.x) ~= "number" or type(d.y) ~= "number" or type(d.z) ~= "number" then return nil end
    return Vector3.new(d.x, d.y, d.z)
end

local function loadRouteStore()
    if not readfile or not isfile or not isfile(ROUTE_FILE) then return end
    local ok, raw = pcall(readfile, ROUTE_FILE)
    if not ok or type(raw) ~= "string" or raw == "" then return end
    local dok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if dok and type(decoded) == "table" then
        RouteStore = decoded
        RouteStore.routes = RouteStore.routes or {}
    end
end

local function saveRouteStore()
    if not writefile then return end
    pcall(function() writefile(ROUTE_FILE, HttpService:JSONEncode(RouteStore)) end)
end

local HivePoint = nil

local function loadHivePoint()
    if RouteStore.hivePoint then
        HivePoint = deserializeV3(RouteStore.hivePoint)
    end
end

local function saveHivePoint(pos)
    HivePoint = pos
    RouteStore.hivePoint = serializeV3(pos)
    saveRouteStore()
end

-- ============================================================
--   Дебаг-лог
-- ============================================================

local logLines     = {}
local logLabel     = nil   -- Rayfield Label на вкладке Debug

local function dbg(msg)
    if not Flags.DebugLog then return end
    local line = ("[%.2f] %s"):format(time() % 1000, msg)
    table.insert(logLines, line)
    if #logLines > MAX_LOG_LINES then
        table.remove(logLines, 1)
    end
    -- Обновляем лейбл последними 6 строками (Rayfield ограничен)
    if logLabel then
        local tail = {}
        local start = math.max(1, #logLines - 5)
        for i = start, #logLines do tail[#tail+1] = logLines[i] end
        pcall(function() logLabel:Set(table.concat(tail, "\n")) end)
    end
    print(line)  -- всегда в output для копирования
end

local function getFullLog()
    return table.concat(logLines, "\n")
end

-- ============================================================
--   Утилиты
-- ============================================================

local function getCharParts()
    local char = Player.Character
    if not char then return nil, nil, nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return char, nil, nil end
    return char, hum, root
end

local function getField()     return Fields[SelectedField] or Fields[DEFAULT_FIELD] end
local function fieldCenter(f) return f.center + Vector3.new(0, TELEPORT_HEIGHT, 0) end

local function hDist(a, b)
    return Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
end

local function insideField(field, pos, padding)
    local pad = padding or 0
    local hx  = math.max(field.size.X * 0.5 - pad, 1)
    local hz  = math.max(field.size.Z * 0.5 - pad, 1)
    local off = pos - field.center
    return math.abs(off.X) <= hx and math.abs(off.Z) <= hz
end

-- Зажать позицию внутри поля
local function clampToField(field, pos, margin)
    local m  = margin or 0
    local hx = field.size.X * 0.5 - m
    local hz = field.size.Z * 0.5 - m
    local ox = math.max(-hx, math.min(hx, pos.X - field.center.X))
    local oz = math.max(-hz, math.min(hz, pos.Z - field.center.Z))
    return Vector3.new(field.center.X + ox, pos.Y, field.center.Z + oz)
end

local function teleportTo(root, pos)
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.new(pos.X, pos.Y, pos.Z)
    end)
end

local function pressE()
    VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- ============================================================
--   Пыльца — определение заполненности
-- ============================================================

local function getPollenStats()
    local statsFolder = Player:FindFirstChild("Stats")
        or Player:FindFirstChild("Data")
        or (Player.Character and Player.Character:FindFirstChild("Stats"))
    if not statsFolder then return nil, nil end
    local cur = statsFolder:FindFirstChild("Pollen") or statsFolder:FindFirstChild("CurrentPollen")
    local max = statsFolder:FindFirstChild("MaxPollen") or statsFolder:FindFirstChild("PollenCapacity") or statsFolder:FindFirstChild("Capacity")
    if cur and max then return cur.Value, max.Value end
    return nil, nil
end

local function getPollenFromGui()
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return nil, nil end
    for _, obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextBox")) then
            local txt = obj.Text or ""
            if txt:find("Pollen") or obj.Name:lower():find("pollen") then
                local cur, max = txt:match("(%d[%d,]*)/(%d[%d,]*)")
                if cur and max then
                    cur = tonumber(cur:gsub(",",""))
                    max = tonumber(max:gsub(",",""))
                    if cur and max then return cur, max end
                end
            end
        end
    end
    return nil, nil
end

local function isBackpackFull()
    local cur, max = getPollenStats()
    if cur and max and max > 0 then return cur >= max * 0.99 end
    cur, max = getPollenFromGui()
    if cur and max and max > 0 then return cur >= max * 0.99 end
    return false
end

-- ============================================================
--   Snake-паттерн (оставлен)
-- ============================================================

local patrolPoints    = nil
local patrolIndex     = 1
local activeSignature = nil

local function pathSig() return SelectedField .. "::Snake" end

local function invalidatePath()
    patrolPoints    = nil
    patrolIndex     = 1
    activeSignature = nil
end

local function buildSnake(field)
    local pts   = {}
    local c     = field.center
    local hx    = math.max(field.size.X * 0.38, 12)
    local hz    = math.max(field.size.Z * 0.38, 12)
    local rows  = field.size.Z >= 90 and 6 or 5
    pts[#pts+1] = c
    for row = 1, rows do
        local alpha = rows == 1 and 0 or (row-1)/(rows-1)
        local z = -hz + hz * 2 * alpha
        local L = c + Vector3.new(-hx, 0, z)
        local R = c + Vector3.new( hx, 0, z)
        if row % 2 == 1 then pts[#pts+1]=L; pts[#pts+1]=R
        else                 pts[#pts+1]=R; pts[#pts+1]=L end
    end
    pts[#pts+1] = c
    return pts
end

local function getOrBuildSnake(field)
    local sig = pathSig()
    if activeSignature ~= sig or not patrolPoints then
        activeSignature = sig
        patrolPoints    = buildSnake(field)
        patrolIndex     = 1
        dbg(("Snake: %d точек"):format(#patrolPoints))
    end
    return patrolPoints
end

local function nextSnakePoint(field)
    local pts   = getOrBuildSnake(field)
    patrolIndex = (patrolIndex % #pts) + 1
    return pts[patrolIndex]
end

-- ============================================================
--   Roam AI — Heat-map блуждание
-- ============================================================
--  Идея:
--  • Поле делится на ячейки ROAM_CELL_SIZE × ROAM_CELL_SIZE
--  • Каждая ячейка имеет «температуру» (heat): 1.0 = никогда не посещалась
--  • При посещении ячейки heat *= ROAM_HEAT_DECAY  → она «остывает»
--  • Следующая цель выбирается: 65% — самая холодная ячейка рядом с токеном
--                                35% — случайная точка в поле
--  • Если токенов нет — идём в наименее посещённую зону
-- ============================================================

local RoamState = {
    heatMap   = {},   -- [cellKey] = 0..1
    target    = nil,  -- Vector3
    lastCellX = nil,
    lastCellZ = nil,
}

local function cellKey(cx, cz) return cx .. "," .. cz end

local function worldToCell(field, pos)
    local ox = pos.X - (field.center.X - field.size.X * 0.5)
    local oz = pos.Z - (field.center.Z - field.size.Z * 0.5)
    local cx = math.floor(ox / ROAM_CELL_SIZE)
    local cz = math.floor(oz / ROAM_CELL_SIZE)
    return cx, cz
end

local function cellToWorld(field, cx, cz)
    local x = field.center.X - field.size.X * 0.5 + (cx + 0.5) * ROAM_CELL_SIZE
    local z = field.center.Z - field.size.Z * 0.5 + (cz + 0.5) * ROAM_CELL_SIZE
    return Vector3.new(x, field.center.Y + TELEPORT_HEIGHT, z)
end

local function getCellsCount(field)
    local nx = math.ceil(field.size.X / ROAM_CELL_SIZE)
    local nz = math.ceil(field.size.Z / ROAM_CELL_SIZE)
    return nx, nz
end

local function initHeatMap(field)
    RoamState.heatMap = {}
    local nx, nz = getCellsCount(field)
    for cx = 0, nx-1 do
        for cz = 0, nz-1 do
            RoamState.heatMap[cellKey(cx, cz)] = 1.0
        end
    end
    dbg(("HeatMap: %dx%d ячеек"):format(nx, nz))
end

local function getHeat(cx, cz)
    return RoamState.heatMap[cellKey(cx, cz)] or 1.0
end

local function visitCell(field, pos)
    local cx, cz = worldToCell(field, pos)
    local key = cellKey(cx, cz)
    local old = RoamState.heatMap[key] or 1.0
    RoamState.heatMap[key] = old * ROAM_HEAT_DECAY
    if cx ~= RoamState.lastCellX or cz ~= RoamState.lastCellZ then
        dbg(("Roam: ячейка [%d,%d] heat=%.2f→%.2f"):format(cx, cz, old, RoamState.heatMap[key]))
        RoamState.lastCellX = cx
        RoamState.lastCellZ = cz
    end
end

-- Найти лучшую ячейку (макс. heat = наименее посещённая)
local function coldestCell(field, nearPos, radius)
    local nx, nz = getCellsCount(field)
    local bestKey, bestHeat, bestCX, bestCZ = nil, -1, 0, 0
    for cx = 0, nx-1 do
        for cz = 0, nz-1 do
            local wp = cellToWorld(field, cx, cz)
            if not nearPos or hDist(nearPos, wp) <= radius then
                local h = getHeat(cx, cz)
                if h > bestHeat then
                    bestHeat = h
                    bestKey  = cellKey(cx, cz)
                    bestCX, bestCZ = cx, cz
                end
            end
        end
    end
    return bestCX, bestCZ, bestHeat
end

-- Случайная точка строго внутри поля
local function randomInField(field)
    local margin = ROAM_BOUNDARY_MARGIN
    local hx = field.size.X * 0.5 - margin
    local hz = field.size.Z * 0.5 - margin
    if hx < 2 then hx = 2 end
    if hz < 2 then hz = 2 end
    local x = field.center.X + (math.random() * 2 - 1) * hx
    local z = field.center.Z + (math.random() * 2 - 1) * hz
    return Vector3.new(x, field.center.Y + TELEPORT_HEIGHT, z)
end

-- Выбрать следующую Roam-цель
-- Приоритет: токены → холодная ячейка → случайная точка
local function roamPickTarget(field, root, tokens)
    -- Если есть токены — идём к ближайшей холодной ячейке рядом с ними
    if tokens and #tokens > 0 then
        -- Берём лучший токен (первый в списке, он уже отсортирован снаружи)
        local tok = tokens[1]
        local cx, cz, heat = coldestCell(field, tok.Position, ROAM_CELL_SIZE * 2.5)
        local wp = cellToWorld(field, cx, cz)
        wp = clampToField(field, wp, ROAM_BOUNDARY_MARGIN)
        dbg(("Roam→токен: ячейка[%d,%d] heat=%.2f"):format(cx, cz, heat))
        return wp
    end

    -- Нет токенов: случайность vs холодная ячейка
    if math.random() < ROAM_WANDER_BIAS then
        local pt = randomInField(field)
        dbg("Roam→рандом")
        return pt
    else
        local cx, cz, heat = coldestCell(field, nil, nil)
        local wp = cellToWorld(field, cx, cz)
        wp = clampToField(field, wp, ROAM_BOUNDARY_MARGIN)
        dbg(("Roam→холодная [%d,%d] heat=%.2f"):format(cx, cz, heat))
        return wp
    end
end

local function resetRoam(field)
    initHeatMap(field)
    RoamState.target    = nil
    RoamState.lastCellX = nil
    RoamState.lastCellZ = nil
end

-- ============================================================
--   Состояние фарма
-- ============================================================

local currentToken   = nil
local currentTarget  = nil
-- mode: "idle" | "snake_patrol" | "snake_token" | "roam" | "hive"
local currentMode    = "idle"
local lastTargetScan = 0
local lastProgressAt = 0
local lastRootPos    = nil
local lastMoveAt     = 0
local lastMoveDest   = nil
local isDoingHiveRun = false
local statusLabel    = nil

local function setStatus(txt)
    if statusLabel then pcall(function() statusLabel:Set("Статус: " .. txt) end) end
end

local function clearFarmState()
    currentToken   = nil
    currentTarget  = nil
    currentMode    = "idle"
    lastTargetScan = 0
    lastProgressAt = 0
    lastRootPos    = nil
    lastMoveAt     = 0
    lastMoveDest   = nil
    isDoingHiveRun = false
    invalidatePath()
    RoamState.target = nil
    setStatus("Остановлен")
    dbg("=== clearFarmState ===")
end

-- ============================================================
--   Движение
-- ============================================================

local function issueMove(hum, root, dest, force)
    local flat = Vector3.new(dest.X, root.Position.Y, dest.Z)
    local ok = force
        or not lastMoveDest
        or hDist(lastMoveDest, flat) >= 2
        or (time() - lastMoveAt) >= MOVE_COMMAND_INTERVAL
    if ok then
        hum:MoveTo(flat)
        lastMoveDest = flat
        lastMoveAt   = time()
    end
end

local function updateProgress(root, now)
    if not lastRootPos then
        lastRootPos    = root.Position
        lastProgressAt = now
        return
    end
    if hDist(root.Position, lastRootPos) >= STUCK_MIN_MOVE then
        lastProgressAt = now
        lastRootPos    = root.Position
    end
end

local function isStuck(now)
    return (now - lastProgressAt) >= STUCK_TIMEOUT
end

-- ============================================================
--   Токены (общие)
-- ============================================================

local function tokenTex(t)
    local d = t:FindFirstChild("FrontDecal") or t:FindFirstChildWhichIsA("Decal")
    if d and typeof(d.Texture) == "string" then return string.lower(d.Texture) end
    return ""
end

local function isCocoOrCombo(t)
    local tx = tokenTex(t)
    return t.Name == "C" or tx:find("coconut",1,true) or tx:find("combo",1,true)
end

local function tokenOwned(t)
    if t.Name == Player.Name then return true end
    local ow = t:FindFirstChild("Owner")
    if ow then
        if ow:IsA("ObjectValue") then return ow.Value == Player end
        if ow:IsA("StringValue") then return ow.Value == Player.Name end
    end
    local pn = t:FindFirstChild("PlayerName")
    if pn and pn:IsA("StringValue") then return pn.Value == Player.Name end
    return nil
end

local function isAllowed(t, field)
    if not t or not t.Parent or not t:IsA("BasePart") then return false end
    if not insideField(field, t.Position, 0) then return false end
    if isCocoOrCombo(t) then return true end
    local owned = tokenOwned(t)
    return owned == nil or owned
end

local function tokenPrio(t)
    if isCocoOrCombo(t) then return 150 end
    local tx = tokenTex(t)
    if tx:find("mythic",1,true) then return 95 end
    if tx:find("rare",  1,true) then return 55 end
    return 15
end

local function scoreToken(t, rootPos, all)
    local dist    = hDist(t.Position, rootPos)
    local cluster = 0
    for _, other in ipairs(all) do
        if other ~= t and hDist(other.Position, t.Position) <= CLUSTER_RADIUS then
            cluster = cluster + 1
        end
    end
    return tokenPrio(t) - dist * 0.75 + cluster * 4
end

-- Возвращает отсортированный список токенов (лучший первый)
local function getTokensSorted(root, field)
    local col = workspace:FindFirstChild("Collectibles")
    if not col then return {} end
    local allowed = {}
    for _, t in ipairs(col:GetChildren()) do
        if isAllowed(t, field) then allowed[#allowed+1] = t end
    end
    if #allowed == 0 then return {} end
    table.sort(allowed, function(a, b)
        local sa = scoreToken(a, root.Position, allowed)
        local sb = scoreToken(b, root.Position, allowed)
        if a == currentToken then sa = sa + 10 end
        if b == currentToken then sb = sb + 10 end
        return sa > sb
    end)
    return allowed
end

local function tokenValid(field)
    return currentToken
        and currentToken.Parent
        and currentToken:IsA("BasePart")
        and insideField(field, currentToken.Position, 0)
end

-- ============================================================
--   Вспомогалки фарма
-- ============================================================

local function resetToField(root, hum)
    local field = getField()
    invalidatePath()
    if SelectedPattern == "Roam" then resetRoam(field) end
    currentToken   = nil
    currentMode    = SelectedPattern == "Roam" and "roam" or "snake_patrol"
    currentTarget  = field.center
    teleportTo(root, fieldCenter(field))
    lastRootPos    = root.Position
    lastProgressAt = time()
    issueMove(hum, root, currentTarget, true)
    setStatus("Телепорт → " .. SelectedField)
    dbg("resetToField → " .. SelectedField .. " mode=" .. currentMode)
end

local function checkField(root, hum, field)
    if not insideField(field, root.Position, FIELD_REENTER_PADDING) then
        dbg("Вышел за пределы поля — телепорт обратно")
        resetToField(root, hum)
        return true
    end
    return false
end

-- ============================================================
--   Авто-конвертация (Hive Run)
-- ============================================================

local returnPosition = nil

local function doHiveRun()
    if isDoingHiveRun then return end
    if not HivePoint then
        setStatus("⚠ Точка улья не сохранена!")
        dbg("doHiveRun: HivePoint не установлен")
        return
    end
    isDoingHiveRun = true
    dbg("=== Hive Run START ===")
    setStatus("🍯 Едем к улью...")

    local _, hum, root = getCharParts()
    if not hum or not root then isDoingHiveRun = false; return end

    returnPosition = fieldCenter(getField())
    teleportTo(root, HivePoint)
    task.wait(0.3)

    setStatus("🍯 Конвертируем...")
    pressE()
    dbg("Hive: нажали E")

    local waitTime = HIVE_WAIT_MIN + math.random() * (HIVE_WAIT_MAX - HIVE_WAIT_MIN)
    for i = math.ceil(waitTime), 1, -1 do
        setStatus(("🍯 Конвертация... %dс"):format(i))
        task.wait(1)
    end

    setStatus("🔄 Возврат на поле...")
    _, hum, root = getCharParts()
    if hum and root then
        teleportTo(root, returnPosition or fieldCenter(getField()))
        task.wait(0.3)
        lastProgressAt = time()
        lastRootPos    = root.Position
        invalidatePath()
        if SelectedPattern == "Roam" then
            local field = getField()
            RoamState.target = nil
            currentMode = "roam"
        else
            currentMode = "snake_patrol"
        end
        currentToken  = nil
        currentTarget = getField().center
        issueMove(hum, root, currentTarget, true)
    end

    isDoingHiveRun = false
    dbg("=== Hive Run END ===")
    setStatus("▶ Фарм продолжается")
    Rayfield:Notify({ Title="Auto Hive", Content="Мёд сконвертирован! Возвращаемся.", Duration=3 })
end

-- ============================================================
--   Загрузка
-- ============================================================

loadRouteStore()
loadHivePoint()

-- ============================================================
--   Основной цикл фарма
-- ============================================================

task.spawn(function()
    while true do
        task.wait(FARM_INTERVAL)
        if not Flags.AutoFarm or isDoingHiveRun then continue end

        local _, hum, root = getCharParts()
        if not hum or not root then clearFarmState(); continue end

        hum.WalkSpeed  = Flags.EnableSpeed and Flags.Speed or 16
        hum.AutoRotate = true

        local field = getField()
        local now   = time()

        updateProgress(root, now)

        if checkField(root, hum, field) then continue end

        -- ── РЕЖИМ: SNAKE ────────────────────────────────────────
        if SelectedPattern == "Snake" then

            if currentMode ~= "snake_patrol" and currentMode ~= "snake_token" then
                currentMode   = "snake_patrol"
                currentTarget = nextSnakePoint(field)
            end

            -- Периодический поиск токенов
            if now - lastTargetScan >= TARGET_SCAN_INTERVAL then
                lastTargetScan = now
                local tokens = getTokensSorted(root, field)
                if #tokens > 0 then
                    currentToken  = tokens[1]
                    currentTarget = currentToken.Position
                    currentMode   = "snake_token"
                    dbg(("Snake→токен %s dist=%.1f"):format(currentToken.Name, hDist(root.Position, currentTarget)))
                elseif currentMode == "snake_token" then
                    currentMode   = "snake_patrol"
                    currentTarget = nextSnakePoint(field)
                    dbg("Snake: нет токенов → патруль")
                end
            end

            -- Проверяем жив ли текущий токен
            if currentMode == "snake_token" and not tokenValid(field) then
                currentToken  = nil
                currentMode   = "snake_patrol"
                currentTarget = nextSnakePoint(field)
                dbg("Snake: токен исчез → патруль")
            end

            -- Движение
            if currentMode == "snake_token" and currentTarget then
                local dist = hDist(root.Position, currentTarget)
                if dist <= TOKEN_REACH_DISTANCE then
                    dbg("Snake: токен подобран")
                    currentToken  = nil
                    currentMode   = "snake_patrol"
                    currentTarget = nextSnakePoint(field)
                    issueMove(hum, root, currentTarget, true)
                elseif isStuck(now) then
                    dbg("Snake: застрял на токене → пропускаем")
                    currentToken   = nil
                    lastProgressAt = now
                    currentMode    = "snake_patrol"
                    currentTarget  = nextSnakePoint(field)
                    issueMove(hum, root, currentTarget, true)
                else
                    issueMove(hum, root, currentTarget, false)
                end

            elseif currentMode == "snake_patrol" and currentTarget then
                local dist = hDist(root.Position, currentTarget)
                if dist <= PATROL_REACH_DISTANCE then
                    currentTarget = nextSnakePoint(field)
                    issueMove(hum, root, currentTarget, true)
                elseif isStuck(now) then
                    dbg("Snake: застрял в патруле → след. точка")
                    currentTarget  = nextSnakePoint(field)
                    lastProgressAt = now
                    issueMove(hum, root, currentTarget, true)
                else
                    issueMove(hum, root, currentTarget, false)
                end
            else
                currentMode   = "snake_patrol"
                currentTarget = nextSnakePoint(field)
                issueMove(hum, root, currentTarget, true)
            end

        -- ── РЕЖИМ: ROAM AI ──────────────────────────────────────
        elseif SelectedPattern == "Roam" then

            if currentMode ~= "roam" then
                currentMode = "roam"
                resetRoam(field)
                dbg("Переключились в Roam")
            end

            -- Обновляем тепловую карту по текущей позиции
            visitCell(field, root.Position)

            -- Периодический поиск токенов
            local tokens = {}
            if now - lastTargetScan >= TARGET_SCAN_INTERVAL then
                lastTargetScan = now
                tokens = getTokensSorted(root, field)
                dbg(("Roam: найдено токенов=%d"):format(#tokens))

                if #tokens > 0 then
                    -- Если лучший токен ближе текущей цели — переключиться
                    local bestTok  = tokens[1]
                    local distTok  = hDist(root.Position, bestTok.Position)
                    local distCurr = currentTarget and hDist(root.Position, currentTarget) or math.huge

                    if bestTok ~= currentToken or not RoamState.target then
                        currentToken    = bestTok
                        RoamState.target = roamPickTarget(field, root, tokens)
                        currentTarget   = RoamState.target
                        dbg(("Roam: новая цель с токеном dist=%.1f"):format(distTok))
                    end
                else
                    -- Нет токенов → идём в холодную зону
                    currentToken     = nil
                    RoamState.target = roamPickTarget(field, root, {})
                    currentTarget    = RoamState.target
                end
            end

            -- Проверяем текущий токен
            if currentToken and not tokenValid(field) then
                dbg("Roam: токен исчез")
                currentToken     = nil
                RoamState.target = roamPickTarget(field, root, {})
                currentTarget    = RoamState.target
            end

            -- Если нет цели — взять новую
            if not currentTarget then
                RoamState.target = roamPickTarget(field, root, {})
                currentTarget    = RoamState.target
            end

            -- Убеждаемся, что цель внутри поля
            if currentTarget then
                local clamped = clampToField(field, currentTarget, ROAM_BOUNDARY_MARGIN)
                if hDist(clamped, currentTarget) > 0.5 then
                    dbg("Roam: цель зажата внутрь поля")
                    currentTarget    = clamped
                    RoamState.target = clamped
                end
            end

            -- Движение
            if currentTarget then
                local dist = hDist(root.Position, currentTarget)

                -- Достигли цели-токена
                if currentToken and dist <= TOKEN_REACH_DISTANCE then
                    dbg("Roam: токен подобран")
                    currentToken     = nil
                    RoamState.target = roamPickTarget(field, root, {})
                    currentTarget    = RoamState.target
                    issueMove(hum, root, currentTarget, true)

                -- Достигли roam-точки
                elseif not currentToken and dist <= ROAM_RESCAN_DIST then
                    RoamState.target = roamPickTarget(field, root, {})
                    currentTarget    = RoamState.target
                    issueMove(hum, root, currentTarget, true)

                -- Застряли
                elseif isStuck(now) then
                    dbg(("Roam: застрял (%.1f studs за %.1f сек) → новая точка"):format(
                        hDist(root.Position, lastRootPos or root.Position),
                        now - lastProgressAt))
                    lastProgressAt   = now
                    lastRootPos      = root.Position
                    currentToken     = nil
                    RoamState.target = roamPickTarget(field, root, {})
                    currentTarget    = RoamState.target
                    issueMove(hum, root, currentTarget, true)

                else
                    issueMove(hum, root, currentTarget, false)
                end
            end
        end -- eof pattern
    end
end)

-- ============================================================
--   Авто-проверка пыльцы → Hive Run
-- ============================================================

task.spawn(function()
    while true do
        task.wait(POLLEN_CHECK_INTERVAL)
        if not Flags.AutoFarm or not Flags.AutoHive then continue end
        if isDoingHiveRun or not HivePoint then continue end
        if isBackpackFull() then
            dbg("Рюкзак полный → запуск Hive Run")
            task.spawn(doHiveRun)
        end
    end
end)

-- ============================================================
--   Auto Dig
-- ============================================================

task.spawn(function()
    while task.wait(DIG_INTERVAL) do
        if Flags.AutoDig and not isDoingHiveRun then
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        end
    end
end)

-- ============================================================
--   Auto Planter
-- ============================================================

task.spawn(function()
    local keyMap = {
        ["1"]=Enum.KeyCode.One,   ["2"]=Enum.KeyCode.Two,
        ["3"]=Enum.KeyCode.Three, ["4"]=Enum.KeyCode.Four,
        ["5"]=Enum.KeyCode.Five,  ["6"]=Enum.KeyCode.Six,
        ["7"]=Enum.KeyCode.Seven,
    }
    while true do
        task.wait(math.random(
            math.floor(PLANTER_MIN_WAIT*10),
            math.floor(PLANTER_MAX_WAIT*10)
        ) / 10)
        if Flags.AutoPlanter and not isDoingHiveRun then
            local kc = keyMap[SelectedSlot]
            if kc then
                VIM:SendKeyEvent(true,  kc, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, kc, false, game)
            end
        end
    end
end)

-- ============================================================
--   Enable Speed
-- ============================================================

RunService.Heartbeat:Connect(function()
    if not Flags.EnableSpeed then return end
    local _, hum = getCharParts()
    if hum then hum.WalkSpeed = Flags.Speed end
end)

-- ============================================================
--   UI (Rayfield)
-- ============================================================

local Window = Rayfield:CreateWindow({
    Name              = "AI FARM v14.0",
    LoadingTitle      = "JanusBSS",
    LoadingSubtitle   = "Roam AI + Debug",
    ConfigurationSaving = { Enabled = false },
})

-- ── Main Tab ───────────────────────────────────────────────

local MainTab = Window:CreateTab("Main", 4483362458)

statusLabel = MainTab:CreateLabel("Статус: Остановлен")

MainTab:CreateToggle({
    Name = "AI AutoFarm", CurrentValue = false,
    Callback = function(v)
        Flags.AutoFarm = v
        local _, hum, root = getCharParts()
        if not v then clearFarmState()
        elseif hum and root then resetToField(root, hum) end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Dig", CurrentValue = false,
    Callback = function(v) Flags.AutoDig = v end,
})

MainTab:CreateToggle({
    Name = "Enable Speed", CurrentValue = false,
    Callback = function(v) Flags.EnableSpeed = v end,
})

MainTab:CreateSlider({
    Name = "Walk Speed", Range = {10, 120}, Increment = 1, CurrentValue = 35,
    Callback = function(v) Flags.Speed = v end,
})

MainTab:CreateDropdown({
    Name = "Field", Options = FieldNames, CurrentOption = { DEFAULT_FIELD },
    Callback = function(opt)
        SelectedField = type(opt)=="table" and (opt[1] or DEFAULT_FIELD) or opt
        local _, hum, root = getCharParts()
        clearFarmState()
        if Flags.AutoFarm and hum and root then resetToField(root, hum) end
    end,
})

MainTab:CreateDropdown({
    Name = "Pattern", Options = PatternNames, CurrentOption = { DEFAULT_PATTERN },
    Callback = function(opt)
        SelectedPattern = type(opt)=="table" and (opt[1] or DEFAULT_PATTERN) or opt
        invalidatePath()
        local field = getField()
        if SelectedPattern == "Roam" then resetRoam(field) end
        local _, hum, root = getCharParts()
        if Flags.AutoFarm and hum and root then resetToField(root, hum) end
        dbg("Pattern → " .. SelectedPattern)
    end,
})

MainTab:CreateDropdown({
    Name = "Слот Плантера", Options = {"1","2","3","4","5","6","7"}, CurrentOption = {"1"},
    Callback = function(opt)
        SelectedSlot = type(opt)=="table" and (opt[1] or "1") or opt
    end,
})

MainTab:CreateToggle({
    Name = "Auto Planter", CurrentValue = false,
    Callback = function(v) Flags.AutoPlanter = v end,
})

MainTab:CreateButton({
    Name = "TP To Selected Field",
    Callback = function()
        local _, _, root = getCharParts()
        if root then teleportTo(root, fieldCenter(getField())) end
    end,
})

-- ── Hive Tab ───────────────────────────────────────────────

local HiveTab = Window:CreateTab("Hive 🍯", 4483362458)

HiveTab:CreateLabel("Авто-конвертация мёда в улей")

HiveTab:CreateToggle({
    Name = "Auto Hive Convert", CurrentValue = false,
    Callback = function(v)
        Flags.AutoHive = v
        if v and not HivePoint then
            Rayfield:Notify({ Title="Auto Hive", Content="Сохрани точку улья!", Duration=4 })
        end
    end,
})

HiveTab:CreateLabel("Встань у улья → нажми ↓")

HiveTab:CreateButton({
    Name = "💾 Сохранить точку улья",
    Callback = function()
        local _, _, root = getCharParts()
        if root then
            saveHivePoint(root.Position)
            dbg(("HivePoint сохранён: %.1f,%.1f,%.1f"):format(root.Position.X, root.Position.Y, root.Position.Z))
            Rayfield:Notify({
                Title   = "Hive Point",
                Content = ("Сохранено: %.1f, %.1f, %.1f"):format(root.Position.X, root.Position.Y, root.Position.Z),
                Duration = 3,
            })
        end
    end,
})

HiveTab:CreateButton({
    Name = "🧪 Тест — поехать к улью",
    Callback = function()
        if not HivePoint then
            Rayfield:Notify({ Title="Hive", Content="Точка не сохранена!", Duration=3 })
            return
        end
        task.spawn(doHiveRun)
    end,
})

HiveTab:CreateLabel(("Ожидание: %.0f–%.0f сек"):format(HIVE_WAIT_MIN, HIVE_WAIT_MAX))

-- ── Debug Tab ──────────────────────────────────────────────

local DebugTab = Window:CreateTab("Debug 🔍", 4483362458)

DebugTab:CreateToggle({
    Name = "Enable Debug Log", CurrentValue = false,
    Callback = function(v)
        Flags.DebugLog = v
        if v then dbg("=== Debug включён ===") end
    end,
})

DebugTab:CreateLabel("Последние события:")
logLabel = DebugTab:CreateLabel("(лог пуст)")

DebugTab:CreateButton({
    Name = "📋 Скопировать полный лог (print в Output)",
    Callback = function()
        print("=== FULL DEBUG LOG ===")
        print(getFullLog())
        print("=== END LOG ===")
        Rayfield:Notify({ Title="Debug", Content="Лог распечатан в Output!", Duration=3 })
    end,
})

DebugTab:CreateButton({
    Name = "🗑 Очистить лог",
    Callback = function()
        logLines = {}
        if logLabel then pcall(function() logLabel:Set("(лог очищен)") end) end
    end,
})

DebugTab:CreateButton({
    Name = "📊 Дамп состояния",
    Callback = function()
        local _, _, root = getCharParts()
        local pos = root and root.Position or Vector3.zero
        local field = getField()
        local inside = insideField(field, pos, 0)
        local cur, max = getPollenStats()
        if not cur then cur, max = getPollenFromGui() end

        local info = {
            ("Mode: %s"):format(currentMode),
            ("Pattern: %s"):format(SelectedPattern),
            ("Field: %s"):format(SelectedField),
            ("Pos: %.1f,%.1f,%.1f"):format(pos.X, pos.Y, pos.Z),
            ("Inside field: %s"):format(tostring(inside)),
            ("Token: %s"):format(currentToken and currentToken.Name or "nil"),
            ("Target: %s"):format(currentTarget and ("%.1f,%.1f,%.1f"):format(currentTarget.X, currentTarget.Y, currentTarget.Z) or "nil"),
            ("Stuck timer: %.1f"):format(time() - lastProgressAt),
            ("Pollen: %s/%s"):format(tostring(cur), tostring(max)),
            ("HivePoint: %s"):format(HivePoint and ("%.1f,%.1f,%.1f"):format(HivePoint.X, HivePoint.Y, HivePoint.Z) or "nil"),
            ("HiveRun: %s"):format(tostring(isDoingHiveRun)),
        }

        local dump = table.concat(info, " | ")
        dbg("DUMP: " .. dump)
        print("=== STATE DUMP ===\n" .. table.concat(info, "\n"))
        Rayfield:Notify({ Title="State Dump", Content="Распечатан в Output!", Duration=3 })
    end,
})

-- ============================================================
--   Сброс при смерти
-- ============================================================

Player.CharacterRemoving:Connect(function()
    isDoingHiveRun = false
    clearFarmState()
    dbg("CharacterRemoving → сброс")
end)
