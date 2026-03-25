-- AI FARM WALK FIXED VERSION

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer

local Flags = {
AutoFarm = true,
AutoDig = true
}

local SelectedField = "Sunflower Field"

local Fields = {
["Sunflower Field"] = Vector3.new(-208,5,-185),
}

-- TOKEN CACHE
local lastScan = 0
local cached = {}

local function GetTokens()
if tick() - lastScan < 0.3 then return cached end
lastScan = tick()

```
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

cached = result
return result
```

end

local function GetPriority(t)
local d = t:FindFirstChild("FrontDecal")
if not d then return 1 end

```
local tex = string.lower(d.Texture)

if string.find(tex, "coconut") or string.find(tex, "combo") then
    return 100
end

if string.find(tex, "mythic") then
    return 60
end

if string.find(tex, "rare") then
    return 40
end

return 1
```

end

local function GetBest(hrp)
local tokens = GetTokens()
local best = nil
local bestScore = -math.huge

```
for _, t in ipairs(tokens) do
    local dist = (t.Position - hrp.Position).Magnitude
    if dist > 1 then
        local p = GetPriority(t)
        local score = p / dist

        if score > bestScore then
            bestScore = score
            best = t
        end
    end
end

return best
```

end

-- WALK
local lastMove = 0
local target = nil

RunService.Heartbeat:Connect(function()
local char = Player.Character
if not char then return end

```
local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")

if not hum or not hrp then return end

if tick() - lastMove > 0.3 then
    local best = GetBest(hrp)

    if best then
        target = best.Position
    else
        local field = Fields[SelectedField]
        target = field + Vector3.new(
            math.random(-20,20),
            0,
            math.random(-20,20)
        )
    end

    lastMove = tick()
end

if target then
    hum:MoveTo(target)
end
```

end)

-- AUTODIG
task.spawn(function()
while task.wait(0.15) do
if Flags.AutoDig then
VIM:SendMouseButtonEvent(0,0,0,true,game,0)
end
end
end)
