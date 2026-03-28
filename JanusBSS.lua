-- ════════════════════════════════════════════════════
--   BSS ULTIMATE FARM  |  Final v13
--   Ability tokens only (ParticleEmitter filter)
-- ════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local VIM               = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local PGui   = Player.PlayerGui

-- ─── Конфиг ──────────────────────────────────────
local CFG = {
    AutoFarm    = false,
    AutoDig     = false,
    AutoConvert = false,
    AutoItem    = false,
    ItemSlot    = 1,
    ItemDelay   = 0.6,
    FarmSpeed   = 80,
    FieldRadius = 50,
    HivePos     = nil,
    FieldPos    = nil,
}

local _converting = false

-- ─── Ремоуты ─────────────────────────────────────
local function findR(name)
    local r = ReplicatedStorage:FindFirstChild(name, true)
    if not r then warn("[BSS] Not found: " .. name) end
    return r
end

local R = {
    ToolClick = findR("toolClick"),
}

-- ─── Персонаж ────────────────────────────────────
local Char, HRP, Hum

local function loadChar()
    Char = Player.Character or Player.CharacterAdded:Wait()
    HRP  = Char:WaitForChild("HumanoidRootPart")
    Hum  = Char:WaitForChild("Humanoid")
end
loadChar()

Player.CharacterAdded:Connect(function()
    _converting = false
    task.wait(0.5)
    loadChar()
end)

-- ─── Pollen ──────────────────────────────────────
local _pollenLabel = nil

local function findPollenLabel()
    if _pollenLabel and _pollenLabel.Parent then return _pollenLabel end
    _pollenLabel = nil
    local function scan(p, d)
        if d > 12 then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextLabel") or c:IsA("TextBox") then
                local t = (c.Text or ""):gsub("[,%s]", "")
                local a, b = t:match("^(%d+)/(%d+)$")
                if a and b and tonumber(b) > 100000 then
                    _pollenLabel = c
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

-- ─── Фильтр токенов способностей ─────────────────
-- Ability token = BasePart + Transparent==0 + вертикальный
--               + ParticleEmitter (золотые искры) + Decal
-- Обычные токены поля (пыльца/мёд) ParticleEmitter НЕ имеют
local function isAbilityToken(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("BasePart") then return false end
    local ok, res = pcall(function()
        if obj.Transparency ~= 0 then return false end
        if math.abs(obj.CFrame.YVector.Y - 1) > 0.01 then return false end
        if not obj:FindFirstChildOfClass("ParticleEmitter") then return false end
        if not obj:FindFirstChildOfClass("Decal") then return false end
        return true
    end)
    return ok and res
end

-- ─── Кэш токенов способностей ────────────────────
local _tokCache     = {}
local _collectibles = nil

local function registerToken(child)
    -- Ждём чуть чтобы ParticleEmitter успел загрузиться
    task.spawn(function()
        task.wait(0.1)
        if isAbilityToken(child) then
            _tokCache[child] = true
            child.AncestryChanged:Connect(function()
                _tokCache[child] = nil
            end)
        end
    end)
end

local function initCollectibles()
    _collectibles = workspace:WaitForChild("Collectibles", 15)
    if not _collectibles then
        warn("[BSS] workspace.Collectibles not found!")
        return
    end

    -- Уже существующие
    for _, child in ipairs(_collectibles:GetChildren()) do
        registerToken(child)
    end

    -- Новые
    _collectibles.ChildAdded:Connect(registerToken)
end

task.spawn(initCollectibles)

-- ─── Ближайший ability-токен в радиусе поля ──────
local function getNearestToken()
    if not HRP then return nil end

    local best, bestDist = nil, math.huge
    local myPos = HRP.Position

    for child in pairs(_tokCache) do
        if not child or not child.Parent then
            _tokCache[child] = nil
            continue
        end

        local pos = child.Position

        -- Фильтр по радиусу поля (если поле установлено)
        if CFG.FieldPos then
            local flatDist = Vector3.new(
                pos.X - CFG.FieldPos.X, 0, pos.Z - CFG.FieldPos.Z
            ).Magnitude
            if flatDist > CFG.FieldRadius then continue end
        end

        local d = (myPos - pos).Magnitude
        if d < bestDist then
            bestDist = d
            best     = pos
        end
    end

    return best
end

-- ─── UI ──────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Win   = Rayfield:CreateWindow({
    Name = "BSS ULTIMATE FARM",
    ConfigurationSaving = { Enabled = false },
})

local TFarm = Win:CreateTab("Farm",      4483362458)
local TItem = Win:CreateTab("Items",     4483362458)
local TPos  = Win:CreateTab("Positions", 4483362458)

local ParaStatus = TFarm:CreateParagraph({ Title = "Status",          Content = "Idle" })
local ParaPollen = TFarm:CreateParagraph({ Title = "Pollen",          Content = "0.0%" })
local ParaTokens = TFarm:CreateParagraph({ Title = "Ability tokens",  Content = "0" })

local function setStatus(s)
    pcall(function() ParaStatus:Set({ Title = "Status", Content = s }) end)
end

-- Farm
TFarm:CreateSection("Auto Farm")

TFarm:CreateToggle({ Name = "Auto Farm (Ability Tokens)", CurrentValue = false,
    Callback = function(v)
        CFG.AutoFarm = v
        setStatus(v and "Farming..." or "Idle")
    end
})

TFarm:CreateToggle({ Name = "Auto Dig", CurrentValue = false,
    Callback = function(v) CFG.AutoDig = v end
})

TFarm:CreateToggle({ Name = "Auto Convert (нужны точки!)", CurrentValue = false,
    Callback = function(v)
        CFG.AutoConvert = v
        if v and (not CFG.HivePos or not CFG.FieldPos) then
            Rayfield:Notify({
                Title   = "Внимание",
                Content = "Установи точки во вкладке Positions!",
                Duration = 5
            })
        end
    end
})

TFarm:CreateSection("Movement")

TFarm:CreateSlider({ Name = "Farm Speed (studs/s)", Range = { 10, 300 }, Increment = 5, CurrentValue = 80,
    Callback = function(v) CFG.FarmSpeed = v end
})

TFarm:CreateSlider({ Name = "Field Radius", Range = { 10, 150 }, Increment = 5, CurrentValue = 50,
    Callback = function(v) CFG.FieldRadius = v end
})

-- Items
TItem:CreateSection("Auto Use Item")

TItem:CreateToggle({ Name = "Auto Use Item", CurrentValue = false,
    Callback = function(v) CFG.AutoItem = v end
})

TItem:CreateSlider({ Name = "Slot (1-7)", Range = { 1, 7 }, Increment = 1, CurrentValue = 1,
    Callback = function(v) CFG.ItemSlot = v end
})

TItem:CreateSlider({ Name = "Delay x0.1s  (6 = 0.6s)", Range = { 1, 50 }, Increment = 1, CurrentValue = 6,
    Callback = function(v) CFG.ItemDelay = v / 10 end
})

-- Positions
TPos:CreateSection("Установи ДО фарма!")

local HivePara  = TPos:CreateParagraph({ Title = "Hive",  Content = "не установлен" })
local FieldPara = TPos:CreateParagraph({ Title = "Field", Content = "не установлен" })

TPos:CreateButton({ Name = "Set Hive (встань у улья)", Callback = function()
    if not HRP then return end
    CFG.HivePos = HRP.Position
    local p = CFG.HivePos
    HivePara:Set({ Title = "Hive OK", Content = ("X:%.1f Y:%.1f Z:%.1f"):format(p.X, p.Y, p.Z) })
    Rayfield:Notify({ Title = "Улей", Content = "Точка сохранена", Duration = 3 })
end })

TPos:CreateButton({ Name = "Set Field (встань в центр поля)", Callback = function()
    if not HRP then return end
    CFG.FieldPos = HRP.Position
    local p = CFG.FieldPos
    FieldPara:Set({ Title = "Field OK", Content = ("X:%.1f Y:%.1f Z:%.1f"):format(p.X, p.Y, p.Z) })
    Rayfield:Notify({ Title = "Поле", Content = "Точка сохранена", Duration = 3 })
end })

TPos:CreateButton({ Name = "Сбросить точки", Callback = function()
    CFG.HivePos = nil
    CFG.FieldPos = nil
    HivePara:Set({ Title = "Hive",  Content = "не установлен" })
    FieldPara:Set({ Title = "Field", Content = "не установлен" })
    Rayfield:Notify({ Title = "Сброс", Content = "Точки очищены", Duration = 3 })
end })

-- Live UI updater
task.spawn(function()
    while task.wait(0.8) do
        pcall(function()
            ParaPollen:Set({ Title = "Pollen", Content = ("%.1f%%"):format(getPollen()) })
            local count = 0
            for _ in pairs(_tokCache) do count += 1 end
            ParaTokens:Set({ Title = "Ability tokens", Content = tostring(count) })
        end)
    end
end)

-- ════════════════════════════════════════════════════
--   ЛОГИКА
-- ════════════════════════════════════════════════════

-- 1. Auto Dig
task.spawn(function()
    while task.wait(0.1) do
        if CFG.AutoDig and not _converting and R.ToolClick then
            pcall(function() R.ToolClick:InvokeServer() end)
        end
    end
end)

-- 2. Auto Item
local SlotKeys = {
    [1] = Enum.KeyCode.One,   [2] = Enum.KeyCode.Two,
    [3] = Enum.KeyCode.Three, [4] = Enum.KeyCode.Four,
    [5] = Enum.KeyCode.Five,  [6] = Enum.KeyCode.Six,
    [7] = Enum.KeyCode.Seven,
}

task.spawn(function()
    while true do
        task.wait(CFG.ItemDelay)
        if CFG.AutoItem and not _converting then
            local key = SlotKeys[CFG.ItemSlot]
            if key then
                pcall(function()
                    VIM:SendKeyEvent(true,  key, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, key, false, game)
                end)
            end
        end
    end
end)

-- 3. Auto Convert
task.spawn(function()
    while task.wait(0.3) do
        if not CFG.AutoConvert or not CFG.HivePos or _converting then continue end
        if getPollen() < 99 then continue end

        _converting = true
        setStatus("Converting...")

        -- Tween к улью
        pcall(function()
            if not HRP then return end
            local dist = (HRP.Position - CFG.HivePos).Magnitude
            local tw = TweenService:Create(
                HRP,
                TweenInfo.new(math.max(dist / 80, 0.05), Enum.EasingStyle.Linear),
                { CFrame = CFrame.new(CFG.HivePos) }
            )
            tw:Play()
            tw.Completed:Wait()
        end)

        task.wait(0.3)
        VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.15)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)

        -- Ждём конвертацию (таймаут 25с)
        local elapsed = 0
        repeat
            task.wait(0.3)
            elapsed += 0.3
        until getPollen() < 3 or elapsed > 25

        -- Tween обратно
        if CFG.FieldPos then
            pcall(function()
                if not HRP then return end
                local dist = (HRP.Position - CFG.FieldPos).Magnitude
                local tw = TweenService:Create(
                    HRP,
                    TweenInfo.new(math.max(dist / 80, 0.05), Enum.EasingStyle.Linear),
                    { CFrame = CFrame.new(CFG.FieldPos) }
                )
                tw:Play()
                tw.Completed:Wait()
            end)
        end

        _converting = false
        setStatus(CFG.AutoFarm and "Farming..." or "Idle")
    end
end)

-- 4. Auto Farm — CFrame движение к ability-токену
-- Токены собираются автоматически при физическом касании (client-side touch)
RunService.Heartbeat:Connect(function(dt)
    if not CFG.AutoFarm or _converting then return end
    if not HRP or not Hum or Hum.Health <= 0 then return end

    local target = getNearestToken()

    -- Нет ability-токенов — стоим в центре поля
    if not target then
        target = CFG.FieldPos
    end
    if not target then return end

    local pPos   = HRP.Position
    local dx     = target.X - pPos.X
    local dz     = target.Z - pPos.Z
    local flatD  = math.sqrt(dx * dx + dz * dz)

    if flatD > 1.5 then
        local inv  = 1 / flatD
        local step = math.min(CFG.FarmSpeed * dt, flatD)

        local nx = pPos.X + dx * inv * step
        local nz = pPos.Z + dz * inv * step

        -- Y не трогаем — прыжки и парашют работают корректно
        HRP.CFrame = CFrame.lookAt(
            Vector3.new(nx, pPos.Y, nz),
            Vector3.new(target.X, pPos.Y, target.Z)
        )

        -- Гасим горизонтальную инерцию, Y сохраняем
        local vy = HRP.AssemblyLinearVelocity.Y
        HRP.AssemblyLinearVelocity = Vector3.new(0, vy, 0)
    end
end)
