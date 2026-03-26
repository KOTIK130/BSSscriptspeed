-- ============================================================
--   JanusBSS AutoFarm v18.1  |  Snake + AutoConvert + CFrame Speed (FIXED)
-- ============================================================

-- ╔══════════════════════════════════════════════════════════╗
-- ║                    КОНФИГИ (CONFIG)                      ║
-- ╚══════════════════════════════════════════════════════════╝

local DEFAULT_FIELD   = "Spider Field"
local ROUTE_FILE      = "JanusBSS_FieldRoutes.json"

-- Интервалы (секунды)
local FARM_INTERVAL         = 0.03
local TOKEN_SCAN_INTERVAL   = 0.15
local DIG_INTERVAL          = 0.10
local PLANTER_WAIT          = 0.7
local ANTI_AFK_INTERVAL     = 120
local CONVERT_WAIT          = 9.5

-- CFrame движение
local CFRAME_BASE_SPEED     = 32
local CFRAME_STEP_MAX       = 6

-- Расстояния
local PATROL_REACH_DIST     = 4
local TOKEN_REACH_DIST      = 3
local FIELD_REENTER_PADDING = 5
local CLUSTER_RADIUS        = 10
local CLUSTER_MAX_CHECK     = 15

-- Застревание
local STUCK_TIMEOUT         = 2.5
local STUCK_MIN_MOVE        = 0.5

-- Прочее
local TELEPORT_HEIGHT       = 8
local GROUND_RAY_DIST       = 60

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
--   Поле Spider Field
-- ============================================================

local Fields = {
    ["Spider Field"] = { center = Vector3.new(-38, 20, -5), size = Vector3.new(68, 10, 68) },
}

local SelectedField = DEFAULT_FIELD

-- ============================================================
--   Флаги & Состояние
-- ============================================================

local Flags = {
    AutoFarm    = false,
    AutoDig     = false,
    CFrameSpeed = false,
    AutoPlanter = false,
    AutoConvert = false,
    AntiAFK     = true,
    Speed       = 48,
}

local SelectedSlot = "1"

-- ============================================================
--   Хранилище точки конвертации
-- ============================================================

local RouteStore = { routes = {}, convertPoint = nil }
local ConvertPoint = nil

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

local function loadConvertPoint()
    if RouteStore.convertPoint then
        ConvertPoint = deserializeV3(RouteStore.convertPoint)
    end
end

local function saveConvertPoint(pos)
    ConvertPoint = pos
    RouteStore.convertPoint = serializeV3(pos)
    saveRouteStore()
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

-- ============================================================
--   Поиск земли (Raycast)
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

local function resetVelocity(root)
    pcall(function()
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function teleportTo(root, pos)
    pcall(function()
        resetVelocity(root)
        root.CFrame = CFrame.new(pos)
        resetVelocity(root)
    end)
end

local function cframeMoveTo(root, dest, speed, dt)
    local pos  = root.Position
    local flat = Vector3.new(dest.X, pos.Y, dest.Z)
    local diff = flat - pos
    local dist = diff.Magnitude

    if dist < 0.5 then 
        resetVelocity(root)
        return true 
    end

    local step = math.min(speed * dt, dist, CFRAME_STEP_MAX)
    local dir  = diff.Unit
    local newPos = pos + dir * step
    
    -- Сохраняем ориентацию, двигаем только позицию
    local lookCF = CFrame.lookAt(newPos, Vector3.new(dest.X, newPos.Y, dest.Z))
    root.CFrame = lookCF
    
    -- Обязательно сбрасываем velocity после CFrame движения
    resetVelocity(root)

    return false
end

local function pressE()
    VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
    task.wait(0.08)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
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
--   Snake-паттерн (FIXED)
-- ============================================================

local patrolPoints    = {}
local patrolIndex     = 0

local function buildSnake(field)
    local pts = {}
    local c   = field.center
    local hx  = field.size.X * 0.45
    local hz  = field.size.Z * 0.45
    local rows = math.max(6, math.ceil(field.size.Z * 0.9 / 8))
    local y   = c.Y

    for row = 0, rows - 1 do
        local alpha = rows == 1 and 0.5 or row / (rows - 1)
        local z = c.Z - hz + hz * 2 * alpha
        local L = Vector3.new(c.X - hx, y, z)
        local R = Vector3.new(c.X + hx, y, z)
        if row % 2 == 0 then
            pts[#pts+1] = L
            pts[#pts+1] = R
        else
            pts[#pts+1] = R
            pts[#pts+1] = L
        end
    end
    return pts
end

local function initSnakePath(field)
    patrolPoints = buildSnake(field)
    patrolIndex = 0
end

local function getNextPatrolPoint()
    if #patrolPoints == 0 then return nil end
    patrolIndex = patrolIndex + 1
    if patrolIndex > #patrolPoints then
        patrolIndex = 1
    end
    return patrolPoints[patrolIndex]
end

local function getCurrentPatrolPoint()
    if #patrolPoints == 0 then return nil end
    if patrolIndex < 1 or patrolIndex > #patrolPoints then
        patrolIndex = 1
    end
    return patrolPoints[patrolIndex]
end

-- ============================================================
--   Состояние фарма
-- ============================================================

local currentTarget   = nil
local currentMode     = "idle"
local lastTargetScan  = 0
local lastProgressAt  = 0
local lastRootPos     = nil
local isConverting    = false
local statusLabel     = nil

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
    isConverting   = false
    patrolPoints   = {}
    patrolIndex    = 0
    setStatus("Stopped")
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
    
    -- Инициализируем snake path
    initSnakePath(field)
    
    currentToken   = nil
    currentMode    = "patrol"
    currentTarget  = getNextPatrolPoint()

    teleportTo(root, fieldCenter(field))
    task.wait(0.15)
    local ground = findGround(root.Position)
    teleportTo(root, ground)

    lastRootPos    = root.Position
    lastProgressAt = time()
    setStatus("Farm: " .. SelectedField)
end

local function checkField(root, hum, field)
    if not insideField(field, root.Position, FIELD_REENTER_PADDING) then
        resetToField(root, hum)
        return true
    end
    return false
end

-- ============================================================
--   Автоконвертация
-- ============================================================

local returnPosition = nil

local function doAutoConvert()
    if isConverting then return end
    if not ConvertPoint then
        setStatus("No convert point!")
        return
    end
    isConverting = true

    local ok, err = pcall(function()
        setStatus("Convert: teleporting...")
        local _, hum, root = getCharParts()
        if not hum or not root then return end

        returnPosition = fieldCenter(getField())
        teleportTo(root, ConvertPoint)
        task.wait(0.5)

        setStatus("Convert: pressing E...")
        pressE()

        local endTime = time() + CONVERT_WAIT
        while time() < endTime do
            local rem = math.ceil(endTime - time())
            setStatus(("Convert: %ds..."):format(rem))
            task.wait(1)
        end

        setStatus("Returning to field...")
        _, hum, root = getCharParts()
        if hum and root then
            teleportTo(root, returnPosition or fieldCenter(getField()))
            task.wait(0.3)
            local ground = findGround(root.Position)
            teleportTo(root, ground)
            lastProgressAt = time()
            lastRootPos    = root.Position
            
            -- Reinit snake path after return
            initSnakePath(getField())
            currentMode    = "patrol"
            currentToken   = nil
            currentTarget  = getNextPatrolPoint()
        end
    end)

    isConverting = false

    if ok then
        setStatus("Farm resumed")
        Rayfield:Notify({ Title="Convert", Content="Done! Returning to field.", Duration=3 })
    end
end

-- ============================================================
--   Загрузка
-- ============================================================

loadRouteStore()
loadConvertPoint()

-- ============================================================
--   ОСНОВНОЙ ЦИКЛ ФАРМА (Snake) - FIXED
-- ============================================================

local lastFarmTick = time()

task.spawn(function()
    while true do
        task.wait(FARM_INTERVAL)
        if not Flags.AutoFarm or isConverting then continue end

        local ok, err = pcall(function()
            local _, hum, root = getCharParts()
            if not hum or not root then clearFarmState(); return end

            local field = getField()
            local now   = time()
            local dt    = math.clamp(now - lastFarmTick, 0.01, 0.15)
            lastFarmTick = now

            updateProgress(root, now)

            if checkField(root, hum, field) then return end

            local moveSpeed = Flags.CFrameSpeed and Flags.Speed or CFRAME_BASE_SPEED

            -- Инициализация если нужно
            if #patrolPoints == 0 then
                initSnakePath(field)
                currentTarget = getNextPatrolPoint()
                currentMode = "patrol"
            end

            -- Сканирование токенов
            if now - lastTargetScan >= TOKEN_SCAN_INTERVAL then
                lastTargetScan = now
                local tokens = getTokensSorted(root, field)
                if #tokens > 0 then
                    currentToken  = tokens[1]
                    currentTarget = currentToken.Position
                    currentMode   = "token"
                elseif currentMode == "token" then
                    currentToken  = nil
                    currentMode   = "patrol"
                    currentTarget = getCurrentPatrolPoint()
                end
            end

            -- Проверка валидности токена
            if currentMode == "token" and not tokenValid(field) then
                currentToken  = nil
                currentMode   = "patrol"
                currentTarget = getCurrentPatrolPoint()
            end

            -- Движение к цели
            if currentTarget then
                local dist = hDist(root.Position, currentTarget)

                if currentMode == "token" and dist <= TOKEN_REACH_DIST then
                    -- Достигли токена, переключаемся на патруль
                    currentToken  = nil
                    currentMode   = "patrol"
                    currentTarget = getNextPatrolPoint()
                elseif currentMode == "patrol" and dist <= PATROL_REACH_DIST then
                    -- Достигли точки патруля, переходим к следующей
                    currentTarget = getNextPatrolPoint()
                elseif isStuck(now) then
                    -- Застряли, пропускаем точку
                    lastProgressAt = now
                    lastRootPos    = root.Position
                    if currentMode == "token" then 
                        currentToken = nil 
                    end
                    currentMode   = "patrol"
                    currentTarget = getNextPatrolPoint()
                end

                -- Выполняем движение
                if currentTarget then
                    cframeMoveTo(root, currentTarget, moveSpeed, dt)
                end
            else
                -- Нет цели, получаем следующую точку
                currentTarget = getNextPatrolPoint()
            end

            -- Статус
            local polCur, polMax = getPollenStats()
            if not polCur then polCur, polMax = getPollenFromGui() end
            local polStr = polCur and polMax
                and (" | " .. tostring(polCur) .. "/" .. tostring(polMax))
                or ""
            local modeIcon = currentMode == "token" and "T" or "P"
            local ptInfo = (" [%d/%d]"):format(patrolIndex, #patrolPoints)
            setStatus(("[%s] %s%s%s"):format(modeIcon, SelectedField, ptInfo, polStr))
        end)
    end
end)

-- ============================================================
--   Авто-проверка пыльцы -> AutoConvert
-- ============================================================

task.spawn(function()
    while true do
        task.wait(1.0)
        if not Flags.AutoFarm or not Flags.AutoConvert then continue end
        if isConverting or not ConvertPoint then continue end
        pcall(function()
            if isBackpackFull() then
                task.spawn(doAutoConvert)
            end
        end)
    end
end)

-- ============================================================
--   Auto Dig
-- ============================================================

task.spawn(function()
    while task.wait(DIG_INTERVAL) do
        if Flags.AutoDig and Flags.AutoFarm and not isConverting then
            pcall(function()
                VIM:SendMouseButtonEvent(0, 0, 0, true,  game, 0)
                task.wait(0.04)
                VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
        end
    end
end)

-- ============================================================
--   Auto Planter (0.7 speed)
-- ============================================================

task.spawn(function()
    local keyMap = {
        ["1"]=Enum.KeyCode.One,   ["2"]=Enum.KeyCode.Two,
        ["3"]=Enum.KeyCode.Three, ["4"]=Enum.KeyCode.Four,
        ["5"]=Enum.KeyCode.Five,  ["6"]=Enum.KeyCode.Six,
        ["7"]=Enum.KeyCode.Seven,
    }
    while true do
        task.wait(PLANTER_WAIT)
        if Flags.AutoPlanter and Flags.AutoFarm and not isConverting then
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
--   CFrame Speed (FIXED - no sliding)
-- ============================================================

local speedConnection = nil
local originalWalkSpeed = 16

local function enableCFrameSpeed()
    if speedConnection then return end
    
    local _, hum, _ = getCharParts()
    if hum then
        originalWalkSpeed = hum.WalkSpeed
    end
    
    speedConnection = RunService.Heartbeat:Connect(function(dt)
        if not Flags.CFrameSpeed then return end
        
        pcall(function()
            local _, hum, root = getCharParts()
            if not hum or not root then return end
            
            -- Не применяем скорость во время автофарма (он сам управляет движением)
            if Flags.AutoFarm then return end
            
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0.1 then
                local speed = Flags.Speed
                local boost = moveDir.Unit * speed * dt
                
                -- Чистое CFrame движение
                root.CFrame = root.CFrame + Vector3.new(boost.X, 0, boost.Z)
                
                -- Сбрасываем горизонтальную скорость чтобы не было скольжения
                local vel = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
            else
                -- Когда не двигаемся - полный сброс горизонтальной скорости
                local vel = root.AssemblyLinearVelocity
                if math.abs(vel.X) > 0.1 or math.abs(vel.Z) > 0.1 then
                    root.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
                end
            end
        end)
    end)
end

local function disableCFrameSpeed()
    if speedConnection then
        speedConnection:Disconnect()
        speedConnection = nil
    end
    
    pcall(function()
        local _, hum, root = getCharParts()
        if hum then
            hum.WalkSpeed = originalWalkSpeed
        end
        if root then
            resetVelocity(root)
        end
    end)
end

-- Start speed system
enableCFrameSpeed()

-- ============================================================
--   UI (Rayfield)
-- ============================================================

local Window = Rayfield:CreateWindow({
    Name              = "JanusBSS v18.1",
    LoadingTitle      = "JanusBSS",
    LoadingSubtitle   = "Snake + AutoConvert",
    ConfigurationSaving = { Enabled = false },
})

-- Main Tab
local MainTab = Window:CreateTab("Farm", 4483362458)

statusLabel = MainTab:CreateLabel("Stopped")

MainTab:CreateToggle({
    Name = "AutoFarm (Snake)", CurrentValue = false,
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
    Name = "CFrame Speed", CurrentValue = false,
    Callback = function(v) 
        Flags.CFrameSpeed = v
        if not v then
            disableCFrameSpeed()
            enableCFrameSpeed() -- Reconnect but flag is off
        end
    end,
})

MainTab:CreateSlider({
    Name = "Speed", Range = {16, 150}, Increment = 1, CurrentValue = 48,
    Callback = function(v) Flags.Speed = v end,
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
    Name = "TP to Spider Field",
    Callback = function()
        local _, _, root = getCharParts()
        if root then teleportTo(root, fieldCenter(getField())) end
    end,
})

-- Convert Tab
local ConvertTab = Window:CreateTab("Convert", 4483362458)

ConvertTab:CreateLabel("Auto conversion when backpack is full")

ConvertTab:CreateToggle({
    Name = "Auto Convert", CurrentValue = false,
    Callback = function(v)
        Flags.AutoConvert = v
        if v and not ConvertPoint then
            Rayfield:Notify({ Title="Convert", Content="Save convert point first!", Duration=4 })
        end
    end,
})

ConvertTab:CreateLabel("Stand at convert spot -> press button below")

ConvertTab:CreateButton({
    Name = "Save Convert Point",
    Callback = function()
        local _, _, root = getCharParts()
        if root then
            saveConvertPoint(root.Position)
            Rayfield:Notify({
                Title   = "Convert",
                Content = ("Saved: %.1f, %.1f, %.1f"):format(root.Position.X, root.Position.Y, root.Position.Z),
                Duration = 3,
            })
        end
    end,
})

ConvertTab:CreateButton({
    Name = "Test Convert",
    Callback = function()
        if not ConvertPoint then
            Rayfield:Notify({ Title="Convert", Content="No convert point!", Duration=3 })
            return
        end
        task.spawn(doAutoConvert)
    end,
})

ConvertTab:CreateToggle({
    Name = "Anti-AFK", CurrentValue = true,
    Callback = function(v) Flags.AntiAFK = v end,
})

-- ============================================================
--   Сброс при смерти + авто-рестарт
-- ============================================================

Player.CharacterRemoving:Connect(function()
    isConverting = false
    clearFarmState()
end)

Player.CharacterAdded:Connect(function(char)
    local hum  = char:WaitForChild("Humanoid", 10)
    local root = char:WaitForChild("HumanoidRootPart", 10)
    if not hum or not root then return end
    task.wait(1)
    
    -- Reconnect speed system
    enableCFrameSpeed()
    
    if Flags.AutoFarm then
        resetToField(root, hum)
    end
end)

-- ============================================================
--   Готово
-- ============================================================

Rayfield:Notify({
    Title    = "JanusBSS v18.1",
    Content  = "Snake + AutoConvert loaded!",
    Duration = 4,
})
