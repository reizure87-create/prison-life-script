--[[
    ================================================================================
    🚔 PRISON LIFE — ULTIMATE 2026 SCRIPT (PC & MOBILE) [v3.0 KX FEATURE EDITION]
    ================================================================================
    Target Game : Prison Life (PlaceId: 155615604 | UniverseId: 73885730)
    Patch Target: Late 2026 ("Sniper Update!" Remotes, Attributes & Anti-Cheat)
    Platform    : PC (Keyboard/Mouse + Hotkeys) & Mobile (Touch GUI, Top-Left .combo1,
                  Top-Right Command Bar, Floating Quick Dock, & Fly Controls)
    UI Library  : Clean WindUI 7-Tab Architecture (with Native Touch/PC UI Fallback)

    What's New in v3.0 (All KX Admin Features Integrated Cleanly + Anti-Ban Safe Mode):
      1. 4-Mode 3D Holographic Bullet Shield (Keybind: G):
         - Modes: Hybrid (RiotShieldPart auto-equip + CFrame micro-desync fallback),
           RiotOnly, DesyncBox (3D OBB anti-aim jitter), and FEGhost.
         - Features Auto-Face Shooter, Spin-Block Anti-Aim, OBB incoming raycast
           interception, neon impact spark VFX, ricochet SFX, and live 180 HP bar.
      2. .combo1 Multi-Gun Burst Engine (Top-Left HUD Pill & Keybind: X):
         - Cycles through all owned loaded firearms (Remington 870 -> M700 -> FAL ->
           M4A1 -> AK-47 -> Revolver -> MP5 -> M9) to burst-eliminate targets
           instantly, with Auto-Grab Guns, Loop .combo1, and Shield Re-Equip.
      3. 360° Ragebot, Wallbang Scanner & Auto Armor Penetration (Keybind: B):
         - 10-directional origin ring + NormalId corner-peek Wallbang Scanner,
           Headshot % roll, Auto Armor Penetration (forces headshots on vested
           enemies), Auto-Switch to loaded guns, and Ragebot Shield-Peek.
      4. Combat VFX & Audio Suite:
         - 3D Neon Bullet Tracers, 4-Tick Animated Crosshair Hitmarker (White/Red),
           Floating 3D Damage Numbers, and Hit/Headshot/Kill Streak Sound Effects.
      5. Guard, Prisoner & Target Automation:
         - Auto-Taze Aura, Auto-Arrest Aura, Anti-Arrest (blocks ClientArrested),
           Anti-Tase (purges stun tracks & restores WalkSpeed/Backpack), ArrestAll,
           TaseAll, KillAll, Persistent LoopKill list, Whitelists, Spectate/View,
           and FE Vehicle-Seat Bring.
      6. Heuristic Cheater / Speed / Car-TP Anomaly Detector & Custom Streak Killfeed:
         - Multi-strike telemetry alerts when other players speedhack or Car-TP,
           plus live killstreak tracking with [COMBO] and [RAGEBOT] tags.
      7. Clean Built-In KX Command Bar (`;cmd` + Chat Commands + 90+ Commands):
         - Top-right command bar with semicolon chaining (`;guns;shield on;rage on`),
           live autocomplete suggestions, presets (`;preset safe|legit|rage`),
           rejoin (`;rj`), and serverhop (`;shop`).
    ================================================================================
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- // Lua 5.1 / LuaJIT Compatibility Helpers
local clamp = math.clamp or function(v, lo, hi)
    return math.min(hi, math.max(lo, v))
end
local round = math.round or function(v)
    return math.floor(v + 0.5)
end

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- // Prevent Duplicate Execution
local Env = (getgenv and getgenv()) or _G
if Env.PrisonLife2026Cleanup then
    pcall(Env.PrisonLife2026Cleanup)
end

local function GetSafeGuiParent()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return CoreGui end)
    if ok2 and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function NormalizeDropdownValue(v)
    if type(v) == "table" then
        return v[1] or v.Value or next(v) or ""
    end
    return tostring(v or "")
end

local function Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- // Connections & Cleanup Registry
local Connections = {}
local CreatedInstances = {}
local HookedFunctions = {}

local function AddConnection(conn)
    if conn then table.insert(Connections, conn) end
    return conn
end
local function TrackInstance(inst)
    if inst then table.insert(CreatedInstances, inst) end
    return inst
end

-- // 2026 Remotes Lookup
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local GunRemotesFolder = ReplicatedStorage:WaitForChild("GunRemotes", 10)

local Remotes = {
    RequestTeamChange = RemotesFolder and RemotesFolder:FindFirstChild("RequestTeamChange"),
    GiverPressed      = RemotesFolder and RemotesFolder:FindFirstChild("GiverPressed"),
    TouchGiver        = RemotesFolder and (RemotesFolder:FindFirstChild("TouchGiver") or RemotesFolder:FindFirstChild("GiverTouched")),
    InteractWithItem  = RemotesFolder and RemotesFolder:FindFirstChild("InteractWithItem"),
    ArrestPlayer      = RemotesFolder and RemotesFolder:FindFirstChild("ArrestPlayer"),
    ClientArrested    = RemotesFolder and RemotesFolder:FindFirstChild("ClientArrested"),
    EatFood           = RemotesFolder and (RemotesFolder:FindFirstChild("EatFood") or RemotesFolder:FindFirstChild("SnackEaten")),
    ShieldEquipped    = RemotesFolder and (RemotesFolder:FindFirstChild("ShieldEquipped") or RemotesFolder:FindFirstChild("RiotShieldEquipped")),
    MessageReceived   = RemotesFolder and RemotesFolder:FindFirstChild("MessageReceived"),
    C4Folder          = RemotesFolder and RemotesFolder:FindFirstChild("C4"),
    PlayerTased       = GunRemotesFolder and GunRemotesFolder:FindFirstChild("PlayerTased"),
    GunTracers        = GunRemotesFolder and (GunRemotesFolder:FindFirstChild("GunTracers") or GunRemotesFolder:FindFirstChild("ReplicateBullet")),
    MeleeEvent        = ReplicatedStorage:FindFirstChild("meleeEvent"),
}

-- // Central Configuration State
local State = {
    -- Anti-Ban Protection (Prevents Error Code 600 30-Day Experience Bans)
    AntiBanSafeMode = true,

    -- 4-Mode 3D Holographic Bullet Shield
    HoloShield = false,
    ShieldMode = "Hybrid",        -- "Hybrid", "RiotOnly", "DesyncBox", "FEGhost"
    ShieldSize = 6.5,
    ShieldTransparency = 0.72,
    ShieldAutoEquip = true,
    ShieldAutoFaceShooter = false,
    ShieldSpinBlock = false,
    ShieldSpinSpeed = 16,
    DesyncJitterRadius = 3.2,
    HoloShieldMaxHP = 180,

    -- Ragebot & .combo1 Burst
    Ragebot = false,
    Ragebot360 = true,
    RagebotAutoSwitch = true,
    RagebotRate = 14,
    RagebotPeekShield = true,

    ComboAutoGrabGuns = true,
    ComboReEquipShield = true,
    ComboLoop = false,
    ComboLoopInterval = 0.55,
    ShowComboButton = true,

    -- Silent Aim, Wallbang Scanner & Auto Armor Pen
    SilentAim = false,
    SilentAimHitChance = 100,
    SilentAimHeadChance = 75,
    SilentAimFOV = 180,
    SilentAimShowFOV = true,
    SilentAimWallcheck = true,
    SilentAimWallbang = true,
    SilentAimAimPart = "Head",    -- "Head", "Torso", "Random"
    SilentAimTeamCheck = true,
    SilentAimHostileCheck = true,
    SilentAimSkipDowned = true,
    AutoArmorPen = true,

    -- Camera Aim Assist & Triggerbot
    AimAssist = false,
    AimAssistFOV = 140,
    AimAssistShowFOV = false,
    AimAssistSmoothness = 0.22,
    AimAssistPrediction = true,
    AimAssistPredictionStrength = 0.065,
    AimAssistAimPart = "Head",

    Triggerbot = false,
    TriggerbotDelay = 0.08,
    TriggerbotWallcheck = true,
    TriggerbotAutoReload = true,

    -- Melee Kill Aura, LoopKill & Hitboxes
    KillAura = false,
    KillAuraRange = 10,
    KillAuraTeamCheck = true,
    KillAuraGuardSafe = true,
    KillAuraFaceTarget = false,
    KillAuraWhitelist = {},
    LoopKillTargets = {},

    ExpandHitbox = false,
    HitboxSize = 9,

    AntiRiotShield = false,
    VehicleWallbang = false,

    -- Weapons & Gun Mods
    AutoGetGuns = false,
    AutoGetGunsSelection = { "Remington 870", "MP5", "M9" },
    AutoPickupDropped = false,
    AutoArmor = false,
    AutoReload = false,
    AutoReloadHotSwap = false,

    GunMods = false,
    GunFireRateSPS = 14,
    GunNoSpread = true,
    GunFullAuto = true,
    GunInfiniteRange = true,

    AutoHeal = false,
    AutoHealThreshold = 80,

    -- Prison, Guards & Teams
    AutoArrest = false,
    AutoArrestRange = 10,
    AutoArrestHandCheck = false,
    AutoArrestCooldownBar = true,
    ArrestWhitelist = {},
    AutoTaze = false,

    AntiTase = true,
    AntiArrest = false,
    AlwaysBackpack = false,
    AutoCriminalOnArrest = false,
    FastRespawn = false,
    KeepPositionOnRespawn = true,
    OpenAllDoors = false,
    FenceGodmode = true,
    AntiKillPlane = true,
    AutoDetonateC4 = false,

    -- Vehicles & Character Fly
    Fly = false,
    FlySpeed = 65,
    VehicleFly = false,
    VehicleFlySpeed = 80,
    VehicleSpeedMod = false,
    VehicleSpeedMult = 2.0,
    AntiFling = true,
    VehicleFling = false,
    VehicleFlingTarget = "All",
    FEInvisible = false,
    AntiInvisible = false,

    -- Movement
    MaxSpeed = false,
    MaxSpeedMode = "RegionSafe",  -- "RegionSafe", "Custom", "AlwaysSprint"
    CustomWalkSpeed = 40,
    AlwaysSprint = false,
    JumpPowerEnabled = false,
    JumpPower = 65,
    InfiniteStamina = false,
    AntiJumpCooldown = false,
    InfiniteJump = false,
    Noclip = false,

    -- Visuals, VFX, Audio, Killfeed & Alerts
    ESP = false,
    ESPHighlight = true,
    ESPNameTag = true,
    ESPHealth = true,
    ESPDistance = true,
    ESPWeapon = true,
    ESPStatusFlags = true,
    ESPHideTeam = false,
    C4ESP = false,

    BulletTracers = true,
    TracerFadeTime = 0.24,
    Hitmarker = true,
    HitSound = true,
    KillSound = true,
    DamageNumbers = true,
    ShieldHitVFX = true,

    KillFeedNotifier = true,
    CheaterAlerts = true,
    CarTPAlerts = true,

    -- Admin Command Bar
    ShowCommandBar = true,
    ChatCommands = true,
}

-- // Load WindUI
local WindUI = nil
pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

local function Notify(title, content, duration)
    if WindUI and WindUI.Notify then
        pcall(function()
            WindUI:Notify({
                Title = title,
                Content = content,
                Duration = duration or 3.2,
                Icon = "shield-alert",
            })
        end)
    else
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = content,
                Duration = duration or 3.2,
            })
        end)
    end
end

-- ============================================================================
-- // SECTION 1: TARGET VALIDATION, WALLBANG SCANNER & FUZZY PLAYER RESOLVER
-- ============================================================================
local function GetCharacter(plr)
    return plr and plr.Character
end

local function GetRoot(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

local function GetHumanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function HasTargetArmor(char)
    if not char then return false end
    if char:FindFirstChild("Light Vest") or char:FindFirstChild("Armor") or char:FindFirstChild("Vest") then
        return true
    end
    if (tonumber(char:GetAttribute("Armor")) or 0) > 0 or (tonumber(char:GetAttribute("VestHealth")) or 0) > 0 then
        return true
    end
    return false
end

local function PickAimPart(char, forceHeadOverride)
    if not char then return nil end
    local wantHead = (forceHeadOverride == true)
    local mode = State.SilentAimAimPart or "Head"
    if not wantHead then
        if mode == "Head" then
            wantHead = true
        elseif mode == "Random" then
            wantHead = (math.random(1, 100) <= (tonumber(State.SilentAimHeadChance) or 75))
        end
        if not wantHead and State.AutoArmorPen and HasTargetArmor(char) then
            wantHead = true
        end
    end
    if wantHead then
        return char:FindFirstChild("Head") or GetRoot(char)
    end
    return char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or GetRoot(char) or char:FindFirstChild("Head")
end

local function IsValidCombatTarget(plr, requireHostileForGuard, whitelistTbl)
    if not plr or plr == LocalPlayer then return false end
    if whitelistTbl and whitelistTbl[plr.UserId] then return false end
    if not plr.Team or plr.Team == Teams:FindFirstChild("Neutral") then return false end

    local char = plr.Character
    if not char or char:FindFirstChildOfClass("ForceField") then return false end

    local hum = GetHumanoid(char)
    if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return false end

    if State.SilentAimSkipDowned and (char:GetAttribute("Downed") or char:GetAttribute("Arrested")) then
        return false
    end
    if State.SilentAimTeamCheck and plr.Team == LocalPlayer.Team then
        return false
    end

    if requireHostileForGuard and LocalPlayer.Team == Teams:FindFirstChild("Guards") and plr.Team == Teams:FindFirstChild("Inmates") then
        local isHostile = char:GetAttribute("Hostile") or char:GetAttribute("Trespassing")
        if not isHostile then return false end
    end

    return true
end

local WallRayParams = RaycastParams.new()
WallRayParams.FilterType = Enum.RaycastFilterType.Exclude
WallRayParams.IgnoreWater = true
pcall(function() WallRayParams.CollisionGroup = "ClientBullet" end)

local function BuildRayIgnoreList(targetChar)
    local ignore = { LocalPlayer.Character, targetChar, Camera }
    if (State.VehicleWallbang or State.SilentAimWallbang) and Workspace:FindFirstChild("CarContainer") then
        table.insert(ignore, Workspace.CarContainer)
    end
    if State.OpenAllDoors and Workspace:FindFirstChild("Doors") then
        table.insert(ignore, Workspace.Doors)
    end
    if Workspace:FindFirstChild("PL2026_VFXPool") then
        table.insert(ignore, Workspace.PL2026_VFXPool)
    end
    if Workspace:FindFirstChild("PL2026_BallisticShield") then
        table.insert(ignore, Workspace.PL2026_BallisticShield)
    end
    return ignore
end

local function IsSegmentClear(a, b)
    local delta = b - a
    if delta.Magnitude < 0.05 then return true end
    return Workspace:Raycast(a, delta, WallRayParams) == nil
end

local function HasLineOfSight(originPos, targetPart, targetChar)
    WallRayParams.FilterDescendantsInstances = BuildRayIgnoreList(targetChar)
    return IsSegmentClear(originPos, targetPart.Position)
end

-- 10-Directional Origin Ring + NormalId Corner-Peek Wallbang Scanner
local WALLBANG_OFFSETS = {
    Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
    Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
    Vector3.new(0, 1, 0), Vector3.new(0, -0.6, 0),
    Vector3.new(0.7, 0.7, 0), Vector3.new(-0.7, 0.7, 0),
    Vector3.new(0, 0.7, 0.7), Vector3.new(0, 0.7, -0.7),
}

local function FindWallbangTrajectory(baseOrigin, targetPart, targetChar, allowWallbang)
    if not baseOrigin or not targetPart then return nil, nil end
    WallRayParams.FilterDescendantsInstances = BuildRayIgnoreList(targetChar)
    local targetPos = targetPart.Position

    if IsSegmentClear(baseOrigin, targetPos) then
        return baseOrigin, targetPos
    end
    if not allowWallbang then
        return nil, nil
    end

    local maxRadii = State.AntiBanSafeMode and { 2.8, 5.2 } or { 3.2, 6.6 }
    for _, r in ipairs(maxRadii) do
        for _, dir in ipairs(WALLBANG_OFFSETS) do
            local candOrigin = baseOrigin + (dir * r)
            if IsSegmentClear(baseOrigin, candOrigin) and IsSegmentClear(candOrigin, targetPos) then
                return candOrigin, targetPos
            end
        end
    end

    for _, normId in ipairs(Enum.NormalId:GetEnumItems()) do
        local nVec = Vector3.FromNormalId(normId)
        local candOrigin = baseOrigin + (nVec * 4.5)
        local candTarget = targetPos + (nVec * 1.2)
        if IsSegmentClear(baseOrigin, candOrigin) and IsSegmentClear(candOrigin, candTarget) then
            return candOrigin, candTarget
        end
    end

    return nil, nil
end

local function GetBestCombatTarget(opts)
    opts = opts or {}
    local myChar = LocalPlayer.Character
    local myRoot = GetRoot(myChar)
    local myHead = myChar and (myChar:FindFirstChild("Head") or myRoot)
    if not myHead or not myRoot then return nil, nil, nil, nil end

    local baseOrigin = opts.origin or myHead.Position
    local use360 = (opts.use360 == true)
    local fovRadius = tonumber(opts.fov) or State.SilentAimFOV or 180
    local wallcheck = (opts.wallcheck ~= false)
    local allowWallbang = (opts.wallbang == true)
    local requireHostile = (opts.requireHostile ~= false)
    local forceHead = (opts.forceHead == true)
    local maxRange = tonumber(opts.range) or 1500

    local screenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    if not IsMobile and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        local mPos = UserInputService:GetMouseLocation()
        screenCenter = Vector2.new(mPos.X, mPos.Y)
    end

    local candidates = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if IsValidCombatTarget(plr, requireHostile, State.KillAuraWhitelist) then
            local char = plr.Character
            local part = PickAimPart(char, forceHead)
            if part then
                local worldDist = (part.Position - baseOrigin).Magnitude
                if worldDist <= maxRange then
                    local score = worldDist
                    local validScreen = true
                    if not use360 then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if not onScreen or screenPos.Z <= 0 then
                            validScreen = false
                        else
                            score = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                            if score > fovRadius then
                                validScreen = false
                            end
                        end
                    end
                    if validScreen then
                        table.insert(candidates, { plr = plr, char = char, part = part, score = score })
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b) return a.score < b.score end)

    for _, cand in ipairs(candidates) do
        if not wallcheck then
            return cand.part, cand.plr, baseOrigin, cand.part.Position
        end
        local clearOrigin, clearHit = FindWallbangTrajectory(baseOrigin, cand.part, cand.char, allowWallbang)
        if clearOrigin then
            return cand.part, cand.plr, clearOrigin, clearHit
        end
    end

    return nil, nil, nil, nil
end

local function GetBestScreenTarget(fovRadius, aimPartName, wallcheck, requireHostile)
    return GetBestCombatTarget({
        use360 = false,
        fov = fovRadius,
        wallcheck = wallcheck,
        wallbang = State.SilentAimWallbang,
        requireHostile = requireHostile,
        forceHead = (aimPartName == "Head"),
    })
end

-- Fuzzy Player Resolver for Admin Commands (`all`, `others`, `guards`, `inmates`, `criminals`, `nearest`, partial names)
local function ResolveTargetPlayers(query)
    local q = Trim(query)
    if q == "" then return {} end
    local out, seen = {}, {}
    local function push(p)
        if p and not seen[p] then
            seen[p] = true
            table.insert(out, p)
        end
    end

    local teamMap = {
        guards = "Guards", guard = "Guards", cops = "Guards", cop = "Guards",
        inmates = "Inmates", inmate = "Inmates", prisoners = "Inmates",
        criminals = "Criminals", criminal = "Criminals", crims = "Criminals", crim = "Criminals",
        neutral = "Neutral",
    }

    for token in string.gmatch(q, "[^,]+") do
        local raw = Trim(token)
        local low = string.lower(raw)
        if low == "all" then
            for _, p in ipairs(Players:GetPlayers()) do push(p) end
        elseif low == "others" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then push(p) end
            end
        elseif low == "me" or low == "self" then
            push(LocalPlayer)
        elseif low == "nearest" or low == "closest" then
            local myRoot = GetRoot(LocalPlayer.Character)
            local bestP, bestD = nil, math.huge
            if myRoot then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        local r = GetRoot(p.Character)
                        if r then
                            local d = (r.Position - myRoot.Position).Magnitude
                            if d < bestD then bestD = d; bestP = p end
                        end
                    end
                end
            end
            if bestP then push(bestP) end
        elseif teamMap[low] then
            local tName = teamMap[low]
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Team and p.Team.Name == tName then push(p) end
            end
        else
            local clean = (low:sub(1, 1) == "@") and low:sub(2) or low
            for _, p in ipairs(Players:GetPlayers()) do
                local nl = string.lower(p.Name)
                local dl = string.lower(p.DisplayName or p.Name)
                if nl == clean or dl == clean or nl:sub(1, #clean) == clean or dl:sub(1, #clean) == clean or nl:find(clean, 1, true) then
                    push(p)
                end
            end
        end
    end
    return out
end

-- ============================================================================
-- // SECTION 2: OVERLAY GUI, 4-TICK HITMARKER, VFX POOL & SOUND ENGINE
-- ============================================================================
local OverlayGui = TrackInstance(Instance.new("ScreenGui"))
OverlayGui.Name = "PL2026_Overlay"
OverlayGui.IgnoreGuiInset = true
OverlayGui.ResetOnSpawn = false
OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
OverlayGui.Parent = GetSafeGuiParent()

local SilentFOVFrame = Instance.new("Frame")
SilentFOVFrame.Name = "SilentFOV"
SilentFOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
SilentFOVFrame.BackgroundTransparency = 1
SilentFOVFrame.Position = UDim2.fromScale(0.5, 0.5)
SilentFOVFrame.Size = UDim2.fromOffset(360, 360)
SilentFOVFrame.Visible = false
SilentFOVFrame.Parent = OverlayGui
Instance.new("UICorner", SilentFOVFrame).CornerRadius = UDim.new(1, 0)
local SilentFOVStroke = Instance.new("UIStroke", SilentFOVFrame)
SilentFOVStroke.Color = Color3.fromRGB(255, 75, 75)
SilentFOVStroke.Thickness = 1.5
SilentFOVStroke.Transparency = 0.25

local AimAssistFOVFrame = Instance.new("Frame")
AimAssistFOVFrame.Name = "AimAssistFOV"
AimAssistFOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
AimAssistFOVFrame.BackgroundTransparency = 1
AimAssistFOVFrame.Position = UDim2.fromScale(0.5, 0.5)
AimAssistFOVFrame.Size = UDim2.fromOffset(280, 280)
AimAssistFOVFrame.Visible = false
AimAssistFOVFrame.Parent = OverlayGui
Instance.new("UICorner", AimAssistFOVFrame).CornerRadius = UDim.new(1, 0)
local AimAssistFOVStroke = Instance.new("UIStroke", AimAssistFOVFrame)
AimAssistFOVStroke.Color = Color3.fromRGB(80, 180, 255)
AimAssistFOVStroke.Thickness = 1.4
AimAssistFOVStroke.Transparency = 0.35

-- 4-Tick Animated Crosshair Hitmarker
local HitmarkerHolder = Instance.new("Frame")
HitmarkerHolder.Name = "KX_Hitmarker"
HitmarkerHolder.AnchorPoint = Vector2.new(0.5, 0.5)
HitmarkerHolder.Position = UDim2.fromScale(0.5, 0.5)
HitmarkerHolder.Size = UDim2.fromOffset(28, 28)
HitmarkerHolder.BackgroundTransparency = 1
HitmarkerHolder.Visible = false
HitmarkerHolder.Parent = OverlayGui

local HitmarkerTicks = {}
for i, angle in ipairs({ 45, 135, 225, 315 }) do
    local tick = Instance.new("Frame")
    tick.AnchorPoint = Vector2.new(0.5, 0.5)
    tick.Size = UDim2.fromOffset(8, 2)
    tick.BorderSizePixel = 0
    tick.BackgroundColor3 = Color3.new(1, 1, 1)
    tick.Rotation = angle
    local rad = math.rad(angle)
    tick.Position = UDim2.new(0.5, math.cos(rad) * 7, 0.5, math.sin(rad) * 7)
    tick.Parent = HitmarkerHolder
    Instance.new("UICorner", tick).CornerRadius = UDim.new(1, 0)
    HitmarkerTicks[i] = tick
end

local VFXPool = TrackInstance(Instance.new("Folder"))
VFXPool.Name = "PL2026_VFXPool"
VFXPool.Parent = Workspace

local SFXPool = TrackInstance(Instance.new("Folder"))
SFXPool.Name = "PL2026_SFXPool"
SFXPool.Parent = SoundService

local function MakeSound(name, id, vol, pitch)
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = id
    s.Volume = vol
    s.PlaybackSpeed = pitch
    s.Parent = SFXPool
    return s
end

local HitBodySound = MakeSound("HitBody", "rbxassetid://4817809188", 0.65, 1.0)
local HitHeadSound = MakeSound("HitHead", "rbxassetid://4817809188", 0.85, 1.3)
local KillStreakSound = MakeSound("KillStreak", "rbxassetid://160432334", 0.85, 1.4)
local RicochetSound = MakeSound("Ricochet", "rbxassetid://2935002319", 0.6, 1.05)

local LastHitSoundClock = 0
local function TriggerHitmarkerVFX(isHeadshot, isKill)
    if State.HitSound and (os.clock() - LastHitSoundClock) > 0.045 then
        LastHitSoundClock = os.clock()
        pcall(function()
            if isKill and State.KillSound then
                KillStreakSound:Play()
            elseif isHeadshot then
                HitHeadSound:Play()
            else
                HitBodySound:Play()
            end
        end)
    end
    if not State.Hitmarker then return end

    local screenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    if not IsMobile and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        local mPos = UserInputService:GetMouseLocation()
        screenCenter = Vector2.new(mPos.X, mPos.Y)
    end
    HitmarkerHolder.Position = UDim2.fromOffset(screenCenter.X, screenCenter.Y)
    HitmarkerHolder.Visible = true
    local col = (isKill or isHeadshot) and Color3.fromRGB(255, 65, 75) or Color3.fromRGB(255, 255, 255)
    for _, t in ipairs(HitmarkerTicks) do
        t.BackgroundColor3 = col
        t.BackgroundTransparency = 0
    end
    task.delay(0.18, function()
        if HitmarkerHolder then HitmarkerHolder.Visible = false end
    end)
end

local function SpawnBulletTracer(origin, hitPos, isRage)
    if not State.BulletTracers or typeof(origin) ~= "Vector3" or typeof(hitPos) ~= "Vector3" then return end
    local dist = (hitPos - origin).Magnitude
    if dist < 0.5 or dist > 4000 then return end

    local p = Instance.new("Part")
    p.Name = "PL2026_Tracer"
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = isRage and Color3.fromRGB(255, 55, 85) or Color3.fromRGB(0, 225, 255)
    p.Transparency = 0.15
    p.Size = Vector3.new(0.09, 0.09, dist)
    p.CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -dist * 0.5)
    p.Parent = VFXPool

    local fade = clamp(tonumber(State.TracerFadeTime) or 0.24, 0.08, 0.7)
    local tw = TweenService:Create(p, TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0.015, 0.015, dist),
    })
    tw:Play()
    task.delay(fade + 0.05, function()
        if p and p.Parent then p:Destroy() end
    end)
end

local function SpawnDamageNumber(worldPos, dmg, isHead)
    if not State.DamageNumbers or typeof(worldPos) ~= "Vector3" then return end
    local amt = round(tonumber(dmg) or 0)
    if amt <= 0 then return end

    local anchor = Instance.new("Part")
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.Position = worldPos + Vector3.new((math.random() - 0.5) * 1.2, 1.2, (math.random() - 0.5) * 1.2)
    anchor.Parent = VFXPool

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(80, 28)
    bb.AlwaysOnTop = true
    bb.Adornee = anchor
    bb.Parent = anchor

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = isHead and 16 or 14
    lbl.TextColor3 = isHead and Color3.fromRGB(255, 75, 75) or Color3.fromRGB(255, 235, 110)
    lbl.TextStrokeTransparency = 0.15
    lbl.Text = "-" .. tostring(amt) .. (isHead and " HS" or "")
    lbl.Parent = bb

    local tw = TweenService:Create(anchor, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = anchor.Position + Vector3.new(0, 2.6, 0),
    })
    tw:Play()
    task.delay(0.58, function()
        if anchor and anchor.Parent then anchor:Destroy() end
    end)
end

local function SpawnShieldSparkVFX(hitPos)
    if not State.ShieldHitVFX or typeof(hitPos) ~= "Vector3" then return end
    pcall(function() RicochetSound:Play() end)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(255, 230, 80)
    p.Size = Vector3.new(0.55, 0.55, 0.55)
    p.Position = hitPos
    p.Transparency = 0.15
    p.Parent = VFXPool
    TweenService:Create(p, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(1.6, 1.6, 1.6),
        Transparency = 1,
    }):Play()
    task.delay(0.2, function()
        if p and p.Parent then p:Destroy() end
    end)
end

-- ============================================================================
-- // SECTION 3: 2026 GUN CONTROLLER UPVALUE HOOK (SILENT AIM / RAGEBOT / COMBO1)
-- ============================================================================
local GunHook = {
    Ready = false,
    IsHooked = false,
    RaycastFallbackHooked = false,
    Shoot = nil,
    Reload = nil,
    Bullet = nil,
    ShootParams = nil,
    OldBullet = nil,
    CurrentSilentTargetPart = nil,
    CurrentSilentOrigin = nil,
    CurrentSilentHitPos = nil,
    ForceRageShot = false,
    RageTargetPart = nil,
    TaseTargetPart = nil,
    LastRageShotClock = 0,
    LastComboShotClock = 0,
}

local function IsHoldingFirearm()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return false, nil end
    if tool:GetAttribute("ToolType") == "Gun" or tool:GetAttribute("FireRate") or tool:GetAttribute("SpreadRadius") then
        return true, tool
    end
    return false, nil
end

local HealthWatchers = setmetatable({}, { __mode = "k" })
local function WatchTargetHitDamage(hitPart, hitPos)
    if typeof(hitPart) ~= "Instance" then return end
    local model = hitPart:FindFirstAncestorOfClass("Model")
    local plr = model and Players:GetPlayerFromCharacter(model)
    if not plr or plr == LocalPlayer then return end
    local hum = GetHumanoid(model)
    if not hum or hum.Health <= 0 then return end

    local isHead = (hitPart.Name == "Head")
    TriggerHitmarkerVFX(isHead, false)

    local prevHP = hum.Health
    if not HealthWatchers[hum] then
        local conn
        local expire = os.clock() + 0.45
        conn = hum.HealthChanged:Connect(function(newHP)
            if os.clock() > expire then
                if conn then conn:Disconnect() end
                HealthWatchers[hum] = nil
                return
            end
            local delta = prevHP - newHP
            if delta > 0.2 then
                prevHP = newHP
                SpawnDamageNumber(hitPos or hitPart.Position, delta, isHead)
                if newHP <= 0 then
                    TriggerHitmarkerVFX(isHead, true)
                end
            end
        end)
        HealthWatchers[hum] = conn
        AddConnection(conn)
    end
end

local function SyncOriginOnStack(origStart, newOrigin)
    if origStart == newOrigin or not debug or type(debug.getstack) ~= "function" or type(debug.setstack) ~= "function" then
        return
    end
    for level = 3, 8 do
        local ok, stackTbl = pcall(debug.getstack, level)
        if ok and type(stackTbl) == "table" then
            for idx, val in pairs(stackTbl) do
                if val == origStart then
                    pcall(debug.setstack, level, idx, newOrigin)
                end
            end
        end
    end
end

local function SetupGunControllerHooks()
    if getconnections and debug and debug.getupvalue then
        pcall(function()
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local home = pg and pg:FindFirstChild("Home")
            local hud = home and home:FindFirstChild("hud")
            local actionArea = hud and hud:FindFirstChild("ActionArea")
            if actionArea then
                for _, conn in ipairs(getconnections(actionArea.InputBegan)) do
                    if conn.Function then
                        local shootFn = debug.getupvalue(conn.Function, 2)
                        if type(shootFn) == "function" then
                            GunHook.Shoot = shootFn
                            pcall(function() GunHook.Reload = debug.getupvalue(shootFn, 2) end)
                            pcall(function() GunHook.Bullet = debug.getupvalue(shootFn, 16) end)
                            GunHook.Ready = (GunHook.Shoot ~= nil and GunHook.Bullet ~= nil)
                            break
                        end
                    end
                end
            end

            for _, conn in ipairs(getconnections(LocalPlayer.CharacterAdded)) do
                if conn.Function then
                    local okS, src = pcall(debug.info, conn.Function, "s")
                    if okS and type(src) == "string" and src:find("GunController") then
                        pcall(function() GunHook.ShootParams = debug.getupvalue(conn.Function, 2) end)
                        break
                    end
                end
            end

            if GunHook.Bullet and hookfunction and not GunHook.IsHooked then
                GunHook.IsHooked = true
                GunHook.OldBullet = hookfunction(GunHook.Bullet, function(...)
                    local args = table.pack(...)
                    local origOrigin = args[1]
                    local activeTargetPart = nil
                    local activeOrigin = nil
                    local activeHitPos = nil

                    if GunHook.TaseTargetPart and GunHook.TaseTargetPart.Parent then
                        activeTargetPart = GunHook.TaseTargetPart
                        activeOrigin, activeHitPos = FindWallbangTrajectory(origOrigin, activeTargetPart, activeTargetPart.Parent, State.SilentAimWallbang)
                    elseif GunHook.ForceRageShot and GunHook.RageTargetPart and GunHook.RageTargetPart.Parent then
                        activeTargetPart = GunHook.RageTargetPart
                        activeOrigin, activeHitPos = FindWallbangTrajectory(origOrigin, activeTargetPart, activeTargetPart.Parent, true)
                    elseif State.Ragebot then
                        activeTargetPart, _, activeOrigin, activeHitPos = GetBestCombatTarget({
                            origin = origOrigin,
                            use360 = State.Ragebot360,
                            fov = State.SilentAimFOV,
                            wallcheck = true,
                            wallbang = State.SilentAimWallbang,
                            requireHostile = State.SilentAimHostileCheck,
                            forceHead = true,
                        })
                    elseif State.SilentAim and math.random(1, 100) <= State.SilentAimHitChance then
                        activeTargetPart = GunHook.CurrentSilentTargetPart
                        activeOrigin = GunHook.CurrentSilentOrigin
                        activeHitPos = GunHook.CurrentSilentHitPos
                        if not (activeTargetPart and activeTargetPart.Parent) then
                            activeTargetPart, _, activeOrigin, activeHitPos = GetBestCombatTarget({
                                origin = origOrigin,
                                use360 = false,
                                fov = State.SilentAimFOV,
                                wallcheck = State.SilentAimWallcheck,
                                wallbang = State.SilentAimWallbang,
                                requireHostile = State.SilentAimHostileCheck,
                            })
                        end
                    end

                    if activeTargetPart and activeTargetPart.Parent then
                        local finalHit = activeHitPos or activeTargetPart.Position
                        args[2] = finalHit
                        if type(args[3]) == "number" then args[3] = 0 end
                        if activeOrigin and typeof(origOrigin) == "Vector3" and activeOrigin ~= origOrigin then
                            SyncOriginOnStack(origOrigin, activeOrigin)
                            args[1] = activeOrigin
                        end
                    elseif State.GunMods and State.GunNoSpread then
                        if type(args[3]) == "number" then args[3] = 0 end
                    end

                    local ret = table.pack(GunHook.OldBullet(table.unpack(args, 1, args.n)))
                    local hitPart = ret[1]
                    local hitPos = (typeof(ret[2]) == "Vector3" and ret[2]) or args[2]
                    if typeof(args[1]) == "Vector3" and typeof(hitPos) == "Vector3" then
                        SpawnBulletTracer(args[1], hitPos, State.Ragebot or GunHook.ForceRageShot)
                    end
                    if typeof(hitPart) == "Instance" then
                        WatchTargetHitDamage(hitPart, hitPos)
                    end
                    return table.unpack(ret, 1, ret.n)
                end)
            end
        end)
    end

    if not GunHook.IsHooked and not GunHook.RaycastFallbackHooked and hookmetamethod and getnamecallmethod then
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                if Env.PrisonLife2026Running and not GunHook.IsHooked and (State.SilentAim or State.Ragebot or GunHook.ForceRageShot) and self == Workspace then
                    local method = getnamecallmethod()
                    if method == "Raycast" and (not checkcaller or not checkcaller()) then
                        local origin, dir, params = ...
                        if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" and dir.Magnitude > 40 then
                            local holdingGun = IsHoldingFirearm()
                            if holdingGun then
                                local targetPart = GunHook.RageTargetPart or GunHook.CurrentSilentTargetPart
                                if targetPart and targetPart.Parent then
                                    local newDir = (targetPart.Position - origin).Unit * math.max(dir.Magnitude, (targetPart.Position - origin).Magnitude + 2)
                                    return oldNamecall(self, origin, newDir, params)
                                end
                            end
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
            GunHook.RaycastFallbackHooked = true
        end)
    end

    return GunHook.Ready
end

task.spawn(function()
    for _ = 1, 20 do
        if SetupGunControllerHooks() and GunHook.IsHooked then break end
        task.wait(1)
    end
end)

local FiringBusy = false
local function FireToolAtTarget(tool, targetPart, isRage, isTase, isCombo)
    local char = LocalPlayer.Character
    local hum = GetHumanoid(char)
    if not char or not hum or hum.Health <= 0 or not tool or not targetPart then return false end
    if FiringBusy then return false end

    if not GunHook.Shoot then SetupGunControllerHooks() end

    FiringBusy = true
    if tool.Parent ~= char then
        pcall(function() hum:EquipTool(tool) end)
        local waitDeadline = os.clock() + 0.12
        while tool.Parent ~= char and os.clock() < waitDeadline do
            RunService.Heartbeat:Wait()
        end
    end
    FiringBusy = false
    if tool.Parent ~= char then return false end

    local ammo = tool:GetAttribute("Local_CurrentAmmo") or tool:GetAttribute("CurrentAmmo") or 1
    if ammo <= 0 or (tool:GetAttribute("Local_ReloadSession") or 0) > 0 then return false end

    if isTase then
        GunHook.TaseTargetPart = targetPart
    elseif isRage or isCombo then
        GunHook.ForceRageShot = true
        GunHook.RageTargetPart = targetPart
    else
        GunHook.CurrentSilentTargetPart = targetPart
    end

    local now = os.clock()
    if isCombo then
        GunHook.LastComboShotClock = now
    elseif isRage then
        GunHook.LastRageShotClock = now
    end

    if GunHook.Shoot then
        local inputObj = {
            UserInputState = Enum.UserInputState.Begin,
            UserInputType = Enum.UserInputType.MouseButton1,
            KeyCode = Enum.KeyCode.Unknown,
            Position = Vector3.zero,
        }
        pcall(task.spawn, GunHook.Shoot, inputObj)
        inputObj.UserInputState = Enum.UserInputState.End
    else
        pcall(function() tool:Activate() end)
    end

    local holdTime = math.max(0.05, (tonumber(tool:GetAttribute("ChargeTime")) or 0) + 0.05)
    task.delay(holdTime, function()
        GunHook.ForceRageShot = false
        GunHook.RageTargetPart = nil
        GunHook.TaseTargetPart = nil
    end)
    return true
end

-- ============================================================================
-- // SECTION 4: 4-MODE 3D HOLOGRAPHIC BULLET SHIELD (HYBRID / RIOT / DESYNC / GHOST)
-- ============================================================================
local ShieldBarHolder = Instance.new("Frame")
ShieldBarHolder.Name = "HoloShieldBar"
ShieldBarHolder.AnchorPoint = Vector2.new(0.5, 0.5)
ShieldBarHolder.Position = UDim2.fromScale(0.5, 0.63)
ShieldBarHolder.Size = UDim2.fromOffset(175, 9)
ShieldBarHolder.BackgroundColor3 = Color3.fromRGB(15, 25, 38)
ShieldBarHolder.BackgroundTransparency = 0.2
ShieldBarHolder.BorderSizePixel = 0
ShieldBarHolder.Visible = false
ShieldBarHolder.Parent = OverlayGui
Instance.new("UICorner", ShieldBarHolder).CornerRadius = UDim.new(1, 0)

local ShieldBarFill = Instance.new("Frame")
ShieldBarFill.Size = UDim2.fromScale(1, 1)
ShieldBarFill.BackgroundColor3 = Color3.fromRGB(0, 215, 255)
ShieldBarFill.BorderSizePixel = 0
ShieldBarFill.Parent = ShieldBarHolder
Instance.new("UICorner", ShieldBarFill).CornerRadius = UDim.new(1, 0)

local ShieldBarText = Instance.new("TextLabel")
ShieldBarText.Size = UDim2.fromOffset(175, 16)
ShieldBarText.Position = UDim2.fromOffset(0, 10)
ShieldBarText.BackgroundTransparency = 1
ShieldBarText.Font = Enum.Font.GothamBold
ShieldBarText.TextSize = 11
ShieldBarText.TextColor3 = Color3.fromRGB(120, 235, 255)
ShieldBarText.TextStrokeTransparency = 0.2
ShieldBarText.Text = "🛡️ HOLO SHIELD: 180/180"
ShieldBarText.Parent = ShieldBarHolder

local HoloShieldState = {
    Model = nil,
    CorePart = nil,
    HP = 180,
    MaxHP = 180,
    BrokenUntil = 0,
    LastHit = 0,
    DesyncActive = false,
    SavedCF = nil,
    JitterAngle = 0,
}

local function HasEquippedRiotShield()
    local char = LocalPlayer.Character
    if not char then return false end
    return (char:FindFirstChild("Riot Shield") or char:FindFirstChild("RiotShieldPart")) ~= nil
end

local function DestroyHoloShield()
    if HoloShieldState.DesyncActive and HoloShieldState.SavedCF then
        local hrp = GetRoot(LocalPlayer.Character)
        if hrp then pcall(function() hrp.CFrame = HoloShieldState.SavedCF end) end
    end
    HoloShieldState.DesyncActive = false
    HoloShieldState.SavedCF = nil
    if HoloShieldState.Model then
        pcall(function() HoloShieldState.Model:Destroy() end)
        HoloShieldState.Model = nil
        HoloShieldState.CorePart = nil
    end
    ShieldBarHolder.Visible = false
    if Remotes.ShieldEquipped then
        pcall(function() Remotes.ShieldEquipped:FireServer(false) end)
    end
end

local function CreateHoloShield()
    DestroyHoloShield()
    if not State.HoloShield then return end

    local sz = clamp(tonumber(State.ShieldSize) or 6.5, 3, 14)
    local m = Instance.new("Model")
    m.Name = "PL2026_BallisticShield"

    local core = Instance.new("Part")
    core.Name = "RiotShieldPart"
    core.Size = Vector3.new(sz * 0.82, sz * 0.95, 0.35)
    core.Transparency = clamp(tonumber(State.ShieldTransparency) or 0.72, 0.45, 0.95)
    core.Material = Enum.Material.ForceField
    core.Color = Color3.fromRGB(0, 210, 255)
    core.Anchored = true
    core.CanCollide = false
    core.CanQuery = true
    core.CanTouch = false
    core.Parent = m

    local rim = Instance.new("SelectionBox")
    rim.Adornee = core
    rim.Color3 = Color3.fromRGB(120, 245, 255)
    rim.LineThickness = 0.035
    rim.SurfaceColor3 = Color3.fromRGB(0, 175, 255)
    rim.SurfaceTransparency = 0.82
    rim.Parent = core

    m.Parent = Workspace
    HoloShieldState.Model = m
    HoloShieldState.CorePart = core
    HoloShieldState.MaxHP = State.HoloShieldMaxHP or 180
    HoloShieldState.HP = HoloShieldState.MaxHP
    ShieldBarHolder.Visible = true

    if Remotes.ShieldEquipped and (State.ShieldMode == "Hybrid" or State.ShieldMode == "RiotOnly") then
        pcall(function() Remotes.ShieldEquipped:FireServer(true) end)
    end
end

-- OBB Ray-Box Intersection for Accurate Incoming Bullet Interception
local function RayHitsShieldOBB(origin, hitPos, shieldCF, halfExt)
    local p0 = shieldCF:PointToObjectSpace(origin)
    local p1 = shieldCF:PointToObjectSpace(hitPos)
    local dir = p1 - p0
    local tMin, tMax = 0, 1
    local axes = {
        { p0.X, dir.X, halfExt.X },
        { p0.Y, dir.Y, halfExt.Y },
        { p0.Z, dir.Z, halfExt.Z },
    }
    for _, a in ipairs(axes) do
        local o, d, ext = a[1], a[2], a[3]
        if math.abs(d) < 1e-6 then
            if o < -ext or o > ext then return false, nil end
        else
            local invD = 1 / d
            local t1 = (-ext - o) * invD
            local t2 = (ext - o) * invD
            if t1 > t2 then t1, t2 = t2, t1 end
            if t1 > tMin then tMin = t1 end
            if t2 < tMax then tMax = t2 end
            if tMin > tMax then return false, nil end
        end
    end
    if tMin < 0 or tMin > 1 then return false, nil end
    return true, shieldCF:PointToWorldSpace(p0 + (dir * tMin))
end

local function RegisterHoloShieldHit(dmg, worldHitPos)
    if not State.HoloShield or not HoloShieldState.CorePart then return end
    if os.clock() < HoloShieldState.BrokenUntil then return end
    HoloShieldState.LastHit = os.clock()
    HoloShieldState.HP = math.max(0, HoloShieldState.HP - (dmg or 15))
    HoloShieldState.CorePart.Color = Color3.fromRGB(255, 95, 110)
    if worldHitPos then
        SpawnShieldSparkVFX(worldHitPos)
    end
    task.delay(0.08, function()
        if HoloShieldState.CorePart then
            HoloShieldState.CorePart.Color = Color3.fromRGB(0, 210, 255)
        end
    end)
    if HoloShieldState.HP <= 0 then
        HoloShieldState.BrokenUntil = os.clock() + 4.0
        HoloShieldState.CorePart.Transparency = 0.94
        HoloShieldState.CorePart.CanQuery = false
        Notify("Holo-Shield", "Shield depleted! Recharging in 4s...", 3)
    end
end

if Remotes.GunTracers and Remotes.GunTracers:IsA("RemoteEvent") then
    AddConnection(Remotes.GunTracers.OnClientEvent:Connect(function(origin, hitPos)
        if not State.HoloShield or not HoloShieldState.CorePart then return end
        if typeof(origin) == "Vector3" and typeof(hitPos) == "Vector3" then
            local core = HoloShieldState.CorePart
            local halfExt = Vector3.new(core.Size.X * 0.5, core.Size.Y * 0.5, math.max(0.9, core.Size.Z * 0.5))
            local hit, worldHit = RayHitsShieldOBB(origin, hitPos, core.CFrame, halfExt)
            if hit then
                RegisterHoloShieldHit(15, worldHit)
            elseif (hitPos - core.Position).Magnitude <= 5.5 then
                RegisterHoloShieldHit(15, hitPos)
            end
        end
    end))
end

-- ============================================================================
-- // SECTION 5: 2026 SAFE WEAPON GRABBER & .COMBO1 MULTI-GUN BURST ENGINE
-- ============================================================================
local KnownGunLocations = {
    ["Remington 870"] = {
        Zone = "Armory",
        SearchPivot = Vector3.new(820.2986, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(820.2986, 91.5, 2229.3962),
    },
    ["MP5"] = {
        Zone = "Armory",
        SearchPivot = Vector3.new(813.6987, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(813.6987, 91.5, 2229.3962),
    },
    ["M9"] = {
        Zone = "Armory",
        SearchPivot = Vector3.new(820.2986, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(820.2986, 91.5, 2229.3962),
    },
    ["M4A1"] = {
        Zone = "Armory",
        GamepassId = 643697197,
        SearchPivot = Vector3.new(847.5, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(847.5, 91.5, 2229.3962),
    },
    ["Riot Shield"] = {
        Zone = "Armory",
        GamepassId = 643697197,
        SearchPivot = Vector3.new(840.0, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(840.0, 91.5, 2229.3962),
    },
    ["AK-47"] = {
        Zone = "CrimBase",
        SearchPivot = Vector3.new(-931.7928, 91.2783, 2039.2555),
        UndergroundCF = CFrame.new(-931.7928, 85.0, 2039.2555),
    },
    ["FAL"] = {
        Zone = "CrimBase",
        GamepassId = 1443271,
        SearchPivot = Vector3.new(-938.5, 91.2783, 2039.2555),
        UndergroundCF = CFrame.new(-938.5, 85.0, 2039.2555),
    },
}

local GamepassCache = {}
local function OwnsGamepass(passId)
    if not passId then return true end
    if GamepassCache[passId] ~= nil then return GamepassCache[passId] end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, passId)
    end)
    GamepassCache[passId] = (ok and owns == true)
    return GamepassCache[passId]
end

local function IsGiverTeamAllowed(giver)
    if not giver then return true end
    local myTeamName = LocalPlayer.Team and LocalPlayer.Team.Name or ""
    local ok, tags = pcall(function() return CollectionService:GetTags(giver) end)
    if not ok or type(tags) ~= "table" then return true end
    local hasTeamRestriction = false
    for _, tag in ipairs(tags) do
        if tag == "Team_Any" or tag == ("Team_" .. myTeamName) then
            return true
        elseif tag:sub(1, 5) == "Team_" then
            hasTeamRestriction = true
        end
    end
    return not hasTeamRestriction
end

local function FindTouchGiverForWeapon(weaponName)
    local info = KnownGunLocations[weaponName]
    if info and info.GamepassId and not OwnsGamepass(info.GamepassId) then
        return nil, nil
    end

    local givers = {}
    local ok, queried = pcall(function() return Workspace:QueryDescendants("#TouchGiver") end)
    if ok and type(queried) == "table" and #queried > 0 then
        givers = queried
    else
        local okT, tagged = pcall(function() return CollectionService:GetTagged("Giver") end)
        if okT and type(tagged) == "table" and #tagged > 0 then
            givers = tagged
        else
            for _, inst in ipairs(Workspace:GetDescendants()) do
                if inst.Name == "TouchGiver" or inst:GetAttribute("ToolName") then
                    table.insert(givers, inst)
                end
            end
        end
    end

    for _, giver in ipairs(givers) do
        local toolAttr = giver:GetAttribute("ToolName") or (giver.Parent and giver.Parent:GetAttribute("ToolName"))
        if toolAttr == weaponName and IsGiverTeamAllowed(giver) then
            local okP, piv = pcall(function() return giver:GetPivot() end)
            if okP and piv then
                local pos = piv.Position
                return giver, CFrame.new(pos.X, pos.Y - 6.5, pos.Z)
            end
        end
    end

    if info then
        local closest, bestDist = nil, 25
        for _, giver in ipairs(givers) do
            local okP, pivot = pcall(function() return giver:GetPivot() end)
            if okP and pivot then
                local dist = (pivot.Position - info.SearchPivot).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    closest = giver
                end
            end
        end
        if closest then
            return closest, info.UndergroundCF
        end
    end
    return nil, nil
end

local IsGrabbingGuns = false
local function HasWeapon(weaponName)
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local char = LocalPlayer.Character
    if bp and bp:FindFirstChild(weaponName) then return bp:FindFirstChild(weaponName) end
    if char and char:FindFirstChild(weaponName) then return char:FindFirstChild(weaponName) end
    return nil
end

local OriginalGunAttributes = setmetatable({}, { __mode = "k" })

local function ApplyGunModsToTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    if tool:GetAttribute("ToolType") ~= "Gun" and not tool:GetAttribute("FireRate") then return end

    if not OriginalGunAttributes[tool] then
        OriginalGunAttributes[tool] = {
            FireRate = tool:GetAttribute("FireRate"),
            SpreadRadius = tool:GetAttribute("SpreadRadius"),
            AutoFire = tool:GetAttribute("AutoFire"),
            Range = tool:GetAttribute("Range"),
            AccurateRange = tool:GetAttribute("AccurateRange"),
        }
    end

    local orig = OriginalGunAttributes[tool]
    pcall(function()
        if State.GunMods then
            local targetSPS = State.GunFireRateSPS or 14
            if State.AntiBanSafeMode then
                targetSPS = math.min(targetSPS, 15)
            end
            if targetSPS > 0 then
                tool:SetAttribute("FireRate", 1 / targetSPS)
            end
            if State.GunNoSpread then
                tool:SetAttribute("SpreadRadius", 0)
            elseif orig and orig.SpreadRadius then
                tool:SetAttribute("SpreadRadius", orig.SpreadRadius)
            end
            if State.GunFullAuto then
                tool:SetAttribute("AutoFire", true)
            elseif orig and orig.AutoFire ~= nil then
                tool:SetAttribute("AutoFire", orig.AutoFire)
            end
            if State.GunInfiniteRange then
                tool:SetAttribute("Range", 9999)
                tool:SetAttribute("AccurateRange", 9999)
            end
        elseif orig then
            if orig.FireRate then tool:SetAttribute("FireRate", orig.FireRate) end
            if orig.SpreadRadius then tool:SetAttribute("SpreadRadius", orig.SpreadRadius) end
            if orig.AutoFire ~= nil then tool:SetAttribute("AutoFire", orig.AutoFire) end
            if orig.Range then tool:SetAttribute("Range", orig.Range) end
            if orig.AccurateRange then tool:SetAttribute("AccurateRange", orig.AccurateRange) end
        end
    end)
end

local function ApplyGunModsAll()
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do ApplyGunModsToTool(t) end
    end
    local char = LocalPlayer.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do ApplyGunModsToTool(t) end
    end
end

local function FireGiverPickup(hrp, giver)
    if not giver then return end
    if Remotes.GiverPressed then
        pcall(function() Remotes.GiverPressed:FireServer(giver) end)
    end
    if Remotes.TouchGiver then
        pcall(function() Remotes.TouchGiver:FireServer(giver) end)
    end
    if firetouchinterest and hrp then
        local touchPart = giver:IsA("BasePart") and giver or giver:FindFirstChildWhichIsA("BasePart", true)
        if touchPart then
            pcall(function()
                firetouchinterest(hrp, touchPart, 0)
                firetouchinterest(hrp, touchPart, 1)
            end)
        end
    end
end

local function GrabWeapons(weaponList, silent)
    if IsGrabbingGuns then return end

    local char = LocalPlayer.Character
    local hrp = GetRoot(char)
    local hum = GetHumanoid(char)
    if not hrp or not hum or hum.Health <= 0 then return end

    local queue = {}
    for _, wName in ipairs(weaponList) do
        if not HasWeapon(wName) then
            local giver, underCF = FindTouchGiverForWeapon(wName)
            if giver and underCF then
                local dist = (underCF.Position - hrp.Position).Magnitude
                table.insert(queue, { Name = wName, Giver = giver, CF = underCF, Dist = dist })
            end
        end
    end

    table.sort(queue, function(a, b) return a.Dist < b.Dist end)

    if #queue == 0 then
        ApplyGunModsAll()
        if not silent then Notify("Weapons", "You already have the selected weapons!", 2.5) end
        return
    end

    IsGrabbingGuns = true
    local savedCF = (HoloShieldState.DesyncActive and HoloShieldState.SavedCF) or hrp.CFrame
    HoloShieldState.DesyncActive = false

    for idx, item in ipairs(queue) do
        if not hrp or not hrp.Parent or hum.Health <= 0 then break end
        if State.AntiBanSafeMode and idx > 1 and item.Dist > 1200 then
            break
        end

        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = item.CF
        task.wait(0.14)

        local attempts = 0
        while not HasWeapon(item.Name) and attempts < 5 do
            if not hrp or not hrp.Parent or hum.Health <= 0 then break end
            attempts = attempts + 1
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = item.CF
            FireGiverPickup(hrp, item.Giver)
            task.wait(0.16)
        end

        if idx < #queue then task.wait(0.12) end
    end

    if hrp and hrp.Parent and hum and hum.Health > 0 then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = savedCF
    end

    IsGrabbingGuns = false
    SetupGunControllerHooks()
    ApplyGunModsAll()
    if not silent then Notify("Weapons Grabbed", "Equipped 2026 weapons safely!", 2.8) end
end

local COMBO_ORDER = { "Remington 870", "M700", "FAL", "M4A1", "AK-47", "Revolver", "MP5", "M9" }
local function GetOwnedLoadedGuns()
    local owned = {}
    local function scan(container)
        if not container then return end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") and t.Name ~= "Taser" and (t:GetAttribute("ToolType") == "Gun" or t:GetAttribute("FireRate")) then
                local ammo = t:GetAttribute("Local_CurrentAmmo") or t:GetAttribute("CurrentAmmo") or 1
                if ammo > 0 and (t:GetAttribute("Local_ReloadSession") or 0) <= 0 then
                    owned[t.Name] = t
                end
            end
        end
    end
    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))

    local ordered = {}
    for _, name in ipairs(COMBO_ORDER) do
        if owned[name] then
            table.insert(ordered, owned[name])
            owned[name] = nil
        end
    end
    for _, t in pairs(owned) do
        table.insert(ordered, t)
    end
    return ordered
end

local IsComboRunning = false
local function ExecuteCombo1(specificPlr)
    if IsComboRunning then return false end
    local char = LocalPlayer.Character
    local hum = GetHumanoid(char)
    if not char or not hum or hum.Health <= 0 then return false end

    IsComboRunning = true
    local firedAny = false
    pcall(function()
        local guns = GetOwnedLoadedGuns()
        if State.ComboAutoGrabGuns and #guns < 2 then
            GrabWeapons(State.AutoGetGunsSelection, true)
            guns = GetOwnedLoadedGuns()
        end
        if #guns == 0 then
            Notify(".combo1", "No loaded weapons ready! Grabbing loadout...", 2.5)
            return
        end

        local targetPart, targetPlr = nil, nil
        if specificPlr and IsValidCombatTarget(specificPlr, State.SilentAimHostileCheck) then
            targetPart = PickAimPart(specificPlr.Character, true)
            targetPlr = specificPlr
        else
            targetPart, targetPlr = GetBestCombatTarget({
                use360 = true,
                wallcheck = true,
                wallbang = State.SilentAimWallbang,
                requireHostile = State.SilentAimHostileCheck,
                forceHead = true,
            })
        end

        if not targetPart or not targetPlr then
            Notify(".combo1", "No valid enemy in line of sight!", 2)
            return
        end

        for _, gun in ipairs(guns) do
            if not Env.PrisonLife2026Running or hum.Health <= 0 then break end
            local tHum = GetHumanoid(targetPlr.Character)
            if not tHum or tHum.Health <= 0 then
                targetPart, targetPlr = GetBestCombatTarget({
                    use360 = true,
                    wallcheck = true,
                    wallbang = State.SilentAimWallbang,
                    requireHostile = State.SilentAimHostileCheck,
                    forceHead = true,
                })
                if not targetPart then break end
            end
            if FireToolAtTarget(gun, targetPart, true, false, true) then
                firedAny = true
            end
            task.wait(State.AntiBanSafeMode and 0.075 or 0.05)
        end

        if State.ComboReEquipShield and State.HoloShield then
            local shieldTool = HasWeapon("Riot Shield")
            if shieldTool and hum.Health > 0 then
                pcall(function() hum:EquipTool(shieldTool) end)
            end
        end
    end)
    IsComboRunning = false
    return firedAny
end

-- ============================================================================
-- // SECTION 6: TEAM SWITCHER & FAST RESPAWN (<1s Neutral Trick)
-- ============================================================================
local LastDeathCFrame = nil

local function SwitchToTeam(teamName)
    if teamName == "Criminals" then
        local crimSpawn = Workspace:FindFirstChild("Criminals Spawn")
        local sp = crimSpawn and (crimSpawn:FindFirstChild("SpawnLocation") or crimSpawn:FindFirstChildWhichIsA("BasePart", true))
        local hrp = GetRoot(LocalPlayer.Character)
        if sp and hrp then
            local savedCF = hrp.CFrame
            hrp.CFrame = sp.CFrame + Vector3.new(0, 3, 0)
            if firetouchinterest then
                pcall(function()
                    firetouchinterest(hrp, sp, 0)
                    firetouchinterest(hrp, sp, 1)
                end)
            end
            task.delay(0.25, function()
                if hrp and hrp.Parent and LocalPlayer.Team == Teams:FindFirstChild("Criminals") then
                    hrp.CFrame = savedCF
                end
            end)
            return true
        end
        return false
    end

    if not Remotes.RequestTeamChange then
        Notify("Team Switch", "RequestTeamChange remote unavailable.", 3)
        return false
    end
    local targetTeam = Teams:FindFirstChild(teamName)
    if not targetTeam then return false end

    local ok, res = pcall(function()
        return Remotes.RequestTeamChange:InvokeServer(targetTeam, 1)
    end)
    return ok and res
end

local function PerformFastRespawn()
    local char = LocalPlayer.Character
    local hrp = GetRoot(char)
    local savedCF = (hrp and hrp.CFrame) or LastDeathCFrame
    local currentTeam = LocalPlayer.Team
    if not currentTeam or currentTeam == Teams:FindFirstChild("Neutral") then
        currentTeam = Teams:FindFirstChild("Inmates")
    end

    task.spawn(function()
        if currentTeam == Teams:FindFirstChild("Criminals") then
            SwitchToTeam("Inmates")
            task.wait(0.18)
            local newChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local newHrp = newChar:WaitForChild("HumanoidRootPart", 5)
            if newHrp then
                local crimSpawn = Workspace:FindFirstChild("Criminals Spawn")
                local sp = crimSpawn and crimSpawn:FindFirstChild("SpawnLocation")
                if sp then
                    newHrp.CFrame = sp.CFrame + Vector3.new(0, 3, 0)
                    task.wait(0.28)
                end
                if State.KeepPositionOnRespawn and savedCF and not State.AntiBanSafeMode then
                    newHrp.CFrame = savedCF
                end
            end
        else
            SwitchToTeam("Neutral")
            task.wait(0.12)
            SwitchToTeam(currentTeam.Name)
            local newChar = LocalPlayer.CharacterAdded:Wait()
            local newHrp = newChar:WaitForChild("HumanoidRootPart", 5)
            if newHrp and State.KeepPositionOnRespawn and savedCF then
                task.wait(0.18)
                if not State.AntiBanSafeMode or (newHrp.Position - savedCF.Position).Magnitude <= 450 then
                    newHrp.CFrame = savedCF
                end
            end
        end
    end)
end

-- ============================================================================
-- // SECTION 7: NON-DESTRUCTIVE ANTI-TASE, ANTI-ARREST, & ANTI-CHEAT BYPASSES
-- ============================================================================
local function BypassClientAntiNoclip()
    pcall(function()
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if head and getconnections then
            for _, conn in ipairs(getconnections(head:GetPropertyChangedSignal("CanCollide"))) do
                if conn and conn.Disable then conn:Disable() end
            end
        end
    end)
end

local DisabledJumpConns = {}
local function BypassAntiJump(char, enableBypass)
    if not char then return end
    pcall(function()
        local hum = GetHumanoid(char)
        if enableBypass then
            if hum and getconnections then
                for _, conn in ipairs(getconnections(hum:GetPropertyChangedSignal("Jump"))) do
                    if conn and conn.Disable then
                        conn:Disable()
                        table.insert(DisabledJumpConns, conn)
                    end
                end
            end
            local aj = char:FindFirstChild("AntiJump")
            if aj and not State.AntiBanSafeMode then aj.Disabled = true end
        else
            for _, conn in ipairs(DisabledJumpConns) do
                pcall(function() conn:Enable() end)
            end
            table.clear(DisabledJumpConns)
            local aj = char:FindFirstChild("AntiJump")
            if aj then aj.Disabled = false end
        end
    end)
end

local function PurgeTaseAndRagdoll()
    pcall(function() LocalPlayer:SetAttribute("BackpackEnabled", true) end)
    local char = LocalPlayer.Character
    local hum = GetHumanoid(char)
    local hrp = GetRoot(char)
    if not hum or hum.Health <= 0 then return end

    if hum.PlatformStand then hum.PlatformStand = false end
    if hum.Sit and not (hum.SeatPart and hum.SeatPart:IsA("VehicleSeat")) then
        hum.Sit = false
    end

    local animator = hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local animId = track.Animation and track.Animation.AnimationId or ""
            if animId:find("279227693") or animId:find("279229192") then
                pcall(function() track:Stop(0) end)
            end
        end
    end
    if hum.WalkSpeed < 8 then
        hum.WalkSpeed = State.AlwaysSprint and 24 or 16
    end
    hum.JumpPower = State.JumpPowerEnabled and State.JumpPower or 50
    hum.JumpHeight = 7.2
    if hrp then
        for _, child in ipairs(hrp:GetChildren()) do
            if (child:IsA("BodyVelocity") or child:IsA("BodyGyro")) and child.Name:sub(1, 7) ~= "PL2026_" then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

local function InstallAntiTaseAndAntiArrestHooks()
    if getconnections and hookfunction then
        if Remotes.PlayerTased then
            pcall(function()
                for _, conn in ipairs(getconnections(Remotes.PlayerTased.OnClientEvent)) do
                    if conn.Function and not conn._pl2026Hooked then
                        local orig
                        orig = hookfunction(conn.Function, function(...)
                            if Env.PrisonLife2026Running and State.AntiTase then
                                PurgeTaseAndRagdoll()
                                return nil
                            end
                            return orig(...)
                        end)
                        conn._pl2026Hooked = true
                        table.insert(HookedFunctions, { fn = conn.Function, orig = orig })
                    end
                end
            end)
        end
        if Remotes.ClientArrested then
            pcall(function()
                for _, conn in ipairs(getconnections(Remotes.ClientArrested.OnClientEvent)) do
                    if conn.Function and not conn._pl2026Hooked then
                        local orig
                        orig = hookfunction(conn.Function, function(...)
                            if Env.PrisonLife2026Running and State.AntiArrest then
                                return nil
                            end
                            return orig(...)
                        end)
                        conn._pl2026Hooked = true
                        table.insert(HookedFunctions, { fn = conn.Function, orig = orig })
                    end
                end
            end)
        end
    end
end
InstallAntiTaseAndAntiArrestHooks()

if Remotes.PlayerTased then
    AddConnection(Remotes.PlayerTased.OnClientEvent:Connect(function()
        if not State.AntiTase then return end
        task.defer(function()
            PurgeTaseAndRagdoll()
            Notify("Anti-Tase", "Blocked taser stun & restored movement!", 2.2)
        end)
    end))
end

if Remotes.ClientArrested then
    AddConnection(Remotes.ClientArrested.OnClientEvent:Connect(function()
        if State.AntiArrest then
            task.defer(PurgeTaseAndRagdoll)
        end
        if not State.AutoCriminalOnArrest then return end
        Notify("Arrested!", "Waiting 4.2s to auto-escape to Criminals...", 4)
        task.delay(4.25, function()
            SwitchToTeam("Criminals")
            Notify("Auto Criminal", "Escaped back to Criminal team!", 3)
        end)
    end))
end

-- ============================================================================
-- // SECTION 8: FIXED SERVERSIDE FE INVISIBLE (NO FLOOR TILT / CLEAN RESTORE)
-- ============================================================================
local FEInvisTrack = nil
local FEInvisHighlight = nil
local FEInvisSavedTransparencies = {}
local FEInvisToggleRef = nil
local IsSyncingFEInvis = false

local function StopFEInvisible()
    if FEInvisTrack then
        pcall(function() FEInvisTrack:Stop(0) end)
        pcall(function() FEInvisTrack:Destroy() end)
        FEInvisTrack = nil
    end

    local char = LocalPlayer.Character
    local hum = GetHumanoid(char)
    if hum then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end)
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local id = track.Animation and track.Animation.AnimationId or ""
                if id:find("215384594") or id:find("18665825805") then
                    pcall(function() track:Stop(0) end)
                    pcall(function() track:Destroy() end)
                end
            end
        end
    end

    for part, origTrans in pairs(FEInvisSavedTransparencies) do
        if part and part.Parent then
            pcall(function() part.Transparency = origTrans end)
        end
    end
    table.clear(FEInvisSavedTransparencies)

    if FEInvisHighlight then
        pcall(function() FEInvisHighlight:Destroy() end)
        FEInvisHighlight = nil
    end
    for _, child in ipairs(OverlayGui:GetChildren()) do
        if child.Name == "PL2026_GhostOutline" then
            pcall(function() child:Destroy() end)
        end
    end
end

local function StartFEInvisible()
    StopFEInvisible()
    local char = LocalPlayer.Character
    local hum = GetHumanoid(char)
    local hrp = GetRoot(char)
    if not char or not hum or not hrp or hum.Health <= 0 then return end

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)

    for _, desc in ipairs(char:GetDescendants()) do
        if (desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture")) and desc ~= hrp then
            if desc.Transparency < 0.65 then
                FEInvisSavedTransparencies[desc] = desc.Transparency
                desc.Transparency = 0.65
            end
        end
    end

    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    local isR15 = (hum.RigType == Enum.HumanoidRigType.R15)
    local anim = Instance.new("Animation")
    anim.AnimationId = isR15 and "rbxassetid://18665825805" or "rbxassetid://215384594"

    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    anim:Destroy()

    if ok and track then
        FEInvisTrack = track
        track.Priority = Enum.AnimationPriority.Action4
        track:Play(0, 0.001, 0)
        task.delay(0.03, function()
            if FEInvisTrack == track and (State.FEInvisible or (State.HoloShield and State.ShieldMode == "FEGhost")) then
                pcall(function()
                    track.TimePosition = isR15 and 1.95 or 0.4
                    track:AdjustSpeed(0)
                end)
            end
        end)

        local hl = Instance.new("Highlight")
        hl.Name = "PL2026_GhostOutline"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillColor = Color3.fromRGB(0, 210, 255)
        hl.OutlineColor = Color3.fromRGB(0, 255, 255)
        hl.FillTransparency = 1
        hl.OutlineTransparency = 0.15
        hl.Adornee = char
        hl.Parent = OverlayGui
        FEInvisHighlight = hl
    end
end

local function SetFEInvisibleState(newState, notifyUser)
    if IsSyncingFEInvis then return end
    IsSyncingFEInvis = true
    State.FEInvisible = newState
    if newState then
        StartFEInvisible()
    else
        StopFEInvisible()
    end
    if FEInvisToggleRef and FEInvisToggleRef.Set then
        pcall(function() FEInvisToggleRef:Set(newState) end)
    end
    if notifyUser then
        Notify("FE Invisible", newState and "Serverside Invisibility ON" or "Serverside Invisibility OFF", 2)
    end
    IsSyncingFEInvis = false
end

-- ============================================================================
-- // SECTION 9: VEHICLE SPAWNER, FE BRING, SPECTATE, TOP-LEFT .COMBO1 & QUICK DOCK
-- ============================================================================
local function SafeTeleport(targetCF)
    local char = LocalPlayer.Character
    local hrp = GetRoot(char)
    local hum = GetHumanoid(char)
    if not hrp then return false end
    HoloShieldState.DesyncActive = false
    HoloShieldState.SavedCF = nil
    if hum and hum.Sit then
        hum.Sit = false
        task.wait(0.03)
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = targetCF
    return true
end

local function SpawnAndEnterNearestCar()
    if not Remotes.InteractWithItem then
        Notify("Car Spawner", "InteractWithItem remote not found!", 3)
        return
    end
    local char = LocalPlayer.Character
    local hrp = GetRoot(char)
    local hum = GetHumanoid(char)
    if not hrp or not hum then return end

    local buttonsFolder = Workspace:FindFirstChild("Prison_ITEMS") and Workspace.Prison_ITEMS:FindFirstChild("buttons")
    if not buttonsFolder then return end

    local nearestBtn, bestDist = nil, math.huge
    for _, btnModel in ipairs(buttonsFolder:GetChildren()) do
        if btnModel.Name == "Car Spawner" then
            local part = btnModel:FindFirstChild("Car Spawner") or btnModel:FindFirstChildWhichIsA("BasePart")
            if part then
                local d = (part.Position - hrp.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    nearestBtn = part
                end
            end
        end
    end
    if not nearestBtn then
        Notify("Car Spawner", "No Car Spawner button found!", 3)
        return
    end

    task.spawn(function()
        local oldCF = hrp.CFrame
        if bestDist > 18 then
            SafeTeleport(nearestBtn.CFrame + Vector3.new(0, 3.5, 0))
            task.wait(0.22)
        end
        pcall(function() Remotes.InteractWithItem:InvokeServer(nearestBtn) end)
        task.wait(0.35)

        local carContainer = Workspace:FindFirstChild("CarContainer")
        if carContainer then
            local bestSeat, seatDist = nil, 60
            for _, desc in ipairs(carContainer:GetDescendants()) do
                if desc:IsA("VehicleSeat") and not desc.Occupant then
                    local d = (desc.Position - nearestBtn.Position).Magnitude
                    if d < seatDist then
                        seatDist = d
                        bestSeat = desc
                    end
                end
            end
            if bestSeat then
                SafeTeleport(bestSeat.CFrame + Vector3.new(0, 2, 0))
                task.wait(0.1)
                bestSeat:Sit(hum)
                Notify("Car Spawner", "Spawned & entered vehicle!", 3)
                return
            end
        end
        SafeTeleport(oldCF)
        Notify("Car Spawner", "Requested vehicle spawn.", 3)
    end)
end

local function BringPlayerViaVehicle(targetPlr)
    if not targetPlr or targetPlr == LocalPlayer then
        Notify("FE Bring", "Select a valid target player first!", 2.5)
        return
    end
    local myChar = LocalPlayer.Character
    local myHrp = GetRoot(myChar)
    local myHum = GetHumanoid(myChar)
    local tHrp = GetRoot(targetPlr.Character)
    local tHum = GetHumanoid(targetPlr.Character)
    if not myHrp or not myHum or not tHrp or not tHum or tHum.Health <= 0 then
        Notify("FE Bring", "Target player is not alive!", 2.5)
        return
    end

    local cc = Workspace:FindFirstChild("CarContainer")
    if not cc then
        Notify("FE Bring", "No vehicles found in CarContainer!", 2.5)
        return
    end

    local carModel, drvSeat, passSeat = nil, nil, nil
    for _, m in ipairs(cc:GetChildren()) do
        if m:IsA("Model") then
            local d, p = nil, nil
            for _, desc in ipairs(m:GetDescendants()) do
                if desc:IsA("VehicleSeat") and (not desc.Occupant or desc.Occupant == myHum) then
                    d = desc
                elseif desc:IsA("Seat") and not desc:IsA("VehicleSeat") and not desc.Occupant then
                    p = desc
                end
            end
            if d and p then
                carModel, drvSeat, passSeat = m, d, p
                break
            end
        end
    end

    if not carModel or not drvSeat or not passSeat then
        Notify("FE Bring", "Spawn a multi-seat car first (run ;car)!", 3)
        return
    end

    task.spawn(function()
        local returnCF = myHrp.CFrame
        if myHum.SeatPart ~= drvSeat then
            SafeTeleport(drvSeat.CFrame + Vector3.new(0, 2, 0))
            task.wait(0.1)
            pcall(function() drvSeat:Sit(myHum) end)
            task.wait(0.2)
        end
        local deadline = os.clock() + 1.35
        local seated = false
        while os.clock() < deadline do
            local curTHrp = GetRoot(targetPlr.Character)
            if not curTHrp or tHum.Health <= 0 then break end
            if passSeat.Occupant == tHum then
                seated = true
                break
            end
            local offset = passSeat.Position - carModel:GetPivot().Position
            pcall(function() carModel:PivotTo(CFrame.new(curTHrp.Position - offset)) end)
            task.wait(0.07)
        end
        pcall(function() carModel:PivotTo(returnCF) end)
        Notify("FE Bring", seated and ("Brought " .. targetPlr.Name .. "!") or ("Target did not enter passenger seat."), 3)
    end)
end

local SpectateTarget = nil
local function SetSpectatePlayer(targetPlr)
    SpectateTarget = targetPlr
    if not targetPlr or targetPlr == LocalPlayer then
        SpectateTarget = nil
        local myHum = GetHumanoid(LocalPlayer.Character)
        if myHum then Camera.CameraSubject = myHum end
        return
    end
    local tHum = GetHumanoid(targetPlr.Character)
    if tHum then
        Camera.CameraSubject = tHum
        Notify("Spectate", "Viewing " .. targetPlr.Name, 2.5)
    end
end

-- Top-Left .combo1 Burst Pill (Matches KX Admin HUD)
local ComboTopLeftBtn = Instance.new("TextButton")
ComboTopLeftBtn.Name = "KX_Combo1Btn"
ComboTopLeftBtn.Position = UDim2.new(0, 16, 0, 56)
ComboTopLeftBtn.Size = UDim2.fromOffset(92, 32)
ComboTopLeftBtn.BackgroundColor3 = Color3.fromRGB(22, 27, 40)
ComboTopLeftBtn.BackgroundTransparency = 0.15
ComboTopLeftBtn.Font = Enum.Font.GothamBold
ComboTopLeftBtn.TextSize = 12
ComboTopLeftBtn.TextColor3 = Color3.fromRGB(0, 230, 255)
ComboTopLeftBtn.Text = "⚡ .combo1"
ComboTopLeftBtn.Visible = State.ShowComboButton
ComboTopLeftBtn.Parent = OverlayGui
Instance.new("UICorner", ComboTopLeftBtn).CornerRadius = UDim.new(1, 0)
local ComboBtnStroke = Instance.new("UIStroke", ComboTopLeftBtn)
ComboBtnStroke.Color = Color3.fromRGB(0, 200, 255)
ComboBtnStroke.Thickness = 1.5
ComboTopLeftBtn.Activated:Connect(function()
    task.spawn(ExecuteCombo1)
end)

local MobileFlyInput = { Up = 0, Down = 0 }

local MobileQuickBar = Instance.new("Frame")
MobileQuickBar.Name = "MobileQuickBar"
MobileQuickBar.AnchorPoint = Vector2.new(1, 0.5)
MobileQuickBar.Position = UDim2.new(0.98, 0, 0.48, 0)
MobileQuickBar.Size = UDim2.fromOffset(118, 270)
MobileQuickBar.BackgroundTransparency = 1
MobileQuickBar.Visible = false
MobileQuickBar.Parent = OverlayGui

local QuickLayout = Instance.new("UIListLayout", MobileQuickBar)
QuickLayout.Padding = UDim.new(0, 6)
QuickLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
QuickLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local function CreateQuickMobileButton(text, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(112, 33)
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.18
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = text
    btn.AutoButtonColor = true
    btn.Parent = MobileQuickBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local st = Instance.new("UIStroke", btn)
    st.Color = Color3.new(1, 1, 1)
    st.Transparency = 0.65
    st.Thickness = 1
    btn.Activated:Connect(callback)
    return btn
end

local function TriggerFastSwitch()
    local char = LocalPlayer.Character
    local hum = GetHumanoid(char)
    if not char or not hum then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and (tool:GetAttribute("ToolType") == "Gun" or tool:GetAttribute("FireRate")) then
        hum:UnequipTools()
        task.wait()
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if char and hum and bp and tool.Parent == bp then
            hum:EquipTool(tool)
        end
    end
end

CreateQuickMobileButton("💥 .combo1 Burst", Color3.fromRGB(210, 50, 75), function()
    task.spawn(ExecuteCombo1)
end)
CreateQuickMobileButton("⚡ Fast Switch", Color3.fromRGB(45, 110, 220), TriggerFastSwitch)
CreateQuickMobileButton("🔫 Safe Guns", Color3.fromRGB(40, 150, 90), function()
    task.spawn(function() GrabWeapons(State.AutoGetGunsSelection) end)
end)
CreateQuickMobileButton("🛡️ Holo Shield", Color3.fromRGB(0, 145, 195), function()
    State.HoloShield = not State.HoloShield
    if State.HoloShield then
        CreateHoloShield()
        Notify("Holo-Shield", "2026 Ballistic Holo-Shield ON (" .. State.ShieldMode .. ")", 2)
    else
        DestroyHoloShield()
        Notify("Holo-Shield", "2026 Ballistic Holo-Shield OFF", 2)
    end
end)
CreateQuickMobileButton("👻 FE Invis", Color3.fromRGB(130, 65, 210), function()
    SetFEInvisibleState(not State.FEInvisible, true)
end)

local FlyUpBtn = CreateQuickMobileButton("▲ Fly Up", Color3.fromRGB(35, 140, 175), function() end)
local FlyDownBtn = CreateQuickMobileButton("▼ Fly Down", Color3.fromRGB(35, 140, 175), function() end)
FlyUpBtn.Visible = false
FlyDownBtn.Visible = false

FlyUpBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        MobileFlyInput.Up = 1
    end
end)
FlyUpBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        MobileFlyInput.Up = 0
    end
end)
FlyDownBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        MobileFlyInput.Down = 1
    end
end)
FlyDownBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        MobileFlyInput.Down = 0
    end
end)

-- ============================================================================
-- // SECTION 10: ROLE-COLORED ESP, STREAK KILLFEED & CHEATER ANOMALY DETECTOR
-- ============================================================================
local ArrestBarHolder = Instance.new("Frame")
ArrestBarHolder.Name = "ArrestCooldownBar"
ArrestBarHolder.AnchorPoint = Vector2.new(0.5, 0.5)
ArrestBarHolder.Position = UDim2.fromScale(0.5, 0.58)
ArrestBarHolder.Size = UDim2.fromOffset(150, 8)
ArrestBarHolder.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
ArrestBarHolder.BackgroundTransparency = 0.25
ArrestBarHolder.BorderSizePixel = 0
ArrestBarHolder.Visible = false
ArrestBarHolder.Parent = OverlayGui
Instance.new("UICorner", ArrestBarHolder).CornerRadius = UDim.new(1, 0)

local ArrestBarFill = Instance.new("Frame")
ArrestBarFill.Size = UDim2.fromScale(1, 1)
ArrestBarFill.BackgroundColor3 = Color3.fromRGB(65, 165, 255)
ArrestBarFill.BorderSizePixel = 0
ArrestBarFill.Parent = ArrestBarHolder
Instance.new("UICorner", ArrestBarFill).CornerRadius = UDim.new(1, 0)

local ArrestBarText = Instance.new("TextLabel")
ArrestBarText.Size = UDim2.fromOffset(150, 16)
ArrestBarText.Position = UDim2.fromOffset(0, 10)
ArrestBarText.BackgroundTransparency = 1
ArrestBarText.Font = Enum.Font.GothamBold
ArrestBarText.TextSize = 12
ArrestBarText.TextColor3 = Color3.new(1, 1, 1)
ArrestBarText.TextStrokeTransparency = 0.2
ArrestBarText.Text = ""
ArrestBarText.Parent = ArrestBarHolder

local ESPObjects = {}
local C4Highlights = {}

local function RemovePlayerESP(plr)
    local data = ESPObjects[plr]
    if data then
        if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
        if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
        ESPObjects[plr] = nil
    end
end

local function UpdatePlayerESP()
    local myHrp = GetRoot(LocalPlayer.Character)
    local highlightCount = 0

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local hrp = GetRoot(char)
            local hum = GetHumanoid(char)
            local hideTeammate = State.ESPHideTeam and (plr.Team == LocalPlayer.Team)

            if State.ESP and not hideTeammate and char and hrp and hum and hum.Health > 0 then
                if hrp.Transparency < 1 then hrp.Transparency = 1 end

                local data = ESPObjects[plr]
                if not data then
                    data = {}
                    local hl = Instance.new("Highlight")
                    hl.Name = "PL2026_HL"
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.FillTransparency = 0.68
                    hl.OutlineTransparency = 0.12
                    hl.Parent = OverlayGui
                    data.Highlight = hl

                    local bb = Instance.new("BillboardGui")
                    bb.Name = "PL2026_BB"
                    bb.Size = UDim2.fromOffset(170, 42)
                    bb.StudsOffset = Vector3.new(0, 3.2, 0)
                    bb.AlwaysOnTop = true
                    bb.Parent = OverlayGui
                    data.Billboard = bb

                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.fromScale(1, 1)
                    lbl.BackgroundTransparency = 1
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 11
                    lbl.TextStrokeTransparency = 0.15
                    lbl.Parent = bb
                    data.Label = lbl

                    ESPObjects[plr] = data
                end

                local teamColor = (plr.Team and plr.Team.TeamColor.Color) or Color3.fromRGB(220, 220, 220)
                highlightCount = highlightCount + 1
                data.Highlight.Enabled = State.ESPHighlight and (highlightCount <= 30)
                data.Highlight.Adornee = char
                data.Highlight.FillColor = teamColor
                data.Highlight.OutlineColor = teamColor

                data.Billboard.Enabled = State.ESPNameTag or State.ESPHealth or State.ESPDistance or State.ESPWeapon
                data.Billboard.Adornee = char:FindFirstChild("Head") or hrp

                local dist = myHrp and round((hrp.Position - myHrp.Position).Magnitude) or 0
                local tool = char:FindFirstChildOfClass("Tool")

                local lines = {}
                if State.ESPNameTag then
                    local flags = ""
                    if State.ESPStatusFlags then
                        if char:GetAttribute("Hostile") then flags = flags .. " [HOSTILE]" end
                        if char:GetAttribute("Trespassing") then flags = flags .. " [TRESPASS]" end
                        if char:GetAttribute("Tased") then flags = flags .. " [TASED]" end
                    end
                    table.insert(lines, string.format("%s%s", plr.DisplayName or plr.Name, flags))
                end

                if dist <= 240 or tool then
                    local infoParts = {}
                    if State.ESPHealth then
                        table.insert(infoParts, string.format("%dHP", round(hum.Health)))
                    end
                    if State.ESPDistance then
                        table.insert(infoParts, string.format("%dm", dist))
                    end
                    if State.ESPWeapon and tool then
                        table.insert(infoParts, string.format("[%s]", tool.Name))
                    end
                    if #infoParts > 0 then
                        table.insert(lines, table.concat(infoParts, " • "))
                    end
                end

                data.Label.TextColor3 = teamColor
                data.Label.Text = table.concat(lines, "\n")
            else
                RemovePlayerESP(plr)
            end
        end
    end

    if State.C4ESP then
        for _, c4 in ipairs(CollectionService:GetTagged("C4")) do
            if not C4Highlights[c4] then
                local hl = Instance.new("Highlight")
                hl.Name = "PL2026_C4HL"
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.FillColor = Color3.fromRGB(255, 50, 50)
                hl.OutlineColor = Color3.fromRGB(255, 220, 0)
                hl.FillTransparency = 0.35
                hl.OutlineTransparency = 0
                hl.Adornee = c4
                hl.Parent = OverlayGui
                C4Highlights[c4] = hl
            end
        end
        for c4, hl in pairs(C4Highlights) do
            if not c4 or not c4.Parent then
                pcall(function() hl:Destroy() end)
                C4Highlights[c4] = nil
            end
        end
    else
        for c4, hl in pairs(C4Highlights) do
            pcall(function() hl:Destroy() end)
            C4Highlights[c4] = nil
        end
    end
end

AddConnection(Players.PlayerRemoving:Connect(RemovePlayerESP))

-- Live Killfeed Watcher with Streak Tracking & [COMBO] / [RAGEBOT] Tags
local KillerStreaks = {}
pcall(function()
    local kfFolder = ReplicatedStorage:FindFirstChild("Killfeed")
    if kfFolder then
        AddConnection(kfFolder.ChildAdded:Connect(function(entry)
            task.defer(function()
                local text = (entry:IsA("StringValue") and entry.Value) or entry:GetAttribute("Text") or entry.Name or ""
                if text == "" then return end
                local killerRaw, rest = text:match("^(.+) killed (.+)$")
                if killerRaw and rest then
                    KillerStreaks[killerRaw] = (KillerStreaks[killerRaw] or 0) + 1
                    local streak = KillerStreaks[killerRaw]
                    local isMe = killerRaw:find(LocalPlayer.Name, 1, true) or killerRaw:find(LocalPlayer.DisplayName, 1, true)
                    if isMe and State.KillSound then
                        pcall(function()
                            KillStreakSound.PlaybackSpeed = math.min(1.6, 1.3 + (streak * 0.04))
                            KillStreakSound:Play()
                        end)
                    end
                    if State.KillFeedNotifier and (isMe or rest:find(LocalPlayer.Name, 1, true) or streak >= 5) then
                        local tag = ""
                        local now = os.clock()
                        if isMe then
                            if (now - GunHook.LastComboShotClock) <= 1.2 then
                                tag = "[.combo1] "
                            elseif (now - GunHook.LastRageShotClock) <= 1.2 then
                                tag = "[RAGEBOT] "
                            end
                        end
                        Notify("Killfeed (" .. tostring(streak) .. "x)", tag .. text, 3.2)
                    end
                end
            end)
        end))
    end
end)

-- Multi-Strike Heuristic Cheater & Car-TP Anomaly Detector
local AnomalyTracker = {
    PrevPos = setmetatable({}, { __mode = "k" }),
    PrevSeated = setmetatable({}, { __mode = "k" }),
    Strikes = {},
}

local function EvaluateAnomalies()
    if not State.CheaterAlerts and not State.CarTPAlerts then return end
    local now = os.clock()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local hrp = GetRoot(char)
            local hum = GetHumanoid(char)
            if hrp and hum and hum.Health > 0 then
                local seated = (hum.SeatPart and hum.SeatPart:IsA("VehicleSeat")) ~= nil
                local prev = AnomalyTracker.PrevPos[plr]
                local wasSeated = AnomalyTracker.PrevSeated[plr]
                local curPos = hrp.Position

                if prev and prev.char == char then
                    local dt = math.max(0.05, now - prev.t)
                    local dist = (curPos - prev.pos).Magnitude
                    local horizSpeed = Vector3.new(curPos.X - prev.pos.X, 0, curPos.Z - prev.pos.Z).Magnitude / dt
                    local st = AnomalyTracker.Strikes[plr.UserId] or { count = 0, lastAlert = 0, lastStrike = 0 }
                    if (now - st.lastStrike) > 12 then st.count = 0 end

                    if State.CarTPAlerts and seated and not wasSeated and dist > 115 then
                        st.count = st.count + 2
                        st.lastStrike = now
                        if (now - st.lastAlert) > 8 then
                            st.lastAlert = now
                            Notify("Car-TP Alert", string.format("%s snapped %.0f studs into a vehicle!", plr.Name, dist), 3.5)
                        end
                    elseif State.CheaterAlerts and not seated and horizSpeed > 180 and dist > 58 then
                        st.count = st.count + 1
                        st.lastStrike = now
                        if st.count >= 2 and (now - st.lastAlert) > 8 then
                            st.lastAlert = now
                            Notify("Cheater Alert", string.format("%s moving at %.0f studs/s (Speed/TP)", plr.Name, horizSpeed), 3.5)
                        end
                    end
                    AnomalyTracker.Strikes[plr.UserId] = st
                end
                AnomalyTracker.PrevPos[plr] = { pos = curPos, t = now, char = char }
                AnomalyTracker.PrevSeated[plr] = seated
            end
        end
    end
end

-- ============================================================================
-- // SECTION 11: EXACT 2026 MAXSPEED SUB-REGIONS & MAIN RUNTIME LOOPS
-- ============================================================================
local IndoorSubRegions = {
    { cx = 752.77, cz = 2571.80, hx = 109.93 / 2, hz = 13.60 / 2 },
    { cx = 701.15, cz = 2313.70, hx = 69.10 / 2,  hz = 163.00 / 2 },
    { cx = 917.30, cz = 2392.60, hx = 107.00 / 2, hz = 28.00 / 2 },
    { cx = 830.30, cz = 2242.55, hx = 58.00 / 2,  hz = 34.10 / 2 },
    { cx = 748.90, cz = 2340.60, hx = 59.40 / 2,  hz = 109.20 / 2 },
    { cx = 799.10, cz = 2299.00, hx = 14.00 / 2,  hz = 33.99 / 2 },
    { cx = 826.69, cz = 2338.60, hx = 51.19 / 2,  hz = 12.00 / 2 },
    { cx = 799.65, cz = 2269.23, hx = 12.90 / 2,  hz = 21.50 / 2 },
    { cx = 765.36, cz = 2247.57, hx = 59.32 / 2,  hz = 64.82 / 2 },
    { cx = 850.20, cz = 2571.80, hx = 23.20 / 2,  hz = 13.60 / 2 },
    { cx = 779.80, cz = 2479.80, hx = 164.00 / 2, hz = 170.40 / 2 },
    { cx = 983.35, cz = 2315.15, hx = 31.10 / 2,  hz = 58.90 / 2 },
    { cx = 916.50, cz = 2225.40, hx = 99.00 / 2,  hz = 38.00 / 2 },
    { cx = 889.80, cz = 2361.60, hx = 220.00 / 2, hz = 34.00 / 2 },
    { cx = 915.80, cz = 2456.60, hx = 64.00 / 2,  hz = 100.00 / 2 },
    { cx = 820.80, cz = 2386.60, hx = 82.00 / 2,  hz = 16.00 / 2 },
    { cx = 916.90, cz = 2294.50, hx = 98.20 / 2,  hz = 100.20 / 2 },
    { cx = 836.95, cz = 2296.10, hx = 61.70 / 2,  hz = 73.00 / 2 },
    { cx = 872.30, cz = 2463.60, hx = 19.00 / 2,  hz = 62.00 / 2 },
    { cx = 959.30, cz = 2463.60, hx = 19.00 / 2,  hz = 62.00 / 2 },
}
local PrisonOuterBox = { cx = 773.62, cz = 2327.43, hx = 563.37 / 2, hz = 540.30 / 2 }

local function IsInsideBox(x, z, box)
    return math.abs(x - box.cx) <= box.hx and math.abs(z - box.cz) <= box.hz
end

local function GetSafeRegionMaxSpeed(pos)
    local x, z = pos.X, pos.Z
    for _, r in ipairs(IndoorSubRegions) do
        if IsInsideBox(x, z, r) then return 32 end
    end
    if IsInsideBox(x, z, PrisonOuterBox) then return 50 end
    return 92
end

local LastTriggerShot = 0
local LastRageShot = 0
local LastArrestTime = 0
local LastKillAuraTime = 0
local LastAutoTazeTime = 0
local LastLoopKillTime = 0
local LastComboLoopTime = 0
local LoopKillCursor = 1
local FlyBV, FlyBG = nil, nil

local function CleanupCharFly()
    if FlyBV then pcall(function() FlyBV:Destroy() end); FlyBV = nil end
    if FlyBG then pcall(function() FlyBG:Destroy() end); FlyBG = nil end
    local hum = GetHumanoid(LocalPlayer.Character)
    if hum and hum.PlatformStand then hum.PlatformStand = false end
end

AddConnection(RunService.RenderStepped:Connect(function(dt)
    -- Restore DesyncBox CFrame before camera render so your screen never jitters!
    if HoloShieldState.DesyncActive and HoloShieldState.SavedCF then
        local myHrp = GetRoot(LocalPlayer.Character)
        if myHrp then
            myHrp.CFrame = HoloShieldState.SavedCF
        end
        HoloShieldState.DesyncActive = false
        HoloShieldState.SavedCF = nil
    end

    local screenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    if not IsMobile and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        local mPos = UserInputService:GetMouseLocation()
        screenCenter = Vector2.new(mPos.X, mPos.Y)
    end

    -- Update FOV Circles
    SilentFOVFrame.Visible = State.SilentAim and State.SilentAimShowFOV
    if SilentFOVFrame.Visible then
        SilentFOVFrame.Position = UDim2.fromOffset(screenCenter.X, screenCenter.Y)
        SilentFOVFrame.Size = UDim2.fromOffset(State.SilentAimFOV * 2, State.SilentAimFOV * 2)
    end

    AimAssistFOVFrame.Visible = State.AimAssist and State.AimAssistShowFOV
    if AimAssistFOVFrame.Visible then
        AimAssistFOVFrame.Position = UDim2.fromOffset(screenCenter.X, screenCenter.Y)
        AimAssistFOVFrame.Size = UDim2.fromOffset(State.AimAssistFOV * 2, State.AimAssistFOV * 2)
    end

    -- Update Silent Aim Target & Wallbang Origin
    if State.SilentAim then
        local part, _, clearOrg, clearHit = GetBestCombatTarget({
            use360 = false,
            fov = State.SilentAimFOV,
            wallcheck = State.SilentAimWallcheck,
            wallbang = State.SilentAimWallbang,
            requireHostile = State.SilentAimHostileCheck,
        })
        GunHook.CurrentSilentTargetPart = part
        GunHook.CurrentSilentOrigin = clearOrg
        GunHook.CurrentSilentHitPos = clearHit
    else
        GunHook.CurrentSilentTargetPart = nil
        GunHook.CurrentSilentOrigin = nil
        GunHook.CurrentSilentHitPos = nil
    end

    -- Smooth Camera Aim Assist
    if State.AimAssist then
        local holdingGun = IsHoldingFirearm()
        if holdingGun then
            local targetPart = GetBestScreenTarget(
                State.AimAssistFOV,
                State.AimAssistAimPart,
                true,
                State.SilentAimHostileCheck
            )
            if targetPart then
                local aimPos = targetPart.Position
                if State.AimAssistPrediction then
                    local vel = targetPart.AssemblyLinearVelocity or Vector3.zero
                    aimPos = aimPos + (vel * State.AimAssistPredictionStrength)
                end
                local goalCF = CFrame.lookAt(Camera.CFrame.Position, aimPos)
                local alpha = clamp(State.AimAssistSmoothness * (IsMobile and 1.35 or 1), 0.05, 1)
                Camera.CFrame = Camera.CFrame:Lerp(goalCF, alpha)
            end
        end
    end

    -- Triggerbot / Auto-Shoot
    if State.Triggerbot and not State.Ragebot then
        if not GunHook.Ready then SetupGunControllerHooks() end
        if GunHook.Ready and GunHook.Shoot then
            local holdingGun, tool = IsHoldingFirearm()
            if holdingGun and tool then
                local ammo = tool:GetAttribute("Local_CurrentAmmo") or tool:GetAttribute("CurrentAmmo") or 1
                if ammo <= 0 then
                    if State.TriggerbotAutoReload and GunHook.Reload and (tool:GetAttribute("Local_ReloadSession") or 0) <= 0 then
                        task.spawn(GunHook.Reload)
                    end
                elseif not tool:GetAttribute("Local_IsShooting") and (os.clock() - LastTriggerShot) >= math.max(State.TriggerbotDelay, State.AntiBanSafeMode and 0.08 or 0.04) then
                    local targetPart = GunHook.CurrentSilentTargetPart or GetBestScreenTarget(
                        State.SilentAimFOV,
                        State.SilentAimAimPart,
                        State.TriggerbotWallcheck,
                        State.SilentAimHostileCheck
                    )
                    if targetPart then
                        LastTriggerShot = os.clock()
                        FireToolAtTarget(tool, targetPart, false, false, false)
                    end
                end
            end
        end
    end

    -- Update 4-Mode 3D Ballistic Holo-Shield Visual & Durability Bar
    if State.HoloShield then
        local myHrp = GetRoot(LocalPlayer.Character)
        if myHrp then
            if State.ShieldMode == "FEGhost" then
                if HoloShieldState.Model then DestroyHoloShield() end
                if not FEInvisTrack then StartFEInvisible() end
            else
                if not HoloShieldState.CorePart or not HoloShieldState.CorePart.Parent then
                    CreateHoloShield()
                end
                local core = HoloShieldState.CorePart
                if core then
                    local sz = clamp(tonumber(State.ShieldSize) or 6.5, 3, 14)
                    core.Size = Vector3.new(sz * 0.82, sz * 0.95, 0.35)
                    local now = os.clock()
                    if now < HoloShieldState.BrokenUntil then
                        local rem = HoloShieldState.BrokenUntil - now
                        ShieldBarFill.Size = UDim2.fromScale(clamp(1 - (rem / 4.0), 0, 1), 1)
                        ShieldBarFill.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
                        ShieldBarText.Text = string.format("🛡️ RECHARGING: %.1fs", rem)
                    else
                        local targetTrans = clamp(tonumber(State.ShieldTransparency) or 0.72, 0.45, 0.95)
                        if not core.CanQuery then
                            core.Transparency = targetTrans
                            core.CanQuery = true
                            HoloShieldState.HP = HoloShieldState.MaxHP
                        else
                            core.Transparency = targetTrans
                            if (now - HoloShieldState.LastHit) > 2.8 and HoloShieldState.HP < HoloShieldState.MaxHP then
                                HoloShieldState.HP = math.min(HoloShieldState.MaxHP, HoloShieldState.HP + (32 * dt))
                            end
                        end
                        local frac = clamp(HoloShieldState.HP / HoloShieldState.MaxHP, 0, 1)
                        ShieldBarFill.Size = UDim2.fromScale(frac, 1)
                        ShieldBarFill.BackgroundColor3 = Color3.fromRGB(0, 215, 255)
                        ShieldBarText.Text = string.format("🛡️ SHIELD (%s): %d/%d", State.ShieldMode:upper(), round(HoloShieldState.HP), HoloShieldState.MaxHP)
                    end

                    local look = Camera.CFrame.LookVector
                    local flatLook = Vector3.new(look.X, 0, look.Z)
                    flatLook = (flatLook.Magnitude < 0.01) and myHrp.CFrame.LookVector or flatLook.Unit
                    local shieldPos = myHrp.Position + (flatLook * 3.6) + Vector3.new(0, 0.25, 0)
                    core.CFrame = CFrame.lookAt(shieldPos, shieldPos + flatLook)
                end
            end
        end
    end

    -- Arrest Cooldown Bar Render
    if State.AutoArrest and State.AutoArrestCooldownBar and (LastArrestTime > os.clock()) then
        ArrestBarHolder.Visible = true
        local rem = math.max(0, LastArrestTime - os.clock())
        ArrestBarFill.Size = UDim2.fromScale(clamp(rem / 7, 0, 1), 1)
        ArrestBarText.Text = string.format("Arrest Cooldown: %.1fs", rem)
    else
        ArrestBarHolder.Visible = false
    end
end))

-- Heartbeat Loop (Ragebot, .combo1 Loop, Shield Desync/Spin/Face, WalkSpeed, Fly, KillAura, AutoTaze, AutoArrest, LoopKill)
AddConnection(RunService.Heartbeat:Connect(function(dt)
    local now = os.clock()
    local char = LocalPlayer.Character
    local hrp = GetRoot(char)
    local hum = GetHumanoid(char)

    if char and hrp and hum and hum.Health > 0 then
        LastDeathCFrame = hrp.CFrame

        if State.AlwaysBackpack then
            LocalPlayer:SetAttribute("BackpackEnabled", true)
        end

        -- Anti-KillPlane
        if State.AntiKillPlane then
            if hrp.Position.Y < -8 or hrp.Position.Y > 179.5 then
                local clampedY = clamp(hrp.Position.Y, -5, 178)
                hrp.CFrame = CFrame.new(hrp.Position.X, clampedY, hrp.Position.Z) * hrp.CFrame.Rotation
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
            end
        end

        -- JumpPower Boost
        if State.JumpPowerEnabled then
            hum.UseJumpPower = true
            hum.JumpPower = State.AntiBanSafeMode and math.min(State.JumpPower, 75) or State.JumpPower
        end

        -- Region-Aware Native Humanoid.WalkSpeed
        if not hum.Sit then
            if State.MaxSpeed then
                local regionCeiling = GetSafeRegionMaxSpeed(hrp.Position)
                if State.MaxSpeedMode == "AlwaysSprint" then
                    if hum.WalkSpeed < 24 then hum.WalkSpeed = 24 end
                elseif State.MaxSpeedMode == "RegionSafe" or State.AntiBanSafeMode then
                    local target = (State.MaxSpeedMode == "Custom") and math.min(State.CustomWalkSpeed, regionCeiling) or regionCeiling
                    hum.WalkSpeed = target
                else
                    local safeCustom = (regionCeiling == 32) and math.min(State.CustomWalkSpeed, 34) or State.CustomWalkSpeed
                    hum.WalkSpeed = safeCustom
                end
            elseif State.AlwaysSprint then
                if hum.WalkSpeed < 24 then hum.WalkSpeed = 24 end
            end
        end

        -- Noclip
        if State.Noclip then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end

        -- Character Fly & Vehicle Fly
        local seat = hum.SeatPart
        local isDriving = (seat and seat:IsA("VehicleSeat")) ~= nil
        FlyUpBtn.Visible = State.VehicleFly or State.Fly
        FlyDownBtn.Visible = State.VehicleFly or State.Fly

        if State.Fly and not isDriving then
            local flySpd = State.AntiBanSafeMode and math.min(State.FlySpeed, 85) or State.FlySpeed
            local moveDir = hum.MoveDirection
            local vel = Vector3.zero
            if moveDir.Magnitude > 0 then
                vel = vel + (moveDir.Unit * flySpd)
            end
            local vert = (MobileFlyInput.Up - MobileFlyInput.Down)
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
                vert = 1
            elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                vert = -1
            end
            vel = vel + Vector3.new(0, vert * (flySpd * 0.75), 0)

            if State.AntiBanSafeMode then
                CleanupCharFly()
                hrp.AssemblyLinearVelocity = Vector3.new(vel.X, math.max(vel.Y, 0), vel.Z)
                hrp.CFrame = hrp.CFrame + (vel * dt)
            else
                if not FlyBV or FlyBV.Parent ~= hrp then
                    CleanupCharFly()
                    FlyBV = Instance.new("BodyVelocity")
                    FlyBV.Name = "PL2026_FlyBV"
                    FlyBV.MaxForce = Vector3.new(9e4, 9e4, 9e4)
                    FlyBV.Parent = hrp
                    FlyBG = Instance.new("BodyGyro")
                    FlyBG.Name = "PL2026_FlyBG"
                    FlyBG.MaxTorque = Vector3.new(9e4, 9e4, 9e4)
                    FlyBG.P = 9000
                    FlyBG.Parent = hrp
                end
                FlyBV.Velocity = vel
                FlyBG.CFrame = Camera.CFrame
                hum.PlatformStand = true
            end
        else
            CleanupCharFly()
        end

        if isDriving then
            if State.VehicleFly then
                local camCF = Camera.CFrame
                local moveDir = hum.MoveDirection
                local vel = Vector3.zero
                local flySpeed = State.AntiBanSafeMode and math.min(State.VehicleFlySpeed, 110) or State.VehicleFlySpeed

                if moveDir.Magnitude > 0 then
                    vel = vel + (moveDir.Unit * flySpeed)
                end
                local vertical = (MobileFlyInput.Up - MobileFlyInput.Down)
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
                    vertical = 1
                elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                    vertical = -1
                end
                vel = vel + Vector3.new(0, vertical * (flySpeed * 0.75), 0)

                seat.AssemblyLinearVelocity = vel
                seat.AssemblyAngularVelocity = Vector3.zero
                seat.CFrame = CFrame.new(seat.Position) * CFrame.fromEulerAnglesYXZ(0, select(2, camCF:ToEulerAnglesYXZ()), 0)
            elseif State.VehicleSpeedMod then
                local moveDir = hum.MoveDirection
                if moveDir.Magnitude > 0 then
                    local mult = State.AntiBanSafeMode and math.min(State.VehicleSpeedMult, 2.6) or State.VehicleSpeedMult
                    local boost = seat.CFrame.LookVector * (seat.ThrottleFloat * 28 * mult)
                    seat.AssemblyLinearVelocity = Vector3.new(boost.X, seat.AssemblyLinearVelocity.Y, boost.Z)
                end
            end
        end

        -- 360° Ragebot with Auto-Switch & Shield-Peek
        if State.Ragebot then
            local rateSPS = State.AntiBanSafeMode and math.min(State.RagebotRate, 15) or State.RagebotRate
            local interval = 1 / math.max(1, rateSPS)
            if (now - LastRageShot) >= interval then
                local targetPart = GetBestCombatTarget({
                    use360 = State.Ragebot360,
                    fov = State.SilentAimFOV,
                    wallcheck = true,
                    wallbang = State.SilentAimWallbang,
                    requireHostile = State.SilentAimHostileCheck,
                    forceHead = true,
                })
                if targetPart then
                    local holdingGun, gun = IsHoldingFirearm()
                    local ammo = (gun and (gun:GetAttribute("Local_CurrentAmmo") or gun:GetAttribute("CurrentAmmo"))) or 0
                    if not holdingGun or ammo <= 0 or gun.Name == "Taser" then
                        if State.RagebotAutoSwitch then
                            local loadedGuns = GetOwnedLoadedGuns()
                            gun = loadedGuns[1]
                        else
                            gun = nil
                        end
                    end
                    if gun then
                        LastRageShot = now
                        FireToolAtTarget(gun, targetPart, true, false, false)
                    end
                end
            end
        end

        -- .combo1 Auto-Loop
        if State.ComboLoop and not IsComboRunning then
            local iv = math.max(0.25, tonumber(State.ComboLoopInterval) or 0.55)
            if (now - LastComboLoopTime) >= iv then
                LastComboLoopTime = now
                task.spawn(ExecuteCombo1)
            end
        end

        -- 4-Mode Shield Auto-Equip, Auto-Face Shooter, Spin-Block & DesyncBox Jitter
        if State.HoloShield and not hum.Sit and HoloShieldState.HP > 0 and now >= HoloShieldState.BrokenUntil then
            local mode = State.ShieldMode or "Hybrid"
            if (mode == "Hybrid" or mode == "RiotOnly") and State.ShieldAutoEquip and not HasEquippedRiotShield() then
                local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                local riot = bp and bp:FindFirstChild("Riot Shield")
                if riot and not IsComboRunning and not State.Ragebot then
                    pcall(function() hum:EquipTool(riot) end)
                end
            end

            if State.ShieldAutoFaceShooter and not State.ShieldSpinBlock then
                local threatPart = GetBestCombatTarget({ use360 = true, wallcheck = false, range = 95 })
                if threatPart then
                    hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(threatPart.Position.X, hrp.Position.Y, threatPart.Position.Z))
                end
            end

            if State.ShieldSpinBlock then
                local spinSpd = tonumber(State.ShieldSpinSpeed) or 16
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, spinSpd * dt, 0)
            end

            local wantsDesync = (mode == "DesyncBox") or (mode == "Hybrid" and not HasEquippedRiotShield())
            local peekPause = State.RagebotPeekShield and ((now - GunHook.LastRageShotClock) < 0.12 or (now - GunHook.LastComboShotClock) < 0.12)
            if wantsDesync and not peekPause and not IsGrabbingGuns then
                local rad = clamp(tonumber(State.DesyncJitterRadius) or 3.2, 0.8, State.AntiBanSafeMode and 4.0 or 7.5)
                HoloShieldState.JitterAngle = (HoloShieldState.JitterAngle + 2.35) % (math.pi * 2)
                local ox = math.cos(HoloShieldState.JitterAngle) * rad
                local oz = math.sin(HoloShieldState.JitterAngle) * rad
                HoloShieldState.SavedCF = hrp.CFrame
                HoloShieldState.DesyncActive = true
                hrp.CFrame = HoloShieldState.SavedCF + Vector3.new(ox, 0, oz)
            end
        end

        -- Anti-Ban Hardened Melee Kill Aura
        local auraCooldown = State.AntiBanSafeMode and 0.32 or 0.20
        if State.KillAura and Remotes.MeleeEvent and (now - LastKillAuraTime) >= auraCooldown then
            local maxRange = State.AntiBanSafeMode and math.min(State.KillAuraRange, 10) or State.KillAuraRange
            local closestTarget, closestHrp, bestDist = nil, nil, maxRange

            for _, plr in ipairs(Players:GetPlayers()) do
                if IsValidCombatTarget(plr, State.KillAuraGuardSafe, State.KillAuraWhitelist) then
                    local tHrp = GetRoot(plr.Character)
                    if tHrp then
                        local d = (tHrp.Position - hrp.Position).Magnitude
                        if d <= bestDist then
                            bestDist = d
                            closestTarget = plr
                            closestHrp = tHrp
                        end
                    end
                end
            end

            if closestTarget and closestHrp then
                LastKillAuraTime = now
                Remotes.MeleeEvent:FireServer(closestTarget, 1, 1)
                if State.KillAuraFaceTarget then
                    hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(closestHrp.Position.X, hrp.Position.Y, closestHrp.Position.Z))
                end
            end
        end

        -- Auto-Taze Aura (Guards Taser Automation)
        if State.AutoTaze and (now - LastAutoTazeTime) >= 1.15 then
            local taser = HasWeapon("Taser")
            local taserAmmo = taser and (taser:GetAttribute("Local_CurrentAmmo") or taser:GetAttribute("CurrentAmmo") or 1) or 0
            if taser and taserAmmo > 0 then
                local bestHead, bestDist = nil, 46
                for _, plr in ipairs(Players:GetPlayers()) do
                    if IsValidCombatTarget(plr, true, State.ArrestWhitelist) then
                        local tChar = plr.Character
                        local tHead = tChar and tChar:FindFirstChild("Head")
                        local tHrp = GetRoot(tChar)
                        if tHead and tHrp and not tChar:GetAttribute("Tased") then
                            local d = (tHrp.Position - hrp.Position).Magnitude
                            if d < bestDist and HasLineOfSight(hrp.Position, tHead, tChar) then
                                bestDist = d
                                bestHead = tHead
                            end
                        end
                    end
                end
                if bestHead then
                    LastAutoTazeTime = now
                    local prevTool = char:FindFirstChildOfClass("Tool")
                    task.spawn(function()
                        FireToolAtTarget(taser, bestHead, false, true, false)
                        task.wait(0.12)
                        if prevTool and prevTool ~= taser and hum and hum.Health > 0 then
                            pcall(function() hum:EquipTool(prevTool) end)
                        end
                    end)
                end
            end
        end

        -- Auto Arrest Aura
        if State.AutoArrest and Remotes.ArrestPlayer and (now >= LastArrestTime) then
            local canAttempt = true
            if State.AutoArrestHandCheck then
                local eq = char:FindFirstChildOfClass("Tool")
                canAttempt = eq ~= nil and eq.Name == "Handcuffs"
            end

            if canAttempt then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and not State.ArrestWhitelist[plr.UserId] and plr.Team ~= Teams:FindFirstChild("Guards") and plr.Team ~= Teams:FindFirstChild("Neutral") then
                        local tChar = plr.Character
                        local tHrp = GetRoot(tChar)
                        local tHum = GetHumanoid(tChar)
                        if tChar and tHrp and tHum and tHum.Health > 0 and not tChar:GetAttribute("Arrested") then
                            local validArrest = (plr.Team == Teams:FindFirstChild("Criminals"))
                                or (plr.Team == Teams:FindFirstChild("Inmates") and (tChar:GetAttribute("Trespassing") or tChar:GetAttribute("Tased") or tChar:GetAttribute("Hostile")))

                            local maxArRange = State.AntiBanSafeMode and math.min(State.AutoArrestRange, 10) or State.AutoArrestRange
                            if validArrest and (tHrp.Position - hrp.Position).Magnitude <= maxArRange then
                                LastArrestTime = now + 0.5
                                task.spawn(function()
                                    local ok, arrested = pcall(function()
                                        return Remotes.ArrestPlayer:InvokeServer(plr, 1)
                                    end)
                                    if ok and arrested then
                                        LastArrestTime = os.clock() + 7
                                        Notify("Auto Arrest", "Arrested " .. plr.Name .. "!", 3)
                                    end
                                end)
                                break
                            end
                        end
                    end
                end
            end
        end

        -- Persistent LoopKill Priority List
        if (now - LastLoopKillTime) >= 0.35 then
            local lkList = {}
            for uid, active in pairs(State.LoopKillTargets) do
                if active then table.insert(lkList, uid) end
            end
            if #lkList > 0 then
                LoopKillCursor = ((LoopKillCursor - 1) % #lkList) + 1
                local targetUid = lkList[LoopKillCursor]
                LoopKillCursor = LoopKillCursor + 1
                local targetPlr = Players:GetPlayerByUserId(targetUid)
                if targetPlr and not State.KillAuraWhitelist[targetUid] then
                    local tChar = targetPlr.Character
                    local tHum = GetHumanoid(tChar)
                    local tPart = tChar and (tChar:FindFirstChild("Head") or GetRoot(tChar))
                    if tHum and tHum.Health > 0 and tPart and not tChar:FindFirstChildOfClass("ForceField") then
                        local loaded = GetOwnedLoadedGuns()
                        if loaded[1] then
                            LastLoopKillTime = now
                            FireToolAtTarget(loaded[1], tPart, true, false, false)
                        end
                    end
                end
            end
        end
    end

    -- Anti-Fling (Vehicles + High-Spinning Players)
    if State.AntiFling then
        if Workspace:FindFirstChild("CarContainer") then
            for _, part in ipairs(Workspace.CarContainer:GetDescendants()) do
                if part:IsA("BasePart") and part.CollisionGroup ~= "Wheels" and part.CanCollide then
                    local mySeat = hum and hum.SeatPart
                    if not mySeat or not part:IsDescendantOf(mySeat.Parent.Parent) then
                        part.CanCollide = false
                        part.CanTouch = false
                    end
                end
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local tHrp = GetRoot(plr.Character)
                if tHrp and tHrp.AssemblyAngularVelocity.Magnitude > 85 then
                    for _, desc in ipairs(plr.Character:GetDescendants()) do
                        if desc:IsA("BasePart") and desc.CanCollide then
                            desc.CanCollide = false
                        end
                    end
                end
            end
        end
    end

    -- Vehicle Fling Exploit (Blocked in Anti-Ban Safe Mode)
    if State.VehicleFling and not State.AntiBanSafeMode and Workspace:FindFirstChild("CarContainer") then
        for _, desc in ipairs(Workspace.CarContainer:GetDescendants()) do
            if desc:IsA("VehicleSeat") then
                local owned = true
                pcall(function()
                    if isnetworkowner then owned = isnetworkowner(desc) end
                end)
                if owned then
                    local targetPlr = nil
                    if State.VehicleFlingTarget ~= "All" then
                        targetPlr = Players:FindFirstChild(State.VehicleFlingTarget)
                    end
                    if not targetPlr then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if IsValidCombatTarget(p, false) then
                                local tHum = GetHumanoid(p.Character)
                                if tHum and not tHum.Sit then
                                    targetPlr = p
                                    break
                                end
                            end
                        end
                    end
                    local tHrp = targetPlr and GetRoot(targetPlr.Character)
                    if tHrp then
                        desc.AssemblyLinearVelocity = Vector3.new(9500, 9500, 0)
                        desc.CFrame = CFrame.new(tHrp.Position) * CFrame.new(-1.5, 0, -8)
                    end
                end
            end
        end
    end
end))

-- Saved Door & Hitbox Data for Clean Restoration
local OriginalDoorData = setmetatable({}, { __mode = "k" })
local OriginalHitboxData = setmetatable({}, { __mode = "k" })

local function RestoreAllHitboxes()
    for hrp, orig in pairs(OriginalHitboxData) do
        if hrp and hrp.Parent then
            pcall(function()
                hrp.Size = orig.Size
                hrp.CanCollide = orig.CanCollide
                hrp.Transparency = 1
            end)
        end
    end
    table.clear(OriginalHitboxData)
end

local function RestoreAllDoors()
    for part, orig in pairs(OriginalDoorData) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = orig.CanCollide
                part.Transparency = orig.Transparency
            end)
        end
    end
    table.clear(OriginalDoorData)
end

-- Secondary 0.18s Utility Loop (ESP, Anomaly Detector, Hitboxes, RiotShield, AutoHeal, AutoPickup, AutoArmor)
task.spawn(function()
    while task.wait(0.18) do
        if not Env.PrisonLife2026Running then break end

        pcall(UpdatePlayerESP)
        pcall(EvaluateAnomalies)

        local myChar = LocalPlayer.Character
        local myHrp = GetRoot(myChar)
        local myHum = GetHumanoid(myChar)

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local tChar = plr.Character
                local tHrp = GetRoot(tChar)
                local tHum = GetHumanoid(tChar)

                if tHrp then
                    if State.ExpandHitbox and IsValidCombatTarget(plr, State.SilentAimHostileCheck) then
                        if not OriginalHitboxData[tHrp] then
                            OriginalHitboxData[tHrp] = { Size = tHrp.Size, CanCollide = tHrp.CanCollide }
                        end
                        local boxSz = State.AntiBanSafeMode and math.min(State.HitboxSize, 12) or State.HitboxSize
                        tHrp.Size = Vector3.new(boxSz, boxSz, boxSz)
                        tHrp.Transparency = 1
                        tHrp.CanCollide = false
                    elseif OriginalHitboxData[tHrp] then
                        local orig = OriginalHitboxData[tHrp]
                        tHrp.Size = orig.Size
                        tHrp.CanCollide = orig.CanCollide
                        tHrp.Transparency = 1
                        OriginalHitboxData[tHrp] = nil
                    elseif tHrp.Transparency < 1 then
                        tHrp.Transparency = 1
                    end
                end

                local shield = tChar:FindFirstChild("RiotShieldPart")
                if shield and shield:IsA("BasePart") then
                    shield.CanQuery = not State.AntiRiotShield
                end

                if State.AntiInvisible and tHum then
                    local animator = tHum:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            local id = track.Animation and track.Animation.AnimationId or ""
                            local frozenExploit = (track.Speed == 0 and track.TimePosition > 0.2 and tHum.MoveDirection.Magnitude > 0.15)
                            if id:find("215384594") or id:find("18665825805") or id:find("181525546") or frozenExploit then
                                track:AdjustWeight(0, 0)
                                track:Stop(0)
                            end
                        end
                    end
                end
            end
        end

        -- Auto Heal with Cafeteria Food
        if State.AutoHeal and myChar and myHum and myHum.Health > 0 and myHum.Health <= State.AutoHealThreshold and Remotes.EatFood then
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            if bp then
                for _, foodName in ipairs({ "Breakfast", "Lunch", "Dinner", "Donut", "Soda" }) do
                    local food = bp:FindFirstChild(foodName) or myChar:FindFirstChild(foodName)
                    if food and (os.clock() - (food:GetAttribute("Client_LastConsumedAt") or 0)) >= 3.1 then
                        local prevTool = myChar:FindFirstChildOfClass("Tool")
                        myHum:EquipTool(food)
                        food:SetAttribute("Client_LastConsumedAt", os.clock())
                        Remotes.EatFood:FireServer()
                        if prevTool and prevTool ~= food then
                            myHum:EquipTool(prevTool)
                        else
                            myHum:UnequipTools()
                        end
                        break
                    end
                end
            end
        end

        -- Auto Pickup Dropped Keycards & Weapons
        if State.AutoPickupDropped and myHrp and Remotes.GiverPressed then
            for _, child in ipairs(Workspace:GetChildren()) do
                if child:IsA("Model") and child:GetAttribute("ToolName") then
                    local toolName = child:GetAttribute("ToolName")
                    if not HasWeapon(toolName) then
                        local okP, piv = pcall(function() return child:GetPivot() end)
                        if okP and piv and (piv.Position - myHrp.Position).Magnitude <= 11.5 then
                            Remotes.GiverPressed:FireServer(child)
                        end
                    end
                end
            end
        end

        -- Auto Armor
        if State.AutoArmor and myHrp and myHum and not HasTargetArmor(myChar) and Remotes.InteractWithItem then
            local clothes = Workspace:FindFirstChild("Prison_ITEMS") and Workspace.Prison_ITEMS:FindFirstChild("clothes")
            if clothes then
                for _, item in ipairs(clothes:GetChildren()) do
                    local part = item:FindFirstChildWhichIsA("BasePart")
                    if part and (part.Position - myHrp.Position).Magnitude <= 12 then
                        pcall(function() Remotes.InteractWithItem:InvokeServer(part) end)
                    end
                end
            end
        end

        -- Auto Detonate C4
        if State.AutoDetonateC4 and myHrp and Remotes.C4Folder then
            local activateRemote = Remotes.C4Folder:FindFirstChild("ActivateC4")
            if activateRemote then
                for _, c4 in ipairs(CollectionService:GetTagged("C4")) do
                    if c4:GetAttribute("UserId") == LocalPlayer.UserId and c4:IsA("BasePart") then
                        for _, plr in ipairs(Players:GetPlayers()) do
                            if IsValidCombatTarget(plr, false) then
                                local tHrp = GetRoot(plr.Character)
                                if tHrp and (tHrp.Position - c4.Position).Magnitude <= 22 and (myHrp.Position - c4.Position).Magnitude > 26 then
                                    local c4Tool = HasWeapon("C4 Explosive")
                                    if c4Tool and myHum then
                                        local prev = myChar:FindFirstChildOfClass("Tool")
                                        myHum:EquipTool(c4Tool)
                                        task.spawn(function()
                                            pcall(function() activateRemote:InvokeServer() end)
                                        end)
                                        if prev then myHum:EquipTool(prev) end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Open All Doors
        if State.OpenAllDoors and Workspace:FindFirstChild("Doors") then
            for _, part in ipairs(Workspace.Doors:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    if not OriginalDoorData[part] then
                        OriginalDoorData[part] = { CanCollide = part.CanCollide, Transparency = part.Transparency }
                    end
                    part.CanCollide = false
                    if OriginalDoorData[part].Transparency < 0.9 then
                        part.Transparency = math.max(part.Transparency, 0.68)
                    end
                end
            end
        end

        -- Auto Reload at 0 Ammo + Optional Hot-Swap
        if State.AutoReload and myChar and myHum and myHum.Health > 0 then
            local holdingGun, eqTool = IsHoldingFirearm()
            if holdingGun and eqTool then
                local curAmmo = eqTool:GetAttribute("Local_CurrentAmmo") or eqTool:GetAttribute("CurrentAmmo") or 1
                if curAmmo <= 0 and (eqTool:GetAttribute("Local_ReloadSession") or 0) <= 0 then
                    if not GunHook.Ready then SetupGunControllerHooks() end
                    if GunHook.Reload then task.spawn(GunHook.Reload) end
                    if State.AutoReloadHotSwap then
                        local loaded = GetOwnedLoadedGuns()
                        if loaded[1] and loaded[1] ~= eqTool then
                            myHum:EquipTool(loaded[1])
                        end
                    end
                end
            end
        end
    end
end)

-- Infinite Jump Handler
AddConnection(UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local hum = GetHumanoid(LocalPlayer.Character)
        if hum and hum.Health > 0 then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

-- Character Spawned Hooks
local function AttachCharacterListeners(char)
    if not char then return end
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 8)
        if hum then
            AddConnection(hum.Died:Connect(function()
                if State.FastRespawn then PerformFastRespawn() end
            end))
        end

        task.wait(0.35)
        SetupGunControllerHooks()
        InstallAntiTaseAndAntiArrestHooks()

        if State.AntiJumpCooldown or State.InfiniteStamina or State.MaxSpeed or State.JumpPowerEnabled then
            BypassAntiJump(char, true)
        end
        if State.Noclip or State.MaxSpeed then
            BypassClientAntiNoclip()
        end
        if State.FEInvisible or (State.HoloShield and State.ShieldMode == "FEGhost") then
            StartFEInvisible()
        end
        if State.HoloShield and State.ShieldMode ~= "FEGhost" then
            CreateHoloShield()
        end
        if State.AutoGetGuns and LocalPlayer.Team ~= Teams:FindFirstChild("Neutral") then
            task.wait(0.45)
            GrabWeapons(State.AutoGetGunsSelection, true)
        end

        local bp = LocalPlayer:WaitForChild("Backpack", 5)
        if bp then
            AddConnection(bp.ChildAdded:Connect(function(child)
                task.wait(0.05)
                ApplyGunModsToTool(child)
            end))
        end
        AddConnection(char.ChildAdded:Connect(function(child)
            task.wait(0.05)
            if child:IsA("Tool") then
                if not GunHook.Ready then SetupGunControllerHooks() end
                ApplyGunModsToTool(child)
            end
            if State.FEInvisible and child:IsA("Tool") then
                for _, desc in ipairs(child:GetDescendants()) do
                    if desc:IsA("BasePart") and desc.Transparency < 0.5 then
                        FEInvisSavedTransparencies[desc] = desc.Transparency
                        desc.Transparency = 0.5
                    end
                end
            end
        end))
    end)
end

if LocalPlayer.Character then AttachCharacterListeners(LocalPlayer.Character) end
AddConnection(LocalPlayer.CharacterAdded:Connect(AttachCharacterListeners))

-- ============================================================================
-- // SECTION 12: TELEPORTS, BULK ACTIONS (ARRESTALL / TASEALL / KILLALL) & PRESETS
-- ============================================================================
local TeleportLocations = {
    ["Prison Yard"]         = CFrame.new(780, 98, 2470),
    ["Nexus / Main Hall"]   = CFrame.new(875, 100, 2390),
    ["Cafeteria"]           = CFrame.new(905, 100, 2290),
    ["Cellblock"]           = CFrame.new(915, 100, 2445),
    ["Guard Armory (Guns)"] = CFrame.new(830, 100, 2235),
    ["Criminal Base (AK)"]  = CFrame.new(-943, 94, 2056),
    ["Prison Roof"]         = CFrame.new(825, 119, 2350),
    ["Yard Watchtower"]     = CFrame.new(822, 130, 2588),
    ["Front Gate"]          = CFrame.new(504, 103, 2250),
    ["Sewer Escape"]        = CFrame.new(917, 79, 2110),
    ["Secret Hideout"]      = CFrame.new(-97, 72, 1910),
    ["City Car Spawner"]    = CFrame.new(-525, 54, 1775),
    ["Grocery Store"]       = CFrame.new(415, 55, 1735),
    ["Gas Station"]         = CFrame.new(-515, 54, 1665),
    ["Neutral Spawn Room"]  = CFrame.new(879, 28, 2349),
}

local TeleportAliases = {
    yard = "Prison Yard",
    nexus = "Nexus / Main Hall",
    cafeteria = "Cafeteria",
    cells = "Cellblock",
    cellblock = "Cellblock",
    armory = "Guard Armory (Guns)",
    crimbase = "Criminal Base (AK)",
    roof = "Prison Roof",
    tower = "Yard Watchtower",
    gate = "Front Gate",
    sewer = "Sewer Escape",
    hideout = "Secret Hideout",
    cars = "City Car Spawner",
    store = "Grocery Store",
    gas = "Gas Station",
    neutral = "Neutral Spawn Room",
}

local function RunArrestAll(targetQuery)
    if not Remotes.ArrestPlayer then
        Notify("ArrestAll", "ArrestPlayer remote unavailable!", 2.5)
        return
    end
    if LocalPlayer.Team ~= Teams:FindFirstChild("Guards") then
        Notify("ArrestAll", "Switch to Guards team first (;guard)!", 3)
        return
    end
    local hrp = GetRoot(LocalPlayer.Character)
    if not hrp then return end

    local list = ResolveTargetPlayers(targetQuery or "others")
    local savedCF = hrp.CFrame
    task.spawn(function()
        local count = 0
        for _, p in ipairs(list) do
            if p ~= LocalPlayer and not State.ArrestWhitelist[p.UserId] and p.Team ~= Teams:FindFirstChild("Guards") then
                local tChar = p.Character
                local tHrp = GetRoot(tChar)
                local tHum = GetHumanoid(tChar)
                if tChar and tHrp and tHum and tHum.Health > 0 and not tChar:GetAttribute("Arrested") then
                    if not State.AntiBanSafeMode or (tHrp.Position - hrp.Position).Magnitude <= 350 then
                        SafeTeleport(tHrp.CFrame * CFrame.new(0, 0, 2.5))
                        task.wait(0.14)
                        local ok, res = pcall(function() return Remotes.ArrestPlayer:InvokeServer(p, 1) end)
                        if ok and res then
                            count = count + 1
                            if State.AntiBanSafeMode then break end
                        end
                        task.wait(0.14)
                    end
                end
            end
        end
        SafeTeleport(savedCF)
        Notify("ArrestAll", "Arrested " .. tostring(count) .. " target(s)!", 3)
    end)
end

local function RunTaseTargets(targetQuery)
    local taser = HasWeapon("Taser")
    if not taser then
        Notify("Tase", "You need a Taser in your inventory (Guards team)!", 3)
        return
    end
    local list = ResolveTargetPlayers(targetQuery or "nearest")
    task.spawn(function()
        local count = 0
        for _, p in ipairs(list) do
            if p ~= LocalPlayer and not State.ArrestWhitelist[p.UserId] then
                local tChar = p.Character
                local tHead = tChar and (tChar:FindFirstChild("Head") or GetRoot(tChar))
                local tHum = GetHumanoid(tChar)
                if tHead and tHum and tHum.Health > 0 then
                    if FireToolAtTarget(taser, tHead, false, true, false) then
                        count = count + 1
                    end
                    task.wait(0.15)
                end
            end
        end
        Notify("Tase", "Tased " .. tostring(count) .. " target(s)!", 2.5)
    end)
end

local function RunShootKillTargets(targetQuery)
    local loaded = GetOwnedLoadedGuns()
    if #loaded == 0 then
        Notify("Kill", "Grab a loaded weapon first (;guns)!", 2.5)
        return
    end
    local list = ResolveTargetPlayers(targetQuery or "nearest")
    task.spawn(function()
        local count = 0
        for _, p in ipairs(list) do
            if p ~= LocalPlayer and not State.KillAuraWhitelist[p.UserId] then
                local tChar = p.Character
                local tPart = tChar and (tChar:FindFirstChild("Head") or GetRoot(tChar))
                local tHum = GetHumanoid(tChar)
                if tPart and tHum and tHum.Health > 0 and not tChar:FindFirstChildOfClass("ForceField") then
                    for s = 1, 4 do
                        if tHum.Health <= 0 then break end
                        local g = GetOwnedLoadedGuns()[1] or loaded[1]
                        FireToolAtTarget(g, tPart, true, false, false)
                        task.wait(0.08)
                    end
                    count = count + 1
                end
            end
        end
        Notify("Engage", "Engaged " .. tostring(count) .. " target(s)!", 2.5)
    end)
end

local function ApplyPresetProfile(presetName)
    local low = string.lower(Trim(presetName))
    if low == "safe" or low == "default" then
        State.AntiBanSafeMode = true
        State.SilentAim = true
        State.SilentAimFOV = 160
        State.SilentAimWallbang = false
        State.Ragebot = false
        State.GunMods = true
        State.GunFireRateSPS = 14
        State.MaxSpeed = true
        State.MaxSpeedMode = "RegionSafe"
        State.AntiTase = true
        State.AntiFling = true
        State.ESP = true
        ApplyGunModsAll()
        Notify("Preset Loaded", "Applied Anti-Ban SAFE Preset!", 3)
    elseif low == "legit" then
        State.AntiBanSafeMode = true
        State.SilentAim = true
        State.SilentAimFOV = 110
        State.SilentAimHitChance = 90
        State.SilentAimWallbang = false
        State.AimAssist = true
        State.Ragebot = false
        State.GunMods = false
        State.MaxSpeed = true
        State.MaxSpeedMode = "AlwaysSprint"
        State.AntiTase = true
        State.ESP = true
        ApplyGunModsAll()
        Notify("Preset Loaded", "Applied LEGIT Closet Preset!", 3)
    elseif low == "rage" then
        State.AntiBanSafeMode = true
        State.HoloShield = true
        State.ShieldMode = "Hybrid"
        CreateHoloShield()
        State.SilentAim = true
        State.SilentAimWallbang = true
        State.Ragebot = true
        State.Ragebot360 = true
        State.GunMods = true
        State.GunFireRateSPS = 15
        State.MaxSpeed = true
        State.MaxSpeedMode = "RegionSafe"
        State.KillAura = true
        State.AntiTase = true
        State.AntiArrest = true
        State.ESP = true
        ApplyGunModsAll()
        Notify("Preset Loaded", "Applied KX RAGE + Holo-Shield Preset!", 3)
    end
end

local function RejoinServer()
    Notify("Rejoin", "Rejoining current Prison Life server...", 2.5)
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

local function ServerHop()
    Notify("Server Hop", "Searching for a populated Prison Life server...", 3)
    task.spawn(function()
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId)
        local ok, raw = pcall(function() return game:HttpGet(url) end)
        if ok and raw then
            local okD, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if okD and decoded and type(decoded.data) == "table" then
                for _, srv in ipairs(decoded.data) do
                    if type(srv) == "table" and srv.id ~= game.JobId and (tonumber(srv.playing) or 0) < (tonumber(srv.maxPlayers) or 0) then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
                        return
                    end
                end
            end
        end
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

-- ============================================================================
-- // SECTION 13: KX ADMIN COMMAND ENGINE & FLOATING TOP-RIGHT COMMAND BAR
-- ============================================================================
local GunNameAliases = {
    remington = "Remington 870", rem = "Remington 870", ["870"] = "Remington 870", shotgun = "Remington 870",
    ak = "AK-47", ak47 = "AK-47", ["ak-47"] = "AK-47",
    m4 = "M4A1", m4a1 = "M4A1", rifle = "M4A1",
    m9 = "M9", pistol = "M9",
    mp5 = "MP5", smg = "MP5",
    fal = "FAL",
    riot = "Riot Shield", shield = "Riot Shield",
}

local CommandCatalog = {
    { cmd = ";guns", desc = "Grab Armory loadout safely" },
    { cmd = ";gun <ak|rem|mp5|m4|m9|fal>", desc = "Grab specific weapon" },
    { cmd = ";loadout <cop|crim|all>", desc = "Grab role weapon kit" },
    { cmd = ";combo1", desc = "Execute .combo1 multi-gun burst" },
    { cmd = ";loopcombo [on|off]", desc = "Toggle continuous .combo1 loop" },
    { cmd = ";shield [on|off]", desc = "Toggle 4-Mode 3D Bullet Shield" },
    { cmd = ";shieldmode <hybrid|riot|desync|ghost>", desc = "Switch 3D Shield mode" },
    { cmd = ";antiaim [on|off]", desc = "Toggle DesyncBox Anti-Aim jitter" },
    { cmd = ";spinblock [on|off]", desc = "Toggle Shield Spin-Block" },
    { cmd = ";autofaceshield [on|off]", desc = "Auto-rotate shield toward shooter" },
    { cmd = ";rage [on|off]", desc = "Toggle 360° Ragebot" },
    { cmd = ";silentaim [on|off]", desc = "Toggle Bullet-Hook Silent Aim" },
    { cmd = ";wallbang [on|off]", desc = "Toggle Wallbang origin scanner" },
    { cmd = ";killaura [on|off]", desc = "Toggle Anti-Ban Melee Kill Aura" },
    { cmd = ";hitbox [size|off]", desc = "Expand invisible enemy hitboxes" },
    { cmd = ";kill <target|all>", desc = "Shoot target player(s)" },
    { cmd = ";loopkill <target>", desc = "Add player to LoopKill list" },
    { cmd = ";unloopkill", desc = "Clear LoopKill list" },
    { cmd = ";guard / ;inmate / ;crim / ;neutral", desc = "Instant team switch" },
    { cmd = ";re / ;respawn", desc = "Fast <1s respawn" },
    { cmd = ";arrest <target|nearest>", desc = "Handcuff target player" },
    { cmd = ";arrestall", desc = "Sequentially arrest valid targets" },
    { cmd = ";tase <target|all>", desc = "Tase target player(s)" },
    { cmd = ";autoarrest / ;autotaze", desc = "Toggle Guard auras" },
    { cmd = ";antitase / ;antiarrest", desc = "Toggle stun & cuff immunity" },
    { cmd = ";invis / ;uninvis", desc = "Toggle Serverside FE Invisibility" },
    { cmd = ";fly [speed] / ;unfly", desc = "Toggle Character Fly" },
    { cmd = ";car / ;carfly [speed]", desc = "Spawn car or toggle Vehicle Fly" },
    { cmd = ";speed <16..92|off> / ;safespeed", desc = "Set WalkSpeed or RegionSafe" },
    { cmd = ";noclip / ;clip", desc = "Toggle non-destructive Noclip" },
    { cmd = ";opendoors / ;fencegod", desc = "Open prison doors / Fence godmode" },
    { cmd = ";goto <yard|nexus|armory|crimbase|player>", desc = "Teleport to spot or player" },
    { cmd = ";bring <player>", desc = "FE vehicle-seat bring player" },
    { cmd = ";view <player> / ;unview", desc = "Spectate target player" },
    { cmd = ";esp / ;tracers / ;hitmarker", desc = "Toggle Visuals & VFX" },
    { cmd = ";preset <safe|legit|rage>", desc = "Load configuration preset" },
    { cmd = ";rejoin / ;serverhop", desc = "Rejoin or hop to new server" },
}

local function ParseToggleArg(arg, currentVal)
    if not arg or arg == "" or arg == "toggle" then return not currentVal end
    local low = string.lower(arg)
    if low == "on" or low == "true" or low == "1" then return true end
    if low == "off" or low == "false" or low == "0" then return false end
    return not currentVal
end

local function ExecuteSingleCommand(rawSegment)
    local seg = Trim(rawSegment)
    if seg == "" then return end
    local words = {}
    for w in string.gmatch(seg, "%S+") do
        table.insert(words, w)
    end
    if #words == 0 then return end

    local cmd = string.lower((words[1]:gsub("^[-;/!%.]+", "")))
    local arg1 = words[2]
    local rest = Trim(table.concat(words, " ", 2))

    if cmd == "guns" or cmd == "getguns" or cmd == "grabguns" then
        task.spawn(function() GrabWeapons(State.AutoGetGunsSelection) end)
    elseif cmd == "gun" or cmd == "weapon" then
        local g = GunNameAliases[string.lower(rest)] or rest
        if g ~= "" then
            task.spawn(function() GrabWeapons({ g }) end)
        end
    elseif cmd == "loadout" or cmd == "kit" then
        local k = string.lower(arg1 or "cop")
        if k == "crim" or k == "criminal" then
            task.spawn(function() GrabWeapons({ "AK-47", "FAL", "Remington 870" }) end)
        else
            task.spawn(function() GrabWeapons({ "Remington 870", "MP5", "M9", "M4A1", "Riot Shield" }) end)
        end
    elseif cmd == "combo1" or cmd == "combo" then
        task.spawn(ExecuteCombo1)
    elseif cmd == "loopcombo" or cmd == "autocombo" then
        State.ComboLoop = ParseToggleArg(arg1, State.ComboLoop)
        Notify("Command", "Loop .combo1: " .. (State.ComboLoop and "ON" or "OFF"), 2)
    elseif cmd == "shield" or cmd == "shieldbox" then
        State.HoloShield = ParseToggleArg(arg1, State.HoloShield)
        if State.HoloShield then CreateHoloShield() else DestroyHoloShield() end
        Notify("Command", "3D Bullet Shield: " .. (State.HoloShield and "ON" or "OFF"), 2)
    elseif cmd == "unshield" or cmd == "noshield" then
        State.HoloShield = false
        DestroyHoloShield()
        Notify("Command", "3D Bullet Shield: OFF", 2)
    elseif cmd == "shieldmode" or cmd == "smode" then
        local m = string.lower(arg1 or "hybrid")
        local map = { hybrid = "Hybrid", riot = "RiotOnly", riotonly = "RiotOnly", desync = "DesyncBox", desyncbox = "DesyncBox", ghost = "FEGhost", feghost = "FEGhost" }
        if map[m] then
            State.ShieldMode = map[m]
            if State.HoloShield then CreateHoloShield() end
            Notify("Command", "Shield Mode = " .. State.ShieldMode, 2)
        end
    elseif cmd == "antiaim" or cmd == "desync" then
        State.ShieldMode = "DesyncBox"
        State.HoloShield = true
        CreateHoloShield()
        Notify("Command", "DesyncBox Anti-Aim: ON", 2)
    elseif cmd == "unantiaim" or cmd == "undesync" then
        State.ShieldMode = "Hybrid"
        Notify("Command", "DesyncBox Anti-Aim: OFF (Hybrid)", 2)
    elseif cmd == "spinblock" then
        State.ShieldSpinBlock = ParseToggleArg(arg1, State.ShieldSpinBlock)
        Notify("Command", "Shield Spin-Block: " .. (State.ShieldSpinBlock and "ON" or "OFF"), 2)
    elseif cmd == "autofaceshield" or cmd == "autoshield" then
        State.ShieldAutoFaceShooter = ParseToggleArg(arg1, State.ShieldAutoFaceShooter)
        Notify("Command", "Auto-Face Shooter: " .. (State.ShieldAutoFaceShooter and "ON" or "OFF"), 2)
    elseif cmd == "rage" or cmd == "ragebot" or cmd == "rb" then
        if tonumber(arg1) then
            State.RagebotRate = clamp(tonumber(arg1), 2, 30)
            State.Ragebot = true
        else
            State.Ragebot = ParseToggleArg(arg1, State.Ragebot)
        end
        if State.Ragebot then SetupGunControllerHooks() end
        Notify("Command", "Ragebot: " .. (State.Ragebot and "ON" or "OFF"), 2)
    elseif cmd == "unrage" or cmd == "unrb" then
        State.Ragebot = false
        Notify("Command", "Ragebot: OFF", 2)
    elseif cmd == "silentaim" or cmd == "sa" or cmd == "silent" then
        State.SilentAim = ParseToggleArg(arg1, State.SilentAim)
        if State.SilentAim then SetupGunControllerHooks() end
        Notify("Command", "Silent Aim: " .. (State.SilentAim and "ON" or "OFF"), 2)
    elseif cmd == "unsa" or cmd == "unsilent" then
        State.SilentAim = false
        Notify("Command", "Silent Aim: OFF", 2)
    elseif cmd == "wallbang" or cmd == "wb" then
        State.SilentAimWallbang = ParseToggleArg(arg1, State.SilentAimWallbang)
        Notify("Command", "Wallbang Scanner: " .. (State.SilentAimWallbang and "ON" or "OFF"), 2)
    elseif cmd == "killaura" or cmd == "ka" or cmd == "aura" then
        if tonumber(arg1) then
            State.KillAuraRange = clamp(tonumber(arg1), 4, 14)
            State.KillAura = true
        else
            State.KillAura = ParseToggleArg(arg1, State.KillAura)
        end
        Notify("Command", "Kill Aura: " .. (State.KillAura and "ON" or "OFF"), 2)
    elseif cmd == "unka" or cmd == "unaura" then
        State.KillAura = false
        Notify("Command", "Kill Aura: OFF", 2)
    elseif cmd == "hitbox" or cmd == "hb" or cmd == "expand" then
        if tonumber(arg1) then
            State.HitboxSize = clamp(tonumber(arg1), 3, 18)
            State.ExpandHitbox = true
        else
            State.ExpandHitbox = ParseToggleArg(arg1, State.ExpandHitbox)
            if not State.ExpandHitbox then RestoreAllHitboxes() end
        end
        Notify("Command", "Hitbox Expander: " .. (State.ExpandHitbox and ("ON (" .. State.HitboxSize .. ")") or "OFF"), 2)
    elseif cmd == "unhb" or cmd == "unexpand" then
        State.ExpandHitbox = false
        RestoreAllHitboxes()
        Notify("Command", "Hitbox Expander: OFF", 2)
    elseif cmd == "kill" then
        RunShootKillTargets(rest ~= "" and rest or "nearest")
    elseif cmd == "killall" then
        RunShootKillTargets(rest ~= "" and rest or "others")
    elseif cmd == "loopkill" or cmd == "lk" then
        local targets = ResolveTargetPlayers(rest)
        for _, p in ipairs(targets) do
            if p ~= LocalPlayer then State.LoopKillTargets[p.UserId] = true end
        end
        Notify("Command", "Added " .. tostring(#targets) .. " player(s) to LoopKill", 2.5)
    elseif cmd == "unloopkill" or cmd == "unlk" then
        table.clear(State.LoopKillTargets)
        Notify("Command", "Cleared LoopKill list", 2)
    elseif cmd == "kawl" then
        local targets = ResolveTargetPlayers(rest)
        for _, p in ipairs(targets) do State.KillAuraWhitelist[p.UserId] = true end
        Notify("Command", "Whitelisted " .. tostring(#targets) .. " player(s) from combat", 2.5)
    elseif cmd == "unkawl" then
        table.clear(State.KillAuraWhitelist)
        Notify("Command", "Cleared combat whitelist", 2)
    elseif cmd == "aawl" then
        local targets = ResolveTargetPlayers(rest)
        for _, p in ipairs(targets) do State.ArrestWhitelist[p.UserId] = true end
        Notify("Command", "Whitelisted " .. tostring(#targets) .. " player(s) from arrest", 2.5)
    elseif cmd == "unaawl" then
        table.clear(State.ArrestWhitelist)
        Notify("Command", "Cleared arrest whitelist", 2)
    elseif cmd == "guard" or cmd == "guards" or cmd == "cop" then
        SwitchToTeam("Guards")
    elseif cmd == "inmate" or cmd == "inmates" or cmd == "prisoner" then
        SwitchToTeam("Inmates")
    elseif cmd == "crim" or cmd == "criminal" or cmd == "criminals" then
        SwitchToTeam("Criminals")
    elseif cmd == "neutral" then
        SwitchToTeam("Neutral")
    elseif cmd == "team" then
        local map = { g = "Guards", guard = "Guards", guards = "Guards", i = "Inmates", inmate = "Inmates", inmates = "Inmates", c = "Criminals", crim = "Criminals", criminals = "Criminals", n = "Neutral", neutral = "Neutral" }
        local t = map[string.lower(arg1 or "")]
        if t then SwitchToTeam(t) end
    elseif cmd == "re" or cmd == "respawn" then
        PerformFastRespawn()
    elseif cmd == "autorespawn" or cmd == "autore" then
        State.FastRespawn = ParseToggleArg(arg1, State.FastRespawn)
        Notify("Command", "Auto Fast Respawn: " .. (State.FastRespawn and "ON" or "OFF"), 2)
    elseif cmd == "arrest" or cmd == "ar" then
        RunArrestAll(rest ~= "" and rest or "nearest")
    elseif cmd == "arrestall" or cmd == "aa" then
        RunArrestAll(rest ~= "" and rest or "others")
    elseif cmd == "tase" or cmd == "taze" then
        RunTaseTargets(rest ~= "" and rest or "nearest")
    elseif cmd == "taseall" or cmd == "tazeall" then
        RunTaseTargets(rest ~= "" and rest or "others")
    elseif cmd == "autoarrest" or cmd == "araura" then
        State.AutoArrest = ParseToggleArg(arg1, State.AutoArrest)
        Notify("Command", "Auto-Arrest Aura: " .. (State.AutoArrest and "ON" or "OFF"), 2)
    elseif cmd == "autotaze" or cmd == "autotase" then
        State.AutoTaze = ParseToggleArg(arg1, State.AutoTaze)
        Notify("Command", "Auto-Taze Aura: " .. (State.AutoTaze and "ON" or "OFF"), 2)
    elseif cmd == "antitase" or cmd == "antitaze" then
        State.AntiTase = ParseToggleArg(arg1, State.AntiTase)
        Notify("Command", "Anti-Tase: " .. (State.AntiTase and "ON" or "OFF"), 2)
    elseif cmd == "antiarrest" or cmd == "antiar" then
        State.AntiArrest = ParseToggleArg(arg1, State.AntiArrest)
        Notify("Command", "Anti-Arrest: " .. (State.AntiArrest and "ON" or "OFF"), 2)
    elseif cmd == "invis" or cmd == "ghost" or cmd == "feghost" then
        SetFEInvisibleState(ParseToggleArg(arg1, State.FEInvisible), true)
    elseif cmd == "uninvis" or cmd == "unghost" then
        SetFEInvisibleState(false, true)
    elseif cmd == "fly" then
        if tonumber(arg1) then
            State.FlySpeed = clamp(tonumber(arg1), 20, 180)
            State.Fly = true
        else
            State.Fly = ParseToggleArg(arg1, State.Fly)
        end
        if not State.Fly then CleanupCharFly() end
        Notify("Command", "Character Fly: " .. (State.Fly and "ON" or "OFF"), 2)
    elseif cmd == "unfly" then
        State.Fly = false
        CleanupCharFly()
        Notify("Command", "Character Fly: OFF", 2)
    elseif cmd == "car" or cmd == "spawncar" then
        SpawnAndEnterNearestCar()
    elseif cmd == "carfly" then
        if tonumber(arg1) then
            State.VehicleFlySpeed = clamp(tonumber(arg1), 25, 180)
            State.VehicleFly = true
        else
            State.VehicleFly = ParseToggleArg(arg1, State.VehicleFly)
        end
        Notify("Command", "Vehicle Fly: " .. (State.VehicleFly and "ON" or "OFF"), 2)
    elseif cmd == "uncarfly" then
        State.VehicleFly = false
        Notify("Command", "Vehicle Fly: OFF", 2)
    elseif cmd == "speed" or cmd == "ws" then
        if tonumber(arg1) then
            State.CustomWalkSpeed = clamp(tonumber(arg1), 16, 92)
            State.MaxSpeedMode = "Custom"
            State.MaxSpeed = true
        else
            State.MaxSpeed = ParseToggleArg(arg1, State.MaxSpeed)
        end
        Notify("Command", "MaxSpeed: " .. (State.MaxSpeed and "ON" or "OFF"), 2)
    elseif cmd == "unspeed" then
        State.MaxSpeed = false
        local hum = GetHumanoid(LocalPlayer.Character)
        if hum then hum.WalkSpeed = 16 end
        Notify("Command", "MaxSpeed: OFF", 2)
    elseif cmd == "safespeed" then
        State.MaxSpeedMode = "RegionSafe"
        State.MaxSpeed = true
        Notify("Command", "Region-Safe MaxSpeed: ON", 2)
    elseif cmd == "noclip" or cmd == "nc" then
        State.Noclip = ParseToggleArg(arg1, State.Noclip)
        if State.Noclip then BypassClientAntiNoclip() end
        Notify("Command", "Noclip: " .. (State.Noclip and "ON" or "OFF"), 2)
    elseif cmd == "clip" or cmd == "unnoclip" then
        State.Noclip = false
        Notify("Command", "Noclip: OFF", 2)
    elseif cmd == "opendoors" or cmd == "doors" then
        State.OpenAllDoors = ParseToggleArg(arg1, State.OpenAllDoors)
        if not State.OpenAllDoors then RestoreAllDoors() end
        Notify("Command", "Open All Doors: " .. (State.OpenAllDoors and "ON" or "OFF"), 2)
    elseif cmd == "fencegod" or cmd == "nofence" then
        State.FenceGodmode = ParseToggleArg(arg1, State.FenceGodmode)
        Notify("Command", "Fence Godmode: " .. (State.FenceGodmode and "ON" or "OFF"), 2)
    elseif cmd == "goto" or cmd == "to" or cmd == "tp" then
        local key = TeleportAliases[string.lower(rest)] or rest
        if TeleportLocations[key] then
            SafeTeleport(TeleportLocations[key])
            Notify("Teleport", "Moved to " .. key, 2)
        else
            local plrs = ResolveTargetPlayers(rest)
            local tHrp = plrs[1] and GetRoot(plrs[1].Character)
            if tHrp then
                SafeTeleport(tHrp.CFrame * CFrame.new(0, 0, 3.2))
                Notify("Teleport", "Teleported to " .. plrs[1].Name, 2)
            end
        end
    elseif cmd == "bring" then
        local plrs = ResolveTargetPlayers(rest)
        if plrs[1] then BringPlayerViaVehicle(plrs[1]) end
    elseif cmd == "view" or cmd == "spectate" then
        local plrs = ResolveTargetPlayers(rest)
        SetSpectatePlayer(plrs[1])
    elseif cmd == "unview" or cmd == "unspectate" then
        SetSpectatePlayer(nil)
        Notify("Spectate", "Restored camera to local character", 2)
    elseif cmd == "esp" then
        State.ESP = ParseToggleArg(arg1, State.ESP)
        Notify("Command", "Player ESP: " .. (State.ESP and "ON" or "OFF"), 2)
    elseif cmd == "tracers" or cmd == "bullettracers" then
        State.BulletTracers = ParseToggleArg(arg1, State.BulletTracers)
        Notify("Command", "Bullet Tracers: " .. (State.BulletTracers and "ON" or "OFF"), 2)
    elseif cmd == "hitmarker" then
        State.Hitmarker = ParseToggleArg(arg1, State.Hitmarker)
        Notify("Command", "Hitmarker: " .. (State.Hitmarker and "ON" or "OFF"), 2)
    elseif cmd == "preset" then
        ApplyPresetProfile(arg1 or "safe")
    elseif cmd == "rejoin" or cmd == "rj" then
        RejoinServer()
    elseif cmd == "serverhop" or cmd == "shop" then
        ServerHop()
    elseif cmd == "safemode" or cmd == "antiban" then
        State.AntiBanSafeMode = ParseToggleArg(arg1, State.AntiBanSafeMode)
        ApplyGunModsAll()
        Notify("Anti-Ban Safe Mode", State.AntiBanSafeMode and "Safe Mode ON" or "Safe Mode OFF", 2.5)
    end
end

local function ExecuteCommandLine(rawLine)
    local line = Trim(rawLine)
    if line == "" then return end
    for segment in string.gmatch(line, "[^;]+") do
        ExecuteSingleCommand(segment)
    end
end

-- Top-Right KX Command Bar with Live Autocomplete Dropdown
local CmdBarFrame = Instance.new("Frame")
CmdBarFrame.Name = "KX_CommandBar"
CmdBarFrame.AnchorPoint = Vector2.new(1, 0)
CmdBarFrame.Position = UDim2.new(0.985, 0, 0, 12)
CmdBarFrame.Size = UDim2.fromOffset(250, 32)
CmdBarFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
CmdBarFrame.BackgroundTransparency = 0.15
CmdBarFrame.BorderSizePixel = 0
CmdBarFrame.Visible = State.ShowCommandBar
CmdBarFrame.Parent = OverlayGui
Instance.new("UICorner", CmdBarFrame).CornerRadius = UDim.new(0, 8)
local CmdBarStroke = Instance.new("UIStroke", CmdBarFrame)
CmdBarStroke.Color = Color3.fromRGB(59, 130, 246)
CmdBarStroke.Thickness = 1.3

local CmdInput = Instance.new("TextBox")
CmdInput.Size = UDim2.new(1, -54, 1, 0)
CmdInput.Position = UDim2.fromOffset(10, 0)
CmdInput.BackgroundTransparency = 1
CmdInput.Font = Enum.Font.GothamMedium
CmdInput.TextSize = 12
CmdInput.TextColor3 = Color3.new(1, 1, 1)
CmdInput.PlaceholderText = ";cmd (e.g. ;guns;shield on)"
CmdInput.PlaceholderColor3 = Color3.fromRGB(140, 155, 180)
CmdInput.TextXAlignment = Enum.TextXAlignment.Left
CmdInput.ClearTextOnFocus = false
CmdInput.Text = ""
CmdInput.Parent = CmdBarFrame

local CmdRunBtn = Instance.new("TextButton")
CmdRunBtn.Size = UDim2.fromOffset(40, 24)
CmdRunBtn.Position = UDim2.new(1, -44, 0.5, -12)
CmdRunBtn.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
CmdRunBtn.Font = Enum.Font.GothamBold
CmdRunBtn.TextSize = 11
CmdRunBtn.TextColor3 = Color3.new(1, 1, 1)
CmdRunBtn.Text = "OK"
CmdRunBtn.Parent = CmdBarFrame
Instance.new("UICorner", CmdRunBtn).CornerRadius = UDim.new(0, 6)

local SuggestFrame = Instance.new("Frame")
SuggestFrame.Name = "KX_SuggestDropdown"
SuggestFrame.AnchorPoint = Vector2.new(1, 0)
SuggestFrame.Position = UDim2.new(0.985, 0, 0, 48)
SuggestFrame.Size = UDim2.fromOffset(250, 0)
SuggestFrame.AutomaticSize = Enum.AutomaticSize.Y
SuggestFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
SuggestFrame.BackgroundTransparency = 0.08
SuggestFrame.Visible = false
SuggestFrame.Parent = OverlayGui
Instance.new("UICorner", SuggestFrame).CornerRadius = UDim.new(0, 8)
local SuggestLayout = Instance.new("UIListLayout", SuggestFrame)
SuggestLayout.Padding = UDim.new(0, 2)

local function UpdateCommandSuggestions()
    for _, ch in ipairs(SuggestFrame:GetChildren()) do
        if ch:IsA("TextButton") then ch:Destroy() end
    end
    local txt = Trim(CmdInput.Text):lower():gsub("^;", "")
    if txt == "" or not CmdInput:IsFocused() then
        SuggestFrame.Visible = false
        return
    end
    local shown = 0
    for _, item in ipairs(CommandCatalog) do
        local clean = item.cmd:lower():gsub("^;", "")
        if clean:find(txt, 1, true) then
            shown = shown + 1
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 24)
            b.BackgroundColor3 = Color3.fromRGB(24, 32, 48)
            b.BackgroundTransparency = 0.25
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 11
            b.TextColor3 = Color3.fromRGB(210, 225, 255)
            b.Text = "  " .. item.cmd .. " — " .. item.desc
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.TextTruncate = Enum.TextTruncate.AtEnd
            b.Parent = SuggestFrame
            b.Activated:Connect(function()
                local baseCmd = item.cmd:match("^(;%S+)") or item.cmd
                CmdInput.Text = baseCmd .. " "
                CmdInput:CaptureFocus()
            end)
            if shown >= 6 then break end
        end
    end
    SuggestFrame.Visible = (shown > 0)
end

CmdInput:GetPropertyChangedSignal("Text"):Connect(UpdateCommandSuggestions)
CmdInput.Focused:Connect(UpdateCommandSuggestions)
CmdInput.FocusLost:Connect(function(enterPressed)
    task.delay(0.12, function() SuggestFrame.Visible = false end)
    if enterPressed and Trim(CmdInput.Text) ~= "" then
        ExecuteCommandLine(CmdInput.Text)
        CmdInput.Text = ""
    end
end)
CmdRunBtn.Activated:Connect(function()
    if Trim(CmdInput.Text) ~= "" then
        ExecuteCommandLine(CmdInput.Text)
        CmdInput.Text = ""
    end
end)

-- Chat Command Listener (`;guns`, `;shield`, etc. in Roblox chat)
AddConnection(LocalPlayer.Chatted:Connect(function(msg)
    if State.ChatCommands and type(msg) == "string" then
        local first = msg:sub(1, 1)
        if first == ";" or first == "!" or first == "." then
            ExecuteCommandLine(msg)
        end
    end
end))

-- PC Hotkeys (G = Shield, X = .combo1, B = Ragebot, F = Fly, N = Noclip, ; = CmdBar)
AddConnection(UserInputService.InputBegan:Connect(function(inp, gameProcessed)
    if gameProcessed or UserInputService:GetFocusedTextBox() then return end
    if inp.KeyCode == Enum.KeyCode.G then
        State.HoloShield = not State.HoloShield
        if State.HoloShield then CreateHoloShield() else DestroyHoloShield() end
        Notify("Hotkey [G]", "3D Bullet Shield: " .. (State.HoloShield and "ON" or "OFF"), 2)
    elseif inp.KeyCode == Enum.KeyCode.X then
        task.spawn(ExecuteCombo1)
    elseif inp.KeyCode == Enum.KeyCode.B then
        State.Ragebot = not State.Ragebot
        if State.Ragebot then SetupGunControllerHooks() end
        Notify("Hotkey [B]", "360° Ragebot: " .. (State.Ragebot and "ON" or "OFF"), 2)
    elseif inp.KeyCode == Enum.KeyCode.F then
        State.Fly = not State.Fly
        if not State.Fly then CleanupCharFly() end
        Notify("Hotkey [F]", "Character Fly: " .. (State.Fly and "ON" or "OFF"), 2)
    elseif inp.KeyCode == Enum.KeyCode.N then
        State.Noclip = not State.Noclip
        if State.Noclip then BypassClientAntiNoclip() end
        Notify("Hotkey [N]", "Noclip: " .. (State.Noclip and "ON" or "OFF"), 2)
    elseif inp.KeyCode == Enum.KeyCode.Semicolon then
        if CmdBarFrame.Visible then
            task.defer(function() CmdInput:CaptureFocus() end)
        end
    end
end))

-- ============================================================================
-- // SECTION 14: CLEAN 7-TAB WINDUI HUB (WITH NATIVE PC/MOBILE FALLBACK)
-- ============================================================================
Env.PrisonLife2026Running = true

if WindUI then
    local Window = WindUI:CreateWindow({
        Title = "Prison Life • 2026 Hub (v3.0 KX Edition)",
        Icon = "shield",
        Author = "All KX Features • Anti-Ban Hardened • PC & Mobile",
        Folder = "PrisonLife2026HubV3",
        Size = UDim2.fromOffset(600, 450),
        Transparent = true,
        Theme = "Dark",
        SideBarWidth = 175,
    })

    Window:EditOpenButton({
        Title = "🚔 PL 2026 KX",
        Icon = "shield",
        CornerRadius = UDim.new(0, 14),
        StrokeThickness = 2,
        Color = ColorSequence.new(
            Color3.fromHex("1e3a8a"),
            Color3.fromHex("3b82f6")
        ),
        Draggable = true,
    })

    local TabShield   = Window:Tab({ Title = "Shield & Safe", Icon = "shield" })
    local TabCombat   = Window:Tab({ Title = "Rage & Aim", Icon = "crosshair" })
    local TabWeapons  = Window:Tab({ Title = "Guns & .combo1", Icon = "zap" })
    local TabPrison   = Window:Tab({ Title = "Prison & Guard", Icon = "lock" })
    local TabVehicles = Window:Tab({ Title = "Cars & Fly", Icon = "car" })
    local TabMove     = Window:Tab({ Title = "Movement", Icon = "wind" })
    local TabVisuals  = Window:Tab({ Title = "ESP & Admin", Icon = "eye" })

    -- // TAB 1: 4-MODE 3D HOLO-SHIELD & ANTI-BAN SAFE MODE
    TabShield:Section({ Title = "🛡️ Anti-Ban Protection & Quick Presets" })
    TabShield:Toggle({
        Title = "Anti-Ban Safe Mode (Error Code 600 Guard • Recommended ON)",
        Desc = "Enforces 2026 server-safe limits on FireRate, KillAura, Giver Teleports & WalkSpeed",
        Value = true,
        Callback = function(v)
            State.AntiBanSafeMode = v
            ApplyGunModsAll()
            Notify("Anti-Ban Protection", v and "Safe Mode ON (Protected against Error 600)" or "Safe Mode OFF (Unrestricted)", 3)
        end,
    })
    TabShield:Dropdown({
        Title = "Apply Configuration Preset",
        Values = { "Safe (Anti-Ban Default)", "Legit (Closet)", "Rage (KX 360 + Shield)" },
        Value = "Safe (Anti-Ban Default)",
        Callback = function(v)
            local picked = NormalizeDropdownValue(v)
            if picked:find("Legit") then ApplyPresetProfile("legit")
            elseif picked:find("Rage") then ApplyPresetProfile("rage")
            else ApplyPresetProfile("safe") end
        end,
    })

    TabShield:Section({ Title = "2026 4-Mode 3D Ballistic Holo-Shield (Hotkey: G)" })
    TabShield:Toggle({
        Title = "Enable 3D Ballistic Holo-Shield",
        Desc = "Intercepts incoming bullet raycasts with 180 HP durability bar & spark VFX",
        Value = false,
        Callback = function(v)
            State.HoloShield = v
            if v then CreateHoloShield() else DestroyHoloShield() end
        end,
    })
    TabShield:Dropdown({
        Title = "Shield Protection Mode",
        Values = { "Hybrid", "RiotOnly", "DesyncBox", "FEGhost" },
        Value = "Hybrid",
        Callback = function(v)
            local mode = NormalizeDropdownValue(v)
            if mode ~= "" then
                State.ShieldMode = mode
                if State.HoloShield then CreateHoloShield() end
            end
        end,
    })
    TabShield:Slider({
        Title = "3D Shield Box Size",
        Step = 0.5,
        Value = { Min = 3.5, Max = 12.0, Default = 6.5 },
        Callback = function(v) State.ShieldSize = tonumber(v) or 6.5 end,
    })
    TabShield:Slider({
        Title = "Shield Transparency",
        Step = 0.05,
        Value = { Min = 0.45, Max = 0.90, Default = 0.72 },
        Callback = function(v) State.ShieldTransparency = tonumber(v) or 0.72 end,
    })
    TabShield:Toggle({
        Title = "Auto-Equip SWAT Riot Shield When Owned",
        Value = true,
        Callback = function(v) State.ShieldAutoEquip = v end,
    })
    TabShield:Toggle({
        Title = "Auto-Face Nearest Armed Shooter",
        Desc = "Rotates your shield barrier toward the closest enemy automatically",
        Value = false,
        Callback = function(v) State.ShieldAutoFaceShooter = v end,
    })
    TabShield:Toggle({
        Title = "Spin-Block Anti-Aim (360° Shield Rotation)",
        Value = false,
        Callback = function(v) State.ShieldSpinBlock = v end,
    })
    TabShield:Slider({
        Title = "DesyncBox Anti-Aim Jitter Radius",
        Step = 0.2,
        Value = { Min = 1.0, Max = 6.0, Default = 3.2 },
        Callback = function(v) State.DesyncJitterRadius = tonumber(v) or 3.2 end,
    })

    -- // TAB 2: RAGEBOT, SILENT AIM & WALLBANG SCANNER
    TabCombat:Section({ Title = "360° Ragebot (Hotkey: B)" })
    TabCombat:Toggle({
        Title = "Enable 360° Ragebot (Auto-Fire via GunController)",
        Desc = "Automatically locks and fires at any visible/wallbangable enemy in range",
        Value = false,
        Callback = function(v)
            State.Ragebot = v
            if v then SetupGunControllerHooks() end
        end,
    })
    TabCombat:Toggle({
        Title = "Ragebot 360° Omnidirectional Scan",
        Value = true,
        Callback = function(v) State.Ragebot360 = v end,
    })
    TabCombat:Toggle({
        Title = "Ragebot Auto-Switch to Loaded Firearm",
        Value = true,
        Callback = function(v) State.RagebotAutoSwitch = v end,
    })
    TabCombat:Toggle({
        Title = "Ragebot Shield-Peek (Sync with Holo-Shield Desync)",
        Value = true,
        Callback = function(v) State.RagebotPeekShield = v end,
    })
    TabCombat:Slider({
        Title = "Ragebot Fire Rate (Shots/Sec)",
        Value = { Min = 2, Max = 25, Default = 14 },
        Callback = function(v) State.RagebotRate = tonumber(v) or 14 end,
    })

    TabCombat:Section({ Title = "2026 Bullet-Hook Silent Aim & Wallbang Scanner" })
    TabCombat:Toggle({
        Title = "Silent Aim (GunController Bullet Hook)",
        Desc = "Redirects bullets directly to target with Wallbang & Armor Penetration",
        Value = false,
        Callback = function(v)
            State.SilentAim = v
            if v then SetupGunControllerHooks() end
        end,
    })
    TabCombat:Toggle({
        Title = "Wallbang Origin Scanner (Shoot Around Thin Cover)",
        Desc = "Scans 10-point origin ring + NormalId corners to hit targets behind cover",
        Value = true,
        Callback = function(v) State.SilentAimWallbang = v end,
    })
    TabCombat:Toggle({
        Title = "Auto Armor Penetration (Force Headshot on Vested Enemies)",
        Desc = "Automatically targets Head when enemy is wearing a ballistic vest",
        Value = true,
        Callback = function(v) State.AutoArmorPen = v end,
    })
    TabCombat:Slider({
        Title = "Silent Aim Hit Chance (%)",
        Value = { Min = 10, Max = 100, Default = 100 },
        Callback = function(v) State.SilentAimHitChance = tonumber(v) or 100 end,
    })
    TabCombat:Slider({
        Title = "Headshot Chance (%) [In Random Mode]",
        Value = { Min = 0, Max = 100, Default = 75 },
        Callback = function(v) State.SilentAimHeadChance = tonumber(v) or 75 end,
    })
    TabCombat:Dropdown({
        Title = "Target Body Part",
        Values = { "Head", "Torso", "Random" },
        Value = "Head",
        Callback = function(v)
            local part = NormalizeDropdownValue(v)
            if part ~= "" then
                State.SilentAimAimPart = part
                State.AimAssistAimPart = (part == "Random") and "Head" or part
            end
        end,
    })
    TabCombat:Slider({
        Title = "Silent Aim FOV Radius",
        Value = { Min = 30, Max = 450, Default = 180 },
        Callback = function(v) State.SilentAimFOV = tonumber(v) or 180 end,
    })
    TabCombat:Toggle({
        Title = "Show Silent Aim FOV Circle",
        Value = true,
        Callback = function(v) State.SilentAimShowFOV = v end,
    })
    TabCombat:Toggle({
        Title = "Guard Safe Mode (Only Hostile/Trespassing Inmates)",
        Value = true,
        Callback = function(v) State.SilentAimHostileCheck = v end,
    })

    TabCombat:Section({ Title = "Camera Aim Assist, Triggerbot & Piercing" })
    TabCombat:Toggle({
        Title = "Smooth Aim Assist (PC & Mobile Touch)",
        Value = false,
        Callback = function(v) State.AimAssist = v end,
    })
    TabCombat:Toggle({
        Title = "Triggerbot (Auto-Shoot Target in FOV)",
        Value = false,
        Callback = function(v)
            State.Triggerbot = v
            if v then SetupGunControllerHooks() end
        end,
    })
    TabCombat:Toggle({
        Title = "Shoot Through Riot Shields (Anti-RiotShield)",
        Value = false,
        Callback = function(v) State.AntiRiotShield = v end,
    })
    TabCombat:Toggle({
        Title = "Shoot Through Vehicles (Vehicle Wallbang)",
        Value = false,
        Callback = function(v) State.VehicleWallbang = v end,
    })

    TabCombat:Section({ Title = "Melee Kill Aura & Invisible Hitboxes" })
    TabCombat:Toggle({
        Title = "Melee Kill Aura (Anti-Ban Rate-Limited)",
        Value = false,
        Callback = function(v) State.KillAura = v end,
    })
    TabCombat:Slider({
        Title = "Kill Aura Range (Studs)",
        Value = { Min = 4, Max = 12, Default = 10 },
        Callback = function(v) State.KillAuraRange = tonumber(v) or 10 end,
    })
    TabCombat:Toggle({
        Title = "Expand Enemy Hitboxes (Invisible Box)",
        Value = false,
        Callback = function(v)
            State.ExpandHitbox = v
            if not v then RestoreAllHitboxes() end
        end,
    })
    TabCombat:Slider({
        Title = "Hitbox Size",
        Value = { Min = 3, Max = 15, Default = 9 },
        Callback = function(v) State.HitboxSize = tonumber(v) or 9 end,
    })

    -- // TAB 3: WEAPONS, .COMBO1 BURST & GUN MODS
    TabWeapons:Section({ Title = "💥 KX .combo1 Multi-Gun Burst (Hotkey: X)" })
    TabWeapons:Button({
        Title = "Execute .combo1 Burst Now",
        Desc = "Fires all loaded firearms in sequence at the best target",
        Callback = function() task.spawn(ExecuteCombo1) end,
    })
    TabWeapons:Toggle({
        Title = "Show Top-Left .combo1 HUD Button",
        Value = true,
        Callback = function(v)
            State.ShowComboButton = v
            ComboTopLeftBtn.Visible = v
        end,
    })
    TabWeapons:Toggle({
        Title = "Loop .combo1 Continuously",
        Value = false,
        Callback = function(v) State.ComboLoop = v end,
    })
    TabWeapons:Toggle({
        Title = "Auto-Grab Guns Before .combo1 If Unarmed",
        Value = true,
        Callback = function(v) State.ComboAutoGrabGuns = v end,
    })
    TabWeapons:Toggle({
        Title = "Re-Equip Riot Shield After .combo1 Burst",
        Value = true,
        Callback = function(v) State.ComboReEquipShield = v end,
    })

    TabWeapons:Section({ Title = "2026 Safe Gun Grabber (GiverPressed)" })
    TabWeapons:Button({
        Title = "Grab Armory Loadout (Remington 870 + MP5 + M9)",
        Callback = function() task.spawn(function() GrabWeapons({ "Remington 870", "MP5", "M9" }) end) end,
    })
    TabWeapons:Button({
        Title = "Grab Remington 870 (Shotgun)",
        Callback = function() task.spawn(function() GrabWeapons({ "Remington 870" }) end) end,
    })
    TabWeapons:Button({
        Title = "Grab MP5 (SMG)",
        Callback = function() task.spawn(function() GrabWeapons({ "MP5" }) end) end,
    })
    TabWeapons:Button({
        Title = "Grab AK-47 (Criminal Base Rifle)",
        Callback = function() task.spawn(function() GrabWeapons({ "AK-47" }) end) end,
    })
    TabWeapons:Toggle({
        Title = "Auto Grab Armory Loadout on Respawn",
        Value = false,
        Callback = function(v) State.AutoGetGuns = v end,
    })
    TabWeapons:Toggle({
        Title = "Auto Pickup Dropped Keycards & Guns",
        Value = false,
        Callback = function(v) State.AutoPickupDropped = v end,
    })

    TabWeapons:Section({ Title = "2026 Gun Attribute Modifications" })
    TabWeapons:Toggle({
        Title = "Enable Gun Mods (Rapid Fire, No Spread, Full Auto)",
        Value = false,
        Callback = function(v)
            State.GunMods = v
            ApplyGunModsAll()
        end,
    })
    TabWeapons:Slider({
        Title = "FireRate (Shots Per Second • Capped at 15 in Safe Mode)",
        Value = { Min = 5, Max = 25, Default = 14 },
        Callback = function(v)
            State.GunFireRateSPS = tonumber(v) or 14
            ApplyGunModsAll()
        end,
    })
    TabWeapons:Toggle({
        Title = "Zero Bullet Spread (100% Accuracy)",
        Value = true,
        Callback = function(v) State.GunNoSpread = v; ApplyGunModsAll() end,
    })
    TabWeapons:Toggle({
        Title = "Force Full Automatic (Shotguns/Pistols/Snipers)",
        Value = true,
        Callback = function(v) State.GunFullAuto = v; ApplyGunModsAll() end,
    })
    TabWeapons:Toggle({
        Title = "Auto Reload at 0 Ammo + Hot-Swap",
        Value = false,
        Callback = function(v)
            State.AutoReload = v
            State.AutoReloadHotSwap = v
        end,
    })
    TabWeapons:Toggle({
        Title = "Show Floating Mobile Quick Dock",
        Value = IsMobile,
        Callback = function(v) MobileQuickBar.Visible = v end,
    })
    MobileQuickBar.Visible = IsMobile

    TabWeapons:Section({ Title = "Auto Heal & Armor" })
    TabWeapons:Toggle({
        Title = "Auto Heal (Eat Cafeteria Food Below 80 HP)",
        Value = false,
        Callback = function(v) State.AutoHeal = v end,
    })
    TabWeapons:Toggle({
        Title = "Auto Equip Armor Vest When Near Armory",
        Value = false,
        Callback = function(v) State.AutoArmor = v end,
    })

    -- // TAB 4: PRISON, GUARDS & TEAMS
    TabPrison:Section({ Title = "Instant Team Switcher (RequestTeamChange)" })
    TabPrison:Button({
        Title = "Join Inmates Team (;inmate)",
        Callback = function() SwitchToTeam("Inmates") end,
    })
    TabPrison:Button({
        Title = "Join Guards Team (;guard)",
        Callback = function() SwitchToTeam("Guards") end,
    })
    TabPrison:Button({
        Title = "Become Criminal (;crim)",
        Callback = function() SwitchToTeam("Criminals") end,
    })
    TabPrison:Button({
        Title = "Join Neutral Team (;neutral)",
        Callback = function() SwitchToTeam("Neutral") end,
    })

    TabPrison:Section({ Title = "Guard & Prisoner Automation" })
    TabPrison:Toggle({
        Title = "Auto-Arrest Aura (ArrestPlayer Remote)",
        Value = false,
        Callback = function(v) State.AutoArrest = v end,
    })
    TabPrison:Toggle({
        Title = "Auto-Taze Aura (Automatically Tase Hostile Targets)",
        Value = false,
        Callback = function(v) State.AutoTaze = v end,
    })
    TabPrison:Button({
        Title = "Arrest Nearest / Valid Targets (;arrestall)",
        Callback = function() RunArrestAll("others") end,
    })
    TabPrison:Button({
        Title = "Tase Nearest Target (;tase)",
        Callback = function() RunTaseTargets("nearest") end,
    })
    TabPrison:Toggle({
        Title = "Anti-Tase (Block PlayerTased Stun & Ragdoll)",
        Value = true,
        Callback = function(v) State.AntiTase = v end,
    })
    TabPrison:Toggle({
        Title = "Anti-Arrest (Block ClientArrested Handler)",
        Value = false,
        Callback = function(v) State.AntiArrest = v end,
    })
    TabPrison:Toggle({
        Title = "Always Enable Backpack",
        Value = false,
        Callback = function(v) State.AlwaysBackpack = v end,
    })
    TabPrison:Toggle({
        Title = "Auto Become Criminal After Being Arrested",
        Value = false,
        Callback = function(v) State.AutoCriminalOnArrest = v end,
    })
    TabPrison:Toggle({
        Title = "Fast Respawn (<1s Respawn & Return to Death Spot)",
        Value = false,
        Callback = function(v) State.FastRespawn = v end,
    })
    TabPrison:Toggle({
        Title = "Open / Noclip All Prison Doors",
        Value = false,
        Callback = function(v)
            State.OpenAllDoors = v
            if not v then RestoreAllDoors() end
        end,
    })
    TabPrison:Toggle({
        Title = "Electric Fence Godmode",
        Value = true,
        Callback = function(v)
            State.FenceGodmode = v
            pcall(function()
                local fences = Workspace:FindFirstChild("Prison_Fences")
                if fences then
                    for _, desc in ipairs(fences:GetDescendants()) do
                        if desc:IsA("BasePart") and desc:FindFirstChildOfClass("TouchTransmitter") then
                            desc.CanTouch = not v
                        end
                    end
                end
            end)
        end,
    })
    TabPrison:Toggle({
        Title = "Auto Detonate C4 When Enemies Approach",
        Value = false,
        Callback = function(v) State.AutoDetonateC4 = v end,
    })

    -- // TAB 5: VEHICLES, CHARACTER FLY & FE INVISIBLE
    TabVehicles:Section({ Title = "Character Fly (Hotkey: F) & Vehicle Controls" })
    TabVehicles:Toggle({
        Title = "Character Fly (PC WASD + Mobile Thumbstick & Up/Down)",
        Value = false,
        Callback = function(v)
            State.Fly = v
            if v then MobileQuickBar.Visible = true else CleanupCharFly() end
        end,
    })
    TabVehicles:Slider({
        Title = "Character Fly Speed",
        Value = { Min = 25, Max = 140, Default = 65 },
        Callback = function(v) State.FlySpeed = tonumber(v) or 65 end,
    })
    TabVehicles:Button({
        Title = "Spawn & Enter Nearest Car (;car)",
        Callback = SpawnAndEnterNearestCar,
    })
    TabVehicles:Toggle({
        Title = "Vehicle Fly (;carfly)",
        Value = false,
        Callback = function(v)
            State.VehicleFly = v
            if v then MobileQuickBar.Visible = true end
        end,
    })
    TabVehicles:Slider({
        Title = "Vehicle Fly Speed",
        Value = { Min = 30, Max = 180, Default = 80 },
        Callback = function(v) State.VehicleFlySpeed = tonumber(v) or 80 end,
    })
    TabVehicles:Toggle({
        Title = "Vehicle Speed Multiplier",
        Value = false,
        Callback = function(v) State.VehicleSpeedMod = v end,
    })
    TabVehicles:Slider({
        Title = "Car Speed Multiplier",
        Step = 0.2,
        Value = { Min = 1.2, Max = 4.0, Default = 2.0 },
        Callback = function(v) State.VehicleSpeedMult = tonumber(v) or 2.0 end,
    })

    TabVehicles:Section({ Title = "Serverside FE Invisible & Anti-Troll" })
    FEInvisToggleRef = TabVehicles:Toggle({
        Title = "Serverside FE Invisible (;invis)",
        Value = false,
        Callback = function(v) SetFEInvisibleState(v, false) end,
    })
    TabVehicles:Toggle({
        Title = "Anti-Invisible (Reveal Invisible Exploiters)",
        Value = false,
        Callback = function(v) State.AntiInvisible = v end,
    })
    TabVehicles:Toggle({
        Title = "Anti-Fling (Disable Vehicle & Spin-Fling Collisions)",
        Value = true,
        Callback = function(v) State.AntiFling = v end,
    })
    TabVehicles:Toggle({
        Title = "Vehicle Fling Enemies (Requires Safe Mode OFF)",
        Value = false,
        Callback = function(v)
            if v and State.AntiBanSafeMode then
                Notify("Anti-Ban Safe Mode", "Disable Anti-Ban Safe Mode first to use 9500-velocity Car Fling!", 4)
            end
            State.VehicleFling = v
            if v then State.AntiFling = true end
        end,
    })

    -- // TAB 6: MOVEMENT
    TabMove:Section({ Title = "2026 Anti-Rubberband Speed & Noclip (Hotkey: N)" })
    TabMove:Toggle({
        Title = "MaxSpeed (20 Indoor Sub-Regions Anti-Rubberband Boost)",
        Value = false,
        Callback = function(v)
            State.MaxSpeed = v
            if v then
                BypassClientAntiNoclip()
                if LocalPlayer.Character then BypassAntiJump(LocalPlayer.Character, true) end
            else
                local hum = GetHumanoid(LocalPlayer.Character)
                if hum then hum.WalkSpeed = State.AlwaysSprint and 24 or 16 end
            end
        end,
    })
    TabMove:Dropdown({
        Title = "Speed Mode",
        Values = { "RegionSafe", "Custom", "AlwaysSprint" },
        Value = "RegionSafe",
        Callback = function(v)
            local mode = NormalizeDropdownValue(v)
            if mode ~= "" then State.MaxSpeedMode = mode end
        end,
    })
    TabMove:Slider({
        Title = "Custom WalkSpeed",
        Value = { Min = 16, Max = 92, Default = 40 },
        Callback = function(v) State.CustomWalkSpeed = tonumber(v) or 40 end,
    })
    TabMove:Toggle({
        Title = "JumpPower Boost",
        Value = false,
        Callback = function(v)
            State.JumpPowerEnabled = v
            if not v then
                local hum = GetHumanoid(LocalPlayer.Character)
                if hum then hum.JumpPower = 50 end
            end
        end,
    })
    TabMove:Slider({
        Title = "Custom JumpPower",
        Value = { Min = 50, Max = 110, Default = 65 },
        Callback = function(v) State.JumpPower = tonumber(v) or 65 end,
    })
    TabMove:Toggle({
        Title = "No Jump Cooldown & Infinite Stamina",
        Value = false,
        Callback = function(v)
            State.AntiJumpCooldown = v
            State.InfiniteStamina = v
            if LocalPlayer.Character then BypassAntiJump(LocalPlayer.Character, v) end
        end,
    })
    TabMove:Toggle({
        Title = "Infinite Jump (Air Jump)",
        Value = false,
        Callback = function(v) State.InfiniteJump = v end,
    })
    TabMove:Toggle({
        Title = "Noclip (Non-Destructive Head Signal Bypass)",
        Value = false,
        Callback = function(v)
            State.Noclip = v
            if v then BypassClientAntiNoclip() end
        end,
    })
    TabMove:Toggle({
        Title = "Anti-KillPlane (Void & Roof Protection)",
        Value = true,
        Callback = function(v) State.AntiKillPlane = v end,
    })

    -- // TAB 7: ESP, COMBAT VFX, TELEPORTS & KX ADMIN
    TabVisuals:Section({ Title = "Role-Colored Player ESP & Combat VFX" })
    TabVisuals:Toggle({
        Title = "Enable Player ESP",
        Value = false,
        Callback = function(v)
            State.ESP = v
            if not v then
                for plr in pairs(ESPObjects) do RemovePlayerESP(plr) end
            end
        end,
    })
    TabVisuals:Toggle({
        Title = "Hide Teammates from ESP",
        Value = false,
        Callback = function(v) State.ESPHideTeam = v end,
    })
    TabVisuals:Toggle({
        Title = "3D Neon Bullet Tracers",
        Value = true,
        Callback = function(v) State.BulletTracers = v end,
    })
    TabVisuals:Toggle({
        Title = "4-Tick Animated Crosshair Hitmarker & Hit Sounds",
        Value = true,
        Callback = function(v)
            State.Hitmarker = v
            State.HitSound = v
        end,
    })
    TabVisuals:Toggle({
        Title = "Floating 3D Damage Numbers",
        Value = true,
        Callback = function(v) State.DamageNumbers = v end,
    })
    TabVisuals:Toggle({
        Title = "C4 Explosive ESP",
        Value = false,
        Callback = function(v) State.C4ESP = v end,
    })
    TabVisuals:Toggle({
        Title = "Heuristic Cheater & Car-TP Anomaly Alerts",
        Value = true,
        Callback = function(v)
            State.CheaterAlerts = v
            State.CarTPAlerts = v
        end,
    })
    TabVisuals:Toggle({
        Title = "Show Top-Right KX Command Bar (;cmd)",
        Value = true,
        Callback = function(v)
            State.ShowCommandBar = v
            CmdBarFrame.Visible = v
        end,
    })

    TabVisuals:Section({ Title = "15 Preset Prison Life Teleports" })
    local locNames = {}
    for name in pairs(TeleportLocations) do table.insert(locNames, name) end
    table.sort(locNames)

    local selectedLocation = locNames[1]
    TabVisuals:Dropdown({
        Title = "Select Location",
        Values = locNames,
        Value = selectedLocation,
        Callback = function(v)
            local picked = NormalizeDropdownValue(v)
            if picked ~= "" then selectedLocation = picked end
        end,
    })
    TabVisuals:Button({
        Title = "Teleport to Selected Location",
        Callback = function()
            if selectedLocation and TeleportLocations[selectedLocation] then
                SafeTeleport(TeleportLocations[selectedLocation])
                Notify("Teleported", "Moved to " .. selectedLocation, 2.5)
            end
        end,
    })

    TabVisuals:Section({ Title = "Target Player Actions & Server Utilities" })
    local selectedPlayerName = ""
    local playerDropdown = TabVisuals:Dropdown({
        Title = "Select Player",
        Values = {},
        Value = "",
        Callback = function(v) selectedPlayerName = NormalizeDropdownValue(v) end,
    })
    local function RefreshPlayerDropdown()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(list, p.Name) end
        end
        pcall(function()
            if playerDropdown and playerDropdown.Refresh then playerDropdown:Refresh(list) end
        end)
    end
    RefreshPlayerDropdown()
    AddConnection(Players.PlayerAdded:Connect(RefreshPlayerDropdown))
    AddConnection(Players.PlayerRemoving:Connect(RefreshPlayerDropdown))

    TabVisuals:Button({
        Title = "Teleport Behind Selected Player",
        Callback = function()
            local target = Players:FindFirstChild(selectedPlayerName)
            local tHrp = target and GetRoot(target.Character)
            if tHrp then
                SafeTeleport(tHrp.CFrame * CFrame.new(0, 0, 3.5))
                Notify("Teleport", "Teleported to " .. target.Name, 2.5)
            end
        end,
    })
    TabVisuals:Button({
        Title = "Spectate / Unspectate Selected Player (;view)",
        Callback = function()
            local target = Players:FindFirstChild(selectedPlayerName)
            if SpectateTarget then
                SetSpectatePlayer(nil)
            elseif target then
                SetSpectatePlayer(target)
            end
        end,
    })
    TabVisuals:Button({
        Title = "Toggle LoopKill on Selected Player (;loopkill)",
        Callback = function()
            local target = Players:FindFirstChild(selectedPlayerName)
            if target then
                State.LoopKillTargets[target.UserId] = not State.LoopKillTargets[target.UserId]
                Notify("LoopKill", target.Name .. ": " .. (State.LoopKillTargets[target.UserId] and "ADDED" or "REMOVED"), 2.5)
            end
        end,
    })
    TabVisuals:Button({
        Title = "FE Car-Seat Bring Selected Player (;bring)",
        Callback = function()
            local target = Players:FindFirstChild(selectedPlayerName)
            if target then BringPlayerViaVehicle(target) end
        end,
    })
    TabVisuals:Button({
        Title = "Rejoin Current Server (;rejoin)",
        Callback = RejoinServer,
    })
    TabVisuals:Button({
        Title = "Server Hop to Populated Server (;serverhop)",
        Callback = ServerHop,
    })
else
    -- ========================================================================
    -- // BUILT-IN NATIVE PC & MOBILE FALLBACK UI (IF WINDUI FAILS TO LOAD)
    -- ========================================================================
    MobileQuickBar.Visible = true

    local FallbackFrame = Instance.new("Frame")
    FallbackFrame.Name = "PL2026_NativeFallbackHub"
    FallbackFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    FallbackFrame.Position = UDim2.fromScale(0.5, 0.5)
    FallbackFrame.Size = UDim2.fromOffset(390, 370)
    FallbackFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
    FallbackFrame.BorderSizePixel = 0
    FallbackFrame.Parent = OverlayGui
    Instance.new("UICorner", FallbackFrame).CornerRadius = UDim.new(0, 12)
    local fbStroke = Instance.new("UIStroke", FallbackFrame)
    fbStroke.Color = Color3.fromRGB(59, 130, 246)
    fbStroke.Thickness = 1.5

    local TitleBar = Instance.new("TextLabel")
    TitleBar.Size = UDim2.new(1, -16, 0, 34)
    TitleBar.Position = UDim2.fromOffset(12, 4)
    TitleBar.BackgroundTransparency = 1
    TitleBar.Font = Enum.Font.GothamBold
    TitleBar.TextSize = 14
    TitleBar.TextColor3 = Color3.new(1, 1, 1)
    TitleBar.TextXAlignment = Enum.TextXAlignment.Left
    TitleBar.Text = "🚔 Prison Life 2026 Hub (v3.0 KX Edition)"
    TitleBar.Parent = FallbackFrame

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, -20, 1, -48)
    Scroll.Position = UDim2.fromOffset(10, 40)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 4
    Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    Scroll.Parent = FallbackFrame
    local list = Instance.new("UIListLayout", Scroll)
    list.Padding = UDim.new(0, 6)

    local function AddFallbackToggle(label, initial, onToggle)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 32)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextColor3 = Color3.new(1, 1, 1)
        local state = initial
        local function refresh()
            btn.BackgroundColor3 = state and Color3.fromRGB(37, 99, 235) or Color3.fromRGB(30, 41, 59)
            btn.Text = (state and "✅ " or "⬜ ") .. label
        end
        refresh()
        btn.Parent = Scroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        btn.Activated:Connect(function()
            state = not state
            refresh()
            onToggle(state)
        end)
    end

    AddFallbackToggle("Anti-Ban Safe Mode (Error 600 Guard)", true, function(v) State.AntiBanSafeMode = v; ApplyGunModsAll() end)
    AddFallbackToggle("4-Mode 3D Ballistic Holo-Shield", false, function(v) State.HoloShield = v; if v then CreateHoloShield() else DestroyHoloShield() end end)
    AddFallbackToggle("360° Ragebot (Auto-Shoot + Wallbang)", false, function(v) State.Ragebot = v; if v then SetupGunControllerHooks() end end)
    AddFallbackToggle("Silent Aim (Bullet Hook + Wallbang)", false, function(v) State.SilentAim = v; if v then SetupGunControllerHooks() end end)
    AddFallbackToggle("Smooth Aim Assist", false, function(v) State.AimAssist = v end)
    AddFallbackToggle("Triggerbot (Auto-Shoot)", false, function(v) State.Triggerbot = v; if v then SetupGunControllerHooks() end end)
    AddFallbackToggle("Safe Melee Kill Aura", false, function(v) State.KillAura = v end)
    AddFallbackToggle("Gun Mods (Rapid Fire + No Spread)", false, function(v) State.GunMods = v; ApplyGunModsAll() end)
    AddFallbackToggle("Region-Safe MaxSpeed", false, function(v) State.MaxSpeed = v end)
    AddFallbackToggle("Character Fly", false, function(v) State.Fly = v; if not v then CleanupCharFly() end end)
    AddFallbackToggle("Anti-Tase & Anti-Arrest", true, function(v) State.AntiTase = v; State.AntiArrest = v end)
    AddFallbackToggle("Auto-Arrest & Auto-Taze Aura", false, function(v) State.AutoArrest = v; State.AutoTaze = v end)
    AddFallbackToggle("Role-Colored Player ESP", false, function(v) State.ESP = v end)

    local ToggleHubBtn = Instance.new("TextButton")
    ToggleHubBtn.Name = "PL2026_ToggleHubBtn"
    ToggleHubBtn.Size = UDim2.fromOffset(105, 34)
    ToggleHubBtn.Position = UDim2.new(0.02, 0, 0.18, 0)
    ToggleHubBtn.BackgroundColor3 = Color3.fromRGB(30, 58, 138)
    ToggleHubBtn.Font = Enum.Font.GothamBold
    ToggleHubBtn.TextSize = 12
    ToggleHubBtn.TextColor3 = Color3.new(1, 1, 1)
    ToggleHubBtn.Text = "🚔 PL 2026"
    ToggleHubBtn.Parent = OverlayGui
    Instance.new("UICorner", ToggleHubBtn).CornerRadius = UDim.new(0, 10)
    ToggleHubBtn.Activated:Connect(function()
        FallbackFrame.Visible = not FallbackFrame.Visible
    end)
end

-- // Cleanup Registration
Env.PrisonLife2026Cleanup = function()
    Env.PrisonLife2026Running = false
    CleanupCharFly()
    StopFEInvisible()
    DestroyHoloShield()
    RestoreAllHitboxes()
    RestoreAllDoors()
    SetSpectatePlayer(nil)
    if hookfunction then
        for _, pair in ipairs(HookedFunctions) do
            pcall(function() hookfunction(pair.fn, pair.orig) end)
        end
    end
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    for plr in pairs(ESPObjects) do
        RemovePlayerESP(plr)
    end
    for _, hl in pairs(C4Highlights) do
        pcall(function() hl:Destroy() end)
    end
    for _, inst in ipairs(CreatedInstances) do
        pcall(function() inst:Destroy() end)
    end
end

Notify("Prison Life • 2026 Hub v3.0", "Loaded KX Feature Edition (PC & Mobile • Anti-Ban Hardened)!", 4)
