-- BSS AI FARM v10 (GitHub Safe)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
   Name = "AI FARM v10",
   LoadingTitle = "Smart Farm",
   LoadingSubtitle = "Walk Mode",
   ConfigurationSaving = { Enabled = false }
})

local Flags = {
    AutoFarm = false,
    AutoDig = false,
    Speed = 16
}

local SelectedField = "Sunflower Field"

local Fields = {
    ["Sunflower Field"] = Vector3.new(-208,5,-185),
    ["Dandelion Field"] = Vector3.new(-30,5,225),
    ["Blue Flower Field"] = Vector3.new(113,5,101),
    ["Strawberry Field"] = Vector3.new(-169,20,-3),
    ["Coconut Field"] = Vector3.new(-255,71,464)
}

local FieldNames = {}
for k in pairs(Fields) do table.insert(FieldNames, k) end

local Tab = Window:CreateTab("Main", 4483362458)

Tab:CreateToggle({
   Name = "AI AutoFarm",
   CurrentValue = false,
   Callback = function(v) Flags.AutoFarm = v end
})

Tab:CreateToggle({
   Name = "Auto Dig",
   CurrentValue = false,
   Callback = function(v) Flags.AutoDig = v end
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
   CurrentOption = {"Sunflower Field"},
   Callback = function(opt) SelectedField = opt[1] end
})

local lastScan = 0
local cachedTokens = {}

local function GetTokens()
    if tick() - lastScan < 0.3 then return cachedTokens end
    lastScan = tick()

    local result = {}
    local col = workspace:FindFirstChild("Collectibles")
    if not col then return result end

    local field = Fields[SelectedField]

    for _, t in ipairs(col:GetChildren()) do
        if t:IsA("BasePart") then
            if (t.Position - field).Magnitude < 60 then
                table.insert(result, t)
            end
        end
    end

    cachedTokens = result
    return result
end

local function GetPriority(t)
    local d = t:FindFirstChild("FrontDecal")
    if not d then return 1 end

    local tex = string.lower(d.Texture)

    if string.find(tex, "coconut") then return 120 end
    if string.find(tex, "combo") then return 120 end
    if string.find(tex, "mythic") then return 80 end
    if string.find(tex, "rare") then return 50 end

    return 1
end

local function GetBestTarget(hrp)
    local tokens = GetTokens()
    if #tokens == 0 then return nil end

    local best = nil
    local bestScore = -math.huge

    for _, t in ipairs(tokens) do
        local dist = (t.Position - hrp.Position).Magnitude
        if dist > 2 then

            local priority = GetPriority(t)

            local density = 0
            for _, other in ipairs(tokens) do
                if (other.Position - t.Position).Magnitude < 12 then
                    density = density + 1
                end
            end

            local score = (priority * 2) / dist + (density * 1.5)

            if score > bestScore then
                bestScore = score
                best = t
            end
        end
    end

    return best
end

local currentTarget = nil
local lastUpdate = 0

RunService.Heartbeat:Connect(function()
    if not Flags.AutoFarm then return end

    local char = Player.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    if not hum or not hrp then return end

    hum.WalkSpeed = Flags.Speed

    if tick() - lastUpdate > 0.3 then
        local best = GetBestTarget(hrp)

        if best then
            currentTarget = best.Position
        else
            local field = Fields[SelectedField]
            currentTarget = field + Vector3.new(
                math.random(-25,25),
                0,
                math.random(-25,25)
            )
        end

        lastUpdate = tick()
    end

    if currentTarget then
        hum:MoveTo(currentTarget)
    end
end)

task.spawn(function()
    while task.wait(0.12) do
        if Flags.AutoDig then
            VIM:SendMouseButtonEvent(0,0,0,true,game,0)
        end
    end
end)
