local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer

local DEFAULT_FIELD = "Sunflower Field"
local FARM_INTERVAL = 0.08
local TARGET_SCAN_INTERVAL = 0.25
local DIG_INTERVAL = 0.12
local STUCK_TIMEOUT = 1.1
local WANDER_INTERVAL = 0.5
local TELEPORT_HEIGHT = 3
local TARGET_REACH_DISTANCE = 6
local TELEPORT_EPSILON = 4
local CLUSTER_RADIUS = 10
local RANDOM_PADDING = 8

local Fields = {
    ["Sunflower Field"] = { center = Vector3.new(-208, 5, -185), size = Vector3.new(72, 6, 72) },
    ["Dandelion Field"] = { center = Vector3.new(-30, 5, 225), size = Vector3.new(72, 6, 72) },
    ["Mushroom Field"] = { center = Vector3.new(-91, 5, 61), size = Vector3.new(65, 6, 65) },
    ["Blue Flower Field"] = { center = Vector3.new(113, 5, 101), size = Vector3.new(72, 6, 72) },
    ["Clover Field"] = { center = Vector3.new(174, 32, 194), size = Vector3.new(72, 6, 72) },
    ["Spider Field"] = { center = Vector3.new(-29, 20, -29), size = Vector3.new(72, 6, 72) },
    ["Bamboo Field"] = { center = Vector3.new(317, 21, -91), size = Vector3.new(72, 6, 72) },
    ["Strawberry Field"] = { center = Vector3.new(-169, 20, -3), size = Vector3.new(72, 6, 72) },
    ["Pineapple Patch"] = { center = Vector3.new(254, 68, -201), size = Vector3.new(72, 6, 72) },
    ["Stump Field"] = { center = Vector3.new(430, 5, -121), size = Vector3.new(72, 6, 72) },
    ["Cactus Field"] = { center = Vector3.new(-326, 68, 1), size = Vector3.new(72, 6, 72) },
    ["Pumpkin Patch"] = { center = Vector3.new(-187, 68, -186), size = Vector3.new(72, 6, 72) },
    ["Pine Tree Forest"] = { center = Vector3.new(-330, 114, -381), size = Vector3.new(80, 6, 80) },
    ["Rose Field"] = { center = Vector3.new(-260, 20, 182), size = Vector3.new(72, 6, 72) },
    ["Mountain Top Field"] = { center = Vector3.new(83, 176, -163), size = Vector3.new(85, 6, 85) },
    ["Coconut Field"] = { center = Vector3.new(-255, 71, 464), size = Vector3.new(95, 6, 95) },
    ["Pepper Patch"] = { center = Vector3.new(-486, 126, 544), size = Vector3.new(80, 6, 80) }
}

local FieldNames = {}
for name in pairs(Fields) do
    FieldNames[#FieldNames + 1] = name
end
table.sort(FieldNames)

local Flags = {
    AutoFarm = false,
    AutoDig = false,
    EnableSpeed = false,
    AutoPlanter = false,
    Speed = 16
}

local SelectedField = DEFAULT_FIELD
local SelectedSlot = "1"
local currentTarget = nil
local currentTargetPosition = nil
local currentMode = "idle"
local lastTargetScan = 0
local lastProgressAt = 0
local lastRootPosition = nil
local lastTeleportPosition = nil
local lastTeleportAt = 0
local wanderIndex = 0
local lastWanderAt = 0

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

local function getFieldTransform(field)
    return CFrame.new(field.center), field.size
end

local function isInsideField(field, worldPosition, padding)
    local fieldCFrame, fieldSize = getFieldTransform(field)
    local localPosition = fieldCFrame:PointToObjectSpace(worldPosition)
    local maxX = math.max((fieldSize.X * 0.5) - (padding or 0), 1)
    local maxZ = math.max((fieldSize.Z * 0.5) - (padding or 0), 1)

    return math.abs(localPosition.X) <= maxX and math.abs(localPosition.Z) <= maxZ
end

local function getRandomPointInField(field)
    local fieldCFrame, fieldSize = getFieldTransform(field)
    local halfX = math.max((fieldSize.X * 0.5) - RANDOM_PADDING, 2)
    local halfZ = math.max((fieldSize.Z * 0.5) - RANDOM_PADDING, 2)

    return (fieldCFrame * CFrame.new(
        math.random(-halfX * 100, halfX * 100) / 100,
        TELEPORT_HEIGHT,
        math.random(-halfZ * 100, halfZ * 100) / 100
    )).Position
end

local function getWanderPoints(field)
    local center = field.center
    local halfX = math.max((field.size.X * 0.5) - RANDOM_PADDING, 4)
    local halfZ = math.max((field.size.Z * 0.5) - RANDOM_PADDING, 4)

    return {
        center + Vector3.new(0, TELEPORT_HEIGHT, 0),
        center + Vector3.new(-halfX, TELEPORT_HEIGHT, -halfZ),
        center + Vector3.new(halfX, TELEPORT_HEIGHT, -halfZ),
        center + Vector3.new(-halfX, TELEPORT_HEIGHT, halfZ),
        center + Vector3.new(halfX, TELEPORT_HEIGHT, halfZ),
        center + Vector3.new(0, TELEPORT_HEIGHT, -halfZ),
        center + Vector3.new(0, TELEPORT_HEIGHT, halfZ),
        center + Vector3.new(-halfX, TELEPORT_HEIGHT, 0),
        center + Vector3.new(halfX, TELEPORT_HEIGHT, 0)
    }
end

local function getNextWanderPoint(field)
    local points = getWanderPoints(field)
    wanderIndex = (wanderIndex % #points) + 1
    return points[wanderIndex]
end

local function teleportRoot(rootPart, position)
    pcall(function()
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        rootPart.CFrame = CFrame.new(position.X, position.Y, position.Z)
    end)
end

local function shouldTeleportTo(position, now)
    if not lastTeleportPosition then
        return true
    end

    if (lastTeleportPosition - position).Magnitude >= TELEPORT_EPSILON then
        return true
    end

    return now - lastTeleportAt >= 0.35
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
        return 140
    end

    local texture = getTokenTexture(token)
    if string.find(texture, "mythic", 1, true) then
        return 90
    end
    if string.find(texture, "rare", 1, true) then
        return 50
    end

    return 10
end

local function scoreToken(token, rootPosition, tokens)
    local distance = (token.Position - rootPosition).Magnitude
    local cluster = 0

    for _, other in ipairs(tokens) do
        if other ~= token and (other.Position - token.Position).Magnitude <= CLUSTER_RADIUS then
            cluster = cluster + 1
        end
    end

    return getTokenPriority(token) - (distance * 0.7) + (cluster * 4)
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
        if token == currentTarget then
            score = score + 12
        end

        if score > bestScore then
            bestScore = score
            bestToken = token
        end
    end

    return bestToken
end

local function isTargetValid(field)
    return currentTarget
        and currentTarget.Parent
        and currentTarget:IsA("BasePart")
        and isInsideField(field, currentTarget.Position, 0)
end

local function clearFarmTarget()
    currentTarget = nil
    currentTargetPosition = nil
    currentMode = "idle"
end

local function updateProgress(rootPart, now)
    if not lastRootPosition then
        lastRootPosition = rootPart.Position
        lastProgressAt = now
        return
    end

    if (rootPart.Position - lastRootPosition).Magnitude >= 1.5 then
        lastProgressAt = now
        lastRootPosition = rootPart.Position
    end
end

local function isStuck(now)
    return now - lastProgressAt >= STUCK_TIMEOUT
end

local function setFarmTarget(position, mode)
    currentTargetPosition = position
    currentMode = mode
end

local Window = Rayfield:CreateWindow({
    Name = "AI FARM v11.3",
    LoadingTitle = "Smart Farm",
    LoadingSubtitle = "AI TP Farm",
    ConfigurationSaving = { Enabled = false }
})

local Tab = Window:CreateTab("Main", 4483362458)

Tab:CreateToggle({
    Name = "AI AutoFarm",
    CurrentValue = false,
    Callback = function(v)
        Flags.AutoFarm = v
        if not v then
            clearFarmTarget()
        else
            local field = getFieldData()
            setFarmTarget(getRandomPointInField(field), "wander")
        end
    end
})

Tab:CreateToggle({
    Name = "Auto Dig",
    CurrentValue = false,
    Callback = function(v)
        Flags.AutoDig = v
    end
})

Tab:CreateToggle({
    Name = "Enable Speed",
    CurrentValue = false,
    Callback = function(v)
        Flags.EnableSpeed = v
    end
})

Tab:CreateSlider({
   Name = "Walk Speed",
   Range = {10, 30},
   Increment = 1,
   CurrentValue = 16,
   Callback = function(v) Flags.Speed = v end
})

Tab:CreateDropdown({
    Name = "Field",
    Options = FieldNames,
    CurrentOption = {DEFAULT_FIELD},
    Callback = function(opt)
        SelectedField = typeof(opt) == "table" and (opt[1] or DEFAULT_FIELD) or (opt or DEFAULT_FIELD)
        wanderIndex = 0
        clearFarmTarget()
        if Flags.AutoFarm then
            local field = getFieldData()
            setFarmTarget(getRandomPointInField(field), "wander")
        end
    end
})

Tab:CreateDropdown({
   Name = "Слот Плантера",
   Options = {"1","2","3","4","5","6","7"},
   CurrentOption = {"1"},
   Callback = function(Option)
        SelectedSlot = typeof(Option) == "table" and (Option[1] or "1") or (Option or "1")
   end,
})

Tab:CreateToggle({
   Name = "Auto-Planter",
   CurrentValue = false,
   Callback = function(Value)
        Flags.AutoPlanter = Value
   end,
})

Tab:CreateButton({
    Name = "TP To Selected Field",
    Callback = function()
        local field = getFieldData()
        local _, _, rootPart = getCharacterParts()
        if rootPart then
            teleportRoot(rootPart, getRandomPointInField(field))
        end
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

    local moveDirection = humanoid.MoveDirection
    if moveDirection.Magnitude <= 0 then
        return
    end

    local offset = moveDirection.Unit * (Flags.Speed * deltaTime * 3)
    rootPart.CFrame = rootPart.CFrame + offset
end)

task.spawn(function()
    while true do
        task.wait(FARM_INTERVAL)

        if not Flags.AutoFarm then
            continue
        end

        local _, _, rootPart = getCharacterParts()
        if not rootPart then
            clearFarmTarget()
            continue
        end

        local field = getFieldData()
        local now = time()
        updateProgress(rootPart, now)

        if not isTargetValid(field) then
            currentTarget = nil
        end

        local rootDistance = currentTargetPosition and (rootPart.Position - currentTargetPosition).Magnitude or math.huge

        if now - lastTargetScan >= TARGET_SCAN_INTERVAL or not currentTarget or rootDistance <= TARGET_REACH_DISTANCE or isStuck(now) then
            lastTargetScan = now

            local bestToken = chooseBestToken(rootPart, field)
            if bestToken then
                currentTarget = bestToken
                setFarmTarget(bestToken.Position + Vector3.new(0, TELEPORT_HEIGHT, 0), "token")
            else
                currentTarget = nil
                if currentMode ~= "wander" or now - lastWanderAt >= WANDER_INTERVAL or isStuck(now) then
                    setFarmTarget(getNextWanderPoint(field), "wander")
                    lastWanderAt = now
                end
            end
        end

        if currentTargetPosition and shouldTeleportTo(currentTargetPosition, now) then
            if currentMode == "token" and (rootPart.Position - currentTargetPosition).Magnitude <= TARGET_REACH_DISTANCE then
                lastTeleportPosition = currentTargetPosition
                lastTeleportAt = now
            else
                teleportRoot(rootPart, currentTargetPosition)
                lastTeleportPosition = currentTargetPosition
                lastTeleportAt = now
            end
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
    clearFarmTarget()
    lastRootPosition = nil
    lastProgressAt = 0
    lastTeleportPosition = nil
    lastTeleportAt = 0
end)
