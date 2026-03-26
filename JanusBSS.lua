local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer

local DEFAULT_FIELD = "Sunflower Field"
local DEFAULT_PATTERN = "Snake"
local ROUTE_FILE = "JanusBSS_FieldRoutes.json"

local FARM_INTERVAL = 0.08
local TARGET_SCAN_INTERVAL = 0.22
local MOVE_COMMAND_INTERVAL = 0.2
local DIG_INTERVAL = 0.12
local STUCK_TIMEOUT = 0.4
local TELEPORT_HEIGHT = 3
local PATROL_REACH_DISTANCE = 4
local TOKEN_REACH_DISTANCE = 5
local FIELD_REENTER_PADDING = 4
local CLUSTER_RADIUS = 10
local SPEED_MULTIPLIER = 1.8

local Fields = {
    ["Dandelion Field"] = { center = Vector3.new(-30, 5, 225), size = Vector3.new(72, 6, 72) },
    ["Sunflower Field"] = { center = Vector3.new(-208, 5, -185), size = Vector3.new(72, 6, 72) },
    ["Mushroom Field"] = { center = Vector3.new(-221, 5, 116), size = Vector3.new(72, 6, 72) },
    ["Blue Flower Field"] = { center = Vector3.new(113, 5, 101), size = Vector3.new(72, 6, 72) },
    ["Clover Field"] = { center = Vector3.new(174, 34, 189), size = Vector3.new(72, 6, 72) },
    ["Spider Field"] = { center = Vector3.new(-38, 20, -5), size = Vector3.new(72, 6, 72) },
    ["Strawberry Field"] = { center = Vector3.new(-169, 20, -3), size = Vector3.new(72, 6, 72) },
    ["Bamboo Field"] = { center = Vector3.new(93, 20, -48), size = Vector3.new(72, 6, 72) },
    ["Pineapple Patch"] = { center = Vector3.new(262, 20, -42), size = Vector3.new(72, 6, 72) },
    ["Stump Field"] = { center = Vector3.new(421, 95, -174), size = Vector3.new(78, 6, 78) },
    ["Cactus Field"] = { center = Vector3.new(-194, 68, -107), size = Vector3.new(72, 6, 72) },
    ["Pumpkin Patch"] = { center = Vector3.new(-194, 68, -182), size = Vector3.new(72, 6, 72) },
    ["Pine Tree Forest"] = { center = Vector3.new(-318, 68, -150), size = Vector3.new(80, 6, 80) },
    ["Rose Field"] = { center = Vector3.new(-322, 20, 124), size = Vector3.new(72, 6, 72) },
    ["Mountain Top Field"] = { center = Vector3.new(76, 226, -122), size = Vector3.new(85, 6, 85) },
    ["Coconut Field"] = { center = Vector3.new(-255, 71, 464), size = Vector3.new(95, 6, 95) },
    ["Pepper Patch"] = { center = Vector3.new(477, 113, 22), size = Vector3.new(80, 6, 80) }
}

local FieldNames = {}
for name in pairs(Fields) do
    FieldNames[#FieldNames + 1] = name
end
table.sort(FieldNames)

local PatternNames = {
    "Snake",
    "Loop",
    "Custom Route"
}

local Flags = {
    AutoFarm = false,
    AutoDig = false,
    EnableSpeed = false,
    AutoPlanter = false,
    Speed = 35
}

local SelectedField = DEFAULT_FIELD
local SelectedSlot = "1"
local SelectedPattern = DEFAULT_PATTERN

local RouteStore = { routes = {} }

local currentToken = nil
local currentMoveTarget = nil
local currentMode = "idle"
local lastTargetScan = 0
local lastProgressAt = 0
local lastRootPosition = nil
local patrolPoints = nil
local patrolIndex = 1
local lastMoveCommandAt = 0
local lastMoveTarget = nil
local activePathSignature = nil
local customRoamTick = 0

local function serializeVector3(position)
    return {
        x = math.floor(position.X * 100) / 100,
        y = math.floor(position.Y * 100) / 100,
        z = math.floor(position.Z * 100) / 100
    }
end

local function deserializeVector3(data)
    if type(data) ~= "table" then
        return nil
    end

    if type(data.x) ~= "number" or type(data.y) ~= "number" or type(data.z) ~= "number" then
        return nil
    end

    return Vector3.new(data.x, data.y, data.z)
end

local function loadRouteStore()
    if not readfile or not isfile then
        return
    end

    if not isfile(ROUTE_FILE) then
        return
    end

    local ok, content = pcall(readfile, ROUTE_FILE)
    if not ok or type(content) ~= "string" or content == "" then
        return
    end

    local decodedOk, decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)

    if decodedOk and type(decoded) == "table" and type(decoded.routes) == "table" then
        RouteStore = decoded
    end
end

local function saveRouteStore()
    if not writefile then
        return
    end

    pcall(function()
        writefile(ROUTE_FILE, HttpService:JSONEncode(RouteStore))
    end)
end

local function ensureFieldRoute(fieldName)
    RouteStore.routes[fieldName] = RouteStore.routes[fieldName] or { points = {} }
    RouteStore.routes[fieldName].points = RouteStore.routes[fieldName].points or {}
    return RouteStore.routes[fieldName]
end

local function getSavedRoutePoint(fieldName, index)
    local route = ensureFieldRoute(fieldName)
    return deserializeVector3(route.points[tostring(index)])
end

local function getSavedRoutePoints(fieldName)
    local points = {}
    for index = 1, 4 do
        points[index] = getSavedRoutePoint(fieldName, index)
    end
    return points
end

local function hasCompleteCustomRoute(fieldName)
    local points = getSavedRoutePoints(fieldName)
    for index = 1, 4 do
        if not points[index] then
            return false
        end
    end
    return true
end

local function saveCurrentFieldPoint(fieldName, index, position)
    local route = ensureFieldRoute(fieldName)
    route.points[tostring(index)] = serializeVector3(position)
    saveRouteStore()
end

local function clearCurrentFieldRoute(fieldName)
    local route = ensureFieldRoute(fieldName)
    route.points = {}
    saveRouteStore()
end

local function getCharacterParts()
    local character = Player.Character
    if not character then
        return nil, nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        return character, nil, nil
    end

    return character, humanoid, rootPart
end

local function getFieldData()
    return Fields[SelectedField] or Fields[DEFAULT_FIELD]
end

local function horizontalVector(fromPosition, toPosition)
    return Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
end

local function horizontalDistance(fromPosition, toPosition)
    return horizontalVector(fromPosition, toPosition).Magnitude
end

local function isInsideField(field, worldPosition, padding)
    local maxX = math.max((field.size.X * 0.5) - (padding or 0), 1)
    local maxZ = math.max((field.size.Z * 0.5) - (padding or 0), 1)
    local offset = worldPosition - field.center

    return math.abs(offset.X) <= maxX and math.abs(offset.Z) <= maxZ
end

local function getFieldCenter(field)
    return field.center + Vector3.new(0, TELEPORT_HEIGHT, 0)
end

local function buildSnakePoints(field)
    local points = {}
    local center = field.center
    local halfX = math.max(field.size.X * 0.38, 12)
    local halfZ = math.max(field.size.Z * 0.38, 12)
    local rowCount = field.size.Z >= 90 and 6 or 5

    points[#points + 1] = center

    for row = 1, rowCount do
        local alpha = rowCount == 1 and 0 or ((row - 1) / (rowCount - 1))
        local z = -halfZ + (halfZ * 2 * alpha)
        local left = center + Vector3.new(-halfX, 0, z)
        local right = center + Vector3.new(halfX, 0, z)

        if row % 2 == 1 then
            points[#points + 1] = left
            points[#points + 1] = right
        else
            points[#points + 1] = right
            points[#points + 1] = left
        end
    end

    points[#points + 1] = center
    return points
end

local function buildLoopPoints(field)
    local center = field.center
    local halfX = math.max(field.size.X * 0.38, 12)
    local halfZ = math.max(field.size.Z * 0.38, 12)

    return {
        center,
        center + Vector3.new(-halfX, 0, -halfZ),
        center + Vector3.new(halfX, 0, -halfZ),
        center + Vector3.new(halfX, 0, halfZ),
        center + Vector3.new(-halfX, 0, halfZ),
        center + Vector3.new(-halfX, 0, -halfZ),
        center
    }
end

local function getPathSignature()
    return SelectedField .. "::" .. SelectedPattern
end

local function invalidatePath()
    patrolPoints = nil
    patrolIndex = 1
    activePathSignature = nil
    customRoamTick = 0
end

local function getPatternPath(field)
    local signature = getPathSignature()
    if activePathSignature ~= signature or not patrolPoints then
        activePathSignature = signature

        if SelectedPattern == "Loop" then
            patrolPoints = buildLoopPoints(field)
        else
            patrolPoints = buildSnakePoints(field)
        end

        patrolIndex = 1
    end

    return patrolPoints
end

local function teleportRoot(rootPart, position)
    pcall(function()
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        rootPart.CFrame = CFrame.new(position.X, position.Y, position.Z)
    end)
end

local function issueMoveTo(humanoid, rootPart, targetPosition, force)
    local moveTarget = Vector3.new(targetPosition.X, rootPart.Position.Y, targetPosition.Z)
    local shouldMove = force
        or not lastMoveTarget
        or horizontalDistance(lastMoveTarget, moveTarget) >= 2
        or (time() - lastMoveCommandAt) >= MOVE_COMMAND_INTERVAL

    if shouldMove then
        humanoid:MoveTo(moveTarget)
        lastMoveTarget = moveTarget
        lastMoveCommandAt = time()
    end
end

local function clearFarmState()
    currentToken = nil
    currentMoveTarget = nil
    currentMode = "idle"
    lastTargetScan = 0
    lastProgressAt = 0
    lastRootPosition = nil
    lastMoveCommandAt = 0
    lastMoveTarget = nil
    invalidatePath()
end

local function getCustomRouteCentroid(points)
    local sum = Vector3.zero
    for index = 1, 4 do
        sum = sum + points[index]
    end
    return sum / 4
end

local function getRandomPointInTriangle(a, b, c)
    local r1 = math.sqrt(math.random())
    local r2 = math.random()

    return a * (1 - r1) + b * (r1 * (1 - r2)) + c * (r1 * r2)
end

local function getCustomRoamPoint(fieldName)
    local points = getSavedRoutePoints(fieldName)
    if not hasCompleteCustomRoute(fieldName) then
        return nil
    end

    local centroid = getCustomRouteCentroid(points)
    customRoamTick = customRoamTick + 1

    if customRoamTick % 4 == 0 then
        local cornerIndex = ((customRoamTick / 4 - 1) % 4) + 1
        return points[cornerIndex]
    end

    local edgeIndex = ((customRoamTick - 1) % 4) + 1
    local nextIndex = (edgeIndex % 4) + 1
    return getRandomPointInTriangle(centroid, points[edgeIndex], points[nextIndex])
end

local function getNextPatrolPoint(field)
    if SelectedPattern == "Custom Route" then
        local customPoint = getCustomRoamPoint(SelectedField)
        if customPoint then
            return customPoint
        end
    end

    local points = getPatternPath(field)
    patrolIndex = (patrolIndex % #points) + 1
    return points[patrolIndex]
end

local function resetFarmToField(rootPart, humanoid)
    local field = getFieldData()
    invalidatePath()

    currentToken = nil
    currentMode = "patrol"
    currentMoveTarget = field.center

    teleportRoot(rootPart, getFieldCenter(field))
    lastRootPosition = rootPart.Position
    lastProgressAt = time()
    issueMoveTo(humanoid, rootPart, currentMoveTarget, true)
end

local function getTokenTexture(token)
    local decal = token:FindFirstChild("FrontDecal") or token:FindFirstChildWhichIsA("Decal")
    if decal and typeof(decal.Texture) == "string" then
        return string.lower(decal.Texture)
    end

    return ""
end

local function isCoconutOrComboToken(token)
    local texture = getTokenTexture(token)
    return token.Name == "C"
        or string.find(texture, "coconut", 1, true) ~= nil
        or string.find(texture, "combo", 1, true) ~= nil
end

local function tokenBelongsToPlayer(token)
    if token.Name == Player.Name then
        return true
    end

    local owner = token:FindFirstChild("Owner")
    if owner then
        if owner:IsA("ObjectValue") then
            return owner.Value == Player
        end
        if owner:IsA("StringValue") then
            return owner.Value == Player.Name
        end
    end

    local playerName = token:FindFirstChild("PlayerName")
    if playerName and playerName:IsA("StringValue") then
        return playerName.Value == Player.Name
    end

    return nil
end

local function isAllowedToken(token, field)
    if not token or not token.Parent or not token:IsA("BasePart") then
        return false
    end

    if not isInsideField(field, token.Position, 0) then
        return false
    end

    if isCoconutOrComboToken(token) then
        return true
    end

    local owned = tokenBelongsToPlayer(token)
    if owned == nil then
        return true
    end

    return owned
end

local function getAllowedTokens(field)
    local collectibles = workspace:FindFirstChild("Collectibles")
    if not collectibles then
        return {}
    end

    local tokens = {}
    for _, token in ipairs(collectibles:GetChildren()) do
        if isAllowedToken(token, field) then
            tokens[#tokens + 1] = token
        end
    end

    return tokens
end

local function getTokenPriority(token)
    if isCoconutOrComboToken(token) then
        return 150
    end

    local texture = getTokenTexture(token)
    if string.find(texture, "mythic", 1, true) then
        return 95
    end
    if string.find(texture, "rare", 1, true) then
        return 55
    end

    return 15
end

local function scoreToken(token, rootPosition, tokens)
    local distance = horizontalDistance(token.Position, rootPosition)
    local cluster = 0

    for _, other in ipairs(tokens) do
        if other ~= token and horizontalDistance(other.Position, token.Position) <= CLUSTER_RADIUS then
            cluster = cluster + 1
        end
    end

    return getTokenPriority(token) - (distance * 0.75) + (cluster * 4)
end

local function chooseBestToken(rootPart, field)
    local tokens = getAllowedTokens(field)
    if #tokens == 0 then
        return nil
    end

    local bestToken = nil
    local bestScore = -math.huge
    local rootPosition = rootPart.Position

    for _, token in ipairs(tokens) do
        local score = scoreToken(token, rootPosition, tokens)
        if token == currentToken then
            score = score + 10
        end

        if score > bestScore then
            bestScore = score
            bestToken = token
        end
    end

    return bestToken
end

local function isCurrentTokenValid(field)
    return currentToken
        and currentToken.Parent
        and currentToken:IsA("BasePart")
        and isInsideField(field, currentToken.Position, 0)
end

local function updateProgress(rootPart, now)
    if not lastRootPosition then
        lastRootPosition = rootPart.Position
        lastProgressAt = now
        return
    end

    if horizontalDistance(rootPart.Position, lastRootPosition) >= 0.8 then
        lastProgressAt = now
        lastRootPosition = rootPart.Position
    end
end

local function isStuck(now)
    return now - lastProgressAt >= STUCK_TIMEOUT
end

local function setPatrolTarget(field)
    currentToken = nil
    currentMode = "patrol"
    currentMoveTarget = getNextPatrolPoint(field)
end

local function ensureFieldCenter(rootPart, humanoid, field)
    if not isInsideField(field, rootPart.Position, FIELD_REENTER_PADDING) then
        resetFarmToField(rootPart, humanoid)
        return true
    end

    return false
end

loadRouteStore()

local Window = Rayfield:CreateWindow({
    Name = "AI FARM v11.6",
    LoadingTitle = "Smart Farm",
    LoadingSubtitle = "Pattern + Route Editor",
    ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Main", 4483362458)

MainTab:CreateToggle({
    Name = "AI AutoFarm",
    CurrentValue = false,
    Callback = function(v)
        Flags.AutoFarm = v

        local _, humanoid, rootPart = getCharacterParts()
        if not v then
            clearFarmState()
        elseif humanoid and rootPart then
            resetFarmToField(rootPart, humanoid)
        end
    end
})

MainTab:CreateToggle({
    Name = "Auto Dig",
    CurrentValue = false,
    Callback = function(v)
        Flags.AutoDig = v
    end
})

MainTab:CreateToggle({
    Name = "Enable Speed",
    CurrentValue = false,
    Callback = function(v)
        Flags.EnableSpeed = v
    end
})

MainTab:CreateSlider({
   Name = "Walk Speed",
   Range = {10, 120},
   Increment = 1,
   CurrentValue = 35,
   Callback = function(v) Flags.Speed = v end
})

MainTab:CreateDropdown({
    Name = "Field",
    Options = FieldNames,
    CurrentOption = {DEFAULT_FIELD},
    Callback = function(opt)
        SelectedField = typeof(opt) == "table" and (opt[1] or DEFAULT_FIELD) or (opt or DEFAULT_FIELD)

        local _, humanoid, rootPart = getCharacterParts()
        clearFarmState()
        if Flags.AutoFarm and humanoid and rootPart then
            resetFarmToField(rootPart, humanoid)
        end
    end
})

MainTab:CreateDropdown({
    Name = "Pattern Switcher",
    Options = PatternNames,
    CurrentOption = {DEFAULT_PATTERN},
    Callback = function(opt)
        SelectedPattern = typeof(opt) == "table" and (opt[1] or DEFAULT_PATTERN) or (opt or DEFAULT_PATTERN)
        invalidatePath()

        local _, humanoid, rootPart = getCharacterParts()
        if Flags.AutoFarm and humanoid and rootPart then
            resetFarmToField(rootPart, humanoid)
        end
    end
})

MainTab:CreateDropdown({
   Name = "Слот Плантера",
   Options = {"1","2","3","4","5","6","7"},
   CurrentOption = {"1"},
   Callback = function(Option)
        SelectedSlot = typeof(Option) == "table" and (Option[1] or "1") or (Option or "1")
   end,
})

MainTab:CreateToggle({
   Name = "Auto-Planter",
   CurrentValue = false,
   Callback = function(Value)
        Flags.AutoPlanter = Value
   end,
})

MainTab:CreateButton({
    Name = "TP To Selected Field",
    Callback = function()
        local _, _, rootPart = getCharacterParts()
        if rootPart then
            teleportRoot(rootPart, getFieldCenter(getFieldData()))
        end
    end
})

MainTab:CreateButton({
    Name = "Save Pos 1 For Current Field",
    Callback = function()
        local _, _, rootPart = getCharacterParts()
        if rootPart then
            saveCurrentFieldPoint(SelectedField, 1, rootPart.Position)
            invalidatePath()
        end
    end
})

MainTab:CreateButton({
    Name = "Save Pos 2 For Current Field",
    Callback = function()
        local _, _, rootPart = getCharacterParts()
        if rootPart then
            saveCurrentFieldPoint(SelectedField, 2, rootPart.Position)
            invalidatePath()
        end
    end
})

MainTab:CreateButton({
    Name = "Save Pos 3 For Current Field",
    Callback = function()
        local _, _, rootPart = getCharacterParts()
        if rootPart then
            saveCurrentFieldPoint(SelectedField, 3, rootPart.Position)
            invalidatePath()
        end
    end
})

MainTab:CreateButton({
    Name = "Save Pos 4 For Current Field",
    Callback = function()
        local _, _, rootPart = getCharacterParts()
        if rootPart then
            saveCurrentFieldPoint(SelectedField, 4, rootPart.Position)
            invalidatePath()
        end
    end
})

MainTab:CreateButton({
    Name = "Clear Saved Route For Current Field",
    Callback = function()
        clearCurrentFieldRoute(SelectedField)
        invalidatePath()
    end
})

RunService.RenderStepped:Connect(function(deltaTime)
    if not Flags.EnableSpeed then
        return
    end

    local _, humanoid, rootPart = getCharacterParts()
    if not humanoid or not rootPart then
        return
    end

    local direction = nil

    if Flags.AutoFarm and currentMoveTarget then
        local delta = horizontalVector(rootPart.Position, currentMoveTarget)
        if delta.Magnitude > 0.5 then
            direction = delta.Unit
        end
    elseif humanoid.MoveDirection.Magnitude > 0 then
        direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z).Unit
    end

    if not direction then
        return
    end

    humanoid.AutoRotate = true

    local step = Flags.Speed * deltaTime * SPEED_MULTIPLIER
    local nextPosition = rootPart.Position + Vector3.new(direction.X * step, 0, direction.Z * step)
    rootPart.CFrame = CFrame.lookAt(nextPosition, nextPosition + direction)
end)

task.spawn(function()
    while true do
        task.wait(FARM_INTERVAL)

        if not Flags.AutoFarm then
            continue
        end

        local _, humanoid, rootPart = getCharacterParts()
        if not humanoid or not rootPart then
            clearFarmState()
            continue
        end

        humanoid.AutoRotate = true

        local field = getFieldData()
        local now = time()

        updateProgress(rootPart, now)

        if ensureFieldCenter(rootPart, humanoid, field) then
            continue
        end

        if not patrolPoints and SelectedPattern ~= "Custom Route" then
            getPatternPath(field)
            currentMoveTarget = field.center
            currentMode = "patrol"
            issueMoveTo(humanoid, rootPart, currentMoveTarget, true)
        elseif SelectedPattern == "Custom Route" and not hasCompleteCustomRoute(SelectedField) then
            getPatternPath(field)
        end

        if not isCurrentTokenValid(field) then
            currentToken = nil
            if currentMode == "token" then
                setPatrolTarget(field)
            end
        end

        if now - lastTargetScan >= TARGET_SCAN_INTERVAL then
            lastTargetScan = now

            local bestToken = chooseBestToken(rootPart, field)
            if bestToken then
                currentToken = bestToken
                currentMoveTarget = bestToken.Position
                currentMode = "token"
            elseif currentMode ~= "patrol" then
                setPatrolTarget(field)
            elseif not currentMoveTarget then
                setPatrolTarget(field)
            end
        end

        if currentMode == "token" and currentMoveTarget then
            if horizontalDistance(rootPart.Position, currentMoveTarget) <= TOKEN_REACH_DISTANCE then
                currentToken = nil
                setPatrolTarget(field)
            elseif isStuck(now) then
                currentToken = nil
                setPatrolTarget(field)
                lastProgressAt = now
            else
                issueMoveTo(humanoid, rootPart, currentMoveTarget, false)
            end
        elseif currentMode == "patrol" and currentMoveTarget then
            if horizontalDistance(rootPart.Position, currentMoveTarget) <= PATROL_REACH_DISTANCE then
                currentMoveTarget = getNextPatrolPoint(field)
                issueMoveTo(humanoid, rootPart, currentMoveTarget, true)
            elseif isStuck(now) then
                currentMoveTarget = getNextPatrolPoint(field)
                lastProgressAt = now
                issueMoveTo(humanoid, rootPart, currentMoveTarget, true)
            else
                issueMoveTo(humanoid, rootPart, currentMoveTarget, false)
            end
        else
            setPatrolTarget(field)
            issueMoveTo(humanoid, rootPart, currentMoveTarget, true)
        end
    end
end)

task.spawn(function()
    while task.wait(DIG_INTERVAL) do
        if Flags.AutoDig then
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        end
    end
end)

task.spawn(function()
    local keyMap = {
        ["1"] = Enum.KeyCode.One,
        ["2"] = Enum.KeyCode.Two,
        ["3"] = Enum.KeyCode.Three,
        ["4"] = Enum.KeyCode.Four,
        ["5"] = Enum.KeyCode.Five,
        ["6"] = Enum.KeyCode.Six,
        ["7"] = Enum.KeyCode.Seven
    }

    while true do
        task.wait(math.random(20, 30) / 10)

        if Flags.AutoPlanter then
            local keyCode = keyMap[SelectedSlot]
            if keyCode then
                VIM:SendKeyEvent(true, keyCode, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, keyCode, false, game)
            end
        end
    end
end)

Player.CharacterRemoving:Connect(function()
    clearFarmState()
end)
