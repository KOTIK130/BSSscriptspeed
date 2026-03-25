--![ BSS AI FARM v9 WALK MODE ]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer

-- UI
local Window = Rayfield:CreateWindow({
Name = "BSS AI FARM v9",
LoadingTitle = "AI WALK FARM",
LoadingSubtitle = "Human-like movement",
ConfigurationSaving = { Enabled = false }
})

-- FLAGS
local Flags = {
Speed = 16,
AutoFarm = false,
AutoDig = false,
AutoPlanter = false
}

local SelectedField = "Sunflower Field"
local SelectedSlot = "1"

-- FIELDS
local Fields = {
["Sunflower Field"] = Vector3.new(-208,5,-185),
["Dandelion Field"] = Vector3.new(-30,5,225),
["Blue Flower Field"] = Vector3.new(113,5,101),
["Strawberry Field"] = Vector3.new(-169,20,-3),
["Coconut Field"] = Vector3.new(-255,71,464),
}

local FieldNames = {}
for k in pairs(Fields) do table.insert(FieldNames, k) end

-- UI
local Tab = Window:CreateTab("Main", 4483362458)

Tab:CreateToggle({
Name = "AI AutoFarm",
Callback = function(v) Flags.AutoFarm = v end
})

Tab:CreateToggle({
Name = "AutoDig",
Callback = function(v) Flags.AutoDig = v end
})

Tab:CreateToggle({
Name = "AutoPlanter",
Callback = function(v) Flags.AutoPlanter = v end
})

Tab:CreateDropdown({
Name = "Field",
Options = FieldNames,
CurrentOption = {"Sunflower Field"},
Callback = function(opt) SelectedField = opt[1] end
})

-- TOKEN CACHE
local lastScan = 0
local cachedTokens = {}

local function GetTokens()
if tick() - lastScan < 0.3 then return cachedTokens end
lastScan = tick()

```
local list = {}
local col = workspace:FindFirstChild("Collectibles")
if not col then return list end

local field = Fields[SelectedField]

for _, t in ipairs(col:GetChildren()) do
    if t:IsA("BasePart") then
        if (t.Position - field).Magnitude < 60 then
            table.insert(list, t)
        end
    end
end

cachedTokens = list
return list
```

end

-- FIELD TYPE
local function GetFieldType()
local name = string.lower(SelectedField)
if name:find("blue") then return "BLUE" end
if name:find("strawberry") or name:find("rose") then return "RED" end
return "WHITE"
end

-- PRIORITY
local function GetPriority(token)
local d = token:FindFirstChild("FrontDecal")
if not d then return 1 end

```
local tex = string.lower(d.Texture)

if tex:find("coconut") or tex:find("combo") then return 150 end
if tex:find("mythic") then return 90 end
if tex:find("rare") then return 60 end

return 1
```

end

-- AI TARGET
local function GetBestTarget(hrp)
local tokens = GetTokens()
if #tokens == 0 then return nil end

```
local best, bestScore = nil, -math.huge

for _, t in ipairs(tokens) do
    local dist = (t.Position - hrp.Position).Magnitude
    if dist < 2 then continue end

    local priority = GetPriority(t)

    local density = 0
    for _, other in ipairs(tokens) do
        if (other.Position - t.Position).Magnitude < 12 then
            density += 1
        end
    end

    local score = (priority * 2) / dist + (density * 2)

    if score > bestScore then
        bestScore = score
        best = t
    end
end

return best
```

end

-- WALK AI
local currentTarget = nil
local lastMove = 0

RunService.Heartbeat:Connect(function()
if not Flags.AutoFarm then return end

```
local char = Player.Character
if not char then return end

local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")

if not hum or not hrp then return end

hum.WalkSpeed = Flags.Speed

-- обновление цели
if tick() - lastMove > 0.25 then
    local targetToken = GetBestTarget(hrp)

    if targetToken then
        currentTarget = targetToken.Position
    else
        -- fallback движение
        local field = Fields[SelectedField]
        currentTarget = field + Vector3.new(
            math.random(-25,25),
            0,
            math.random(-25,25)
        )
    end

    lastMove = tick()
end

if currentTarget then
    hum:MoveTo(currentTarget)
end
```

end)

-- AUTODIG
task.spawn(function()
while task.wait(0.12) do
if Flags.AutoDig then
VIM:SendMouseButtonEvent(0,0,0,true,game,0)
end
end
end)

-- AUTOPLANTER
task.spawn(function()
while task.wait(1) do
if Flags.AutoPlanter then
pcall(function()
local hotbar = require(game.ReplicatedStorage.Libs.ClientStat).Get("Hotbar")
local item = hotbar[tonumber(SelectedSlot)]

```
            if item then
                game.ReplicatedStorage.Events.PlayerAction:FireServer({
                    Com = "UseItem",
                    Item = item
                })
            end
        end)
    end
end
```

end)
