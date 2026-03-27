-- ════════════════════════════════════════════════════
--   BSS ULTIMATE FARM  v5  |  Полностью новый скрипт
--   Каждый модуль НЕЗАВИСИМ
-- ════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local VIM               = game:GetService("VirtualInputManager")

local Player  = Players.LocalPlayer
local PGui    = Player.PlayerGui

-- ─── Конфиг ──────────────────────────────────────
local CFG = {
    -- AutoFarm
    AutoFarm    = false,
    FieldPos    = nil,
    FieldRadius = 45,
    FarmSpeed   = 60,   -- studs/s для CFrame движения

    -- AutoDig
    AutoDig     = false,

    -- AutoConvert
    AutoConvert = false,
    HivePos     = nil,

    -- AutoItem
    AutoItem    = false,
    ItemSlot    = 1,

    -- SpeedHack
    SpeedHack   = false,
    WalkSpeed   = 70,
}

-- ─── Ремоты ──────────────────────────────────────
local function findRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name, true)
    if not r then warn("[BSS] Remote not found: " .. name) end
    return r
end

local R = {
    ToolClick = findRemote("toolClick"),
    Actives   = findRemote("PlayerActivesCommand"),
    AbilityEv = findRemote("playerAbilityEvent") or findRemote("tokenEvent"),
}

-- ─── Персонаж ────────────────────────────────────
local Char, HRP, Hum
local defaultSpeed = 16

local function loadChar()
    Char = Player.Character or Player.CharacterAdded:Wait()
    HRP  = Char:WaitForChild("HumanoidRootPart")
    Hum  = Char:WaitForChild("Humanoid")
    defaultSpeed = Hum.WalkSpeed
end
loadChar()

Player.CharacterAdded:Connect(function()
    task.wait(0.5)
    loadChar()
    if CFG.SpeedHack and Hum then
        Hum.WalkSpeed = CFG.WalkSpeed
    end
end)

-- ─── Pollen ──────────────────────────────────────
local _pollenCache = nil
local function findPollenLabel()
    if _pollenCache and _pollenCache.Parent then return _pollenCache end
    _pollenCache = nil
    local function scan(p, d)
        if d > 12 then return end
        for _, c in ipairs(p:GetChildren()) do
            if (c:IsA("TextLabel") or c:IsA("TextBox")) then
                local t = (c.Text or ""):gsub("[,%s]", "")
                local a, b = t:match("^(%d+)/(%d+)$")
                if a and b and tonumber(b) > 100000 then
                    _pollenCache = c; return c
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

-- ─── Сканирование токенов ─────────────────────────
-- Ищем ВСЕ небольшие объекты в радиусе поля.
-- Фильтр: BasePart/MeshPart с CanCollide=false (токены обычно без коллизий)
-- и небольшой размер (Magnitude < 10).
local _tokCache = {}
local _tokTime  = 0

local function scanTokens()
    local now = os.clock()
    if now - _tokTime < 0.5 then return _tokCache end
    _tokTime = now
    _tokCache = {}

    if not CFG.FieldPos then return _tokCache end
    local fp = CFG.FieldPos
    local rr = CFG.FieldRadius * CFG.FieldRadius

    local function check(obj)
        local pos
        if (obj:IsA("BasePart") or obj:IsA("MeshPart")) then
            -- Фильтр: без коллизий и маленький (токен)
            if not obj.CanCollide and obj.Size.Magnitude < 12 then
                pos = obj.Position
            end
        elseif obj:IsA("Model") then
            local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if pp and not pp.CanCollide and pp.Size.Magnitude < 12 then
                pos = pp.Position
            end
        end
        if pos then
            local dx = pos.X - fp.X
            local dz = pos.Z - fp.Z
            if dx * dx + dz * dz <= rr then
                table.insert(_tokCache, pos)
            end
        end
    end

    -- Сканируем только прямые потомки workspace (depth 1–3)
    for _, child in ipairs(workspace:GetChildren()) do
        check(child)
        for _, gc in ipairs(child:GetChildren()) do
            check(gc)
            for _, ggc in ipairs(gc:GetChildren()) do
                check(ggc)
            end
        end
    end

    return _tokCache
end

-- ─── UI ──────────────────────────────────────────
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Win = Rayfield:CreateWindow({
    Name = "BSS ULTIMATE FARM",
    ConfigurationSaving = { Enabled = false },
})

local TFarm = Win:CreateTab("⚙ Farm",        4483362458)
local TItem = Win:CreateTab("🎒 Items",      4483362458)
local TPos  = Win:CreateTab("📍 Positions",  4483362458)

-- Статус + поллен
local ParaStatus = TFarm:CreateParagraph({ Title = "Status", Content = "● Idle" })
local ParaPollen = TFarm:CreateParagraph({ Title = "Pollen", Content = "0.0%" })

local function setStatus(s)
    pcall(function() ParaStatus:Set({ Title = "Status", Content = s }) end)
end

-- ── Farm tab ──
TFarm:CreateSection("Auto Farm")

TFarm:CreateToggle({ Name = "Auto Farm (Tokens)", CurrentValue = false, Callback = function(v)
    CFG.AutoFarm = v
    setStatus(v and "● Farming..." or "● Idle")
end })

TFarm:CreateToggle({ Name = "Auto Dig", CurrentValue = false, Callback = function(v)
    CFG.AutoDig = v
end })

TFarm:CreateToggle({ Name = "Auto Convert  ⚠ нужны точки!", CurrentValue = false, Callback = function(v)
    CFG.AutoConvert = v
    if v and (not CFG.HivePos or not CFG.FieldPos) then
        Rayfield:Notify({ Title = "⚠ Внимание", Content = "Установи точки во вкладке Positions!", Duration = 5 })
    end
end })

TFarm:CreateSection("Speed Hack")

TFarm:CreateToggle({ Name = "Speed Hack", CurrentValue = false, Callback = function(v)
    CFG.SpeedHack = v
    if Hum then
        Hum.WalkSpeed = v and CFG.WalkSpeed or defaultSpeed
    end
end })

TFarm:CreateSlider({ Name = "WalkSpeed", Range = { 16, 500 }, Increment = 1, CurrentValue = 70,
    Callback = function(v)
        CFG.WalkSpeed = v
        if CFG.SpeedHack and Hum then
            Hum.WalkSpeed = v
        end
    end
})

TFarm:CreateSection("Farm Settings")

TFarm:CreateSlider({ Name = "Farm Move Speed (studs/s)", Range = { 10, 300 }, Increment = 5, CurrentValue = 60,
    Callback = function(v) CFG.FarmSpeed = v end })

TFarm:CreateSlider({ Name = "Field Radius", Range = { 10, 150 }, Increment = 5, CurrentValue = 45,
    Callback = function(v) CFG.FieldRadius = v end })

-- ── Items tab ──
TItem:CreateSection("Auto Use Item")

TItem:CreateToggle({ Name = "Auto Use Item", CurrentValue = false, Callback = function(v)
    CFG.AutoItem = v
end })

TItem:CreateSlider({ Name = "Slot (1–7)", Range = { 1, 7 }, Increment = 1, CurrentValue = 1,
    Callback = function(v) CFG.ItemSlot = v end })

-- ── Positions tab ──
TPos:CreateSection("⚠ Установи ДО фарма!")

local HivePara  = TPos:CreateParagraph({ Title = "Hive",  Content = "не установлен" })
local FieldPara = TPos:CreateParagraph({ Title = "Field", Content = "не установлен" })

TPos:CreateButton({ Name = "📍 Set Hive  (встань у улья)", Callback = function()
    if not HRP then return end
    CFG.HivePos = HRP.Position
    local p = CFG.HivePos
    HivePara:Set({ Title = "Hive ✓", Content = ("X:%.1f  Y:%.1f  Z:%.1f"):format(p.X, p.Y, p.Z) })
    Rayfield:Notify({ Title = "Улей ✓", Content = "Точка сохранена", Duration = 3 })
end })

TPos:CreateButton({ Name = "📍 Set Field  (встань в центр поля)", Callback = function()
    if not HRP then return end
    CFG.FieldPos = HRP.Position
    _tokCache = {}; _tokTime = 0
    local p = CFG.FieldPos
    FieldPara:Set({ Title = "Field ✓", Content = ("X:%.1f  Y:%.1f  Z:%.1f"):format(p.X, p.Y, p.Z) })
    Rayfield:Notify({ Title = "Поле ✓", Content = "Точка сохранена", Duration = 3 })
end })

TPos:CreateButton({ Name = "🗑 Сбросить точки", Callback = function()
    CFG.HivePos = nil; CFG.FieldPos = nil
    HivePara:Set({ Title = "Hive",  Content = "не установлен" })
    FieldPara:Set({ Title = "Field", Content = "не установлен" })
    Rayfield:Notify({ Title = "Сброс", Content = "Точки очищены", Duration = 3 })
end })

-- Обновление поллена
task.spawn(function()
    while task.wait(0.8) do
        pcall(function()
            ParaPollen:Set({ Title = "Pollen", Content = ("%.1f%%"):format(getPollen()) })
        end)
    end
end)

-- ════════════════════════════════════════════════════
--   МОДУЛИ — каждый полностью независим
-- ════════════════════════════════════════════════════

-- ── 1. SPEED HACK ─────────────────────────────────
-- Каждые 0.5с принудительно держит WalkSpeed
task.spawn(function()
    while task.wait(0.5) do
        if CFG.SpeedHack and Hum then
            pcall(function() Hum.WalkSpeed = CFG.WalkSpeed end)
        end
    end
end)

-- ── 2. AUTO DIG ───────────────────────────────────
-- Независим, работает всегда когда включён
task.spawn(function()
    while task.wait(0.1) do
        if CFG.AutoDig and R.ToolClick then
            pcall(function() R.ToolClick:InvokeServer() end)
        end
    end
end)

-- ── 3. AUTO ITEM ──────────────────────────────────
-- Независим, строго 0.7с, слоты 1–7
task.spawn(function()
    while task.wait(0.7) do
        if CFG.AutoItem and R.Actives then
            pcall(function()
                -- Пробуем оба варианта вызова
                if R.Actives:IsA("RemoteFunction") then
                    R.Actives:InvokeServer(CFG.ItemSlot)
                else
                    R.Actives:FireServer(CFG.ItemSlot)
                end
            end)
        end
    end
end)

-- ── 4. AUTO CONVERT ───────────────────────────────
-- Независим от AutoFarm. При 99% поллена идёт на улей,
-- конвертирует, возвращается на поле (если поле установлено)
local _converting = false
task.spawn(function()
    while task.wait(0.3) do
        if not CFG.AutoConvert then continue end
        if not CFG.HivePos then continue end
        if _converting then continue end
        if getPollen() < 99 then continue end

        _converting = true
        setStatus("● Converting...")

        -- Идём на улей через TweenService
        pcall(function()
            if not HRP then return end
            local dist = (HRP.Position - CFG.HivePos).Magnitude
            local t = TweenInfo.new(math.max(dist / 60, 0.1), Enum.EasingStyle.Linear)
            local tw = TweenService:Create(HRP, t, { CFrame = CFrame.new(CFG.HivePos) })
            tw:Play()
            tw.Completed:Wait()
        end)

        task.wait(0.3)

        -- Конвертируем (клавиша E)
        VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.15)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)

        -- Ждём пока поллен упадёт
        local waited = 0
        repeat task.wait(0.3); waited += 0.3
        until getPollen() < 3 or waited > 30

        -- Возвращаемся на поле если оно задано
        if CFG.FieldPos then
            pcall(function()
                if not HRP then return end
                local dist = (HRP.Position - CFG.FieldPos).Magnitude
                local t = TweenInfo.new(math.max(dist / 60, 0.1), Enum.EasingStyle.Linear)
                local tw = TweenService:Create(HRP, t, { CFrame = CFrame.new(CFG.FieldPos) })
                tw:Play()
                tw.Completed:Wait()
            end)
        end

        _converting = false
        setStatus(CFG.AutoFarm and "● Farming..." or (CFG.AutoConvert and "● Waiting..." or "● Idle"))
    end
end)

-- ── 5. AUTO FARM ──────────────────────────────────
-- Движение по полю через CFrame каждый кадр.
-- Пауза только при конвертации (чтобы не конфликтовали CFrame).
RunService.Heartbeat:Connect(function(dt)
    if not CFG.AutoFarm then return end
    if _converting then return end  -- физическая необходимость, не зависимость
    if not HRP or not Hum or Hum.Health <= 0 then return end
    if not CFG.FieldPos then return end

    local tokens  = scanTokens()
    local target  = nil
    local bestD   = math.huge

    local px = HRP.Position.X
    local pz = HRP.Position.Z

    for _, pos in ipairs(tokens) do
        local dx = pos.X - px
        local dz = pos.Z - pz
        local d  = dx * dx + dz * dz
        if d < bestD then
            bestD  = d
            target = pos
        end
    end

    if not target then return end

    local cur  = HRP.Position
    local dx   = target.X - cur.X
    local dz   = target.Z - cur.Z
    local dist = math.sqrt(dx * dx + dz * dz)

    if dist > 1.5 then
        local inv  = 1 / dist
        local step = math.min(CFG.FarmSpeed * dt, dist)
        local nx   = cur.X + dx * inv * step
        local nz   = cur.Z + dz * inv * step

        HRP.CFrame = CFrame.lookAt(
            Vector3.new(nx, cur.Y, nz),
            Vector3.new(target.X, cur.Y, target.Z)
        )

        -- Убираем горизонтальный дрейф от физики
        local vy = HRP.AssemblyLinearVelocity.Y
        HRP.AssemblyLinearVelocity = Vector3.new(0, vy, 0)
    end
end)

-- ════════════════════════════════════════════════════
warn("[BSS] ✅ Скрипт загружен! v5 — все модули независимы")
