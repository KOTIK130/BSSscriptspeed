-- ============================================================
--   JanusBSS AutoFarm v16.0  |  CFrame AI + Token Magnet
-- ============================================================

-- ╔══════════════════════════════════════════════════════════╗
-- ║                    КОНФИГИ (CONFIG)                      ║
-- ╚══════════════════════════════════════════════════════════╝

local DEFAULT_FIELD   = "Sunflower Field"
local DEFAULT_PATTERN = "Snake"   -- "Snake" | "Spiral" | "Roam"
local ROUTE_FILE      = "JanusBSS_FieldRoutes.json"

-- Интервалы (секунды)
local FARM_INTERVAL         = 0.05
local TOKEN_SCAN_INTERVAL   = 0.15
local TOKEN_MAGNET_INTERVAL = 0.08
local DIG_INTERVAL          = 0.10
local PLANTER_MIN_WAIT      = 0.6
local PLANTER_MAX_WAIT      = 1.0
local ANTI_AFK_INTERVAL     = 120

-- CFrame движение
local CFRAME_BASE_SPEED     = 28
local CFRAME_STEP_MAX       = 5

-- Расстояния
local PATROL_REACH_DIST     = 3
local TOKEN_REACH_DIST      = 3
local TOKEN_MAGNET_RADIUS   = 14
local FIELD_REENTER_PADDING = 5
local CLUSTER_RADIUS        = 10
local CLUSTER_MAX_CHECK     = 15

-- Застревание
local STUCK_TIMEOUT         = 2.5
local STUCK_MIN_MOVE        = 0.5

-- Roam AI
local ROAM_CELL_SIZE        = 10
local ROAM_HEAT_DECAY       = 0.80
local ROAM_HEAT_REGEN       = 0.03
local ROAM_HEAT_REGEN_INT   = 5
local ROAM_WANDER_BIAS      = 0.30
local ROAM_RESCAN_DIST      = 3.0
local ROAM_BOUNDARY_MARGIN  = 4

-- Улей
local HIVE_WAIT_MIN         = 7.0
local HIVE_WAIT_MAX         = 9.0
local HIVE_E_SPAM           = 1
local POLLEN_CHECK_INTERVAL = 1.0

-- Прочее
local TELEPORT_HEIGHT       = 8
local GROUND_RAY_DIST       = 60
local MAX_LOG_LINES         = 80

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
--   Поля BSS (ИСПРАВЛЕННЫЕ координаты)
-- ============================================================
-- center.Y = уровень земли. TELEPORT_HEIGHT добавляется при ТП,
-- затем рейкаст вниз находит реальную поверхность.

local Fields = {
    -- Starter Zone (Y ~ 3)
    ["Dandelion Field"]    = { center = Vector3.new( -43,   3,  220), size = Vector3.new(68, 10, 68) },
    ["Sunflower Field"]    = { center = Vector3.new(-209,   3, -186), size = Vector3.new(68, 10, 68) },
    ["Mushroom Field"]     = { center = Vector3.new(-220,   3,  116), size = Vector3.new(68, 10, 68) },
    ["Blue Flower Field"]  = { center = Vector3.new( 115,   3,  100), size = Vector3.new(68, 10, 68) },

    -- 5 Bee Zone (Y ~ 20)
    ["Clover Field"]       = { center = Vector3.new( 175,  34,  190), size = Vector3.new(68, 10, 68) },
    ["Spider Field"]       = { center = Vector3.new( -38,  20,   -5), size = Vector3.new(68, 10, 68) },
    ["Strawberry Field"]   = { center = Vector3.new(-170,  20,   -3), size = Vector3.new(68, 10, 68) },
    ["Bamboo Field"]       = { center = Vector3.new(  93,  20,  -48), size = Vector3.new(68, 10, 68) },
    ["Pineapple Patch"]    = { center = Vector3.new( 262,  20,  -42), size = Vector3.new(68, 10, 68) },
    ["Rose Field"]         = { center = Vector3.new(-322,  20,  124), size = Vector3.new(68, 10, 68) },

    -- 15 Bee Zone (Y ~ 68)
    ["Cactus Field"]       = { center = Vector3.new(-194,  68, -107), size = Vector3.new(68, 10, 68) },
    ["Pumpkin Patch"]      = { center = Vector3.new(-194,  68, -182), size = Vector3.new(68, 10, 68) },
    ["Pine Tree Forest"]   = { center = Vector3.new(-318,  68, -150), size = Vector3.new(78, 10, 78) },
    ["Stump Field"]        = { center = Vector3.new( 421,  96, -174), size = Vector3.new(76, 10, 76) },

    -- 25+ Bee Zone
    ["Mountain Top Field"] = { center = Vector3.new(  76, 227, -122), size = Vector3.new(82, 10, 82) },
    ["Coconut Field"]      = { center = Vector3.new(-255,  71,  464), size = Vector3.new(92, 10, 92) },
    ["Pepper Patch"]       = { center = Vector3.new( 477, 114,   22), size = Vector3.new(78, 10, 78) },
}

local FieldNames = {}
for name in pairs(Fields) do FieldNames[#FieldNames + 1] = name end
table.sort(FieldNames)

local PatternNames = { "Snake", "Spiral", "Roam" }

-- ============================================================
--   Флаги & Состояние
-- ============================================================

local Flags = {
    AutoFarm    = false,
    AutoDig     = false,
    CFrameSpeed = false,
    AutoPlanter = false,
    AutoHive    = false,
    AntiAFK     = true,
    TokenMagnet = true,
    DebugLog    = false,
    Speed       = 40,
}

local SelectedField   = DEFAULT_FIELD
local SelectedSlot    = "1"
local SelectedPattern = DEFAULT_PATTERN

local SessionStats = {
    startTime       = time(),
    tokensCollected = 0,
    hiveRuns        = 0,
    stuckCount      = 0,
}

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

local logLines = {}
local logLabel = nil

local function dbg(msg)
    if not Flags.DebugLog then return end
    local line = ("[%.2f] %s"):format(time() % 1000, msg)
    table.insert(logLines, line)
    if #logLines > MAX_LOG_LINES then
        table.remove(logLines, 1)
    end
    if logLabel then
        local tail = {}
        local start = math.max(1, #logLines - 5)
        for i = start, #logLines do tail[#tail+1] = logLines[i] end
        pcall(function() logLabel:Set(table.concat(tail, "\n")) end)
    end
    print(line)
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

local function getField()
    return Fields[SelectedField] or Fields[DEFAULT_FIELD]
end

local function hDist(a, b)
    local dx, dz = b.X - a.X, b.Z - a.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function insideField(field, pos, padding)
    local pad = padding or 0
    local hx  = math.max(field.size.X * 0.5 - pad, 1)
    local hz  = math.max(field.size.Z * 0.5 - pad, 1)
    local off = pos - field.center
    return math.abs(off.X) <= hx and math.abs(off.Z) <= hz
end

local function clampToField(field, pos, margin)
    local m  = margin or 0
    local hx = field.size.X * 0.5 - m
    local hz = field.size.Z * 0.5 - m
    local ox = math.clamp(pos.X - field.center.X, -hx, hx)
    local oz = math.clamp(pos.Z - field.center.Z, -hz, hz)
    return Vector3.new(field.center.X + ox, pos.Y, field.center.Z + oz)
end

-- ============================================================
--   Поиск земли (Raycast) — чтобы НЕ проваливаться
-- ============================================================

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist

local function findGround(pos)
    local char = Player.Character
    rayParams.FilterDescendantsInstances = char and {char} or {}
    local origin = Vector3.new(pos.X, pos.Y + 10, pos.Z)
    local result = workspace:Raycast(origin, Vector3.new(0, -GROUND_RAY_DIST, 0), rayParams)
    if result then
        return result.Position + Vector3.new(0, 3, 0)
    end
    return pos
end

local function fieldCenter(f)
    return findGround(f.center + Vector3.new(0, TELEPORT_HEIGHT, 0))
end

-- ============================================================
--   Телепорт & CFrame движение
-- ============================================================

local function teleportTo(root, pos)
    pcall(function()
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.new(pos)
    end)
end

-- CFrame шаг к цели. Возвращает true если достигли.
local function cframeStep(root, dest, speed, dt)
    local pos  = root.Position
    local flat = Vector3.new(dest.X, pos.Y, dest.Z)
    local diff = flat - pos
    local dist = diff.Magnitude

    if dist < 0.5 then return true end

    local step = math.min(speed * dt, dist, CFRAME_STEP_MAX)
    local dir  = diff.Unit
    local newPos = pos + dir * step
    local lookAt = pos + dir
    root.CFrame = CFrame.new(newPos, Vector3.new(lookAt.X, newPos.Y, lookAt.Z))
    root.AssemblyLinearVelocity  = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    return false
end

local function pressE(times)
    times = times or 1
    for _ = 1, times do
        VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.08)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        if times > 1 then task.wait(0.12) end
    end
end

-- ============================================================
--   Пыльца
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

local _cachedPollenLabel = nil
local _cachedPollenTime  = 0

local function getPollenFromGui()
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return nil, nil end
    if _cachedPollenLabel and (time() - _cachedPollenTime) < 10 then
        local ok, cur, max = pcall(function()
            local txt = _cachedPollenLabel.Text or ""
            local c, m = txt:match("(%d[%d,]*)/(%d[%d,]*)")
            if c and m then
                return tonumber(c:gsub(",","")), tonumber(m:gsub(",",""))
            end
            return nil, nil
        end)
        if ok and cur and max then return cur, max end
        _cachedPollenLabel = nil
    end
    for _, obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextBox")) then
            local txt = obj.Text or ""
            if txt:find("Pollen") or obj.Name:lower():find("pollen") then
                local cur, max = txt:match("(%d[%d,]*)/(%d[%d,]*)")
                if cur and max then
                    cur = tonumber(cur:gsub(",",""))
                    max = tonumber(max:gsub(",",""))
                    if cur and max then
                        _cachedPollenLabel = obj
                        _cachedPollenTime  = time()
                        return cur, max
                    end
                end
            end
        end
    end
    return nil, nil
end

local function isBackpackFull()
    local cur, max = getPollenStats()
    if cur and max and max > 0 then return cur >= max * 0.95 end
    cur, max = getPollenFromGui()
    if cur and max and max > 0 then return cur >= max * 0.95 end
    return false
end

-- ============================================================
--   Токены
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
    if tx:find("star",  1,true) then return 80 end
    if tx:find("rare",  1,true) then return 55 end
    if tx:find("honey", 1,true) then return 45 end
    if tx:find("treat", 1,true) then return 40 end
    return 15
end

local currentToken = nil

local function scoreToken(t, rootPos, all)
    local dist    = hDist(t.Position, rootPos)
    local cluster = 0
    local maxCheck = math.min(#all, CLUSTER_MAX_CHECK)
    for i = 1, maxCheck do
        local other = all[i]
        if other ~= t and hDist(other.Position, t.Position) <= CLUSTER_RADIUS then
            cluster = cluster + 1
        end
    end
    return tokenPrio(t) - dist * 0.8 + cluster * 4
end

local function getTokensSorted(root, field)
    local col = workspace:FindFirstChild("Collectibles")
    if not col then return {} end
    local allowed = {}
    for _, t in ipairs(col:GetChildren()) do
        if isAllowed(t, field) then allowed[#allowed+1] = t end
    end
    if #allowed == 0 then return {} end
    local scores = {}
    for _, t in ipairs(allowed) do
        scores[t] = scoreToken(t, root.Position, allowed)
        if t == currentToken then scores[t] = scores[t] + 10 end
    end
    table.sort(allowed, function(a, b)
        return (scores[a] or 0) > (scores[b] or 0)
    end)
    return allowed
end

local function tokenValid(field)
    if not currentToken then return false end
    local ok, result = pcall(function()
        return currentToken.Parent
            and currentToken.Parent.Name == "Collectibles"
            and currentToken:IsA("BasePart")
            and insideField(field, currentToken.Position, 0)
    end)
    return ok and result
end

-- ============================================================
--   Токен-магнит — мгновенный сбор ВСЕХ токенов в радиусе
-- ============================================================

local lastMagnetTime = 0

local function doTokenMagnet(root, field)
    local now = time()
    if now - lastMagnetTime < TOKEN_MAGNET_INTERVAL then return end
    if not Flags.TokenMagnet then return end
    lastMagnetTime = now

    local col = workspace:FindFirstChild("Collectibles")
    if not col then return end

    local rootPos  = root.Position
    local savedCF  = root.CFrame
    local collected = 0

    for _, t in ipairs(col:GetChildren()) do
        if t:IsA("BasePart") and t.Parent then
            local tPos = t.Position
            if hDist(rootPos, tPos) <= TOKEN_MAGNET_RADIUS and insideField(field, tPos, 0) then
                local owned = tokenOwned(t)
                if isCocoOrCombo(t) or owned == nil or owned then
                    root.CFrame = CFrame.new(tPos)
                    collected = collected + 1
                end
            end
        end
    end

    if collected > 0 then
        root.CFrame = savedCF
        SessionStats.tokensCollected = SessionStats.tokensCollected + collected
        if collected > 2 then
            dbg(("Magnet: %d tokens"):format(collected))
        end
    end
end

-- ============================================================
--   Snake-паттерн (полное покрытие поля)
-- ============================================================

local patrolPoints    = nil
local patrolIndex     = 1
local activeSignature = nil

local function pathSig() return SelectedField .. "::" .. SelectedPattern end

local function invalidatePath()
    patrolPoints    = nil
    patrolIndex     = 1
    activeSignature = nil
end

local function buildSnake(field)
    local pts = {}
    local c   = field.center
    local hx  = field.size.X * 0.45
    local hz  = field.size.Z * 0.45
    local rows = math.max(5, math.ceil(field.size.Z * 0.9 / 9))
    local y   = c.Y

    for row = 0, rows - 1 do
        local alpha = rows == 1 and 0.5 or row / (rows - 1)
        local z = c.Z - hz + hz * 2 * alpha
        local L = Vector3.new(c.X - hx, y, z)
        local R = Vector3.new(c.X + hx, y, z)
        if row % 2 == 0 then
            pts[#pts+1] = L; pts[#pts+1] = R
        else
            pts[#pts+1] = R; pts[#pts+1] = L
        end
    end
    return pts
end

-- ============================================================
--   Spiral-паттерн (от центра наружу)
-- ============================================================

local function buildSpiral(field)
    local pts  = {}
    local c    = field.center
    local maxR = math.min(field.size.X, field.size.Z) * 0.45
    local step = 6
    local angStep = 15
    local y    = c.Y

    local r = 2
    local angle = 0
    while r <= maxR do
        local rad = math.rad(angle)
        local x = c.X + math.cos(rad) * r
        local z = c.Z + math.sin(rad) * r
        pts[#pts+1] = Vector3.new(x, y, z)
        angle = angle + angStep
        r = r + step * (angStep / 360)
    end

    for i = #pts, 1, -2 do
        if pts[i] then pts[#pts+1] = pts[i] end
    end

    if #pts == 0 then pts[1] = c end
    return pts
end

local function getOrBuildPath(field)
    local sig = pathSig()
    if activeSignature ~= sig or not patrolPoints then
        activeSignature = sig
        if SelectedPattern == "Spiral" then
            patrolPoints = buildSpiral(field)
        else
            patrolPoints = buildSnake(field)
        end
        patrolIndex = 1
        dbg(("%s: %d pts"):format(SelectedPattern, #patrolPoints))
    end
    return patrolPoints
end

local function nextPatrolPoint(field)
    local pts   = getOrBuildPath(field)
    patrolIndex = (patrolIndex % #pts) + 1
    return pts[patrolIndex]
end

-- ============================================================
--   Roam AI — Heat-map
-- ============================================================

local RoamState = {
    heatMap       = {},
    target        = nil,
    lastCellX     = nil,
    lastCellZ     = nil,
    lastRegenTime = 0,
}

local function cellKey(cx, cz) return cx .. "," .. cz end

local function worldToCell(field, pos)
    local ox = pos.X - (field.center.X - field.size.X * 0.5)
    local oz = pos.Z - (field.center.Z - field.size.Z * 0.5)
    return math.floor(ox / ROAM_CELL_SIZE), math.floor(oz / ROAM_CELL_SIZE)
end

local function cellToWorld(field, cx, cz)
    local x = field.center.X - field.size.X * 0.5 + (cx + 0.5) * ROAM_CELL_SIZE
    local z = field.center.Z - field.size.Z * 0.5 + (cz + 0.5) * ROAM_CELL_SIZE
    return Vector3.new(x, field.center.Y, z)
end

local function getCellsCount(field)
    return math.ceil(field.size.X / ROAM_CELL_SIZE), math.ceil(field.size.Z / ROAM_CELL_SIZE)
end

local function initHeatMap(field)
    RoamState.heatMap = {}
    local nx, nz = getCellsCount(field)
    for cx = 0, nx-1 do
        for cz = 0, nz-1 do
            RoamState.heatMap[cellKey(cx, cz)] = 1.0
        end
    end
    dbg(("HeatMap: %dx%d"):format(nx, nz))
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
        RoamState.lastCellX = cx
        RoamState.lastCellZ = cz
    end
end

local function regenHeatMap()
    local now = time()
    if now - RoamState.lastRegenTime < ROAM_HEAT_REGEN_INT then return end
    RoamState.lastRegenTime = now
    for key, heat in pairs(RoamState.heatMap) do
        if heat < 1.0 then
            RoamState.heatMap[key] = math.min(1.0, heat + ROAM_HEAT_REGEN)
        end
    end
end

local function coldestCell(field, nearPos, radius)
    local nx, nz = getCellsCount(field)
    local bestHeat, bestCX, bestCZ = -1, nil, nil
    for cx = 0, nx-1 do
        for cz = 0, nz-1 do
            local wp = cellToWorld(field, cx, cz)
            if not nearPos or hDist(nearPos, wp) <= radius then
                local h = getHeat(cx, cz)
                if h > bestHeat then
                    bestHeat = h
                    bestCX, bestCZ = cx, cz
                end
            end
        end
    end
    if bestCX == nil then
        bestCX = math.floor(nx / 2)
        bestCZ = math.floor(nz / 2)
        bestHeat = getHeat(bestCX, bestCZ)
    end
    return bestCX, bestCZ, bestHeat
end

local function randomInField(field)
    local m  = ROAM_BOUNDARY_MARGIN
    local hx = math.max(field.size.X * 0.5 - m, 2)
    local hz = math.max(field.size.Z * 0.5 - m, 2)
    return Vector3.new(
        field.center.X + (math.random() * 2 - 1) * hx,
        field.center.Y,
        field.center.Z + (math.random() * 2 - 1) * hz
    )
end

local function roamPickTarget(field, root, tokens)
    if tokens and #tokens > 0 then
        local tok = tokens[1]
        local target = Vector3.new(tok.Position.X, field.center.Y, tok.Position.Z)
        target = clampToField(field, target, ROAM_BOUNDARY_MARGIN)
        dbg(("Roam -> token: %s"):format(tok.Name))
        return target
    end
    if math.random() < ROAM_WANDER_BIAS then
        return randomInField(field)
    else
        local cx, cz = coldestCell(field, nil, nil)
        local wp = cellToWorld(field, cx, cz)
        return clampToField(field, wp, ROAM_BOUNDARY_MARGIN)
    end
end

local function resetRoam(field)
    initHeatMap(field)
    RoamState.target        = nil
    RoamState.lastCellX     = nil
    RoamState.lastCellZ     = nil
    RoamState.lastRegenTime = time()
end

-- ============================================================
--   Состояние фарма
-- ============================================================

local currentTarget  = nil
local currentMode    = "idle"
local lastTargetScan = 0
local lastProgressAt = 0
local lastRootPos    = nil
local isDoingHiveRun = false
local statusLabel    = nil
local lastDt         = 0.05

local function setStatus(txt)
    if statusLabel then pcall(function() statusLabel:Set(txt) end) end
end

local function clearFarmState()
    currentToken   = nil
    currentTarget  = nil
    currentMode    = "idle"
    lastTargetScan = 0
    lastProgressAt = 0
    lastRootPos    = nil
    isDoingHiveRun = false
    invalidatePath()
    RoamState.target = nil
    setStatus("Stopped")
    dbg("=== clearFarmState ===")
end

-- ============================================================
--   Прогресс & Застревание
-- ============================================================

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
--   Вспомогалки фарма
-- ============================================================

local function resetToField(root, hum)
    local field = getField()
    invalidatePath()
    if SelectedPattern == "Roam" then resetRoam(field) end
    currentToken   = nil
    currentMode    = SelectedPattern == "Roam" and "roam" or "patrol"
    currentTarget  = field.center

    teleportTo(root, fieldCenter(field))
    task.wait(0.1)
    local ground = findGround(root.Position)
    teleportTo(root, ground)

    lastRootPos    = root.Position
    lastProgressAt = time()
    setStatus("Farm: " .. SelectedField)
    dbg("resetToField -> " .. SelectedField .. " mode=" .. currentMode)
end

local function checkField(root, hum, field)
    if not insideField(field, root.Position, FIELD_REENTER_PADDING) then
        dbg("Out of field -> TP back")
        resetToField(root, hum)
        return true
    end
    return false
end

-- ============================================================
--   Hive Run
-- ============================================================

local returnPosition = nil

local function doHiveRun()
    if isDoingHiveRun then return end
    if not HivePoint then
        setStatus("No hive point!")
        return
    end
    isDoingHiveRun = true
    dbg("=== Hive Run START ===")

    local ok, err = pcall(function()
        setStatus("Hive: flying...")
        local _, hum, root = getCharParts()
        if not hum or not root then return end

        returnPosition = fieldCenter(getField())
        teleportTo(root, HivePoint)
        task.wait(0.5)

        setStatus("Hive: converting...")
        pressE(HIVE_E_SPAM)

        local endTime = time() + HIVE_WAIT_MIN + math.random() * (HIVE_WAIT_MAX - HIVE_WAIT_MIN)
        while time() < endTime do
            local rem = math.ceil(endTime - time())
            setStatus(("Hive: %ds..."):format(rem))
            if rem % 3 == 0 then pressE(1) end
            task.wait(1)
        end

        setStatus("Returning...")
        _, hum, root = getCharParts()
        if hum and root then
            teleportTo(root, returnPosition or fieldCenter(getField()))
            task.wait(0.3)
            local ground = findGround(root.Position)
            teleportTo(root, ground)
            lastProgressAt = time()
            lastRootPos    = root.Position
            invalidatePath()
            if SelectedPattern == "Roam" then
                resetRoam(getField())
                currentMode = "roam"
            else
                currentMode = "patrol"
            end
            currentToken  = nil
            currentTarget = getField().center
        end
    end)

    isDoingHiveRun = false
    dbg("=== Hive Run END ===")

    if not ok then
        dbg("Hive ERROR: " .. tostring(err))
        setStatus("Hive error!")
    else
        SessionStats.hiveRuns = SessionStats.hiveRuns + 1
        setStatus("Farm resumed")
        Rayfield:Notify({ Title="Hive", Content="Converted! Returning.", Duration=3 })
    end
end

-- ============================================================
--   Загрузка
-- ============================================================

loadRouteStore()
loadHivePoint()

-- ============================================================
--   ОСНОВНОЙ ЦИКЛ ФАРМА
-- ============================================================

local lastFarmTick = time()

task.spawn(function()
    while true do
        task.wait(FARM_INTERVAL)
        if not Flags.AutoFarm or isDoingHiveRun then continue end

        local ok, err = pcall(function()
            local _, hum, root = getCharParts()
            if not hum or not root then clearFarmState(); return end

            local field = getField()
            local now   = time()
            local dt    = math.min(now - lastFarmTick, 0.2)
            lastFarmTick = now
            lastDt = dt

            updateProgress(root, now)

            if checkField(root, hum, field) then return end

            -- Токен-магнит
            doTokenMagnet(root, field)

            local moveSpeed = Flags.CFrameSpeed and Flags.Speed or CFRAME_BASE_SPEED

            -- ════════════════════════════════════════════════
            -- SNAKE / SPIRAL
            -- ════════════════════════════════════════════════
            if SelectedPattern == "Snake" or SelectedPattern == "Spiral" then

                if currentMode ~= "patrol" and currentMode ~= "token" then
                    currentMode   = "patrol"
                    currentTarget = nextPatrolPoint(field)
                end

                if now - lastTargetScan >= TOKEN_SCAN_INTERVAL then
                    lastTargetScan = now
                    local tokens = getTokensSorted(root, field)
                    if #tokens > 0 then
                        currentToken  = tokens[1]
                        currentTarget = currentToken.Position
                        currentMode   = "token"
                    elseif currentMode == "token" then
                        currentMode   = "patrol"
                        currentTarget = nextPatrolPoint(field)
                    end
                end

                if currentMode == "token" and not tokenValid(field) then
                    currentToken  = nil
                    currentMode   = "patrol"
                    currentTarget = nextPatrolPoint(field)
                end

                if currentTarget then
                    local dist = hDist(root.Position, currentTarget)

                    if currentMode == "token" and dist <= TOKEN_REACH_DIST then
                        SessionStats.tokensCollected = SessionStats.tokensCollected + 1
                        currentToken  = nil
                        currentMode   = "patrol"
                        currentTarget = nextPatrolPoint(field)
                    elseif currentMode == "patrol" and dist <= PATROL_REACH_DIST then
                        currentTarget = nextPatrolPoint(field)
                    elseif isStuck(now) then
                        SessionStats.stuckCount = SessionStats.stuckCount + 1
                        lastProgressAt = now
                        lastRootPos    = root.Position
                        if currentMode == "token" then currentToken = nil end
                        currentMode   = "patrol"
                        currentTarget = nextPatrolPoint(field)
                        dbg("Stuck -> next point")
                    end

                    if currentTarget then
                        cframeStep(root, currentTarget, moveSpeed, dt)
                    end
                end

            -- ════════════════════════════════════════════════
            -- ROAM AI
            -- ════════════════════════════════════════════════
            elseif SelectedPattern == "Roam" then

                if currentMode ~= "roam" then
                    currentMode = "roam"
                    resetRoam(field)
                end

                visitCell(field, root.Position)
                regenHeatMap()

                if now - lastTargetScan >= TOKEN_SCAN_INTERVAL then
                    lastTargetScan = now
                    local tokens = getTokensSorted(root, field)
                    if #tokens > 0 then
                        local bestTok = tokens[1]
                        if bestTok ~= currentToken or not RoamState.target then
                            currentToken     = bestTok
                            RoamState.target = roamPickTarget(field, root, tokens)
                            currentTarget    = RoamState.target
                        end
                    else
                        currentToken     = nil
                        RoamState.target = roamPickTarget(field, root, {})
                        currentTarget    = RoamState.target
                    end
                end

                if currentToken and not tokenValid(field) then
                    currentToken     = nil
                    RoamState.target = roamPickTarget(field, root, {})
                    currentTarget    = RoamState.target
                end

                if not currentTarget then
                    RoamState.target = roamPickTarget(field, root, {})
                    currentTarget    = RoamState.target
                end

                if currentTarget then
                    currentTarget    = clampToField(field, currentTarget, ROAM_BOUNDARY_MARGIN)
                    RoamState.target = currentTarget
                end

                if currentTarget then
                    local dist = hDist(root.Position, currentTarget)

                    if currentToken and dist <= TOKEN_REACH_DIST then
                        SessionStats.tokensCollected = SessionStats.tokensCollected + 1
                        currentToken     = nil
                        RoamState.target = roamPickTarget(field, root, {})
                        currentTarget    = RoamState.target
                    elseif not currentToken and dist <= ROAM_RESCAN_DIST then
                        RoamState.target = roamPickTarget(field, root, {})
                        currentTarget    = RoamState.target
                    elseif isStuck(now) then
                        SessionStats.stuckCount = SessionStats.stuckCount + 1
                        lastProgressAt   = now
                        lastRootPos      = root.Position
                        currentToken     = nil
                        RoamState.target = roamPickTarget(field, root, {})
                        currentTarget    = RoamState.target
                        dbg("Roam: stuck -> new target")
                    end

                    if currentTarget then
                        cframeStep(root, currentTarget, moveSpeed, dt)
                    end
                end
            end -- patterns

            -- Статус
            local polCur, polMax = getPollenStats()
            if not polCur then polCur, polMax = getPollenFromGui() end
            local polStr = polCur and polMax
                and (" | " .. tostring(polCur) .. "/" .. tostring(polMax))
                or ""
            local modeIcon = currentMode == "token" and "T" or "P"
            setStatus(("[%s] %s%s"):format(modeIcon, SelectedField, polStr))

        end) -- pcall
        if not ok then dbg("Farm error: " .. tostring(err)) end
    end
end)

-- ============================================================
--   Авто-проверка пыльцы -> Hive Run
-- ============================================================

task.spawn(function()
    while true do
        task.wait(POLLEN_CHECK_INTERVAL)
        if not Flags.AutoFarm or not Flags.AutoHive then continue end
        if isDoingHiveRun or not HivePoint then continue end
        pcall(function()
            if isBackpackFull() then
                dbg("Backpack full -> Hive Run")
                task.spawn(doHiveRun)
            end
        end)
    end
end)

-- ============================================================
--   Auto Dig
-- ============================================================

task.spawn(function()
    while task.wait(DIG_INTERVAL) do
        if Flags.AutoDig and Flags.AutoFarm and not isDoingHiveRun then
            pcall(function()
                VIM:SendMouseButtonEvent(0, 0, 0, true,  game, 0)
                task.wait(0.04)
                VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
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
        task.wait(PLANTER_MIN_WAIT + math.random() * (PLANTER_MAX_WAIT - PLANTER_MIN_WAIT))
        if Flags.AutoPlanter and Flags.AutoFarm and not isDoingHiveRun then
            pcall(function()
                local kc = keyMap[SelectedSlot]
                if kc then
                    VIM:SendKeyEvent(true,  kc, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, kc, false, game)
                end
            end)
        end
    end
end)

-- ============================================================
--   Анти-AFK
-- ============================================================

task.spawn(function()
    while true do
        task.wait(ANTI_AFK_INTERVAL)
        if Flags.AntiAFK then
            pcall(function()
                VIM:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
                task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
        end
    end
end)

-- ============================================================
--   CFrame Speed (Heartbeat)
-- ============================================================

RunService.Heartbeat:Connect(function()
    if not Flags.CFrameSpeed then return end
    pcall(function()
        local _, hum, root = getCharParts()
        if not hum or not root then return end
        hum.WalkSpeed = Flags.Speed
        if root.AssemblyLinearVelocity.Magnitude > Flags.Speed * 1.5 then
            root.AssemblyLinearVelocity = root.AssemblyLinearVelocity.Unit * Flags.Speed
        end
    end)
end)

-- ============================================================
--   UI (Rayfield)
-- ============================================================

local Window = Rayfield:CreateWindow({
    Name              = "JanusBSS v16.0",
    LoadingTitle      = "JanusBSS",
    LoadingSubtitle   = "CFrame AI + Token Magnet",
    ConfigurationSaving = { Enabled = false },
})

-- Main Tab
local MainTab = Window:CreateTab("Farm", 4483362458)

statusLabel = MainTab:CreateLabel("Stopped")

MainTab:CreateToggle({
    Name = "AI AutoFarm", CurrentValue = false,
    Callback = function(v)
        Flags.AutoFarm = v
        if not v then
            clearFarmState()
        else
            local _, hum, root = getCharParts()
            if hum and root then resetToField(root, hum) end
        end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Dig", CurrentValue = false,
    Callback = function(v) Flags.AutoDig = v end,
})

MainTab:CreateToggle({
    Name = "Token Magnet", CurrentValue = true,
    Callback = function(v) Flags.TokenMagnet = v end,
})

MainTab:CreateToggle({
    Name = "CFrame Speed", CurrentValue = false,
    Callback = function(v) Flags.CFrameSpeed = v end,
})

MainTab:CreateSlider({
    Name = "Speed", Range = {16, 150}, Increment = 1, CurrentValue = 40,
    Callback = function(v) Flags.Speed = v end,
})

MainTab:CreateDropdown({
    Name = "Field", Options = FieldNames, CurrentOption = { DEFAULT_FIELD },
    Callback = function(opt)
        SelectedField = type(opt)=="table" and (opt[1] or DEFAULT_FIELD) or opt
        clearFarmState()
        local _, hum, root = getCharParts()
        if Flags.AutoFarm and hum and root then resetToField(root, hum) end
    end,
})

MainTab:CreateDropdown({
    Name = "Pattern", Options = PatternNames, CurrentOption = { DEFAULT_PATTERN },
    Callback = function(opt)
        SelectedPattern = type(opt)=="table" and (opt[1] or DEFAULT_PATTERN) or opt
        invalidatePath()
        if SelectedPattern == "Roam" then resetRoam(getField()) end
        local _, hum, root = getCharParts()
        if Flags.AutoFarm and hum and root then resetToField(root, hum) end
        dbg("Pattern -> " .. SelectedPattern)
    end,
})

MainTab:CreateDropdown({
    Name = "Planter Slot", Options = {"1","2","3","4","5","6","7"}, CurrentOption = {"1"},
    Callback = function(opt)
        SelectedSlot = type(opt)=="table" and (opt[1] or "1") or opt
    end,
})

MainTab:CreateToggle({
    Name = "Auto Planter", CurrentValue = false,
    Callback = function(v) Flags.AutoPlanter = v end,
})

MainTab:CreateButton({
    Name = "TP to Field",
    Callback = function()
        local _, _, root = getCharParts()
        if root then teleportTo(root, fieldCenter(getField())) end
    end,
})

-- Hive Tab
local HiveTab = Window:CreateTab("Hive", 4483362458)

HiveTab:CreateLabel("Auto honey conversion")

HiveTab:CreateToggle({
    Name = "Auto Hive Convert", CurrentValue = false,
    Callback = function(v)
        Flags.AutoHive = v
        if v and not HivePoint then
            Rayfield:Notify({ Title="Hive", Content="Save hive point first!", Duration=4 })
        end
    end,
})

HiveTab:CreateLabel("Stand at hive -> press button below")

HiveTab:CreateButton({
    Name = "Save Hive Point",
    Callback = function()
        local _, _, root = getCharParts()
        if root then
            saveHivePoint(root.Position)
            Rayfield:Notify({
                Title   = "Hive",
                Content = ("Saved: %.1f, %.1f, %.1f"):format(root.Position.X, root.Position.Y, root.Position.Z),
                Duration = 3,
            })
        end
    end,
})

HiveTab:CreateButton({
    Name = "Test Hive Run",
    Callback = function()
        if not HivePoint then
            Rayfield:Notify({ Title="Hive", Content="No hive point!", Duration=3 })
            return
        end
        task.spawn(doHiveRun)
    end,
})

-- Stats Tab
local StatsTab = Window:CreateTab("Stats", 4483362458)

local statsLabel = StatsTab:CreateLabel("Loading...")

task.spawn(function()
    while true do
        task.wait(2)
        local uptime = time() - SessionStats.startTime
        local mins = math.floor(uptime / 60)
        local secs = math.floor(uptime % 60)
        local cur, max = getPollenStats()
        if not cur then cur, max = getPollenFromGui() end
        local polStr = cur and max and ("%d / %d"):format(cur, max) or "???"

        local info = {
            ("Uptime: %dm %ds"):format(mins, secs),
            ("Tokens: %d"):format(SessionStats.tokensCollected),
            ("Hive runs: %d"):format(SessionStats.hiveRuns),
            ("Stuck: %d"):format(SessionStats.stuckCount),
            ("Pollen: %s"):format(polStr),
            ("Field: %s"):format(SelectedField),
            ("Pattern: %s"):format(SelectedPattern),
            ("Mode: %s"):format(currentMode),
        }
        pcall(function() statsLabel:Set(table.concat(info, "\n")) end)
    end
end)

-- Debug Tab
local DebugTab = Window:CreateTab("Debug", 4483362458)

DebugTab:CreateToggle({
    Name = "Debug Log", CurrentValue = false,
    Callback = function(v)
        Flags.DebugLog = v
        if v then dbg("=== Debug ON ===") end
    end,
})

DebugTab:CreateLabel("Recent events:")
logLabel = DebugTab:CreateLabel("(empty)")

DebugTab:CreateButton({
    Name = "Print Full Log",
    Callback = function()
        print("=== FULL LOG ===")
        print(getFullLog())
        print("=== END ===")
        Rayfield:Notify({ Title="Debug", Content="Printed to Output!", Duration=3 })
    end,
})

DebugTab:CreateButton({
    Name = "Clear Log",
    Callback = function()
        logLines = {}
        pcall(function() logLabel:Set("(cleared)") end)
    end,
})

DebugTab:CreateButton({
    Name = "State Dump",
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
            ("Pos: %.1f, %.1f, %.1f"):format(pos.X, pos.Y, pos.Z),
            ("Inside: %s"):format(tostring(inside)),
            ("Token: %s"):format(currentToken and currentToken.Name or "nil"),
            ("Target: %s"):format(currentTarget and ("%.1f,%.1f,%.1f"):format(currentTarget.X, currentTarget.Y, currentTarget.Z) or "nil"),
            ("Stuck: %.1fs"):format(time() - lastProgressAt),
            ("Pollen: %s/%s"):format(tostring(cur), tostring(max)),
            ("Hive: %s"):format(HivePoint and ("%.1f,%.1f,%.1f"):format(HivePoint.X, HivePoint.Y, HivePoint.Z) or "nil"),
            ("HiveRun: %s"):format(tostring(isDoingHiveRun)),
            ("Magnet: %s"):format(tostring(Flags.TokenMagnet)),
        }
        print("=== STATE ===\n" .. table.concat(info, "\n"))
        Rayfield:Notify({ Title="Dump", Content="Printed to Output!", Duration=3 })
    end,
})

DebugTab:CreateToggle({
    Name = "Anti-AFK", CurrentValue = true,
    Callback = function(v) Flags.AntiAFK = v end,
})

-- ============================================================
--   Сброс при смерти + авто-рестарт
-- ============================================================

Player.CharacterRemoving:Connect(function()
    isDoingHiveRun = false
    clearFarmState()
    dbg("CharacterRemoving -> reset")
end)

Player.CharacterAdded:Connect(function(char)
    local hum  = char:WaitForChild("Humanoid", 10)
    local root = char:WaitForChild("HumanoidRootPart", 10)
    if not hum or not root then return end
    task.wait(1)
    if Flags.AutoFarm then
        dbg("CharacterAdded -> auto-restart")
        resetToField(root, hum)
    end
end)

-- ============================================================
--   Готово
-- ============================================================

Rayfield:Notify({
    Title    = "JanusBSS v16.0",
    Content  = "CFrame AI + Token Magnet loaded!",
    Duration = 4,
})

dbg("=== JanusBSS v16.0 loaded ===")
