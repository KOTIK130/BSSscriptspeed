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
    SpeedHack   = false,
    ItemSlot    = 1,
    Speed       = 70,      -- WalkSpeed значение
    CFrameSpeed = 60,      -- скорость движения автофарма (studs/s)
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
    ToolClick = findR("toolClick"),
    Actives   = findR("PlayerActivesCommand"),
}

-- ─── Персонаж ────────────────────────────────────
local Char, HRP, Hum
local defaultWalkSpeed = 16

local function loadChar()
    Char = Player.Character or Player.CharacterAdded:Wait()
    HRP  = Char:WaitForChild("HumanoidRootPart")
    Hum  = Char:WaitForChild("Humanoid")
    defaultWalkSpeed = Hum.WalkSpeed
end
loadChar()
Player.CharacterAdded:Connect(function()
    isConverting = false
    task.wait(0.5)
    loadChar()
    -- Восстанавливаем скорость после респавна
    if Flags.SpeedHack and Hum then
        Hum.WalkSpeed = Flags.Speed
    end
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
    local t = TweenInfo.new(math.max(dist / Flags.CFrameSpeed, 0.05), Enum.EasingStyle.Linear)
    curTween = TweenService:Create(HRP, t, {CFrame = CFrame.new(pos)})
    curTween:Play()
    curTween.Completed:Wait()
    curTween = nil
end

-- ─── Поиск токенов (ОПТИМИЗИРОВАНО) ─────────────
-- Сканируем ТОЛЬКО известные папки с токенами, не весь workspace
local _tokenCache     = {}
local _tokenCacheTime = 0
local _tokenFolders   = nil

-- Один раз находим все папки-кандидаты (при первом вызове)
local function getTokenFolders()
    if _tokenFolders then return _tokenFolders end
    _tokenFolders = {}
    -- Известные имена папок токенов в BSS
    local names = {"Collectibles", "Tokens", "AbilityTokens", "FieldTokens", "PlayerTokens", "FlowerZones", "tokenEvent"}
    for _, name in ipairs(names) do
        local f = workspace:FindFirstChild(name)
        if f then table.insert(_tokenFolders, f) end
    end
    -- Если ничего не нашли — фоллбэк: ищем все Folder в workspace
    if #_tokenFolders == 0 then
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Folder") then
                table.insert(_tokenFolders, child)
            end
        end
    end
    return _tokenFolders
end

local function getTokensInField()
    if not Flags.FieldPos then return {} end
    local now = os.clock()
    -- Кэш 0.5с вместо 0.25 — в 2 раза меньше нагрузки
    if now - _tokenCacheTime < 0.5 then return _tokenCache end
    _tokenCacheTime = now
    _tokenCache = {}

    local fp = Flags.FieldPos
    local rr = Flags.FieldRadius * Flags.FieldRadius

    local folders = getTokenFolders()
    for _, folder in ipairs(folders) do
        for _, obj in ipairs(folder:GetChildren()) do
            local pos
            if obj:IsA("BasePart") then
                pos = obj.Position
            elseif obj:IsA("Model") then
                local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if pp then pos = pp.Position end
            end

            if pos then
                local dx = pos.X - fp.X
                local dz = pos.Z - fp.Z
                if (dx*dx + dz*dz) <= rr then
                    table.insert(_tokenCache, pos)
                end
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

-- ── Farm tab ──
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

TFarm:CreateSection("Speed")
TFarm:CreateToggle({Name="Speed Hack", CurrentValue=false, Callback=function(v)
    Flags.SpeedHack = v
    if Hum then
        Hum.WalkSpeed = v and Flags.Speed or defaultWalkSpeed
    end
end})
TFarm:CreateSlider({Name="WalkSpeed", Range={16,500}, Increment=1, CurrentValue=70,
    Callback=function(v)
        Flags.Speed = v
        if Flags.SpeedHack and Hum then
            Hum.WalkSpeed = v
        end
    end
})

TFarm:CreateSection("Auto Farm Settings")
TFarm:CreateSlider({Name="Farm Move Speed (studs/s)", Range={10,250}, Increment=5, CurrentValue=60,
    Callback=function(v) Flags.CFrameSpeed=v end})
TFarm:CreateSlider({Name="Field Radius", Range={10,120}, Increment=5, CurrentValue=45,
    Callback=function(v) Flags.FieldRadius=v end})

-- ── Items tab ──
TItem:CreateSection("Auto Use Item")
TItem:CreateToggle({Name="Auto Use Item", CurrentValue=false, Callback=function(v) Flags.AutoItem=v end})
TItem:CreateSlider({Name="Item Slot  (1–7)", Range={1,7}, Increment=1, CurrentValue=1,
    Callback=function(v) Flags.ItemSlot=v end})

-- ── Positions tab ──
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
    -- Сбрасываем кэш папок при смене поля
    _tokenFolders = nil
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
--   ЛОГИКА  (каждый модуль ПОЛНОСТЬЮ независим)
-- ════════════════════════════════════════════════

-- ── 1. SPEED HACK ────────────────────────────────
-- Постоянно поддерживает WalkSpeed (игра может сбрасывать)
task.spawn(function()
    while task.wait(0.5) do
        if Flags.SpeedHack and Hum then
            pcall(function() Hum.WalkSpeed = Flags.Speed end)
        end
    end
end)

-- ── 2. AUTO DIG ──────────────────────────────────
task.spawn(function()
    while task.wait(0.1) do
        if Flags.AutoDig and R.ToolClick then
            pcall(function() R.ToolClick:InvokeServer() end)
        end
    end
end)

-- ── 3. AUTO ITEM ─────────────────────────────────
-- Пробуем оба варианта: RemoteFunction (InvokeServer) и RemoteEvent (FireServer)
task.spawn(function()
    while task.wait(0.7) do
        if Flags.AutoItem and R.Actives then
            pcall(function()
                if R.Actives:IsA("RemoteFunction") then
                    R.Actives:InvokeServer("Use", Flags.ItemSlot)
                elseif R.Actives:IsA("RemoteEvent") then
                    R.Actives:FireServer("Use", Flags.ItemSlot)
                end
            end)
        end
    end
end)

-- ── 4. AUTO CONVERT ──────────────────────────────
task.spawn(function()
    while task.wait(0.4) do
        if not Flags.AutoConvert then continue end
        if not Flags.HivePos then continue end
        if isConverting then continue end
        if getPollenPct() < 99 then continue end

        isConverting = true
        setStatus("● Converting...")

        tweenTo(Flags.HivePos)

        task.wait(0.3)
        VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.15)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)

        local waited = 0
        repeat
            task.wait(0.3)
            waited += 0.3
        until getPollenPct() < 3 or waited > 25

        if Flags.AutoFarm and Flags.FieldPos then
            tweenTo(Flags.FieldPos)
        end

        isConverting = false
        setStatus(Flags.AutoFarm and "● Farming..." or "● Idle")
    end
end)

-- ── 5. AUTO FARM (движение по полю) ──────────────
-- НЕ вызывается каждый кадр — используем Stepped с троттлингом
local _lastFarmTick = 0
RunService.Heartbeat:Connect(function(dt)
    if not Flags.AutoFarm then return end
    if not HRP or not Hum or Hum.Health <= 0 then return end
    if not Flags.FieldPos then return end

    -- Ищем ближайший токен
    local tokens   = getTokensInField()
    local target   = nil
    local bestDist = math.huge

    local px, pz = HRP.Position.X, HRP.Position.Z
    for _, pos in ipairs(tokens) do
        local dx = pos.X - px
        local dz = pos.Z - pz
        local d  = dx*dx + dz*dz
        if d < bestDist then
            bestDist = d
            target   = pos
        end
    end

    -- Нет токенов → не блокируем игрока
    if not target then return end

    local pPos    = HRP.Position
    local dx      = target.X - pPos.X
    local dz      = target.Z - pPos.Z
    local flatDst = math.sqrt(dx*dx + dz*dz)

    if flatDst > 1.5 then
        local inv  = 1 / flatDst
        local step = math.min(Flags.CFrameSpeed * dt, flatDst)
        local nx   = pPos.X + dx * inv * step
        local nz   = pPos.Z + dz * inv * step

        HRP.CFrame = CFrame.lookAt(
            Vector3.new(nx, pPos.Y, nz),
            Vector3.new(target.X, pPos.Y, target.Z)
        )

        local vy = HRP.AssemblyLinearVelocity.Y
        HRP.AssemblyLinearVelocity = Vector3.new(0, vy, 0)
    end
end)
