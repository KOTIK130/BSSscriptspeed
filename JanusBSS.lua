local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local rng = Random.new()

local DEFAULT_FIELD = "Sunflower Field"
local TELEPORT_INTERVAL = 0.08
local IDLE_TELEPORT_INTERVAL = 0.45
local DIG_INTERVAL = 0.12
local TELEPORT_HEIGHT = 3
local FIELD_PADDING = 2
local RANDOM_PADDING = 6

local fields = {
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

local fieldOptions = {}
for name in pairs(fields) do
    fieldOptions[#fieldOptions + 1] = name
end
table.sort(fieldOptions)

local state = {
    autoFarm = false,
    autoDig = false,
    enableSpeed = false,
    speed = 16,
    selectedField = DEFAULT_FIELD,
    mouseHeld = false,
    trackedHumanoid = nil,
    savedWalkSpeed = 16,
    speedApplied = false,
    lastIdleTeleport = 0
}

local function getCharacterParts()
    local character = player.Character
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

local function isAlive(humanoid)
    return humanoid and humanoid.Health > 0 and humanoid.Parent ~= nil
end

local function getFieldData(name)
    return fields[name] or fields[DEFAULT_FIELD]
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
        rng:NextNumber(-halfX, halfX),
        TELEPORT_HEIGHT,
        rng:NextNumber(-halfZ, halfZ)
    )).Position
end

local function teleportRoot(rootPart, position)
    pcall(function()
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        rootPart.CFrame = CFrame.new(position.X, position.Y, position.Z)
    end)
end

local function restoreWalkSpeed()
    local _, humanoid = getCharacterParts()
    if humanoid and state.trackedHumanoid == humanoid and state.speedApplied then
        humanoid.WalkSpeed = state.savedWalkSpeed
    end
    state.speedApplied = false
end

local function syncWalkSpeed(humanoid)
    if state.trackedHumanoid ~= humanoid then
        state.trackedHumanoid = humanoid
        state.savedWalkSpeed = humanoid.WalkSpeed
        state.speedApplied = false
    end

    if state.enableSpeed then
        if humanoid.WalkSpeed ~= state.speed then
            humanoid.WalkSpeed = state.speed
        end
        state.speedApplied = true
    elseif state.speedApplied then
        humanoid.WalkSpeed = state.savedWalkSpeed
        state.speedApplied = false
    else
        state.savedWalkSpeed = humanoid.WalkSpeed
    end
end

local function setDigState(enabled)
    if enabled and not state.mouseHeld then
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        state.mouseHeld = true
    elseif not enabled and state.mouseHeld then
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        state.mouseHeld = false
    end
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
    if token.Name == player.Name then
        return true
    end

    local owner = token:FindFirstChild("Owner")
    if owner then
        if owner:IsA("ObjectValue") then
            return owner.Value == player
        end
        if owner:IsA("StringValue") then
            return owner.Value == player.Name
        end
    end

    local playerName = token:FindFirstChild("PlayerName")
    if playerName and playerName:IsA("StringValue") then
        return playerName.Value == player.Name
    end

    local playerValue = token:FindFirstChild("Player")
    if playerValue then
        if playerValue:IsA("ObjectValue") then
            return playerValue.Value == player
        end
        if playerValue:IsA("StringValue") then
            return playerValue.Value == player.Name
        end
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

    local ownerState = tokenBelongsToPlayer(token)
    if ownerState == nil then
        return true
    end

    return ownerState
end

local function getBestToken(rootPart, field)
    local collectibles = workspace:FindFirstChild("Collectibles")
    if not collectibles then
        return nil
    end

    local bestCombo = nil
    local bestComboDistance = math.huge
    local bestToken = nil
    local bestTokenDistance = math.huge

    for _, token in ipairs(collectibles:GetChildren()) do
        if isAllowedToken(token, field) then
            local distance = (token.Position - rootPart.Position).Magnitude

            if isCoconutOrComboToken(token) then
                if distance < bestComboDistance then
                    bestCombo = token
                    bestComboDistance = distance
                end
            elseif distance < bestTokenDistance then
                bestToken = token
                bestTokenDistance = distance
            end
        end
    end

    return bestCombo or bestToken
end

local function teleportToSelectedField()
    local field = getFieldData(state.selectedField)
    local _, _, rootPart = getCharacterParts()
    if field and rootPart then
        teleportRoot(rootPart, getRandomPointInField(field))
        state.lastIdleTeleport = time()
    end
end

local Window = Rayfield:CreateWindow({
    Name = "AI FARM v11.2",
    LoadingTitle = "Smart Farm",
    LoadingSubtitle = "TP Field Farm",
    ConfigurationSaving = { Enabled = false }
})

local Tab = Window:CreateTab("Main", 4483362458)

Tab:CreateToggle({
    Name = "AI AutoFarm (TP)",
    CurrentValue = false,
    Callback = function(value)
        state.autoFarm = value
        if value then
            teleportToSelectedField()
        end
    end
})

Tab:CreateToggle({
    Name = "Auto Dig",
    CurrentValue = false,
    Callback = function(value)
        state.autoDig = value
        if not value then
            setDigState(false)
        end
    end
})

Tab:CreateToggle({
    Name = "Enable Speed",
    CurrentValue = false,
    Callback = function(value)
        state.enableSpeed = value
        if not value then
            restoreWalkSpeed()
        end
    end
})

Tab:CreateSlider({
    Name = "Walk Speed",
    Range = {10, 50},
    Increment = 1,
    CurrentValue = 16,
    Callback = function(value)
        state.speed = value
    end
})

Tab:CreateDropdown({
    Name = "Field",
    Options = fieldOptions,
    CurrentOption = {DEFAULT_FIELD},
    Callback = function(option)
        local nextField = DEFAULT_FIELD

        if typeof(option) == "table" then
            nextField = option[1] or DEFAULT_FIELD
        elseif typeof(option) == "string" then
            nextField = option
        end

        if fields[nextField] then
            state.selectedField = nextField
            if state.autoFarm then
                teleportToSelectedField()
            end
        end
    end
})

Tab:CreateButton({
    Name = "TP To Selected Field",
    Callback = function()
        teleportToSelectedField()
    end
})

task.spawn(function()
    while true do
        task.wait(TELEPORT_INTERVAL)

        local _, humanoid, rootPart = getCharacterParts()
        if humanoid and isAlive(humanoid) and rootPart then
            syncWalkSpeed(humanoid)

            if state.autoFarm then
                local field = getFieldData(state.selectedField)
                local targetToken = getBestToken(rootPart, field)

                if targetToken then
                    teleportRoot(rootPart, targetToken.Position + Vector3.new(0, TELEPORT_HEIGHT, 0))
                    state.lastIdleTeleport = time()
                else
                    local now = time()
                    if not isInsideField(field, rootPart.Position, FIELD_PADDING)
                        or now - state.lastIdleTeleport >= IDLE_TELEPORT_INTERVAL then
                        teleportRoot(rootPart, getRandomPointInField(field))
                        state.lastIdleTeleport = now
                    end
                end
            end
        else
            state.trackedHumanoid = nil
            state.speedApplied = false
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(DIG_INTERVAL)
        local _, humanoid = getCharacterParts()
        setDigState(state.autoDig and isAlive(humanoid))
    end
end)

player.CharacterRemoving:Connect(function()
    setDigState(false)
    state.trackedHumanoid = nil
    state.speedApplied = false
end)
