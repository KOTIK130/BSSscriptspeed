-- ════════════════════════════════════════════════
--   BSS ULTIMATE FARM  |  Final Version
-- ════════════════════════════════════════════════
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local VIM               = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local PGui   = Player.PlayerGui

-- ─── Flags ───────────────────────────────────────
local Flags = {
    AutoFarm    = false,
    AutoDig     = false,
    AutoConvert = false,
    AutoItem    = false,
    ItemSlot    = 1,
    CFrameSpeed = 60,
    FieldRadius = 45,
    HivePos     = nil,
    FieldPos    = nil,
}

local isConverting = false

-- ─── Remotes ─────────────────────────────────────
local function findR(name)
    local r = ReplicatedStorage:FindFirstChild(name, true)
    if not r then warn("[BSS] Remote not found: "..name) end
    return r
end

local R = {
    ToolClick = findR("toolClick"),            -- InvokeServer() — копание
    Actives   = findR("PlayerActivesCommand"), -- InvokeServer("Use", slot) — предметы
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
    isConverting = false
    task.wait(0.5)
    loadChar()
end)

-- ─── Pollen Parser ───────────────────────────────
local _pollenCache = nil
local function findPollenLabel()
    if _pollenCache and _pollenCache.Parent then return _pollenCache end
    _pollenCache = nil
    local function scan(parent, depth)
        if depth > 10 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("TextLabel") or c:IsA("TextBox") then
                local t = (c.Text or ""):gsub("[,%s]","")
                local a, b = t:match("^(%d+)/(%d+)$")
                if a and b and tonumber(b) > 100000 then
                    _pollenCache = c; return c
                end
            end
            local f = scan(c, depth+1)
            if f then return f end
        end
    end
    return scan(PGui, 0)
end

local function getPollenPct()
    local ok, v = pcall(function()
        local lbl = findPollenLabel()
        if not lbl then return 0 end
        local t = lbl.Text:gsub("[,%s]","")
        local cur, max = t:match("(%d+)/(%d+)")
        if not cur then return 0 end
        local m = tonumber(max)
        return m > 0 and (tonumber(cur)/m*100) or 0
    end)
    return ok and v or 0
end

-- ─── Tween Teleport (для конвертации) ────────────
local curTween = nil
local function tweenTo(pos)
    if not HRP then return end
    if curTween then curTween:Cancel() end
    local dist = (HRP.Position - pos).Magnitude
    -- скорость = прямо из слайдера (studs/s)
    local t = TweenInfo.new(math.max(dist / Flags.CFrameSpeed, 0.05), Enum.EasingStyle.Linear)
    curTween = TweenService:Create(HRP, t, {CFrame = CFrame.new(pos)})
    curTween:Play()
    curTween.Completed:Wait()
    curTween = nil
end

-- ─── Поиск токенов в workspace ───────────────────
-- Ищем ВСЕ объекты в радиусе поля (без фильтра по имени)
-- Сканируем: workspace напрямую + один уровень вложенных папок/моделей
local _tokenCache     = {}
local _tokenCacheTime = 0

local function getTokensInField()
    if not Flags.FieldPos then return {} end
    local now = os.clock()
    if now - _tokenCacheTime < 0.25 then return _tokenCache end
    _tokenCacheTime = now
    _tokenCache = {}

    local fp = Flags.FieldPos
    local r  = Flags.FieldRadius

    local function checkObj(obj)
        -- Пропускаем служебные объекты (terrain, camera, baseplate и т.д.)
        if obj:IsA("Terrain") or obj:IsA("Camera") then return end
        -- Пропускаем сам персонаж
        if obj == Char then return end
        -- Пропускаем других игроков
        if Players:GetPlayerFromCharacter(obj) then return end

        local pos
        if obj:IsA("BasePart") then
            pos = obj.Position
        elseif obj:IsA("Model") and obj.PrimaryPart then
            pos = obj.PrimaryPart.Position
        end

        if pos then
            local dx = pos.X - fp.X
            local dz = pos.Z - fp.Z
            if (dx*dx + dz*dz) <= r*r then
                table.insert(_tokenCache, pos)
            end
        end
    end

    for _, child in ipairs(workspace:GetChildren()) do
        checkObj(child)
        -- Заглядываем на один уровень в папки/модели
        if child:IsA("Folder") or child:IsA("Model") then
            for _, obj in ipairs(child:GetChildren()) do
                checkObj(obj)
            end
        end
    end

    return _tokenCache
end

-- ════════════════════════════════════════════════
--   UI  —  Rayfield
-- ════════════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Win = Rayfield:CreateWindow({
    Name = "BSS ULTIMATE FARM",
    ConfigurationSaving = {Enabled = false},
})

local TFarm = Win:CreateTab("⚙ Farm",       4483362458)
local TItem = Win:CreateTab("🎒 Items",     4483362458)
local TPos  = Win:CreateTab("📍 Positions", 4483362458)

-- Status + Pollen display
local ParaStatus = TFarm:CreateParagraph({Title="Status", Content="● Idle"})
local ParaPollen = TFarm:CreateParagraph({Title="Pollen",  Content="0.0%"})

local function setStatus(s)
    pcall(function() ParaStatus:Set({Title="Status", Content=s}) end)
end

-- Farm toggles
TFarm:CreateSection("Auto Farm")
TFarm:CreateToggle({Name="Auto Farm (Tokens)", CurrentValue=false, Callback=function(v)
    Flags.AutoFarm = v
    setStatus(v and "● Farming..." or "● Idle")
end})
TFarm:CreateToggle({Name="Auto Dig", CurrentValue=false, Callback=function(v)
    Flags.AutoDig = v
end})
TFarm:CreateToggle({Name="Auto Convert  ⚠ нужны точки!", CurrentValue=false, Callback=function(v)
    Flags.AutoConvert = v
    if v and (not Flags.HivePos or not Flags.FieldPos) then
        Rayfield:Notify({Title="⚠ Внимание", Content="Сначала установи точки во вкладке Positions!", Duration=6})
    end
end})

TFarm:CreateSection("Movement")
TFarm:CreateSlider({Name="CFrame Speed", Range={10,250}, Increment=5, CurrentValue=60,
    Callback=function(v) Flags.CFrameSpeed=v end})
TFarm:CreateSlider({Name="Field Radius", Range={10,120}, Increment=5, CurrentValue=45,
    Callback=function(v) Flags.FieldRadius=v end})

-- Items tab
TItem:CreateSection("Auto Use Item")
TItem:CreateToggle({Name="Auto Use Item", CurrentValue=false, Callback=function(v) Flags.AutoItem=v end})
TItem:CreateSlider({Name="Item Slot  (1–7)", Range={1,7}, Increment=1, CurrentValue=1,
    Callback=function(v) Flags.ItemSlot=v end})

-- Positions tab
TPos:CreateSection("⚠ Установи ДО фарма!")

local HivePara  = TPos:CreateParagraph({Title="Hive",  Content="не установлен"})
local FieldPara = TPos:CreateParagraph({Title="Field", Content="не установлен"})

TPos:CreateButton({Name="📍 Set Hive  (встань у улья)", Callback=function()
    if not HRP then return end
    Flags.HivePos = HRP.Position
    local p = Flags.HivePos
    HivePara:Set({Title="Hive ✓", Content=("X:%.1f  Y:%.1f  Z:%.1f"):format(p.X,p.Y,p.Z)})
    Rayfield:Notify({Title="Улей ✓", Content="Точка сохранена", Duration=3})
end})

TPos:CreateButton({Name="📍 Set Field  (встань в центр поля)", Callback=function()
    if not HRP then return end
    Flags.FieldPos = HRP.Position
    local p = Flags.FieldPos
    FieldPara:Set({Title="Field ✓", Content=("X:%.1f  Y:%.1f  Z:%.1f"):format(p.X,p.Y,p.Z)})
    Rayfield:Notify({Title="Поле ✓", Content="Точка сохранена", Duration=3})
end})

TPos:CreateButton({Name="🗑 Сбросить точки", Callback=function()
    Flags.HivePos=nil; Flags.FieldPos=nil
    HivePara:Set({Title="Hive",  Content="не установлен"})
    FieldPara:Set({Title="Field", Content="не установлен"})
    Rayfield:Notify({Title="Сброс", Content="Точки очищены", Duration=3})
end})

-- Live pollen updater
task.spawn(function()
    while task.wait(0.8) do
        pcall(function()
            ParaPollen:Set({Title="Pollen", Content=("%.1f%%"):format(getPollenPct())})
        end)
    end
end)

-- ════════════════════════════════════════════════
--   ЛОГИКА  (каждый модуль независим)
-- ════════════════════════════════════════════════

-- ── 1. AUTO DIG ──────────────────────────────────
-- Независим от всего. Просто вызывает toolClick каждые 0.1с.
task.spawn(function()
    while task.wait(0.1) do
        if Flags.AutoDig and R.ToolClick then
            pcall(function() R.ToolClick:InvokeServer() end)
        end
    end
end)

-- ── 2. AUTO ITEM ─────────────────────────────────
-- Независим от всего. Скорость строго 0.7с, слоты 1–7.
task.spawn(function()
    while task.wait(0.7) do
        if Flags.AutoItem and R.Actives then
            pcall(function() R.Actives:InvokeServer("Use", Flags.ItemSlot) end)
        end
    end
end)

-- ── 3. AUTO CONVERT ──────────────────────────────
-- Независим от AutoFarm. Возвращается на поле только если AutoFarm включён.
task.spawn(function()
    while task.wait(0.4) do
        if not Flags.AutoConvert then continue end
        if not Flags.HivePos then continue end
        if isConverting then continue end
        if getPollenPct() < 99 then continue end

        isConverting = true
        setStatus("● Converting...")

        -- Летим к улью
        tweenTo(Flags.HivePos)

        -- Жмём E для подтверждения конвертации
        task.wait(0.3)
        VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.15)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)

        -- Ждём пока пыльца сконвертируется (таймаут 25с)
        local waited = 0
        repeat
            task.wait(0.3)
            waited += 0.3
        until getPollenPct() < 3 or waited > 25

        -- Возвращаемся на поле ТОЛЬКО если AutoFarm включён
        if Flags.AutoFarm and Flags.FieldPos then
            tweenTo(Flags.FieldPos)
        end

        isConverting = false
        setStatus(Flags.AutoFarm and "● Farming..." or "● Idle")
    end
end)

-- ── 4. AUTO FARM (движение по полю) ──────────────
-- Независим от AutoConvert/AutoDig/AutoItem.
-- Скорость = Flags.CFrameSpeed (studs/s), чистое значение без привязки к WalkSpeed.
-- Если токенов нет — НЕ блокируем игрока (ждём появления).
RunService.Heartbeat:Connect(function(dt)
    if not Flags.AutoFarm then return end
    if not HRP or not Hum or Hum.Health <= 0 then return end
    if not Flags.FieldPos then return end

    -- Ищем ближайший токен в радиусе поля
    local tokens   = getTokensInField()
    local target   = nil
    local bestDist = math.huge

    local hrpXZ = Vector3.new(HRP.Position.X, 0, HRP.Position.Z)
    for _, pos in ipairs(tokens) do
        local d = (Vector3.new(pos.X, 0, pos.Z) - hrpXZ).Magnitude
        if d < bestDist then
            bestDist = d
            target   = pos
        end
    end

    -- Нет токенов → не двигаемся (игрок свободен)
    if not target then return end

    local pPos    = HRP.Position
    local dx      = target.X - pPos.X
    local dz      = target.Z - pPos.Z
    local flatDst = math.sqrt(dx*dx + dz*dz)

    if flatDst > 1.5 then
        local inv  = 1 / flatDst
        -- Скорость строго из слайдера (studs/s), работает при любом состоянии персонажа
        local step = math.min(Flags.CFrameSpeed * dt, flatDst)
        local nx   = pPos.X + dx * inv * step
        local nz   = pPos.Z + dz * inv * step

        -- Y не трогаем — прыжок, полёт и парашют работают корректно
        HRP.CFrame = CFrame.lookAt(
            Vector3.new(nx, pPos.Y, nz),
            Vector3.new(target.X, pPos.Y, target.Z)
        )

        -- Гасим только горизонтальную инерцию, вертикальную сохраняем
        local vy = HRP.AssemblyLinearVelocity.Y
        HRP.AssemblyLinearVelocity = Vector3.new(0, vy, 0)
    end
end)
