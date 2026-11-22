--[[
    ================================================================================
    🚔 PRISON LIFE — ULTIMATE 2026 SCRIPT (PC & MOBILE) [v4.0 CLEAN KX PRO EDITION]
    ================================================================================
    Target Game : Prison Life (PlaceId: 155615604 | UniverseId: 73885730)
    Patch Target: Late 2026 ("Sniper Update!" Remotes, Attributes & Anti-Cheat)
    Platform    : PC (Keyboard/Mouse + Hotkeys) & Mobile (Clean Clutter-Free HUD)
    UI Library  : Clean 7-Tab WindUI (with Built-In Native Touch/PC UI Fallback)

    Fixes & KX Upgrades in v4.0 (From 10-Minute Mobile Video Review + KX Research):
      1. Clean Clutter-Free Mobile/PC HUD:
         - Removed the messy right-side button stack completely.
         - Made the top-right Command Bar collapse into a tiny draggable `⌘ CMD` pill
           (so it never overlaps the game Menu or Ammo counter).
         - Moved Shield HP & Arrest Cooldown into a sleek non-overlapping bottom HUD
           strip (never stacks on top of your character or the Teams menu).
         - Replaced noisy WindUI Killfeed toast spam with a crisp 3-line transparent
           mini-killfeed overlay.
      2. Fixed Guard Innocent-Kill Warning Bug:
         - Lethal combat (Ragebot, Silent Aim, .combo1, KillAura) on Guards now
           strictly checks `Hostile == true` (NEVER shoots Trespassing-only inmates),
           eliminating "Do not kill innocent people!" warnings/kicks.
         - Auto-Arrest & Auto-Taze continue to handle Criminals + Hostile/Trespassing.
      3. Fixed 3D Bullet Shield & Real Incoming Bullet Detection:
         - Hooked the real 2026 bullet replicator (`GunRemotes.ReplicateEvent`) so
           incoming enemy shots genuinely trigger shield impact sparks, ricochet SFX,
           and live durability decay (180 HP -> 0 with auto-recharge).
         - Added true FE bullet dodging (`UndergroundPeek` / `DesyncBox` / `Hybrid` /
           `RiotOnly` / `FEGhost`) and auto-hides Shield visuals when dead or on the
           Prison Life Intro/Teams menu.
      4. Fixed FE Invisible Stuck Outline & Safe Gun Grabber:
         - Removed the intrusive cyan Highlight outline from FE Invisible.
         - Fixed GrabWeapons so AK-47, Remington 870, MP5, M9, M4A1, FAL, Hammer,
           and Crude Knife all grab reliably in one clean pass without 60Hz jitter.
      5. Added Signature KX Admin Vehicle & Combat Mechanics:
         - `.savecar [num]` (Saved Cars pool with SC counter for instant car ops).
         - `.forcecrim <plr|all>` / `.fc` (Uses saved car to turn Inmates Criminal).
         - `.bring <plr>` (Improved FE car-seat bring from inside/outside prison).
         - `.void <plr>` / `.forcekick <plr>` / `.fling <plr>` (Saved-car void/fling).
         - `.autohvh` (Hack-vs-Hack combat suite: threat priority + Ragebot + Peek
           Desync + Auto-Switch + Stop-on-Kill + Anti-Tase/Anti-Arrest).
         - `.wheelaura` (Neon wheel aura & trails on driven vehicles) & Instant
           Hammer / Crude Knife grabber (`.hammer`, `.knife`).
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

local function MakeDraggable(guiObj)
    if not guiObj then return end
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    guiObj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObj.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    guiObj.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
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

-- // 2026 Remotes Lookup (Verified from PrisonLife-Deobfuscated-API.md)
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
    ReplicateEvent    = GunRemotesFolder and (GunRemotesFolder:FindFirstChild("ReplicateEvent") or GunRemotesFolder:FindFirstChild("GunTracers")),
    MeleeEvent        = ReplicatedStorage:FindFirstChild("meleeEvent"),
}

-- // Central Configuration State
local State = {
    -- Anti-Ban Protection (Prevents Error Code 600 30-Day Experience Bans)
    AntiBanSafeMode = true,

    -- 5-Mode 3D Holographic Bullet Shield & Anti-Aim
    HoloShield = false,
    ShieldMode = "Hybrid",        -- "Hybrid", "UndergroundPeek", "DesyncBox", "RiotOnly", "FEGhost"
    ShieldSize = 5.4,
    ShieldTransparency = 0.84,    -- Sleek translucent ForceField (does not block view!)
    ShieldShowVisual = true,
    ShieldAutoEquip = true,
    ShieldAutoFaceShooter = false,
    ShieldSpinBlock = false,
    ShieldSpinSpeed = 18,
    DesyncJitterRadius = 5.5,
    HoloShieldMaxHP = 180,

    -- AutoHvH, Ragebot & .combo1 Burst
    AutoHvH = false,
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
    SilentAimHeadChance = 80,
    SilentAimFOV = 180,
    SilentAimShowFOV = true,
    SilentAimWallcheck = true,
    SilentAimWallbang = true,
    SilentAimAimPart = "Head",    -- "Head", "Torso", "Random"
    SilentAimTeamCheck = true,
    SilentAimHostileCheck = true, -- Strictly Hostile-only on Guards for lethal shots!
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
    AutoGetGunsSelection = { "Remington 870", "AK-47", "MP5" },
    AutoPickupDropped = false,
    AutoArmor = false,
    AutoReload = true,
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

    -- Vehicles, Saved Cars, WheelAura & Character Fly
    Fly = false,
    FlySpeed = 65,
    VehicleFly = false,
    VehicleFlySpeed = 80,
    VehicleSpeedMod = false,
    VehicleSpeedMult = 2.0,
    WheelAura = false,
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

    -- Visuals, VFX, Audio, Mini-Killfeed & Alerts
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
    TracerFadeTime = 0.22,
    Hitmarker = true,
    HitSound = true,
    KillSound = true,
    DamageNumbers = true,
    ShieldHitVFX = true,

    ShowMiniKillfeed = true,
    CheaterAlerts = true,
    CarTPAlerts = true,

    -- KX Command Pill & Chat Commands
    ShowCommandPill = true,
    ChatCommands = true,
}

-- // Load WindUI
local WindUI = nil
pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

local LastNotifyClock = 0
local function Notify(title, content, duration)
    if WindUI and WindUI.Notify then
        pcall(function()
            WindUI:Notify({
                Title = title,
                Content = content,
                Duration = duration or 2.8,
                Icon = "shield",
            })
        end)
    else
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = content,
                Duration = duration or 2.8,
            })
        end)
    end
end

-- ============================================================================
-- // SECTION 1: TARGET VALIDATION (FIXED GUARD HOSTILE CHECK) & WALLBANG SCANNER
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

local function IsOnTeamsMenu()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local home = pg and pg:FindFirstChild("Home")
    local intro = home and home:FindFirstChild("IntroFrame")
    if intro and intro.Visible then return true end
    return (LocalPlayer.Team == nil or LocalPlayer.Team == Teams:FindFirstChild("Neutral"))
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
            wantHead = (math.random(1, 100) <= (tonumber(State.SilentAimHeadChance) or 80))
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

-- CRITICAL FIX FROM VIDEO:
-- Lethal weapons (forArrest == false) on Guards MUST ONLY shoot Inmates with `Hostile == true`!
-- Shooting a Trespassing-only inmate triggers "Do not kill innocent people!" and kicks you off Guards!
-- Non-lethal arrest/taze (forArrest == true) allows Criminals + Hostile/Trespassing/Tased Inmates.
local function IsValidCombatTarget(plr, requireHostileForGuard, whitelistTbl, forArrest)
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
        if forArrest then
            local arrestable = char:GetAttribute("Hostile") or char:GetAttribute("Trespassing") or char:GetAttribute("Tased")
            if not arrestable then return false end
        else
            -- Strictly require Hostile == true for lethal damage (prevents InnocentWarnEvent!)
            if char:GetAttribute("Hostile") ~= true then return false end
        end
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

    local maxRadii = State.AntiBanSafeMode and { 2.8, 5.0 } or { 3.2, 6.4 }
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
        local candTarget = targetPos + (nVec * 1.15)
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
    local prioritizeArmed = (opts.prioritizeArmed == true or State.AutoHvH)

    local screenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    if not IsMobile and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        local mPos = UserInputService:GetMouseLocation()
        screenCenter = Vector2.new(mPos.X, mPos.Y)
    end

    local candidates = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if IsValidCombatTarget(plr, requireHostile, State.KillAuraWhitelist, false) then
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
                            if score > fovRadius then validScreen = false end
                        end
                    end
                    if validScreen then
                        -- In AutoHvH mode, strongly prioritize enemies holding firearms or shooting at you
                        if prioritizeArmed then
                            local eq = char:FindFirstChildOfClass("Tool")
                            if eq and (eq:GetAttribute("FireRate") or eq:GetAttribute("ToolType") == "Gun") then
                                score = score * 0.45
                            end
                        end
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

local function ResolveTargetPlayers(query)
    local q = Trim(query)
    if q == "" then return {} end
    local out, seen = {}, {}
    local function push(p)
        if p and not seen[p] then seen[p] = true; table.insert(out, p) end
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
-- // SECTION 2: CLEAN OVERLAY GUI, MINI-KILLFEED, HITMARKER, VFX & AUDIO
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
SilentFOVStroke.Thickness = 1.4
SilentFOVStroke.Transparency = 0.35

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
AimAssistFOVStroke.Thickness = 1.3
AimAssistFOVStroke.Transparency = 0.4

-- Clean Bottom-Center Status Strip (Above Hotbar — NEVER covers your character!)
local BottomStatusStrip = Instance.new("Frame")
BottomStatusStrip.Name = "PL2026_BottomStrip"
BottomStatusStrip.AnchorPoint = Vector2.new(0.5, 1)
BottomStatusStrip.Position = UDim2.new(0.5, 0, 1, -78)
BottomStatusStrip.Size = UDim2.fromOffset(320, 44)
BottomStatusStrip.BackgroundTransparency = 1
BottomStatusStrip.Parent = OverlayGui
local StripLayout = Instance.new("UIListLayout", BottomStatusStrip)
StripLayout.Padding = UDim.new(0, 4)
StripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
StripLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

local ShieldBarHolder = Instance.new("Frame")
ShieldBarHolder.Name = "HoloShieldBar"
ShieldBarHolder.Size = UDim2.fromOffset(185, 18)
ShieldBarHolder.BackgroundColor3 = Color3.fromRGB(12, 18, 28)
ShieldBarHolder.BackgroundTransparency = 0.25
ShieldBarHolder.BorderSizePixel = 0
ShieldBarHolder.Visible = false
ShieldBarHolder.Parent = BottomStatusStrip
Instance.new("UICorner", ShieldBarHolder).CornerRadius = UDim.new(1, 0)

local ShieldBarFill = Instance.new("Frame")
ShieldBarFill.Size = UDim2.fromScale(1, 1)
ShieldBarFill.BackgroundColor3 = Color3.fromRGB(0, 190, 240)
ShieldBarFill.BackgroundTransparency = 0.35
ShieldBarFill.BorderSizePixel = 0
ShieldBarFill.Parent = ShieldBarHolder
Instance.new("UICorner", ShieldBarFill).CornerRadius = UDim.new(1, 0)

local ShieldBarText = Instance.new("TextLabel")
ShieldBarText.Size = UDim2.fromScale(1, 1)
ShieldBarText.BackgroundTransparency = 1
ShieldBarText.Font = Enum.Font.GothamBold
ShieldBarText.TextSize = 11
ShieldBarText.TextColor3 = Color3.new(1, 1, 1)
ShieldBarText.TextStrokeTransparency = 0.25
ShieldBarText.Text = "🛡️ SHIELD: 180/180"
ShieldBarText.Parent = ShieldBarHolder

local ArrestBarHolder = Instance.new("Frame")
ArrestBarHolder.Name = "ArrestCooldownBar"
ArrestBarHolder.Size = UDim2.fromOffset(165, 16)
ArrestBarHolder.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
ArrestBarHolder.BackgroundTransparency = 0.25
ArrestBarHolder.BorderSizePixel = 0
ArrestBarHolder.Visible = false
ArrestBarHolder.Parent = BottomStatusStrip
Instance.new("UICorner", ArrestBarHolder).CornerRadius = UDim.new(1, 0)

local ArrestBarFill = Instance.new("Frame")
ArrestBarFill.Size = UDim2.fromScale(1, 1)
ArrestBarFill.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
ArrestBarFill.BackgroundTransparency = 0.35
ArrestBarFill.BorderSizePixel = 0
ArrestBarFill.Parent = ArrestBarHolder
Instance.new("UICorner", ArrestBarFill).CornerRadius = UDim.new(1, 0)

local ArrestBarText = Instance.new("TextLabel")
ArrestBarText.Size = UDim2.fromScale(1, 1)
ArrestBarText.BackgroundTransparency = 1
ArrestBarText.Font = Enum.Font.GothamBold
ArrestBarText.TextSize = 10
ArrestBarText.TextColor3 = Color3.new(1, 1, 1)
ArrestBarText.TextStrokeTransparency = 0.25
ArrestBarText.Text = ""
ArrestBarText.Parent = ArrestBarHolder

-- Compact Transparent Mini-Killfeed (Top-Left below .combo1 — ZERO Toast Spam!)
local MiniKillfeedFrame = Instance.new("Frame")
MiniKillfeedFrame.Name = "PL2026_MiniKillfeed"
MiniKillfeedFrame.Position = UDim2.new(0, 14, 0, 92)
MiniKillfeedFrame.Size = UDim2.fromOffset(290, 62)
MiniKillfeedFrame.BackgroundTransparency = 1
MiniKillfeedFrame.Parent = OverlayGui
local KFLayout = Instance.new("UIListLayout", MiniKillfeedFrame)
KFLayout.Padding = UDim.new(0, 2)
KFLayout.VerticalAlignment = Enum.VerticalAlignment.Top

local function PushMiniKillfeedLine(text, color)
    if not State.ShowMiniKillfeed then return end
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextColor3 = color or Color3.fromRGB(235, 240, 255)
    lbl.TextStrokeTransparency = 0.2
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Text = text
    lbl.Parent = MiniKillfeedFrame

    local kids = {}
    for _, ch in ipairs(MiniKillfeedFrame:GetChildren()) do
        if ch:IsA("TextLabel") then table.insert(kids, ch) end
    end
    while #kids > 3 do
        kids[1]:Destroy()
        table.remove(kids, 1)
    end
    task.delay(4.2, function()
        if lbl and lbl.Parent then lbl:Destroy() end
    end)
end

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
            if isKill and State.KillSound then KillStreakSound:Play()
            elseif isHeadshot then HitHeadSound:Play()
            else HitBodySound:Play() end
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
    p.Size = Vector3.new(0.08, 0.08, dist)
    p.CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -dist * 0.5)
    p.Parent = VFXPool

    local fade = clamp(tonumber(State.TracerFadeTime) or 0.22, 0.08, 0.6)
    TweenService:Create(p, TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0.015, 0.015, dist),
    }):Play()
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
    anchor.Position = worldPos + Vector3.new((math.random() - 0.5) * 1.1, 1.2, (math.random() - 0.5) * 1.1)
    anchor.Parent = VFXPool

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(76, 26)
    bb.AlwaysOnTop = true
    bb.Adornee = anchor
    bb.Parent = anchor

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = isHead and 15 or 13
    lbl.TextColor3 = isHead and Color3.fromRGB(255, 75, 75) or Color3.fromRGB(255, 235, 110)
    lbl.TextStrokeTransparency = 0.15
    lbl.Text = "-" .. tostring(amt) .. (isHead and " HS" or "")
    lbl.Parent = bb

    TweenService:Create(anchor, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = anchor.Position + Vector3.new(0, 2.4, 0),
    }):Play()
    task.delay(0.54, function()
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
    p.Size = Vector3.new(0.45, 0.45, 0.45)
    p.Position = hitPos
    p.Transparency = 0.15
    p.Parent = VFXPool
    TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(1.4, 1.4, 1.4),
        Transparency = 1,
    }):Play()
    task.delay(0.18, function()
        if p and p.Parent then p:Destroy() end
    end)
end

-- ============================================================================
-- // SECTION 3: 2026 GUN CONTROLLER UPVALUE HOOK (SILENT AIM / RAGEBOT / AUTOHVH)
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
                    local activeTargetPart, activeOrigin, activeHitPos = nil, nil, nil

                    if GunHook.TaseTargetPart and GunHook.TaseTargetPart.Parent then
                        activeTargetPart = GunHook.TaseTargetPart
                        activeOrigin, activeHitPos = FindWallbangTrajectory(origOrigin, activeTargetPart, activeTargetPart.Parent, State.SilentAimWallbang)
                    elseif GunHook.ForceRageShot and GunHook.RageTargetPart and GunHook.RageTargetPart.Parent then
                        activeTargetPart = GunHook.RageTargetPart
                        activeOrigin, activeHitPos = FindWallbangTrajectory(origOrigin, activeTargetPart, activeTargetPart.Parent, true)
                    elseif State.Ragebot or State.AutoHvH then
                        activeTargetPart, _, activeOrigin, activeHitPos = GetBestCombatTarget({
                            origin = origOrigin,
                            use360 = State.Ragebot360 or State.AutoHvH,
                            fov = State.SilentAimFOV,
                            wallcheck = true,
                            wallbang = State.SilentAimWallbang,
                            requireHostile = State.SilentAimHostileCheck,
                            forceHead = true,
                            prioritizeArmed = State.AutoHvH,
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
                        SpawnBulletTracer(args[1], hitPos, State.Ragebot or State.AutoHvH or GunHook.ForceRageShot)
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
                if Env.PrisonLife2026Running and not GunHook.IsHooked and (State.SilentAim or State.Ragebot or State.AutoHvH or GunHook.ForceRageShot) and self == Workspace then
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
    if isCombo then GunHook.LastComboShotClock = now
    elseif isRage then GunHook.LastRageShotClock = now end

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
-- // SECTION 4: 5-MODE 3D BULLET SHIELD & REAL REPLICATEEVENT INTERCEPTION
-- ============================================================================
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
    if not State.HoloShield or IsOnTeamsMenu() then return end

    local sz = clamp(tonumber(State.ShieldSize) or 5.4, 3, 12)
    local m = Instance.new("Model")
    m.Name = "PL2026_BallisticShield"

    local core = Instance.new("Part")
    core.Name = "RiotShieldPart"
    core.Size = Vector3.new(sz * 0.85, sz * 0.95, 0.22)
    core.Transparency = State.ShieldShowVisual and clamp(tonumber(State.ShieldTransparency) or 0.84, 0.55, 0.96) or 1
    core.Material = Enum.Material.ForceField
    core.Color = Color3.fromRGB(0, 195, 255)
    core.Anchored = true
    core.CanCollide = false
    core.CanQuery = true
    core.CanTouch = false
    core.CastShadow = false
    core.Parent = m

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

local function RegisterHoloShieldHit(dmg, worldHitPos)
    if not State.HoloShield or IsOnTeamsMenu() then return end
    if os.clock() < HoloShieldState.BrokenUntil then return end
    HoloShieldState.LastHit = os.clock()
    HoloShieldState.HP = math.max(0, HoloShieldState.HP - (dmg or 16))
    if HoloShieldState.CorePart then
        HoloShieldState.CorePart.Color = Color3.fromRGB(255, 95, 110)
        task.delay(0.08, function()
            if HoloShieldState.CorePart then
                HoloShieldState.CorePart.Color = Color3.fromRGB(0, 195, 255)
            end
        end)
    end
    if worldHitPos then SpawnShieldSparkVFX(worldHitPos) end
    if HoloShieldState.HP <= 0 then
        HoloShieldState.BrokenUntil = os.clock() + 3.8
        if HoloShieldState.CorePart then
            HoloShieldState.CorePart.Transparency = 0.96
            HoloShieldState.CorePart.CanQuery = false
        end
    end
end

-- Hook the REAL 2026 incoming bullet replicator (`ReplicatedStorage.GunRemotes.ReplicateEvent`)
local function ExtractPointsFromReplicatePayload(...)
    local pts = {}
    local function scan(v, depth)
        if depth > 3 then return end
        local tv = typeof(v)
        if tv == "Vector3" then
            table.insert(pts, v)
        elseif tv == "CFrame" then
            table.insert(pts, v.Position)
        elseif tv == "table" then
            for _, sub in pairs(v) do scan(sub, depth + 1) end
        end
    end
    for i = 1, select("#", ...) do
        scan(select(i, ...), 1)
    end
    return pts
end

if Remotes.ReplicateEvent and Remotes.ReplicateEvent:IsA("RemoteEvent") then
    AddConnection(Remotes.ReplicateEvent.OnClientEvent:Connect(function(...)
        if not State.HoloShield or IsOnTeamsMenu() then return end
        local myHrp = GetRoot(LocalPlayer.Character)
        if not myHrp then return end
        local realPos = (HoloShieldState.DesyncActive and HoloShieldState.SavedCF and HoloShieldState.SavedCF.Position) or myHrp.Position
        local pts = ExtractPointsFromReplicatePayload(...)
        if #pts >= 2 then
            local origin, hitPos = pts[1], pts[2]
            -- Only react to enemy bullets (origin > 6 studs away from us) passing near our shield
            if (origin - realPos).Magnitude > 6 then
                local shieldPos = (HoloShieldState.CorePart and HoloShieldState.CorePart.Position) or realPos
                local seg = hitPos - origin
                local len = seg.Magnitude
                if len > 1 then
                    local t = clamp((shieldPos - origin):Dot(seg) / (len * len), 0, 1)
                    local closest = origin + (seg * t)
                    if (closest - shieldPos).Magnitude <= 5.2 or (hitPos - realPos).Magnitude <= 6.0 then
                        RegisterHoloShieldHit(15, closest)
                    end
                end
            end
        end
    end))
end

-- ============================================================================
-- // SECTION 5: FIXED SAFE WEAPON GRABBER (ALL GUNS + HAMMER + KNIFE) & .COMBO1
-- ============================================================================
local KnownGunLocations = {
    ["Remington 870"] = {
        SearchPivot = Vector3.new(820.2986, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(820.2986, 91.5, 2229.3962),
    },
    ["MP5"] = {
        SearchPivot = Vector3.new(813.6987, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(813.6987, 91.5, 2229.3962),
    },
    ["M9"] = {
        SearchPivot = Vector3.new(820.2986, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(820.2986, 91.5, 2229.3962),
    },
    ["M4A1"] = {
        GamepassId = 643697197,
        SearchPivot = Vector3.new(847.5, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(847.5, 91.5, 2229.3962),
    },
    ["Riot Shield"] = {
        GamepassId = 643697197,
        SearchPivot = Vector3.new(840.0, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(840.0, 91.5, 2229.3962),
    },
    ["AK-47"] = {
        SearchPivot = Vector3.new(-931.7928, 91.2783, 2039.2555),
        UndergroundCF = CFrame.new(-931.7928, 85.0, 2039.2555),
    },
    ["FAL"] = {
        GamepassId = 1443271,
        SearchPivot = Vector3.new(-938.5, 91.2783, 2039.2555),
        UndergroundCF = CFrame.new(-938.5, 85.0, 2039.2555),
    },
    ["Hammer"] = {
        SearchPivot = Vector3.new(778.0, 97.5, 2480.0),
        UndergroundCF = CFrame.new(778.0, 93.0, 2480.0),
    },
    ["Crude Knife"] = {
        SearchPivot = Vector3.new(778.0, 97.5, 2480.0),
        UndergroundCF = CFrame.new(778.0, 93.0, 2480.0),
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
    end
    local okT, tagged = pcall(function() return CollectionService:GetTagged("Giver") end)
    if okT and type(tagged) == "table" then
        for _, inst in ipairs(tagged) do table.insert(givers, inst) end
    end
    local singleFolder = Workspace:FindFirstChild("Prison_ITEMS") and Workspace.Prison_ITEMS:FindFirstChild("single")
    if singleFolder then
        for _, child in ipairs(singleFolder:GetChildren()) do table.insert(givers, child) end
    end

    local lowTarget = string.lower(weaponName)
    for _, giver in ipairs(givers) do
        local toolAttr = giver:GetAttribute("ToolName") or (giver.Parent and giver.Parent:GetAttribute("ToolName"))
        local matched = (type(toolAttr) == "string" and string.lower(toolAttr) == lowTarget)
            or (string.lower(giver.Name) == lowTarget)
            or (giver.Parent and string.lower(giver.Parent.Name) == lowTarget)
        if matched and IsGiverTeamAllowed(giver) then
            local okP, piv = pcall(function() return giver:GetPivot() end)
            if okP and piv then
                local pos = piv.Position
                return giver, CFrame.new(pos.X, pos.Y - 6.0, pos.Z)
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
        if closest then return closest, info.UndergroundCF end
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
            if State.AntiBanSafeMode then targetSPS = math.min(targetSPS, 15) end
            if targetSPS > 0 then tool:SetAttribute("FireRate", 1 / targetSPS) end
            if State.GunNoSpread then tool:SetAttribute("SpreadRadius", 0)
            elseif orig and orig.SpreadRadius then tool:SetAttribute("SpreadRadius", orig.SpreadRadius) end
            if State.GunFullAuto then tool:SetAttribute("AutoFire", true)
            elseif orig and orig.AutoFire ~= nil then tool:SetAttribute("AutoFire", orig.AutoFire) end
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
    if Remotes.GiverPressed then pcall(function() Remotes.GiverPressed:FireServer(giver) end) end
    if Remotes.TouchGiver then pcall(function() Remotes.TouchGiver:FireServer(giver) end) end
    if Remotes.InteractWithItem then
        pcall(function()
            local part = giver:IsA("BasePart") and giver or giver:FindFirstChildWhichIsA("BasePart", true)
            if part then task.spawn(function() Remotes.InteractWithItem:InvokeServer(part) end) end
        end)
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
        if not silent then Notify("Weapons", "You already have the selected weapons!", 2.2) end
        return
    end

    IsGrabbingGuns = true
    local savedCF = (HoloShieldState.DesyncActive and HoloShieldState.SavedCF) or hrp.CFrame
    HoloShieldState.DesyncActive = false

    local lastPos = hrp.Position
    for idx, item in ipairs(queue) do
        if not hrp or not hrp.Parent or hum.Health <= 0 then break end
        -- Pause briefly if switching map zones (Armory <-> Criminal Base) so server doesn't see 60Hz oscillation
        if (item.CF.Position - lastPos).Magnitude > 600 then
            task.wait(0.22)
        end

        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = item.CF
        lastPos = item.CF.Position
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

        if idx < #queue then task.wait(0.10) end
    end

    if hrp and hrp.Parent and hum and hum.Health > 0 then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = savedCF
    end

    IsGrabbingGuns = false
    SetupGunControllerHooks()
    ApplyGunModsAll()
    if not silent then Notify("Weapons Grabbed", "Equipped weapons safely!", 2.2) end
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
    for _, t in pairs(owned) do table.insert(ordered, t) end
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
            Notify(".combo1", "No loaded weapons ready!", 2.0)
            return
        end

        local targetPart, targetPlr = nil, nil
        if specificPlr and IsValidCombatTarget(specificPlr, State.SilentAimHostileCheck, nil, false) then
            targetPart = PickAimPart(specificPlr.Character, true)
            targetPlr = specificPlr
        else
            targetPart, targetPlr = GetBestCombatTarget({
                use360 = true,
                wallcheck = true,
                wallbang = State.SilentAimWallbang,
                requireHostile = State.SilentAimHostileCheck,
                forceHead = true,
                prioritizeArmed = true,
            })
        end

        if not targetPart or not targetPlr then
            Notify(".combo1", "No valid hostile target in range!", 1.8)
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
                    prioritizeArmed = true,
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
-- // SECTION 6: KX SAVED CARS (.savecar), .forcecrim, .bring, .void & WHEELAURA
-- ============================================================================
local SavedCars = {} -- Array of saved multi-seat car Models in Workspace.CarContainer

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

local function PruneSavedCars()
    for i = #SavedCars, 1, -1 do
        local m = SavedCars[i]
        if not m or not m.Parent or not m:FindFirstChildWhichIsA("VehicleSeat", true) then
            table.remove(SavedCars, i)
        end
    end
end

local function GetCarSeats(carModel, myHum)
    if not carModel or not carModel.Parent then return nil, nil end
    local drv, pass = nil, nil
    for _, desc in ipairs(carModel:GetDescendants()) do
        if desc:IsA("VehicleSeat") and (not desc.Occupant or desc.Occupant == myHum) then
            drv = desc
        elseif desc:IsA("Seat") and not desc:IsA("VehicleSeat") and not desc.Occupant then
            pass = desc
        end
    end
    return drv, pass
end

local function SpawnSingleCarAndTrack()
    if not Remotes.InteractWithItem then return nil end
    local char = LocalPlayer.Character
    local hrp = GetRoot(char)
    if not hrp then return nil end
    local buttonsFolder = Workspace:FindFirstChild("Prison_ITEMS") and Workspace.Prison_ITEMS:FindFirstChild("buttons")
    local cc = Workspace:FindFirstChild("CarContainer")
    if not buttonsFolder or not cc then return nil end

    local nearestBtn, bestDist = nil, math.huge
    for _, btnModel in ipairs(buttonsFolder:GetChildren()) do
        if btnModel.Name == "Car Spawner" then
            local part = btnModel:FindFirstChild("Car Spawner") or btnModel:FindFirstChildWhichIsA("BasePart")
            if part then
                local d = (part.Position - hrp.Position).Magnitude
                if d < bestDist then bestDist = d; nearestBtn = part end
            end
        end
    end
    if not nearestBtn then return nil end

    local before = {}
    for _, c in ipairs(cc:GetChildren()) do before[c] = true end

    local oldCF = hrp.CFrame
    if bestDist > 18 then
        SafeTeleport(nearestBtn.CFrame + Vector3.new(0, 3.2, 0))
        task.wait(0.18)
    end
    pcall(function() Remotes.InteractWithItem:InvokeServer(nearestBtn) end)
    if Remotes.GiverPressed then pcall(function() Remotes.GiverPressed:FireServer(nearestBtn) end) end

    local spawnedCar = nil
    local deadline = os.clock() + 3.0
    while os.clock() < deadline do
        for _, c in ipairs(cc:GetChildren()) do
            if not before[c] then spawnedCar = c; break end
        end
        if spawnedCar then break end
        task.wait(0.08)
    end

    SafeTeleport(oldCF)
    return spawnedCar
end

local function SaveCarsCommand(count)
    local targetNum = clamp(tonumber(count) or 1, 1, 5)
    task.spawn(function()
        PruneSavedCars()
        local cc = Workspace:FindFirstChild("CarContainer")
        local myHum = GetHumanoid(LocalPlayer.Character)
        -- First collect any existing unoccupied multi-seat cars already in CarContainer
        if cc then
            for _, m in ipairs(cc:GetChildren()) do
                if #SavedCars >= targetNum then break end
                local already = false
                for _, s in ipairs(SavedCars) do if s == m then already = true; break end end
                if not already then
                    local d, p = GetCarSeats(m, myHum)
                    if d and p then table.insert(SavedCars, m) end
                end
            end
        end
        -- Spawn more if needed
        local tries = 0
        while #SavedCars < targetNum and tries < targetNum do
            tries = tries + 1
            local spawned = SpawnSingleCarAndTrack()
            if spawned then
                table.insert(SavedCars, spawned)
            end
            task.wait(0.25)
        end
        PruneSavedCars()
        Notify("Saved Cars (SC)", "Saved " .. tostring(#SavedCars) .. " vehicle(s) ready for Bring / ForceCrim / Void!", 3)
    end)
end

local function AcquireUsableCar(myHum)
    PruneSavedCars()
    if myHum and myHum.SeatPart and myHum.SeatPart:IsA("VehicleSeat") then
        local m = myHum.SeatPart:FindFirstAncestorOfClass("Model")
        local d, p = GetCarSeats(m, myHum)
        if d and p then return m, d, p end
    end
    for _, m in ipairs(SavedCars) do
        local d, p = GetCarSeats(m, myHum)
        if d and p then return m, d, p end
    end
    local cc = Workspace:FindFirstChild("CarContainer")
    if cc then
        for _, m in ipairs(cc:GetChildren()) do
            local d, p = GetCarSeats(m, myHum)
            if d and p then
                table.insert(SavedCars, m)
                return m, d, p
            end
        end
    end
    local spawned = SpawnSingleCarAndTrack()
    if spawned then
        table.insert(SavedCars, spawned)
        local d, p = GetCarSeats(spawned, myHum)
        if d and p then return spawned, d, p end
    end
    return nil, nil, nil
end

-- Unified KX Vehicle Target Manipulation Engine (Supports: "bring", "forcecrim", "void", "fling")
local function ExecuteCarTargetAction(targetPlr, actionMode)
    if not targetPlr or targetPlr == LocalPlayer then
        Notify("KX Car Action", "Select a valid target player first!", 2.5)
        return
    end
    local myChar = LocalPlayer.Character
    local myHrp = GetRoot(myChar)
    local myHum = GetHumanoid(myChar)
    local tHrp = GetRoot(targetPlr.Character)
    local tHum = GetHumanoid(targetPlr.Character)
    if not myHrp or not myHum or not tHrp or not tHum or tHum.Health <= 0 then
        Notify("KX Car Action", "Target player is not alive!", 2.2)
        return
    end

    task.spawn(function()
        local returnCF = myHrp.CFrame
        local carModel, drvSeat, passSeat = AcquireUsableCar(myHum)
        if not carModel or not drvSeat or not passSeat then
            Notify("KX Car Action", "No vehicle available! Run .savecar first.", 3)
            return
        end

        if myHum.SeatPart ~= drvSeat then
            SafeTeleport(drvSeat.CFrame + Vector3.new(0, 2.2, 0))
            task.wait(0.1)
            pcall(function() drvSeat:Sit(myHum) end)
            task.wait(0.2)
        end
        if myHum.SeatPart ~= drvSeat then
            Notify("KX Car Action", "Could not enter driver seat!", 2.5)
            return
        end

        local deadline = os.clock() + 1.5
        local seated = false
        while os.clock() < deadline do
            local curTHrp = GetRoot(targetPlr.Character)
            if not curTHrp or tHum.Health <= 0 then break end
            if passSeat.Occupant == tHum or tHum.SeatPart == passSeat then
                seated = true
                break
            end
            local velLead = (curTHrp.AssemblyLinearVelocity or Vector3.zero) * 0.14
            local offset = passSeat.Position - carModel:GetPivot().Position
            pcall(function()
                carModel:PivotTo(CFrame.new((curTHrp.Position + velLead) - offset))
                drvSeat.AssemblyLinearVelocity = Vector3.zero
            end)
            RunService.Heartbeat:Wait()
        end

        if seated then
            if actionMode == "bring" then
                pcall(function() carModel:PivotTo(returnCF) end)
                task.wait(0.15)
                myHum.Sit = false
                Notify("KX Bring", "Brought " .. targetPlr.Name .. "!", 2.5)
            elseif actionMode == "forcecrim" then
                local crimSpawn = Workspace:FindFirstChild("Criminals Spawn")
                local sp = crimSpawn and (crimSpawn:FindFirstChild("SpawnLocation") or crimSpawn:FindFirstChildWhichIsA("BasePart", true))
                if sp then
                    pcall(function() carModel:PivotTo(sp.CFrame + Vector3.new(0, 3, 0)) end)
                    task.wait(0.32)
                end
                pcall(function() carModel:PivotTo(returnCF) end)
                Notify("KX ForceCrim", "Forced " .. targetPlr.Name .. " to Criminals!", 2.5)
            elseif actionMode == "void" or actionMode == "forcekick" then
                pcall(function() carModel:PivotTo(CFrame.new(returnCF.X, -420, returnCF.Z)) end)
                task.wait(0.28)
                myHum.Sit = false
                task.wait(0.06)
                SafeTeleport(returnCF)
                Notify("KX Void", "Dropped " .. targetPlr.Name .. " into the void!", 2.5)
            elseif actionMode == "fling" then
                pcall(function()
                    drvSeat.AssemblyLinearVelocity = Vector3.new(0, 650, 0)
                    drvSeat.AssemblyAngularVelocity = Vector3.new(120, 260, 120)
                end)
                task.wait(0.22)
                myHum.Sit = false
                task.wait(0.06)
                SafeTeleport(returnCF)
                Notify("KX Car Fling", "Flung " .. targetPlr.Name .. "!", 2.5)
            end
        else
            pcall(function() carModel:PivotTo(returnCF) end)
            Notify("KX Car Action", targetPlr.Name .. " moved out of seat range.", 2.2)
        end
    end)
end

local function SpawnAndEnterNearestCar()
    task.spawn(function()
        local myHum = GetHumanoid(LocalPlayer.Character)
        if not myHum then return end
        local spawned = SpawnSingleCarAndTrack()
        if spawned then
            table.insert(SavedCars, spawned)
            local seat = spawned:FindFirstChildWhichIsA("VehicleSeat", true)
            if seat then
                SafeTeleport(seat.CFrame + Vector3.new(0, 2, 0))
                task.wait(0.1)
                pcall(function() seat:Sit(myHum) end)
                Notify("Car Spawner", "Spawned & entered vehicle!", 2.5)
                return
            end
        end
        Notify("Car Spawner", "Requested vehicle spawn.", 2.2)
    end)
end

-- KX WheelAura Visual Customization on Driven Vehicle
local WheelAuraParts = setmetatable({}, { __mode = "k" })
local function UpdateVehicleWheelAura(seat)
    if not State.WheelAura or not seat then
        for inst, fx in pairs(WheelAuraParts) do
            pcall(function() fx:Destroy() end)
            WheelAuraParts[inst] = nil
        end
        return
    end
    local car = seat:FindFirstAncestorOfClass("Model")
    if not car then return end
    for _, desc in ipairs(car:GetDescendants()) do
        if desc:IsA("BasePart") and (desc.Name:lower():find("wheel") or desc.CollisionGroup == "Wheels") then
            if not WheelAuraParts[desc] then
                local pe = Instance.new("ParticleEmitter")
                pe.Name = "PL2026_WheelAura"
                pe.Color = ColorSequence.new(Color3.fromRGB(0, 235, 255), Color3.fromRGB(160, 75, 255))
                pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
                pe.Lifetime = NumberRange.new(0.25, 0.45)
                pe.Rate = 45
                pe.Speed = NumberRange.new(2, 6)
                pe.LightEmission = 1
                pe.Parent = desc
                WheelAuraParts[desc] = pe
            end
        end
    end
end

-- ============================================================================
-- // SECTION 7: TEAMS, RESPAWN, BYPASSES, ANTI-TASE/ARREST & AUTOHVH THREATS
-- ============================================================================
Env.PrisonLife2026Running = true

local Core = {
    PendingRespawnCF = nil,
    LastDeathCF = nil,
    RecentShooters = setmetatable({}, { __mode = "k" }),
    LastShooterPos = nil,
    LastShooterClock = 0,
    DisabledTaseConns = {},
    DisabledArrestConns = {},
    AntiJumpHooked = {},
}

function Core.ResolveTeamObject(teamQuery)
    local q = string.lower(Trim(tostring(teamQuery or "")))
    if q == "inmate" or q == "inmates" or q == "prisoner" or q == "prisoners" then
        return Teams:FindFirstChild("Inmates")
    elseif q == "guard" or q == "guards" or q == "cop" or q == "cops" or q == "police" then
        return Teams:FindFirstChild("Guards")
    elseif q == "crim" or q == "crims" or q == "criminal" or q == "criminals" then
        return Teams:FindFirstChild("Criminals")
    elseif q == "neutral" or q == "menu" then
        return Teams:FindFirstChild("Neutral")
    end
    for _, t in ipairs(Teams:GetTeams()) do
        if string.lower(t.Name) == q then
            return t
        end
    end
    return nil
end

function Core.SwitchToTeam(teamName, silent)
    local targetTeam = Core.ResolveTeamObject(teamName)
    if not targetTeam then
        if not silent then Notify("Team Switch", "Unknown team: " .. tostring(teamName), 2.5) end
        return false
    end

    task.spawn(function()
        local hrp = GetRoot(LocalPlayer.Character)
        local savedCF = (State.KeepPositionOnRespawn and hrp and not IsOnTeamsMenu()) and hrp.CFrame or nil
        if savedCF then Core.PendingRespawnCF = savedCF end

        if targetTeam.Name == "Criminals" then
            local curTeam = LocalPlayer.Team
            if curTeam and curTeam.Name ~= "Inmates" and Remotes.RequestTeamChange then
                local inm = Teams:FindFirstChild("Inmates")
                if inm then
                    pcall(function() Remotes.RequestTeamChange:InvokeServer(inm) end)
                    task.wait(0.35)
                end
            end
            local crimSpawn = Workspace:FindFirstChild("Criminals Spawn")
            local pad = crimSpawn and (crimSpawn:FindFirstChild("SpawnLocation") or crimSpawn:FindFirstChildWhichIsA("BasePart", true))
            if pad then
                local myHrp = GetRoot(LocalPlayer.Character)
                local fti = firetouchinterest
                if myHrp and fti then
                    pcall(function()
                        fti(myHrp, pad, 0)
                        task.wait(0.05)
                        fti(myHrp, pad, 1)
                    end)
                elseif myHrp then
                    SafeTeleport(pad.CFrame + Vector3.new(0, 3.0, 0))
                    task.wait(0.35)
                    if savedCF then SafeTeleport(savedCF) end
                end
            end
        elseif Remotes.RequestTeamChange then
            pcall(function() Remotes.RequestTeamChange:InvokeServer(targetTeam) end)
        end

        if not silent then
            Notify("Team Switch", "Requested team: " .. targetTeam.Name, 2.2)
        end
    end)
    return true
end

function Core.PerformFastRespawn(silent)
    if IsOnTeamsMenu() then
        if not silent then Notify("Respawn", "Select a team from the menu first.", 2.2) end
        return
    end
    task.spawn(function()
        local char = LocalPlayer.Character
        local hrp = GetRoot(char)
        local hum = GetHumanoid(char)
        if State.KeepPositionOnRespawn and hrp then
            Core.PendingRespawnCF = hrp.CFrame
        end
        local curTeam = LocalPlayer.Team
        if curTeam and curTeam.Name == "Criminals" then
            Core.SwitchToTeam("Criminals", true)
        elseif Remotes.RequestTeamChange and curTeam then
            pcall(function() Remotes.RequestTeamChange:InvokeServer(curTeam) end)
            task.wait(0.25)
            local curChar = LocalPlayer.Character
            local curHum = GetHumanoid(curChar)
            if curChar == char and curHum and curHum.Health > 0 then
                curHum:ChangeState(Enum.HumanoidStateType.Dead)
            end
        elseif hum then
            hum:ChangeState(Enum.HumanoidStateType.Dead)
        end
        if not silent then Notify("Fast Respawn", "Respawning character...", 1.8) end
    end)
end

function Core.BypassAntiJump()
    local hum = GetHumanoid(LocalPlayer.Character)
    if not hum then return end
    pcall(function()
        hum.UseJumpPower = true
        if State.JumpPowerEnabled then
            hum.JumpPower = State.JumpPower or 65
        end
    end)
    if State.AntiJumpCooldown then
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local ps = LocalPlayer:FindFirstChildOfClass("PlayerScripts")
        for _, root in ipairs({ LocalPlayer.Character, ps, pg }) do
            if root then
                for _, d in ipairs(root:GetDescendants()) do
                    if (d:IsA("LocalScript") or d:IsA("ModuleScript")) and d.Name == "AntiJump" and not Core.AntiJumpHooked[d] then
                        Core.AntiJumpHooked[d] = true
                        if d:IsA("LocalScript") then pcall(function() d.Disabled = true end) end
                    end
                end
            end
        end
    end
end

function Core.PurgeTaseAndRagdoll()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = GetHumanoid(char)
    pcall(function()
        if char:GetAttribute("Tased") then char:SetAttribute("Tased", false) end
        if char:GetAttribute("Downed") then char:SetAttribute("Downed", false) end
    end)
    if hum then
        pcall(function()
            hum.PlatformStand = false
            if hum:GetState() == Enum.HumanoidStateType.Physics or hum:GetState() == Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            if not State.MaxSpeed and hum.WalkSpeed < 16 then
                hum.WalkSpeed = 16
            end
        end)
    end
    if State.AlwaysBackpack or State.AntiTase then
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
        end)
    end
end

function Core.SyncRemoteConnectionBypasses()
    local gc = getconnections
    if not gc then return end
    if Remotes.PlayerTased and Remotes.PlayerTased:IsA("RemoteEvent") then
        local ok, conns = pcall(gc, Remotes.PlayerTased.OnClientEvent)
        if ok and type(conns) == "table" then
            for _, c in ipairs(conns) do
                if State.AntiTase and c.Function and not HookedFunctions[c.Function] then
                    if c.Enabled ~= false then
                        pcall(function() c:Disable() end)
                        table.insert(Core.DisabledTaseConns, c)
                    end
                end
            end
        end
    end
    if Remotes.ClientArrested and Remotes.ClientArrested:IsA("RemoteEvent") then
        local ok, conns = pcall(gc, Remotes.ClientArrested.OnClientEvent)
        if ok and type(conns) == "table" then
            for _, c in ipairs(conns) do
                if State.AntiArrest and c.Function and not HookedFunctions[c.Function] then
                    if c.Enabled ~= false then
                        pcall(function() c:Disable() end)
                        table.insert(Core.DisabledArrestConns, c)
                    end
                end
            end
        end
    end
end

if Remotes.PlayerTased and Remotes.PlayerTased:IsA("RemoteEvent") then
    local onTasedFn = function()
        if State.AntiTase then
            task.defer(Core.PurgeTaseAndRagdoll)
        end
    end
    HookedFunctions[onTasedFn] = true
    AddConnection(Remotes.PlayerTased.OnClientEvent:Connect(onTasedFn))
end

if Remotes.ClientArrested and Remotes.ClientArrested:IsA("RemoteEvent") then
    local onArrestedFn = function()
        if State.AutoCriminalOnArrest then
            task.delay(0.35, function()
                if Env.PrisonLife2026Running and LocalPlayer.Team ~= Teams:FindFirstChild("Criminals") then
                    Core.SwitchToTeam("Criminals", true)
                end
            end)
        end
    end
    HookedFunctions[onArrestedFn] = true
    AddConnection(Remotes.ClientArrested.OnClientEvent:Connect(onArrestedFn))
end

-- AutoHvH Threat Tracker & ShieldAutoFaceShooter Origin Recorder
if Remotes.ReplicateEvent and Remotes.ReplicateEvent:IsA("RemoteEvent") then
    local onReplicateThreatFn = function(...)
        if not Env.PrisonLife2026Running or IsOnTeamsMenu() then return end
        local myHrp = GetRoot(LocalPlayer.Character)
        if not myHrp then return end
        local realPos = (HoloShieldState.DesyncActive and HoloShieldState.SavedCF and HoloShieldState.SavedCF.Position) or myHrp.Position
        local pts = ExtractPointsFromReplicatePayload(...)
        if #pts < 2 then return end
        local origin, hitPos = pts[1], pts[2]
        local originDist = (origin - realPos).Magnitude
        if originDist <= 6 then return end

        local seg = hitPos - origin
        local len = seg.Magnitude
        if len <= 1 then return end
        local t = clamp((realPos - origin):Dot(seg) / (len * len), 0, 1)
        local closest = origin + (seg * t)
        if (closest - realPos).Magnitude <= 16 or (hitPos - realPos).Magnitude <= 16 then
            Core.LastShooterPos = origin
            Core.LastShooterClock = os.clock()
            local bestShooter, bestSD = nil, 14
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local r = GetRoot(plr.Character)
                    if r then
                        local d = (r.Position - origin).Magnitude
                        if d < bestSD then
                            bestSD = d
                            bestShooter = plr
                        end
                    end
                end
            end
            if bestShooter then
                Core.RecentShooters[bestShooter] = os.clock()
            end
        end
    end
    HookedFunctions[onReplicateThreatFn] = true
    AddConnection(Remotes.ReplicateEvent.OnClientEvent:Connect(onReplicateThreatFn))
end

-- ============================================================================
-- // SECTION 8: CLEAN FE INVISIBLE (NO CYAN HIGHLIGHT GLOW BUG)
-- ============================================================================
local Stealth = {
    Active = false,
    Track = nil,
    AnimObj = nil,
}

function Stealth.StopFEInvisible()
    Stealth.Active = false
    if Stealth.Track then
        pcall(function() Stealth.Track:Stop(0) end)
        pcall(function() Stealth.Track:Destroy() end)
        Stealth.Track = nil
    end
    if Stealth.AnimObj then
        pcall(function() Stealth.AnimObj:Destroy() end)
        Stealth.AnimObj = nil
    end
    local char = LocalPlayer.Character
    if char then
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("BasePart") or desc:IsA("Decal") then
                pcall(function() desc.LocalTransparencyModifier = 0 end)
            end
        end
    end
end

function Stealth.StartFEInvisible()
    Stealth.StopFEInvisible()
    if IsOnTeamsMenu() then return false end
    local char = LocalPlayer.Character
    local hum = GetHumanoid(char)
    if not char or not hum or hum.Health <= 0 then return false end

    local isR15 = (hum.RigType == Enum.HumanoidRigType.R15)
    local anim = Instance.new("Animation")
    anim.AnimationId = isR15 and "rbxassetid://18665825805" or "rbxassetid://215384594"
    local animator = hum:FindFirstChildOfClass("Animator") or hum
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then
        pcall(function() anim:Destroy() end)
        return false
    end

    track.Priority = Enum.AnimationPriority.Action4
    track:Play(0, 1, 0)
    track:AdjustWeight(1, 0)
    track.TimePosition = isR15 and 1.95 or 0.4

    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") or desc:IsA("Decal") then
            pcall(function() desc.LocalTransparencyModifier = 0.55 end)
        end
    end

    Stealth.AnimObj = anim
    Stealth.Track = track
    Stealth.Active = true
    return true
end

function Stealth.SetFEInvisibleState(enabled, silent)
    State.FEInvisible = (enabled == true)
    if State.FEInvisible then
        local ok = Stealth.StartFEInvisible()
        if not silent then
            Notify("FE Invisible", ok and "FE Ghost Active (clean translucent view)." or "Spawn first to activate FE Invisible.", 2.2)
        end
    else
        Stealth.StopFEInvisible()
        if not silent then Notify("FE Invisible", "Restored visibility.", 1.8) end
    end
end

-- ============================================================================
-- // SECTION 9: CLEAN TOP-LEFT .COMBO1 PILL & CONTEXTUAL FLY ARROWS ONLY
-- ============================================================================
-- Per user review: ZERO messy right-side button dock. Only .combo1 + Cmd Pill (Sec 13)
-- and minimal ▲ / ▼ thumb controls when Fly or VehicleFly is active on Mobile.
local HUDControls = {
    FlyAscendHeld = false,
    FlyDescendHeld = false,
}

do
    local comboBtn = Instance.new("TextButton")
    comboBtn.Name = "Combo1TopLeftPill"
    comboBtn.Position = UDim2.new(0, 14, 0, 56)
    comboBtn.Size = UDim2.fromOffset(92, 26)
    comboBtn.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
    comboBtn.BackgroundTransparency = 0.18
    comboBtn.BorderSizePixel = 0
    comboBtn.Font = Enum.Font.GothamBold
    comboBtn.TextSize = 11
    comboBtn.TextColor3 = Color3.fromRGB(95, 225, 255)
    comboBtn.Text = "⚡ .combo1"
    comboBtn.AutoButtonColor = true
    comboBtn.Visible = false
    comboBtn.Parent = OverlayGui
    Instance.new("UICorner", comboBtn).CornerRadius = UDim.new(1, 0)
    local cStroke = Instance.new("UIStroke", comboBtn)
    cStroke.Color = Color3.fromRGB(0, 195, 255)
    cStroke.Thickness = 1.1
    cStroke.Transparency = 0.25
    MakeDraggable(comboBtn)

    comboBtn.Activated:Connect(function()
        cStroke.Color = Color3.fromRGB(255, 190, 60)
        task.spawn(function()
            ExecuteCombo1()
            task.wait(0.15)
            cStroke.Color = Color3.fromRGB(0, 195, 255)
        end)
    end)
    HUDControls.ComboBtn = comboBtn

    local function makeFlyThumb(name, labelText, posOffset)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Position = posOffset
        btn.Size = UDim2.fromOffset(42, 34)
        btn.BackgroundColor3 = Color3.fromRGB(14, 20, 32)
        btn.BackgroundTransparency = 0.2
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 15
        btn.TextColor3 = Color3.fromRGB(120, 230, 255)
        btn.Text = labelText
        btn.Visible = false
        btn.Parent = OverlayGui
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
        local st = Instance.new("UIStroke", btn)
        st.Color = Color3.fromRGB(0, 185, 245)
        st.Thickness = 1
        st.Transparency = 0.3
        return btn
    end

    local upBtn = makeFlyThumb("FlyUpThumb", "▲", UDim2.new(1, -138, 1, -136))
    local dnBtn = makeFlyThumb("FlyDownThumb", "▼", UDim2.new(1, -88, 1, -136))

    upBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            HUDControls.FlyAscendHeld = true
        end
    end)
    upBtn.InputEnded:Connect(function() HUDControls.FlyAscendHeld = false end)

    dnBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            HUDControls.FlyDescendHeld = true
        end
    end)
    dnBtn.InputEnded:Connect(function() HUDControls.FlyDescendHeld = false end)

    HUDControls.FlyUpBtn = upBtn
    HUDControls.FlyDownBtn = dnBtn
end

function HUDControls.UpdateVisibility(onMenu, alive)
    if HUDControls.ComboBtn then
        HUDControls.ComboBtn.Visible = State.ShowComboButton and not onMenu
    end
    local showFly = IsMobile and (State.Fly or State.VehicleFly) and not onMenu and alive
    if HUDControls.FlyUpBtn then HUDControls.FlyUpBtn.Visible = showFly end
    if HUDControls.FlyDownBtn then HUDControls.FlyDownBtn.Visible = showFly end
    if not showFly then
        HUDControls.FlyAscendHeld = false
        HUDControls.FlyDescendHeld = false
    end
end

-- ============================================================================
-- // SECTION 10: CLEAN ROLE-COLORED ESP, MINI-KILLFEED & ANOMALY TRACKER
-- ============================================================================
local Visuals = {
    ESPFolder = nil,
    PlayerEntries = {},
    C4Entries = {},
    KillfeedHooked = {},
    AnomalyState = {},
    LastRecentDamage = setmetatable({}, { __mode = "k" }),
}

do
    local f = TrackInstance(Instance.new("Folder"))
    f.Name = "PL2026_ESP"
    f.Parent = OverlayGui
    Visuals.ESPFolder = f
end

function Visuals.GetPlayerESPColor(plr, char)
    local tName = plr.Team and plr.Team.Name or "Neutral"
    if tName == "Guards" then
        return Color3.fromRGB(70, 150, 255), "Guard"
    elseif tName == "Criminals" then
        return Color3.fromRGB(255, 70, 75), "Crim"
    elseif tName == "Inmates" then
        if char and char:GetAttribute("Hostile") then
            return Color3.fromRGB(255, 95, 40), "Hostile"
        elseif char and char:GetAttribute("Trespassing") then
            return Color3.fromRGB(255, 210, 55), "Tresp"
        end
        return Color3.fromRGB(255, 165, 65), "Inmate"
    end
    return Color3.fromRGB(180, 185, 195), "Neutral"
end

function Visuals.RemovePlayerESP(plr)
    local ent = Visuals.PlayerEntries[plr]
    if not ent then return end
    if ent.Highlight then pcall(function() ent.Highlight:Destroy() end) end
    if ent.Billboard then pcall(function() ent.Billboard:Destroy() end) end
    Visuals.PlayerEntries[plr] = nil
end

function Visuals.ClearAllESP()
    for plr in pairs(Visuals.PlayerEntries) do
        Visuals.RemovePlayerESP(plr)
    end
    for inst, bb in pairs(Visuals.C4Entries) do
        pcall(function() bb:Destroy() end)
        Visuals.C4Entries[inst] = nil
    end
end

function Visuals.UpdateESP()
    if not State.ESP and not State.C4ESP then
        Visuals.ClearAllESP()
        return
    end

    local myChar = LocalPlayer.Character
    local myRoot = GetRoot(myChar)
    local originPos = myRoot and myRoot.Position or Camera.CFrame.Position

    if State.ESP then
        local sorted = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and not (State.ESPHideTeam and plr.Team == LocalPlayer.Team) then
                local ch = plr.Character
                local hrp = GetRoot(ch)
                local hum = GetHumanoid(ch)
                if hrp and hum and hum.Health > 0 then
                    table.insert(sorted, {
                        plr = plr,
                        char = ch,
                        hrp = hrp,
                        hum = hum,
                        dist = (hrp.Position - originPos).Magnitude,
                    })
                else
                    Visuals.RemovePlayerESP(plr)
                end
            else
                Visuals.RemovePlayerESP(plr)
            end
        end
        table.sort(sorted, function(a, b) return a.dist < b.dist end)

        local seen = {}
        for idx, item in ipairs(sorted) do
            if idx > 30 then break end -- Safe Roblox 31-Highlight cap
            local plr, char, hum, dist = item.plr, item.char, item.hum, item.dist
            seen[plr] = true
            local color, roleTag = Visuals.GetPlayerESPColor(plr, char)

            local ent = Visuals.PlayerEntries[plr]
            if not ent then
                ent = {}
                Visuals.PlayerEntries[plr] = ent
            end

            if State.ESPHighlight then
                if not ent.Highlight or ent.Highlight.Adornee ~= char or not ent.Highlight.Parent then
                    if ent.Highlight then pcall(function() ent.Highlight:Destroy() end) end
                    local hl = Instance.new("Highlight")
                    hl.Name = "PL_HL_" .. plr.Name
                    hl.FillTransparency = 0.72
                    hl.OutlineTransparency = 0.12
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Adornee = char
                    hl.Parent = Visuals.ESPFolder
                    ent.Highlight = hl
                end
                ent.Highlight.FillColor = color
                ent.Highlight.OutlineColor = color
            elseif ent.Highlight then
                pcall(function() ent.Highlight:Destroy() end)
                ent.Highlight = nil
            end

            local showTag = State.ESPNameTag or State.ESPHealth or State.ESPDistance or State.ESPWeapon or State.ESPStatusFlags
            local head = char:FindFirstChild("Head") or item.hrp
            if showTag and head then
                if not ent.Billboard or ent.Billboard.Adornee ~= head or not ent.Billboard.Parent then
                    if ent.Billboard then pcall(function() ent.Billboard:Destroy() end) end
                    local bb = Instance.new("BillboardGui")
                    bb.Name = "PL_TAG_" .. plr.Name
                    bb.Size = UDim2.fromOffset(170, 38)
                    bb.StudsOffset = Vector3.new(0, 2.7, 0)
                    bb.AlwaysOnTop = true
                    bb.Adornee = head
                    bb.Parent = Visuals.ESPFolder

                    local top = Instance.new("TextLabel")
                    top.Name = "Top"
                    top.Size = UDim2.new(1, 0, 0.52, 0)
                    top.BackgroundTransparency = 1
                    top.Font = Enum.Font.GothamBold
                    top.TextSize = 11
                    top.TextStrokeTransparency = 0.15
                    top.Parent = bb

                    local sub = Instance.new("TextLabel")
                    sub.Name = "Sub"
                    sub.Position = UDim2.fromScale(0, 0.5)
                    sub.Size = UDim2.new(1, 0, 0.5, 0)
                    sub.BackgroundTransparency = 1
                    sub.Font = Enum.Font.Gotham
                    sub.TextSize = 10
                    sub.TextStrokeTransparency = 0.15
                    sub.TextColor3 = Color3.fromRGB(235, 240, 250)
                    sub.Parent = bb

                    ent.Billboard = bb
                    ent.TopLbl = top
                    ent.SubLbl = sub
                end

                local topParts = {}
                if State.ESPNameTag then
                    table.insert(topParts, string.format("%s [%s]", plr.DisplayName ~= "" and plr.DisplayName or plr.Name, roleTag))
                end
                if State.ESPStatusFlags then
                    local flags = {}
                    if char:GetAttribute("Tased") then table.insert(flags, "TASED") end
                    if char:GetAttribute("Arrested") then table.insert(flags, "CUFFED") end
                    if HasTargetArmor(char) then table.insert(flags, "ARMOR") end
                    if #flags > 0 then
                        table.insert(topParts, "[" .. table.concat(flags, ",") .. "]")
                    end
                end
                ent.TopLbl.Text = table.concat(topParts, " ")
                ent.TopLbl.TextColor3 = color

                local subParts = {}
                if State.ESPHealth then
                    table.insert(subParts, string.format("%d/%d HP", math.floor(hum.Health), math.floor(hum.MaxHealth)))
                end
                if State.ESPDistance then
                    table.insert(subParts, string.format("%dm", math.floor(dist)))
                end
                if State.ESPWeapon then
                    local eq = char:FindFirstChildOfClass("Tool")
                    if eq then table.insert(subParts, eq.Name) end
                end
                ent.SubLbl.Text = table.concat(subParts, " | ")
            elseif ent.Billboard then
                pcall(function() ent.Billboard:Destroy() end)
                ent.Billboard = nil
            end
        end

        for plr in pairs(Visuals.PlayerEntries) do
            if not seen[plr] then
                Visuals.RemovePlayerESP(plr)
            end
        end
    else
        for plr in pairs(Visuals.PlayerEntries) do
            Visuals.RemovePlayerESP(plr)
        end
    end

    -- C4 ESP
    if State.C4ESP then
        local activeC4 = {}
        local folders = { Workspace:FindFirstChild("Prison_ITEMS"), Workspace:FindFirstChild("C4"), Workspace }
        for _, root in ipairs(folders) do
            if root then
                for _, d in ipairs(root:GetChildren()) do
                    if (d.Name == "C4" or d.Name == "Explosive" or d:GetAttribute("PlantedC4")) and (d:IsA("BasePart") or d:IsA("Model")) then
                        local p = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart", true)
                        if p then activeC4[p] = true end
                    end
                end
            end
        end
        for part in pairs(activeC4) do
            if not Visuals.C4Entries[part] then
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.fromOffset(90, 24)
                bb.AlwaysOnTop = true
                bb.Adornee = part
                bb.Parent = Visuals.ESPFolder
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.fromScale(1, 1)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamBold
                lbl.TextSize = 11
                lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
                lbl.TextStrokeTransparency = 0.1
                lbl.Text = "💣 C4"
                lbl.Parent = bb
                Visuals.C4Entries[part] = bb
            end
            local d = math.floor((part.Position - originPos).Magnitude)
            local lbl = Visuals.C4Entries[part]:FindFirstChildOfClass("TextLabel")
            if lbl then lbl.Text = string.format("💣 C4 [%dm]", d) end
        end
        for part, bb in pairs(Visuals.C4Entries) do
            if not activeC4[part] or not part.Parent then
                pcall(function() bb:Destroy() end)
                Visuals.C4Entries[part] = nil
            end
        end
    else
        for part, bb in pairs(Visuals.C4Entries) do
            pcall(function() bb:Destroy() end)
            Visuals.C4Entries[part] = nil
        end
    end
end

function Visuals.AttachKillfeedToCharacter(plr, char)
    if not plr or not char or Visuals.KillfeedHooked[char] then return end
    Visuals.KillfeedHooked[char] = true
    local hum = char:WaitForChild("Humanoid", 4)
    if not hum then return end
    AddConnection(hum.Died:Connect(function()
        if not Env.PrisonLife2026Running then return end
        local creatorTag = hum:FindFirstChild("creator")
        local killer = (creatorTag and creatorTag:IsA("ObjectValue") and creatorTag.Value) or nil
        if killer == LocalPlayer then
            TriggerHitmarkerVFX(false, true)
            PushMiniKillfeedLine("☠ Eliminated " .. plr.Name, Color3.fromRGB(100, 255, 160))
        elseif killer and killer:IsA("Player") then
            PushMiniKillfeedLine("☠ " .. killer.Name .. " → " .. plr.Name, Color3.fromRGB(255, 160, 140))
        elseif plr ~= LocalPlayer then
            PushMiniKillfeedLine("☠ " .. plr.Name .. " died", Color3.fromRGB(210, 215, 225))
        end
    end))
end

for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then Visuals.AttachKillfeedToCharacter(p, p.Character) end
    AddConnection(p.CharacterAdded:Connect(function(ch) Visuals.AttachKillfeedToCharacter(p, ch) end))
end
AddConnection(Players.PlayerAdded:Connect(function(p)
    AddConnection(p.CharacterAdded:Connect(function(ch) Visuals.AttachKillfeedToCharacter(p, ch) end))
end))

function Visuals.EvaluateAnomalies(now)
    if not State.CheaterAlerts and not State.CarTPAlerts then return end
    local myRoot = GetRoot(LocalPlayer.Character)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local hrp = GetRoot(char)
            local hum = GetHumanoid(char)
            if hrp and hum and hum.Health > 0 then
                local st = Visuals.AnomalyState[plr]
                if not st then
                    Visuals.AnomalyState[plr] = {
                        lastPos = hrp.Position,
                        lastTime = now,
                        lastAlert = 0,
                        spawnTime = now,
                    }
                else
                    local dt = now - st.lastTime
                    if dt >= 0.2 then
                        local delta = (hrp.Position - st.lastPos).Magnitude
                        local horizVel = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
                        local nearMe = (not myRoot) or ((hrp.Position - myRoot.Position).Magnitude <= 350)
                        if (now - st.spawnTime) > 2.0 and (now - st.lastAlert) > 8.5 and nearMe then
                            if hum.Sit and State.CarTPAlerts and delta > 95 and dt < 0.6 then
                                st.lastAlert = now
                                PushMiniKillfeedLine("🚗 Car-TP: " .. plr.Name, Color3.fromRGB(255, 130, 80))
                            elseif (not hum.Sit) and State.CheaterAlerts and ((delta > 85 and dt < 0.6) or horizVel > 78) then
                                st.lastAlert = now
                                PushMiniKillfeedLine(string.format("⚠️ Anomaly: %s (%d sps)", plr.Name, math.floor(math.max(horizVel, delta / dt))), Color3.fromRGB(255, 200, 75))
                            end
                        end
                        st.lastPos = hrp.Position
                        st.lastTime = now
                    end
                end
            else
                Visuals.AnomalyState[plr] = nil
            end
        end
    end
end

-- ============================================================================
-- // SECTION 11: REGIONSAFE WALKSPEED, RENDERSTEPPED, HEARTBEAT & UTILITY LOOPS
-- ============================================================================
local Runtime = {
    IndoorSubRegions = {
        { name = "CellblockMain",   min = Vector3.new(865, 92, 2360),  max = Vector3.new(958, 128, 2498) },
        { name = "CellblockNorth",  min = Vector3.new(865, 92, 2318),  max = Vector3.new(958, 128, 2360) },
        { name = "Cafeteria",       min = Vector3.new(872, 92, 2232),  max = Vector3.new(962, 122, 2318) },
        { name = "Kitchen",         min = Vector3.new(902, 92, 2200),  max = Vector3.new(965, 122, 2240) },
        { name = "Armory",          min = Vector3.new(804, 92, 2218),  max = Vector3.new(862, 120, 2272) },
        { name = "GuardStation",    min = Vector3.new(804, 92, 2272),  max = Vector3.new(868, 122, 2328) },
        { name = "SecurityHall",    min = Vector3.new(835, 92, 2328),  max = Vector3.new(868, 122, 2380) },
        { name = "EntranceHall",    min = Vector3.new(780, 92, 2330),  max = Vector3.new(835, 122, 2405) },
        { name = "Visitation",      min = Vector3.new(780, 92, 2405),  max = Vector3.new(850, 122, 2465) },
        { name = "Infirmary",       min = Vector3.new(780, 92, 2270),  max = Vector3.new(806, 120, 2330) },
        { name = "GarageBay",       min = Vector3.new(612, 92, 2258),  max = Vector3.new(675, 125, 2338) },
        { name = "Gatehouse",       min = Vector3.new(492, 92, 2230),  max = Vector3.new(540, 126, 2285) },
        { name = "TowerNW",         min = Vector3.new(742, 94, 2205),  max = Vector3.new(780, 145, 2245) },
        { name = "TowerNE",         min = Vector3.new(978, 94, 2205),  max = Vector3.new(1020, 145, 2245) },
        { name = "TowerSW",         min = Vector3.new(742, 94, 2555),  max = Vector3.new(780, 145, 2595) },
        { name = "TowerSE",         min = Vector3.new(978, 94, 2555),  max = Vector3.new(1020, 145, 2595) },
        { name = "RoofStairwell",   min = Vector3.new(865, 114, 2345), max = Vector3.new(902, 142, 2385) },
        { name = "YardShed",        min = Vector3.new(765, 92, 2465),  max = Vector3.new(805, 118, 2505) },
        { name = "CriminalBaseInt", min = Vector3.new(-980, 88, 2005), max = Vector3.new(-890, 122, 2085) },
        { name = "SecretRoom",      min = Vector3.new(695, 92, 2335),  max = Vector3.new(745, 118, 2380) },
    },
    PrisonOuterBox = { min = Vector3.new(600, 60, 2170), max = Vector3.new(1070, 165, 2635) },
    PeekPauseUntil = 0,
    ArrestCooldownUntil = 0,
    LastArrestAttempt = 0,
    LastKillAuraClock = 0,
    LastTaseClock = 0,
    LastRageClock = 0,
    LastComboClock = 0,
    LastLoopKillClock = 0,
    LastArmorClock = 0,
    LastHealClock = 0,
    LastPickupClock = 0,
    LastTriggerClock = 0,
    LastBypassSync = 0,
    FlyBodyVel = nil,
    FlyBodyGyro = nil,
    ModifiedDoors = {},
    ModifiedFences = {},
    ModifiedHitboxes = {},
    NoclipParts = {},
    UpdateCommandPillVisibility = nil,
}

function Runtime.IsPointInBox(pos, box)
    return pos.X >= box.min.X and pos.X <= box.max.X
        and pos.Y >= box.min.Y and pos.Y <= box.max.Y
        and pos.Z >= box.min.Z and pos.Z <= box.max.Z
end

function Runtime.GetSafeRegionWalkSpeed(pos)
    local mode = State.MaxSpeedMode or "RegionSafe"
    if mode == "AlwaysSprint" then
        return 25
    elseif mode == "Custom" then
        local custom = tonumber(State.CustomWalkSpeed) or 40
        return State.AntiBanSafeMode and clamp(custom, 16, 46) or custom
    end
    -- RegionSafe
    for _, box in ipairs(Runtime.IndoorSubRegions) do
        if Runtime.IsPointInBox(pos, box) then
            return 20
        end
    end
    if Runtime.IsPointInBox(pos, Runtime.PrisonOuterBox) then
        return 26
    end
    return 35
end

function Runtime.DestroyFlyMovers()
    if Runtime.FlyBodyVel then pcall(function() Runtime.FlyBodyVel:Destroy() end); Runtime.FlyBodyVel = nil end
    if Runtime.FlyBodyGyro then pcall(function() Runtime.FlyBodyGyro:Destroy() end); Runtime.FlyBodyGyro = nil end
end

function Runtime.RestoreNoclip()
    for part in pairs(Runtime.NoclipParts) do
        if part and part.Parent then pcall(function() part.CanCollide = true end) end
    end
    Runtime.NoclipParts = {}
end

function Runtime.RestoreDoors()
    for part, orig in pairs(Runtime.ModifiedDoors) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = orig.CanCollide
                part.Transparency = orig.Transparency
            end)
        end
    end
    Runtime.ModifiedDoors = {}
end

function Runtime.RestoreHitboxes()
    for hrp, orig in pairs(Runtime.ModifiedHitboxes) do
        if hrp and hrp.Parent then
            pcall(function()
                hrp.Size = orig.Size
                hrp.Transparency = orig.Transparency
                hrp.Material = orig.Material
                hrp.CanCollide = orig.CanCollide
            end)
        end
    end
    Runtime.ModifiedHitboxes = {}
end

function Runtime.RestoreFences()
    for part, origCanTouch in pairs(Runtime.ModifiedFences) do
        if part and part.Parent then
            pcall(function() part.CanTouch = origCanTouch end)
        end
    end
    Runtime.ModifiedFences = {}
end

function Runtime.OnCharacterAdded(char)
    task.defer(function()
        if not Env.PrisonLife2026Running then return end
        Stealth.StopFEInvisible()
        HoloShieldState.DesyncActive = false
        HoloShieldState.SavedCF = nil
        Runtime.DestroyFlyMovers()

        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hrp or not hum then return end

        local restoreCF = Core.PendingRespawnCF or (State.KeepPositionOnRespawn and Core.LastDeathCF) or nil
        Core.PendingRespawnCF = nil
        Core.LastDeathCF = nil
        if restoreCF and not IsOnTeamsMenu() then
            task.wait(0.08)
            SafeTeleport(restoreCF)
        end

        AddConnection(hum.Died:Connect(function()
            if State.KeepPositionOnRespawn and hrp and hrp.Parent and not IsOnTeamsMenu() then
                Core.LastDeathCF = hrp.CFrame
            end
            DestroyHoloShield()
            Stealth.StopFEInvisible()
            Runtime.DestroyFlyMovers()
            if State.FastRespawn and not IsOnTeamsMenu() then
                task.delay(0.18, function()
                    if Env.PrisonLife2026Running and State.FastRespawn then
                        Core.PerformFastRespawn(true)
                    end
                end)
            end
        end))

        Core.BypassAntiJump()
        if State.HoloShield and not IsOnTeamsMenu() then
            CreateHoloShield()
        end
        if State.AutoGetGuns and not IsOnTeamsMenu() then
            task.delay(0.35, function()
                if Env.PrisonLife2026Running and State.AutoGetGuns and not IsOnTeamsMenu() then
                    GrabWeapons(State.AutoGetGunsSelection, true)
                end
            end)
        end
        if State.FEInvisible and not IsOnTeamsMenu() then
            task.delay(0.45, function()
                if Env.PrisonLife2026Running and State.FEInvisible and not IsOnTeamsMenu() then
                    Stealth.StartFEInvisible()
                end
            end)
        end
    end)
end

if LocalPlayer.Character then
    Runtime.OnCharacterAdded(LocalPlayer.Character)
end
AddConnection(LocalPlayer.CharacterAdded:Connect(Runtime.OnCharacterAdded))

-- // RENDERSTEPPED: Restore FE Desync BEFORE Render, Visuals, HoloShield, AimAssist & Triggerbot
AddConnection(RunService.RenderStepped:Connect(function(dt)
    if not Env.PrisonLife2026Running then return end
    Camera = Workspace.CurrentCamera
    local char = LocalPlayer.Character
    local hrp = GetRoot(char)
    local hum = GetHumanoid(char)
    local onMenu = IsOnTeamsMenu()
    local alive = (char ~= nil and hrp ~= nil and hum ~= nil and hum.Health > 0)

    -- 1. CRITICAL: Restore real CFrame before frame renders so camera & movement never stutter
    if HoloShieldState.DesyncActive and HoloShieldState.SavedCF and hrp then
        hrp.CFrame = HoloShieldState.SavedCF
        HoloShieldState.DesyncActive = false
    end

    -- 2. HUD & Bar Visibility (Always hidden on Teams menu or death!)
    HUDControls.UpdateVisibility(onMenu, alive)
    if Runtime.UpdateCommandPillVisibility then
        Runtime.UpdateCommandPillVisibility(onMenu)
    end

    local aimCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    if not IsMobile and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        local mPos = UserInputService:GetMouseLocation()
        aimCenter = Vector2.new(mPos.X, mPos.Y)
    end

    SilentFOVFrame.Visible = (State.SilentAim and State.SilentAimShowFOV and not onMenu and alive)
    if SilentFOVFrame.Visible then
        local d = (tonumber(State.SilentAimFOV) or 180) * 2
        SilentFOVFrame.Size = UDim2.fromOffset(d, d)
        SilentFOVFrame.Position = UDim2.fromOffset(aimCenter.X, aimCenter.Y)
    end

    AimAssistFOVFrame.Visible = (State.AimAssist and State.AimAssistShowFOV and not onMenu and alive)
    if AimAssistFOVFrame.Visible then
        local d = (tonumber(State.AimAssistFOV) or 140) * 2
        AimAssistFOVFrame.Size = UDim2.fromOffset(d, d)
        AimAssistFOVFrame.Position = UDim2.fromOffset(aimCenter.X, aimCenter.Y)
    end

    local showShieldUI = (State.HoloShield and not onMenu and alive)
    ShieldBarHolder.Visible = showShieldUI
    if showShieldUI then
        local now = os.clock()
        if not HoloShieldState.CorePart or not HoloShieldState.CorePart.Parent then
            CreateHoloShield()
        end
        if now >= HoloShieldState.BrokenUntil then
            if (now - HoloShieldState.LastHit) > 3.5 and HoloShieldState.HP < HoloShieldState.MaxHP then
                HoloShieldState.HP = math.min(HoloShieldState.MaxHP, HoloShieldState.HP + 26 * dt)
            end
            if HoloShieldState.CorePart then
                HoloShieldState.CorePart.Transparency = State.ShieldShowVisual and clamp(tonumber(State.ShieldTransparency) or 0.84, 0.55, 0.96) or 1
                HoloShieldState.CorePart.CanQuery = true
            end
            local ratio = clamp(HoloShieldState.HP / math.max(1, HoloShieldState.MaxHP), 0, 1)
            ShieldBarFill.Size = UDim2.fromScale(ratio, 1)
            ShieldBarFill.BackgroundColor3 = Color3.fromRGB(0, 190, 240)
            ShieldBarText.Text = string.format("🛡️ SHIELD: %d/%d [%s]", math.floor(HoloShieldState.HP), math.floor(HoloShieldState.MaxHP), State.ShieldMode)
        else
            local rem = math.max(0, HoloShieldState.BrokenUntil - now)
            ShieldBarFill.Size = UDim2.fromScale(clamp(1 - (rem / 3.8), 0, 1), 1)
            ShieldBarFill.BackgroundColor3 = Color3.fromRGB(255, 95, 95)
            ShieldBarText.Text = string.format("⚡ RECHARGING %.1fs", rem)
        end

        if HoloShieldState.CorePart then
            local baseCF = HoloShieldState.SavedCF or hrp.CFrame
            local rotCF
            if State.ShieldAutoFaceShooter and Core.LastShooterPos and (now - Core.LastShooterClock) < 2.5 then
                local flat = Vector3.new(Core.LastShooterPos.X, baseCF.Y, Core.LastShooterPos.Z)
                rotCF = CFrame.lookAt(baseCF.Position, flat)
            elseif State.ShieldSpinBlock then
                local spin = (now * (tonumber(State.ShieldSpinSpeed) or 18)) % (math.pi * 2)
                rotCF = CFrame.new(baseCF.Position) * CFrame.Angles(0, spin, 0)
            else
                local camLook = Camera.CFrame.LookVector
                local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
                if flatLook.Magnitude < 0.01 then flatLook = baseCF.LookVector end
                rotCF = CFrame.lookAt(baseCF.Position, baseCF.Position + flatLook.Unit)
            end
            HoloShieldState.CorePart.CFrame = rotCF * CFrame.new(0, 0.4, -2.55)
        end
    elseif HoloShieldState.Model then
        DestroyHoloShield()
    end

    local isGuard = (LocalPlayer.Team == Teams:FindFirstChild("Guards"))
    ArrestBarHolder.Visible = (State.AutoArrest and State.AutoArrestCooldownBar and isGuard and not onMenu and alive)
    if ArrestBarHolder.Visible then
        local rem = math.max(0, Runtime.ArrestCooldownUntil - os.clock())
        if rem > 0 then
            ArrestBarFill.Size = UDim2.fromScale(clamp(1 - (rem / 7.0), 0, 1), 1)
            ArrestBarFill.BackgroundColor3 = Color3.fromRGB(245, 165, 65)
            ArrestBarText.Text = string.format("🚓 ARREST CD: %.1fs", rem)
        else
            ArrestBarFill.Size = UDim2.fromScale(1, 1)
            ArrestBarFill.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
            ArrestBarText.Text = "🚓 AUTO-ARREST READY"
        end
    end

    if not alive or onMenu then return end

    -- 3. Smooth Camera Aim Assist
    if State.AimAssist then
        local holdingAim = IsMobile or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if holdingAim and IsHoldingFirearm() then
            local part, plr = GetBestCombatTarget({
                use360 = false,
                fov = State.AimAssistFOV or 140,
                wallcheck = true,
                wallbang = false,
                requireHostile = State.SilentAimHostileCheck,
                forceHead = (State.AimAssistAimPart == "Head"),
            })
            if part and plr then
                local aimPos = part.Position
                if State.AimAssistPrediction then
                    aimPos = aimPos + ((part.AssemblyLinearVelocity or Vector3.zero) * (State.AimAssistPredictionStrength or 0.065))
                end
                local targetCF = CFrame.lookAt(Camera.CFrame.Position, aimPos)
                local alpha = clamp(1 - (tonumber(State.AimAssistSmoothness) or 0.22), 0.04, 0.92)
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha)
            end
        end
    end

    -- 4. Triggerbot
    if State.Triggerbot and (os.clock() - Runtime.LastTriggerClock) >= (State.TriggerbotDelay or 0.08) then
        local firearm = IsHoldingFirearm()
        if firearm then
            local ray = Camera:ViewportPointToRay(aimCenter.X, aimCenter.Y)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { char, HoloShieldState.Model }
            local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
            if hit and hit.Instance then
                local m = hit.Instance:FindFirstAncestorOfClass("Model")
                local plr = m and Players:GetPlayerFromCharacter(m)
                if plr and IsValidCombatTarget(plr, State.SilentAimHostileCheck, State.KillAuraWhitelist, false) then
                    Runtime.LastTriggerClock = os.clock()
                    FireToolAtTarget(firearm, hit.Instance, false, false, false)
                end
            end
        end
    end
end))

-- // HEARTBEAT: Fly, Vehicle Fly, Speed, 5-Mode FE Shield Desync, AutoHvH/Ragebot, KillAura, AutoTaze, AutoArrest
AddConnection(RunService.Heartbeat:Connect(function()
    if not Env.PrisonLife2026Running then return end
    local char = LocalPlayer.Character
    local hrp = GetRoot(char)
    local hum = GetHumanoid(char)
    local onMenu = IsOnTeamsMenu()
    local alive = (char ~= nil and hrp ~= nil and hum ~= nil and hum.Health > 0)
    local now = os.clock()

    if not alive or onMenu then
        HoloShieldState.DesyncActive = false
        Runtime.DestroyFlyMovers()
        return
    end

    -- 1. Vehicle Mechanics (VehicleFly, VehicleSpeedMod, WheelAura)
    local seat = hum.SeatPart
    if seat and seat:IsA("VehicleSeat") then
        Runtime.DestroyFlyMovers()
        UpdateVehicleWheelAura(seat)
        if State.VehicleFly then
            local spd = tonumber(State.VehicleFlySpeed) or 80
            if State.AntiBanSafeMode then spd = math.min(spd, 95) end
            local camCF = Camera.CFrame
            local md = hum.MoveDirection
            local flatMove = Vector3.zero
            if md.Magnitude > 0.05 then
                local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
                local fwd = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
                local dir2 = Vector3.zero
                if fwd.Magnitude > 0.01 then dir2 = dir2 + (camCF.LookVector * md:Dot(fwd.Unit)) end
                if right.Magnitude > 0.01 then dir2 = dir2 + (camCF.RightVector * md:Dot(right.Unit)) end
                flatMove = dir2.Magnitude > 0.01 and dir2.Unit or md
            end
            local vert = 0
            if HUDControls.FlyAscendHeld or UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
                vert = vert + 1
            end
            if HUDControls.FlyDescendHeld or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                vert = vert - 1
            end
            local targetVel = (flatMove * spd) + Vector3.new(0, (vert ~= 0 and vert * spd or 0.5), 0)
            pcall(function()
                seat.AssemblyLinearVelocity = targetVel
                seat.AssemblyAngularVelocity = Vector3.zero
            end)
        elseif State.VehicleSpeedMod and math.abs(seat.ThrottleFloat) > 0.1 then
            local mult = clamp(tonumber(State.VehicleSpeedMult) or 2.0, 1.0, 4.0)
            local dir = seat.CFrame.LookVector * seat.ThrottleFloat
            local curVel = seat.AssemblyLinearVelocity
            seat.AssemblyLinearVelocity = Vector3.new(dir.X * 55 * mult, curVel.Y, dir.Z * 55 * mult)
        end
    else
        UpdateVehicleWheelAura(nil)
        -- 2. Character Fly
        if State.Fly and not hum.Sit then
            if not Runtime.FlyBodyVel or Runtime.FlyBodyVel.Parent ~= hrp then
                Runtime.DestroyFlyMovers()
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(9e4, 9e4, 9e4)
                bv.P = 12000
                bv.Velocity = Vector3.zero
                bv.Parent = hrp
                local bg = Instance.new("BodyGyro")
                bg.MaxTorque = Vector3.new(9e4, 9e4, 9e4)
                bg.P = 18000
                bg.D = 400
                bg.CFrame = Camera.CFrame
                bg.Parent = hrp
                Runtime.FlyBodyVel = bv
                Runtime.FlyBodyGyro = bg
            end
            local spd = tonumber(State.FlySpeed) or 65
            if State.AntiBanSafeMode then spd = math.min(spd, 80) end
            local camCF = Camera.CFrame
            local md = hum.MoveDirection
            local moveVec = Vector3.zero
            if md.Magnitude > 0.05 then
                local fwdFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
                local rightFlat = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
                if fwdFlat.Magnitude > 0.01 then moveVec = moveVec + camCF.LookVector * md:Dot(fwdFlat.Unit) end
                if rightFlat.Magnitude > 0.01 then moveVec = moveVec + camCF.RightVector * md:Dot(rightFlat.Unit) end
                if moveVec.Magnitude > 0.01 then moveVec = moveVec.Unit end
            end
            local vert = 0
            if HUDControls.FlyAscendHeld or UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
                vert = vert + 1
            end
            if HUDControls.FlyDescendHeld or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                vert = vert - 1
            end
            Runtime.FlyBodyVel.Velocity = (moveVec + Vector3.new(0, vert, 0)) * spd
            Runtime.FlyBodyGyro.CFrame = camCF
        else
            Runtime.DestroyFlyMovers()
        end
    end

    -- 3. WalkSpeed / Sprint / JumpPower / Noclip / AntiFling
    if State.MaxSpeed or State.AlwaysSprint then
        hum.WalkSpeed = State.MaxSpeed and Runtime.GetSafeRegionWalkSpeed(hrp.Position) or 25
    end
    if State.JumpPowerEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = clamp(tonumber(State.JumpPower) or 65, 50, State.AntiBanSafeMode and 85 or 140)
    end
    if State.Noclip then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                Runtime.NoclipParts[p] = true
                p.CanCollide = false
            end
        end
    elseif next(Runtime.NoclipParts) ~= nil then
        Runtime.RestoreNoclip()
    end

    if State.AntiFling and not State.Fly and not hum.Sit then
        local lv = hrp.AssemblyLinearVelocity
        local av = hrp.AssemblyAngularVelocity
        if lv.Magnitude > 145 then
            hrp.AssemblyLinearVelocity = Vector3.new(clamp(lv.X, -35, 35), clamp(lv.Y, -60, 45), clamp(lv.Z, -35, 35))
        end
        if av.Magnitude > 40 then
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end

    if State.AntiKillPlane and hrp.Position.Y < -95 then
        SafeTeleport(CFrame.new(820, 102, 2380))
    end

    -- 4. AutoHvH / Ragebot
    if (State.AutoHvH or State.Ragebot) and not hum.Sit then
        local rate = clamp(tonumber(State.RagebotRate) or 14, 1, 30)
        local minInterval = math.max(1 / rate, State.AntiBanSafeMode and 0.08 or 0.04)
        if (now - Runtime.LastRageClock) >= minInterval then
            local targetPart, targetPlr = nil, nil
            -- AutoHvH counter-threat priority: return fire on anyone actively shooting at us
            if State.AutoHvH then
                for shooter, ts in pairs(Core.RecentShooters) do
                    if (now - ts) <= 4.0 and IsValidCombatTarget(shooter, State.SilentAimHostileCheck, State.KillAuraWhitelist, false) then
                        local ch = shooter.Character
                        local pt = PickAimPart(ch, true)
                        if pt then
                            local orig = FindWallbangTrajectory(hrp.Position + Vector3.new(0, 1.5, 0), pt, ch, State.SilentAimWallbang)
                            if orig then
                                targetPart, targetPlr = pt, shooter
                                break
                            end
                        end
                    end
                end
            end
            if not targetPart then
                targetPart, targetPlr = GetBestCombatTarget({
                    use360 = State.Ragebot360 or State.AutoHvH,
                    fov = State.SilentAimFOV or 180,
                    wallcheck = true,
                    wallbang = State.SilentAimWallbang,
                    requireHostile = State.SilentAimHostileCheck,
                    forceHead = true,
                    prioritizeArmed = true,
                })
            end
            if targetPart and targetPlr then
                local tool = IsHoldingFirearm()
                if (not tool or tool.Name == "Taser") and (State.RagebotAutoSwitch or State.AutoHvH) then
                    local guns = GetOwnedLoadedGuns()
                    tool = guns[1]
                end
                if tool and tool.Name ~= "Taser" then
                    Runtime.LastRageClock = now
                    if State.RagebotPeekShield or State.AutoHvH then
                        Runtime.PeekPauseUntil = now + 0.12
                    end
                    task.spawn(FireToolAtTarget, tool, targetPart, true, false, false)
                end
            end
        end
    end

    -- 5. .combo1 Loop
    if State.ComboLoop and (now - Runtime.LastComboClock) >= math.max(0.25, tonumber(State.ComboLoopInterval) or 0.55) then
        Runtime.LastComboClock = now
        task.spawn(ExecuteCombo1)
    end

    -- 6. Throttled Melee KillAura (Strict Guard Hostile Check + Safe Range)
    if State.KillAura and Remotes.MeleeEvent and not hum.Sit and (now - Runtime.LastKillAuraClock) >= 0.32 then
        local kaRange = tonumber(State.KillAuraRange) or 10
        if State.AntiBanSafeMode then kaRange = math.min(kaRange, 10) end
        local bestPlr, bestDist = nil, kaRange
        for _, plr in ipairs(Players:GetPlayers()) do
            if IsValidCombatTarget(plr, State.KillAuraGuardSafe, State.KillAuraWhitelist, false) then
                local tr = GetRoot(plr.Character)
                if tr then
                    local d = (tr.Position - hrp.Position).Magnitude
                    if d <= bestDist then
                        bestDist = d
                        bestPlr = plr
                    end
                end
            end
        end
        if bestPlr then
            Runtime.LastKillAuraClock = now
            if State.KillAuraFaceTarget then
                local tr = GetRoot(bestPlr.Character)
                if tr then hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(tr.Position.X, hrp.Position.Y, tr.Position.Z)) end
            end
            pcall(function() Remotes.MeleeEvent:FireServer(bestPlr) end)
        end
    end

    -- 7. AutoTaze (Guards only)
    if State.AutoTaze and LocalPlayer.Team == Teams:FindFirstChild("Guards") and not hum.Sit and (now - Runtime.LastTaseClock) >= 0.45 then
        local taser = HasWeapon("Taser")
        if taser then
            local bestPart, bestD = nil, 45
            for _, plr in ipairs(Players:GetPlayers()) do
                if IsValidCombatTarget(plr, true, State.ArrestWhitelist, true) and not plr.Character:GetAttribute("Tased") then
                    local pt = GetRoot(plr.Character)
                    if pt then
                        local d = (pt.Position - hrp.Position).Magnitude
                        if d < bestD and HasLineOfSight(hrp.Position + Vector3.new(0, 1.5, 0), pt, plr.Character) then
                            bestD = d
                            bestPart = pt
                        end
                    end
                end
            end
            if bestPart then
                Runtime.LastTaseClock = now
                task.spawn(FireToolAtTarget, taser, bestPart, false, true, false)
            end
        end
    end

    -- 8. AutoArrest (Fixed: Skip when seated & start 7s cooldown ONLY on confirmed arrest)
    if State.AutoArrest and Remotes.ArrestPlayer and LocalPlayer.Team == Teams:FindFirstChild("Guards") and not hum.Sit then
        if now >= Runtime.ArrestCooldownUntil and (now - Runtime.LastArrestAttempt) >= 0.28 then
            if not State.AutoArrestHandCheck or (char:FindFirstChild("Handcuffs") ~= nil) then
                local range = tonumber(State.AutoArrestRange) or 10
                if State.AntiBanSafeMode then range = math.min(range, 10) end
                local bestTarget, bestDist = nil, range
                for _, plr in ipairs(Players:GetPlayers()) do
                    if IsValidCombatTarget(plr, true, State.ArrestWhitelist, true) then
                        local tHum = GetHumanoid(plr.Character)
                        local tr = GetRoot(plr.Character)
                        if tr and tHum and not tHum.Sit then
                            local d = (tr.Position - hrp.Position).Magnitude
                            if d <= bestDist then
                                bestDist = d
                                bestTarget = plr
                            end
                        end
                    end
                end
                if bestTarget and bestTarget.Character then
                    Runtime.LastArrestAttempt = now
                    local tPlr = bestTarget
                    local tChar = tPlr.Character
                    task.spawn(function()
                        local ok, arrested = pcall(function() return Remotes.ArrestPlayer:InvokeServer(tChar) end)
                        if ok and (arrested == true or (tChar.Parent and tChar:GetAttribute("Arrested"))) then
                            Runtime.ArrestCooldownUntil = os.clock() + 7.0
                            PushMiniKillfeedLine("🚓 Arrested " .. tPlr.Name, Color3.fromRGB(95, 175, 255))
                        end
                    end)
                end
            end
        end
    end

    -- 9. LoopKill Targets
    if next(State.LoopKillTargets) ~= nil and (now - Runtime.LastLoopKillClock) >= 0.22 then
        Runtime.LastLoopKillClock = now
        local guns = GetOwnedLoadedGuns()
        local activeGun = guns[1]
        for uid in pairs(State.LoopKillTargets) do
            local plr = Players:GetPlayerByUserId(uid)
            if plr and IsValidCombatTarget(plr, false, nil, false) then
                local tr = GetRoot(plr.Character)
                local head = plr.Character and plr.Character:FindFirstChild("Head") or tr
                if activeGun and head then
                    task.spawn(FireToolAtTarget, activeGun, head, true, false, false)
                    break
                elseif Remotes.MeleeEvent and tr and (tr.Position - hrp.Position).Magnitude <= 12 then
                    pcall(function() Remotes.MeleeEvent:FireServer(plr) end)
                    break
                end
            end
        end
    end

    -- 10. 5-Mode FE Bullet Shield Desync (Applied at end of Heartbeat, Restored at top of RenderStepped)
    if State.HoloShield and not hum.Sit and now > Runtime.PeekPauseUntil then
        local mode = State.ShieldMode or "Hybrid"
        if mode ~= "RiotOnly" then
            local savedCF = hrp.CFrame
            HoloShieldState.SavedCF = savedCF
            local desyncCF = savedCF
            HoloShieldState.JitterAngle = (HoloShieldState.JitterAngle + 2.35) % 62.8318

            if mode == "UndergroundPeek" then
                desyncCF = CFrame.new(savedCF.X, math.max(-18, savedCF.Y - 3.8), savedCF.Z) * savedCF.Rotation
            elseif mode == "DesyncBox" then
                local r = clamp(tonumber(State.DesyncJitterRadius) or 5.5, 2, 8.5)
                local ox = math.cos(HoloShieldState.JitterAngle) * r
                local oz = math.sin(HoloShieldState.JitterAngle) * r
                desyncCF = CFrame.new(savedCF.X + ox, savedCF.Y, savedCF.Z + oz) * savedCF.Rotation
            elseif mode == "Hybrid" then
                local r = clamp((tonumber(State.DesyncJitterRadius) or 5.5) * 0.6, 1.5, 5.5)
                local ox = math.cos(HoloShieldState.JitterAngle) * r
                local oz = math.sin(HoloShieldState.JitterAngle) * r
                desyncCF = CFrame.new(savedCF.X + ox, math.max(-18, savedCF.Y - 2.9), savedCF.Z + oz) * savedCF.Rotation
            elseif mode == "FEGhost" then
                desyncCF = CFrame.new(savedCF.X, math.max(-18, savedCF.Y - 3.2), savedCF.Z) * savedCF.Rotation
            end

            hrp.CFrame = desyncCF
            HoloShieldState.DesyncActive = true
        end
    end
end))

-- // Infinite Jump Connection
AddConnection(UserInputService.JumpRequest:Connect(function()
    if not Env.PrisonLife2026Running or not State.InfiniteJump or IsOnTeamsMenu() then return end
    local hum = GetHumanoid(LocalPlayer.Character)
    if hum and hum.Health > 0 and not hum.Sit then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- // 0.18s UTILITY LOOP: ESP, Anomalies, Hitbox, OpenDoors, FenceGodmode, AutoReload, AutoHeal, AutoArmor, Bypasses
task.spawn(function()
    while Env.PrisonLife2026Running do
        local now = os.clock()
        local char = LocalPlayer.Character
        local hrp = GetRoot(char)
        local hum = GetHumanoid(char)
        local onMenu = IsOnTeamsMenu()
        local alive = (char ~= nil and hrp ~= nil and hum ~= nil and hum.Health > 0)

        pcall(Visuals.UpdateESP)
        pcall(Visuals.EvaluateAnomalies, now)

        if (now - Runtime.LastBypassSync) >= 1.0 then
            Runtime.LastBypassSync = now
            pcall(Core.SyncRemoteConnectionBypasses)
            if State.AlwaysBackpack then
                pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end)
            end
        end

        if alive and not onMenu then
            -- Auto Reload & HotSwap
            if State.AutoReload or State.AutoReloadHotSwap then
                local eq = IsHoldingFirearm()
                if eq then
                    local ammo = eq:GetAttribute("Local_CurrentAmmo") or eq:GetAttribute("CurrentAmmo") or 1
                    local rel = eq:GetAttribute("Local_ReloadSession") or 0
                    if ammo <= 0 and rel <= 0 then
                        if State.AutoReloadHotSwap then
                            local guns = GetOwnedLoadedGuns()
                            if guns[1] then pcall(function() hum:EquipTool(guns[1]) end) end
                        elseif GunHook.Reload then
                            pcall(GunHook.Reload)
                        end
                    end
                end
            end

            -- Auto Heal
            if State.AutoHeal and hum.Health < (tonumber(State.AutoHealThreshold) or 80) and (now - Runtime.LastHealClock) >= 1.2 then
                Runtime.LastHealClock = now
                local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                local snack = (char:FindFirstChild("Donut") or (bp and bp:FindFirstChild("Donut")))
                if snack then
                    pcall(function() hum:EquipTool(snack); snack:Activate() end)
                elseif Remotes.EatFood then
                    pcall(function() Remotes.EatFood:FireServer() end)
                end
            end

            -- Auto Armor
            if State.AutoArmor and not HasTargetArmor(char) and (now - Runtime.LastArmorClock) >= 4.0 then
                Runtime.LastArmorClock = now
                local armorPart = nil
                local items = Workspace:FindFirstChild("Prison_ITEMS")
                local clothes = items and (items:FindFirstChild("clothes") or items:FindFirstChild("single"))
                if clothes then
                    for _, d in ipairs(clothes:GetDescendants()) do
                        if (d.Name:lower():find("vest") or d.Name:lower():find("armor")) and (d:IsA("BasePart") or d:IsA("Model")) then
                            armorPart = d; break
                        end
                    end
                end
                if armorPart and Remotes.GiverPressed then
                    pcall(function() Remotes.GiverPressed:FireServer(armorPart) end)
                end
            end

            -- Auto Pickup Dropped Weapons
            if State.AutoPickupDropped and (now - Runtime.LastPickupClock) >= 0.85 then
                Runtime.LastPickupClock = now
                for _, item in ipairs(Workspace:GetChildren()) do
                    if item:IsA("Tool") and item:FindFirstChild("Handle") then
                        if (item.Handle.Position - hrp.Position).Magnitude <= 28 then
                            pcall(function() hum:EquipTool(item) end)
                        end
                    end
                end
            end

            -- Auto Detonate C4
            if State.AutoDetonateC4 then
                local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                local det = char:FindFirstChild("Detonator") or (bp and bp:FindFirstChild("Detonator"))
                if det then
                    pcall(function()
                        if det.Parent ~= char then hum:EquipTool(det) end
                        det:Activate()
                    end)
                end
            end
        end

        -- ExpandHitbox & AntiRiotShield & AntiInvisible
        if State.ExpandHitbox then
            local hbSize = clamp(tonumber(State.HitboxSize) or 9, 3, State.AntiBanSafeMode and 12 or 22)
            local active = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and not (State.SilentAimTeamCheck and plr.Team == LocalPlayer.Team) then
                    local tHrp = GetRoot(plr.Character)
                    local tHum = GetHumanoid(plr.Character)
                    if tHrp and tHum and tHum.Health > 0 then
                        active[tHrp] = true
                        if not Runtime.ModifiedHitboxes[tHrp] then
                            Runtime.ModifiedHitboxes[tHrp] = {
                                Size = tHrp.Size,
                                Transparency = tHrp.Transparency,
                                Material = tHrp.Material,
                                CanCollide = tHrp.CanCollide,
                            }
                        end
                        pcall(function()
                            tHrp.Size = Vector3.new(hbSize, hbSize, hbSize)
                            tHrp.Transparency = 0.72
                            tHrp.Material = Enum.Material.Neon
                            tHrp.CanCollide = false
                        end)
                    end
                end
            end
            for h in pairs(Runtime.ModifiedHitboxes) do
                if not active[h] or not h.Parent then
                    Runtime.ModifiedHitboxes[h] = nil
                end
            end
        elseif next(Runtime.ModifiedHitboxes) ~= nil then
            Runtime.RestoreHitboxes()
        end

        if State.AntiRiotShield or State.AntiInvisible then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    if State.AntiRiotShield then
                        local rs = plr.Character:FindFirstChild("RiotShieldPart", true)
                        if rs and rs:IsA("BasePart") then
                            rs.CanQuery = false
                            rs.CanCollide = false
                        end
                    end
                    if State.AntiInvisible and not State.ESP then
                        local tHead = plr.Character:FindFirstChild("Head")
                        if tHead and tHead.Transparency >= 0.9 then
                            tHead.Transparency = 0
                        end
                    end
                end
            end
        end

        -- OpenAllDoors
        if State.OpenAllDoors then
            local doorsFolder = Workspace:FindFirstChild("Doors")
            if doorsFolder then
                for _, d in ipairs(doorsFolder:GetDescendants()) do
                    if d:IsA("BasePart") and (d.CanCollide or d.Transparency < 0.5) then
                        if not Runtime.ModifiedDoors[d] then
                            Runtime.ModifiedDoors[d] = { CanCollide = d.CanCollide, Transparency = d.Transparency }
                        end
                        d.CanCollide = false
                        d.Transparency = math.max(d.Transparency, 0.55)
                    end
                end
            end
        elseif next(Runtime.ModifiedDoors) ~= nil then
            Runtime.RestoreDoors()
        end

        -- FenceGodmode
        if State.FenceGodmode then
            local fences = Workspace:FindFirstChild("Prison_Fences")
            if fences then
                for _, d in ipairs(fences:GetDescendants()) do
                    if d:IsA("BasePart") and d.CanTouch and (d.Name:lower():find("damage") or d.Name:lower():find("wire") or d.Name:lower():find("shock") or d:FindFirstChildOfClass("TouchTransmitter")) then
                        if Runtime.ModifiedFences[d] == nil then
                            Runtime.ModifiedFences[d] = d.CanTouch
                        end
                        d.CanTouch = false
                    end
                end
            end
        elseif next(Runtime.ModifiedFences) ~= nil then
            Runtime.RestoreFences()
        end

        task.wait(0.18)
    end
end)

-- ============================================================================
-- // SECTION 12: TELEPORTS, BULK TARGET ACTIONS, PRESETS & SERVER HOP
-- ============================================================================
local Actions = {}

Actions.TeleportLocations = {
    ["Prison Yard"]     = CFrame.new(785, 98, 2445),
    ["Armory"]          = CFrame.new(828, 100, 2248),
    ["Guard Room"]      = CFrame.new(834, 100, 2302),
    ["Cellblock"]       = CFrame.new(912, 100, 2418),
    ["Prison Roof"]     = CFrame.new(895, 120, 2365),
    ["Cafeteria"]       = CFrame.new(918, 100, 2282),
    ["Criminal Base"]   = CFrame.new(-943, 95, 2063),
    ["Gas Station"]     = CFrame.new(-515, 55, 1650),
    ["Prison Gate"]     = CFrame.new(503, 102, 2216),
    ["Front Parking"]   = CFrame.new(470, 99, 2320),
    ["Secret Room"]     = CFrame.new(718, 100, 2358),
    ["Sewer Escape"]    = CFrame.new(915, 78, 2115),
    ["Yard Tower NE"]   = CFrame.new(998, 125, 2225),
    ["Yard Tower SW"]   = CFrame.new(760, 125, 2575),
    ["Suburban Town"]   = CFrame.new(-285, 55, 1790),
}

function Actions.TeleportToLocation(locName)
    local cf = Actions.TeleportLocations[locName]
    if not cf then return false end
    SafeTeleport(cf)
    Notify("Teleport", "Teleported to " .. tostring(locName), 1.8)
    return true
end

function Actions.RunArrestTargets(targetList)
    if LocalPlayer.Team ~= Teams:FindFirstChild("Guards") then
        Notify("Arrest", "Switch to Guards team first!", 2.5)
        return
    end
    task.spawn(function()
        local hrp = GetRoot(LocalPlayer.Character)
        if not hrp or not Remotes.ArrestPlayer then return end
        local startCF = hrp.CFrame
        local count = 0
        for _, plr in ipairs(targetList) do
            if not Env.PrisonLife2026Running then break end
            if IsValidCombatTarget(plr, true, State.ArrestWhitelist, true) then
                local tr = GetRoot(plr.Character)
                local th = GetHumanoid(plr.Character)
                if tr and th and not th.Sit then
                    SafeTeleport(tr.CFrame * CFrame.new(0, 0, 2.2))
                    task.wait(0.08)
                    local ok, res = pcall(function() return Remotes.ArrestPlayer:InvokeServer(plr.Character) end)
                    if ok and res == true then
                        count = count + 1
                        PushMiniKillfeedLine("🚓 Arrested " .. plr.Name, Color3.fromRGB(95, 175, 255))
                    end
                    task.wait(0.08)
                end
            end
        end
        SafeTeleport(startCF)
        Notify("Bulk Arrest", string.format("Processed %d arrest(s).", count), 2.5)
    end)
end

function Actions.RunTaseTargets(targetList)
    if LocalPlayer.Team ~= Teams:FindFirstChild("Guards") then
        Notify("Tase", "Switch to Guards team first!", 2.5)
        return
    end
    local taser = HasWeapon("Taser")
    if not taser then
        Notify("Tase", "No Taser found!", 2.2)
        return
    end
    task.spawn(function()
        for _, plr in ipairs(targetList) do
            if not Env.PrisonLife2026Running then break end
            if IsValidCombatTarget(plr, true, State.ArrestWhitelist, true) then
                local pt = GetRoot(plr.Character)
                if pt then
                    FireToolAtTarget(taser, pt, false, true, false)
                    task.wait(0.16)
                end
            end
        end
    end)
end

function Actions.RunShootKillTargets(targetList)
    task.spawn(function()
        local guns = GetOwnedLoadedGuns()
        if #guns == 0 then
            GrabWeapons(State.AutoGetGunsSelection, true)
            guns = GetOwnedLoadedGuns()
        end
        if #guns == 0 then
            Notify("Kill Targets", "No loaded weapons!", 2.2)
            return
        end
        local idx = 1
        for _, plr in ipairs(targetList) do
            if not Env.PrisonLife2026Running then break end
            if IsValidCombatTarget(plr, State.SilentAimHostileCheck, State.KillAuraWhitelist, false) then
                local head = plr.Character and (plr.Character:FindFirstChild("Head") or GetRoot(plr.Character))
                if head then
                    local g = guns[((idx - 1) % #guns) + 1]
                    idx = idx + 1
                    FireToolAtTarget(g, head, true, false, false)
                    task.wait(State.AntiBanSafeMode and 0.1 or 0.06)
                end
            end
        end
    end)
end

function Actions.ApplyPresetProfile(modeName)
    local m = string.lower(Trim(tostring(modeName or "")))
    if m == "safe" or m == "legit" then
        State.AntiBanSafeMode = true
        State.AutoHvH = false
        State.Ragebot = false
        State.ComboLoop = false
        State.KillAura = (m == "safe")
        State.SilentAim = true
        State.SilentAimFOV = 135
        State.SilentAimWallcheck = true
        State.SilentAimWallbang = false
        State.SilentAimHostileCheck = true
        State.AimAssist = (m == "legit")
        State.HoloShield = false
        State.GunMods = true
        State.GunFireRateSPS = 12
        State.MaxSpeed = true
        State.MaxSpeedMode = "RegionSafe"
        State.AntiTase = true
        DestroyHoloShield()
    elseif m == "rage" then
        State.AntiBanSafeMode = true
        State.SilentAim = true
        State.SilentAimFOV = 280
        State.SilentAimWallbang = true
        State.SilentAimHostileCheck = true
        State.Ragebot = true
        State.AutoHvH = false
        State.KillAura = true
        State.HoloShield = true
        State.ShieldMode = "Hybrid"
        State.GunMods = true
        State.GunFireRateSPS = 15
        State.MaxSpeed = true
        State.MaxSpeedMode = "RegionSafe"
        State.AntiTase = true
    elseif m == "hvh" then
        State.AntiBanSafeMode = true
        State.AutoHvH = true
        State.Ragebot = true
        State.Ragebot360 = true
        State.RagebotAutoSwitch = true
        State.RagebotPeekShield = true
        State.SilentAim = true
        State.SilentAimFOV = 360
        State.SilentAimWallbang = true
        State.SilentAimHostileCheck = true
        State.HoloShield = true
        State.ShieldMode = "Hybrid"
        State.ShieldAutoFaceShooter = true
        State.KillAura = true
        State.GunMods = true
        State.GunFireRateSPS = 15
        State.AntiTase = true
        State.MaxSpeed = true
        State.MaxSpeedMode = "RegionSafe"
    else
        Notify("Preset", "Unknown preset: " .. tostring(modeName), 2.2)
        return
    end
    ApplyGunModsAll()
    Notify("Preset Loaded", "Applied [" .. m:upper() .. "] profile!", 2.5)
end

function Actions.RejoinServer()
    Notify("Server", "Rejoining current server...", 2)
    task.spawn(function()
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end)
end

function Actions.ServerHop()
    Notify("Server", "Searching for another server...", 2.5)
    task.spawn(function()
        local reqFn = request or (syn and syn.request) or http_request
        local ok, body = pcall(function()
            local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=50", game.PlaceId)
            if reqFn then
                local r = reqFn({ Url = url, Method = "GET" })
                return r and r.Body
            end
            return game:HttpGet(url)
        end)
        if not ok or not body then
            Actions.RejoinServer()
            return
        end
        local okJ, parsed = pcall(function() return HttpService:JSONDecode(body) end)
        if okJ and parsed and type(parsed.data) == "table" then
            for _, srv in ipairs(parsed.data) do
                if srv.id and srv.id ~= game.JobId and (srv.playing or 0) < (srv.maxPlayers or 99) then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
                    return
                end
            end
        end
        Actions.RejoinServer()
    end)
end

-- ============================================================================
-- // SECTION 13: KX COMMAND ENGINE, COLLAPSIBLE CMD PILL, CHAT & HOTKEYS
-- ============================================================================
local Commands = {
    Expanded = false,
}

local function ParseBoolArg(arg, currentVal)
    local a = string.lower(Trim(tostring(arg or "")))
    if a == "on" or a == "true" or a == "1" or a == "enable" then return true end
    if a == "off" or a == "false" or a == "0" or a == "disable" then return false end
    return not currentVal
end

function Commands.Execute(rawInput)
    local rawStr = Trim(tostring(rawInput or ""))
    if rawStr == "" then return end

    local chunks = {}
    for seg in string.gmatch(rawStr, "[^;]+") do
        local s = Trim(seg)
        if s ~= "" then table.insert(chunks, s) end
    end
    if #chunks > 1 then
        for _, ch in ipairs(chunks) do Commands.Execute(ch) end
        return
    end

    local line = rawStr
    local prefix = line:sub(1, 1)
    if prefix == "." or prefix == ";" or prefix == "/" or prefix == ":" then
        line = Trim(line:sub(2))
    end
    if line == "" then return end

    local parts = {}
    for w in string.gmatch(line, "%S+") do
        table.insert(parts, w)
    end
    local cmd = string.lower(parts[1] or "")
    local rest = Trim(line:sub(#(parts[1] or "") + 1))

    if cmd == "guns" or cmd == "arm" or cmd == "loadout" then
        task.spawn(GrabWeapons, State.AutoGetGunsSelection, false)
    elseif cmd == "gun" and rest ~= "" then
        task.spawn(GrabWeapons, { rest }, false)
    elseif cmd == "hammer" then
        task.spawn(GrabWeapons, { "Hammer" }, false)
    elseif cmd == "knife" or cmd == "crudeknife" then
        task.spawn(GrabWeapons, { "Crude Knife" }, false)
    elseif cmd == "riot" or cmd == "riotshield" then
        task.spawn(GrabWeapons, { "Riot Shield" }, false)
    elseif cmd == "combo1" or cmd == "combo" or cmd == "c1" then
        local targets = rest ~= "" and ResolveTargetPlayers(rest) or {}
        task.spawn(ExecuteCombo1, targets[1])
    elseif cmd == "loopcombo" or cmd == "lc" then
        State.ComboLoop = ParseBoolArg(parts[2], State.ComboLoop)
        Notify("Combo Loop", "Combo Loop: " .. (State.ComboLoop and "ON" or "OFF"), 2)
    elseif cmd == "shield" or cmd == "holoshield" then
        State.HoloShield = ParseBoolArg(parts[2], State.HoloShield)
        if State.HoloShield then CreateHoloShield() else DestroyHoloShield() end
        Notify("Holo-Shield", "Holo-Shield: " .. (State.HoloShield and "ON [" .. State.ShieldMode .. "]" or "OFF"), 2)
    elseif cmd == "shieldmode" or cmd == "antiaim" then
        local modeMap = {
            hybrid = "Hybrid", underground = "UndergroundPeek", undergroundpeek = "UndergroundPeek",
            desync = "DesyncBox", desyncbox = "DesyncBox", riot = "RiotOnly", riotonly = "RiotOnly",
            ghost = "FEGhost", feghost = "FEGhost",
        }
        local picked = modeMap[string.lower(parts[2] or "")]
        if picked then
            State.ShieldMode = picked
            State.HoloShield = true
            CreateHoloShield()
            Notify("Shield Mode", "Mode set to " .. picked, 2)
        else
            Notify("Shield Mode", "Modes: Hybrid, UndergroundPeek, DesyncBox, RiotOnly, FEGhost", 2.8)
        end
    elseif cmd == "autohvh" or cmd == "hvh" then
        State.AutoHvH = ParseBoolArg(parts[2], State.AutoHvH)
        if State.AutoHvH then
            State.Ragebot = true
            State.SilentAim = true
            State.HoloShield = true
            State.AntiTase = true
            CreateHoloShield()
        end
        Notify("AutoHvH", "AutoHvH: " .. (State.AutoHvH and "ON" or "OFF"), 2)
    elseif cmd == "rage" or cmd == "ragebot" then
        State.Ragebot = ParseBoolArg(parts[2], State.Ragebot)
        if State.Ragebot then State.SilentAim = true end
        Notify("Ragebot", "Ragebot: " .. (State.Ragebot and "ON" or "OFF"), 2)
    elseif cmd == "silentaim" or cmd == "sa" then
        State.SilentAim = ParseBoolArg(parts[2], State.SilentAim)
        Notify("Silent Aim", "Silent Aim: " .. (State.SilentAim and "ON" or "OFF"), 2)
    elseif cmd == "wallbang" or cmd == "wb" then
        State.SilentAimWallbang = ParseBoolArg(parts[2], State.SilentAimWallbang)
        Notify("Wallbang", "Wallbang Scanner: " .. (State.SilentAimWallbang and "ON" or "OFF"), 2)
    elseif cmd == "killaura" or cmd == "ka" then
        State.KillAura = ParseBoolArg(parts[2], State.KillAura)
        Notify("KillAura", "KillAura: " .. (State.KillAura and "ON" or "OFF"), 2)
    elseif cmd == "hitbox" then
        local sz = tonumber(parts[2])
        if sz then
            State.HitboxSize = sz
            State.ExpandHitbox = true
        else
            State.ExpandHitbox = ParseBoolArg(parts[2], State.ExpandHitbox)
        end
        Notify("Hitbox", string.format("Hitbox: %s (%d)", State.ExpandHitbox and "ON" or "OFF", State.HitboxSize), 2)
    elseif cmd == "kill" and rest ~= "" then
        Actions.RunShootKillTargets(ResolveTargetPlayers(rest))
    elseif cmd == "killall" then
        Actions.RunShootKillTargets(ResolveTargetPlayers("others"))
    elseif cmd == "loopkill" or cmd == "lk" then
        local list = ResolveTargetPlayers(rest)
        for _, p in ipairs(list) do
            if p ~= LocalPlayer then State.LoopKillTargets[p.UserId] = true end
        end
        Notify("LoopKill", "Added " .. tostring(#list) .. " target(s).", 2)
    elseif cmd == "unloopkill" or cmd == "unlk" then
        if rest == "" or string.lower(rest) == "all" then
            State.LoopKillTargets = {}
            Notify("LoopKill", "Cleared all LoopKill targets.", 2)
        else
            for _, p in ipairs(ResolveTargetPlayers(rest)) do
                State.LoopKillTargets[p.UserId] = nil
            end
            Notify("LoopKill", "Removed matching target(s).", 2)
        end
    elseif cmd == "kawl" then
        if string.lower(rest) == "clear" then
            State.KillAuraWhitelist = {}
        else
            for _, p in ipairs(ResolveTargetPlayers(rest)) do State.KillAuraWhitelist[p.UserId] = true end
        end
        Notify("Whitelist", "Updated Combat Whitelist.", 2)
    elseif cmd == "aawl" then
        if string.lower(rest) == "clear" then
            State.ArrestWhitelist = {}
        else
            for _, p in ipairs(ResolveTargetPlayers(rest)) do State.ArrestWhitelist[p.UserId] = true end
        end
        Notify("Whitelist", "Updated Arrest Whitelist.", 2)
    elseif cmd == "savecar" or cmd == "sc" or cmd == "savecars" then
        SaveCarsCommand(tonumber(parts[2]) or 1)
    elseif cmd == "fc" or cmd == "forcecrim" then
        local t = ResolveTargetPlayers(rest)[1]
        ExecuteCarTargetAction(t, "forcecrim")
    elseif cmd == "bring" then
        local t = ResolveTargetPlayers(rest)[1]
        ExecuteCarTargetAction(t, "bring")
    elseif cmd == "void" or cmd == "forcekick" then
        local t = ResolveTargetPlayers(rest)[1]
        ExecuteCarTargetAction(t, "void")
    elseif cmd == "fling" or cmd == "carfling" then
        local t = ResolveTargetPlayers(rest)[1]
        ExecuteCarTargetAction(t, "fling")
    elseif cmd == "wheelaura" or cmd == "wa" then
        State.WheelAura = ParseBoolArg(parts[2], State.WheelAura)
        Notify("WheelAura", "Wheel Aura: " .. (State.WheelAura and "ON" or "OFF"), 2)
    elseif cmd == "car" or cmd == "spawncar" then
        SpawnAndEnterNearestCar()
    elseif cmd == "guard" or cmd == "guards" or cmd == "cop" then
        Core.SwitchToTeam("Guards")
    elseif cmd == "inmate" or cmd == "inmates" then
        Core.SwitchToTeam("Inmates")
    elseif cmd == "crim" or cmd == "criminals" or cmd == "criminal" then
        Core.SwitchToTeam("Criminals")
    elseif cmd == "neutral" then
        Core.SwitchToTeam("Neutral")
    elseif cmd == "re" or cmd == "respawn" or cmd == "refresh" then
        Core.PerformFastRespawn()
    elseif cmd == "arrest" then
        Actions.RunArrestTargets(ResolveTargetPlayers(rest ~= "" and rest or "criminals"))
    elseif cmd == "arrestall" then
        Actions.RunArrestTargets(ResolveTargetPlayers("others"))
    elseif cmd == "tase" then
        Actions.RunTaseTargets(ResolveTargetPlayers(rest ~= "" and rest or "criminals"))
    elseif cmd == "taseall" then
        Actions.RunTaseTargets(ResolveTargetPlayers("others"))
    elseif cmd == "autoarrest" or cmd == "aa" then
        State.AutoArrest = ParseBoolArg(parts[2], State.AutoArrest)
        Notify("AutoArrest", "AutoArrest: " .. (State.AutoArrest and "ON" or "OFF"), 2)
    elseif cmd == "autotaze" or cmd == "at" then
        State.AutoTaze = ParseBoolArg(parts[2], State.AutoTaze)
        Notify("AutoTaze", "AutoTaze: " .. (State.AutoTaze and "ON" or "OFF"), 2)
    elseif cmd == "antitase" then
        State.AntiTase = ParseBoolArg(parts[2], State.AntiTase)
        Core.SyncRemoteConnectionBypasses()
        Notify("AntiTase", "AntiTase: " .. (State.AntiTase and "ON" or "OFF"), 2)
    elseif cmd == "antiarrest" then
        State.AntiArrest = ParseBoolArg(parts[2], State.AntiArrest)
        Core.SyncRemoteConnectionBypasses()
        Notify("AntiArrest", "AntiArrest: " .. (State.AntiArrest and "ON" or "OFF"), 2)
    elseif cmd == "invis" or cmd == "invisible" then
        Stealth.SetFEInvisibleState(ParseBoolArg(parts[2], State.FEInvisible))
    elseif cmd == "fly" then
        State.Fly = ParseBoolArg(parts[2], State.Fly)
        Notify("Fly", "Fly: " .. (State.Fly and "ON" or "OFF"), 2)
    elseif cmd == "carfly" or cmd == "vfly" then
        State.VehicleFly = ParseBoolArg(parts[2], State.VehicleFly)
        Notify("Vehicle Fly", "Vehicle Fly: " .. (State.VehicleFly and "ON" or "OFF"), 2)
    elseif cmd == "speed" or cmd == "ws" then
        local sp = tonumber(parts[2])
        if sp then
            State.MaxSpeed = true
            State.MaxSpeedMode = "Custom"
            State.CustomWalkSpeed = sp
        else
            State.MaxSpeed = ParseBoolArg(parts[2], State.MaxSpeed)
        end
        Notify("Speed", "MaxSpeed: " .. (State.MaxSpeed and State.MaxSpeedMode or "OFF"), 2)
    elseif cmd == "safespeed" then
        State.MaxSpeed = true
        State.MaxSpeedMode = "RegionSafe"
        Notify("Speed", "Enabled RegionSafe WalkSpeed.", 2)
    elseif cmd == "noclip" then
        State.Noclip = ParseBoolArg(parts[2], State.Noclip)
        if not State.Noclip then Runtime.RestoreNoclip() end
        Notify("Noclip", "Noclip: " .. (State.Noclip and "ON" or "OFF"), 2)
    elseif cmd == "opendoors" or cmd == "doors" then
        State.OpenAllDoors = ParseBoolArg(parts[2], State.OpenAllDoors)
        if not State.OpenAllDoors then Runtime.RestoreDoors() end
        Notify("Doors", "Open Doors: " .. (State.OpenAllDoors and "ON" or "OFF"), 2)
    elseif cmd == "fencegod" then
        State.FenceGodmode = ParseBoolArg(parts[2], State.FenceGodmode)
        if not State.FenceGodmode then Runtime.RestoreFences() end
        Notify("Fence Godmode", "Fence Godmode: " .. (State.FenceGodmode and "ON" or "OFF"), 2)
    elseif cmd == "goto" or cmd == "tp" then
        local matchedLoc = nil
        for locName in pairs(Actions.TeleportLocations) do
            if string.lower(locName):find(string.lower(rest), 1, true) then
                matchedLoc = locName; break
            end
        end
        if matchedLoc then
            Actions.TeleportToLocation(matchedLoc)
        else
            local target = ResolveTargetPlayers(rest)[1]
            local tr = target and GetRoot(target.Character)
            if tr then
                SafeTeleport(tr.CFrame + Vector3.new(0, 3, 2))
                Notify("Teleport", "Teleported to " .. target.Name, 2)
            else
                Notify("Teleport", "Target not found: " .. rest, 2.2)
            end
        end
    elseif cmd == "view" or cmd == "spectate" then
        local target = ResolveTargetPlayers(rest)[1]
        local tHum = target and GetHumanoid(target.Character)
        if tHum then
            Camera.CameraSubject = tHum
            Notify("Spectate", "Viewing " .. target.Name, 2)
        end
    elseif cmd == "unview" or cmd == "unspectate" then
        local myHum = GetHumanoid(LocalPlayer.Character)
        if myHum then Camera.CameraSubject = myHum end
        Notify("Spectate", "Camera restored.", 1.8)
    elseif cmd == "esp" then
        State.ESP = ParseBoolArg(parts[2], State.ESP)
        Notify("ESP", "ESP: " .. (State.ESP and "ON" or "OFF"), 2)
    elseif cmd == "tracers" then
        State.BulletTracers = ParseBoolArg(parts[2], State.BulletTracers)
        Notify("Tracers", "Bullet Tracers: " .. (State.BulletTracers and "ON" or "OFF"), 2)
    elseif cmd == "hitmarker" then
        State.Hitmarker = ParseBoolArg(parts[2], State.Hitmarker)
        Notify("Hitmarker", "Hitmarker: " .. (State.Hitmarker and "ON" or "OFF"), 2)
    elseif cmd == "preset" then
        Actions.ApplyPresetProfile(parts[2] or "safe")
    elseif cmd == "rj" or cmd == "rejoin" then
        Actions.RejoinServer()
    elseif cmd == "shop" or cmd == "serverhop" then
        Actions.ServerHop()
    elseif cmd == "cmds" or cmd == "help" then
        Notify("KX Commands", "guns, hammer, knife, combo1, savecar, fc, bring, void, autohvh, shield, invis, fly, goto, arrest, guard, inmate, crim, preset", 5)
    else
        Notify("Command", "Unknown command: ." .. cmd .. " (try .cmds)", 2.2)
    end
end

-- // Collapsible Top-Left `⌘ CMD` Pill (Never overlaps Game Menu, Team Icon, or Ammo!)
do
    local cmdPill = Instance.new("TextButton")
    cmdPill.Name = "CommandPill"
    cmdPill.Position = UDim2.new(0, 112, 0, 56)
    cmdPill.Size = UDim2.fromOffset(64, 26)
    cmdPill.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
    cmdPill.BackgroundTransparency = 0.18
    cmdPill.BorderSizePixel = 0
    cmdPill.Font = Enum.Font.GothamBold
    cmdPill.TextSize = 11
    cmdPill.TextColor3 = Color3.fromRGB(220, 232, 255)
    cmdPill.Text = "⌘ CMD"
    cmdPill.Visible = false
    cmdPill.Parent = OverlayGui
    Instance.new("UICorner", cmdPill).CornerRadius = UDim.new(1, 0)
    local pStroke = Instance.new("UIStroke", cmdPill)
    pStroke.Color = Color3.fromRGB(90, 150, 255)
    pStroke.Thickness = 1.1
    pStroke.Transparency = 0.3
    MakeDraggable(cmdPill)

    local drawer = Instance.new("Frame")
    drawer.Name = "CommandDrawer"
    drawer.Position = UDim2.new(0, 14, 0, 88)
    drawer.Size = UDim2.fromOffset(220, 30)
    drawer.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
    drawer.BackgroundTransparency = 0.08
    drawer.BorderSizePixel = 0
    drawer.Visible = false
    drawer.Parent = OverlayGui
    Instance.new("UICorner", drawer).CornerRadius = UDim.new(0, 8)
    local dStroke = Instance.new("UIStroke", drawer)
    dStroke.Color = Color3.fromRGB(0, 195, 255)
    dStroke.Thickness = 1.1

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -48, 1, -4)
    box.Position = UDim2.fromOffset(8, 2)
    box.BackgroundTransparency = 1
    box.Font = Enum.Font.Gotham
    box.TextSize = 11
    box.TextColor3 = Color3.new(1, 1, 1)
    box.PlaceholderColor3 = Color3.fromRGB(145, 160, 185)
    box.PlaceholderText = ".combo1, .savecar 2, .fc, .autohvh"
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.Text = ""
    box.Parent = drawer

    local runBtn = Instance.new("TextButton")
    runBtn.Position = UDim2.new(1, -38, 0, 3)
    runBtn.Size = UDim2.fromOffset(34, 24)
    runBtn.BackgroundColor3 = Color3.fromRGB(0, 165, 235)
    runBtn.BorderSizePixel = 0
    runBtn.Font = Enum.Font.GothamBold
    runBtn.TextSize = 10
    runBtn.TextColor3 = Color3.new(1, 1, 1)
    runBtn.Text = "GO"
    runBtn.Parent = drawer
    Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 6)

    local function toggleDrawer(open, focusBox)
        if open == nil then open = not Commands.Expanded end
        Commands.Expanded = open
        drawer.Visible = open
        if open then
            drawer.Position = UDim2.new(cmdPill.Position.X.Scale, cmdPill.Position.X.Offset - 98, cmdPill.Position.Y.Scale, cmdPill.Position.Y.Offset + 32)
            if focusBox then
                task.defer(function() pcall(function() box:CaptureFocus() end) end)
            end
        end
    end

    local function submitCmd()
        local txt = Trim(box.Text)
        box.Text = ""
        toggleDrawer(false, false)
        if txt ~= "" then Commands.Execute(txt) end
    end

    cmdPill.Activated:Connect(function() toggleDrawer(nil, true) end)
    runBtn.Activated:Connect(submitCmd)
    box.FocusLost:Connect(function(enter)
        if enter then submitCmd() end
    end)

    Commands.OpenAndFocus = function() toggleDrawer(true, true) end
    Runtime.UpdateCommandPillVisibility = function(onMenu)
        cmdPill.Visible = State.ShowCommandPill and not onMenu
        if onMenu or not State.ShowCommandPill then
            drawer.Visible = false
            Commands.Expanded = false
        end
    end
end

AddConnection(LocalPlayer.Chatted:Connect(function(msg)
    if not Env.PrisonLife2026Running or not State.ChatCommands then return end
    local m = Trim(msg)
    local p = m:sub(1, 1)
    if p == "." or p == ";" then
        Commands.Execute(m)
    end
end))

-- // PC Hotkeys
AddConnection(UserInputService.InputBegan:Connect(function(inp, gpe)
    if not Env.PrisonLife2026Running or IsMobile then return end
    if gpe or UserInputService:GetFocusedTextBox() then return end
    if inp.KeyCode == Enum.KeyCode.G then
        task.spawn(ExecuteCombo1)
    elseif inp.KeyCode == Enum.KeyCode.X then
        Commands.Execute("silentaim")
    elseif inp.KeyCode == Enum.KeyCode.B then
        Commands.Execute("shield")
    elseif inp.KeyCode == Enum.KeyCode.H then
        Commands.Execute("autohvh")
    elseif inp.KeyCode == Enum.KeyCode.F then
        local hum = GetHumanoid(LocalPlayer.Character)
        if hum and hum.SeatPart then Commands.Execute("carfly") else Commands.Execute("fly") end
    elseif inp.KeyCode == Enum.KeyCode.N then
        Commands.Execute("noclip")
    elseif inp.KeyCode == Enum.KeyCode.V then
        Commands.Execute("invis")
    elseif inp.KeyCode == Enum.KeyCode.Semicolon then
        if Commands.OpenAndFocus then Commands.OpenAndFocus() end
    end
end))

-- ============================================================================
-- // SECTION 14: MOBILE-RESPONSIVE 7-TAB WINDUI HUB (+ NATIVE FALLBACK UI)
-- ============================================================================
local UI = {
    Window = nil,
    FallbackGui = nil,
    SelectedTargetName = "",
    SelectedTeleportLoc = "Prison Yard",
}

local function BuildPlayerListStrings()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.Name)
        end
    end
    table.sort(list)
    if #list == 0 then table.insert(list, "None") end
    return list
end

local function BuildLocationListStrings()
    local list = {}
    for name in pairs(Actions.TeleportLocations) do table.insert(list, name) end
    table.sort(list)
    return list
end

local function BuildWindUI()
    local vp = (Camera and Camera.ViewportSize) or Vector2.new(1280, 720)
    local winW = IsMobile and math.min(500, math.max(360, math.floor(vp.X - 80))) or 590
    local winH = IsMobile and math.min(315, math.max(245, math.floor(vp.Y - 64))) or 440
    local sideW = IsMobile and 130 or 175

    local Window = WindUI:CreateWindow({
        Title = "Prison Life KX Pro",
        Icon = "shield",
        Author = "v4.0 Clean Edition • " .. (IsMobile and "Mobile" or "PC"),
        Folder = "PrisonLife_KX_Pro_v4",
        Size = UDim2.fromOffset(winW, winH),
        SideBarWidth = sideW,
        Transparent = true,
        Theme = "Dark",
        Resizable = true,
    })
    UI.Window = Window

    if Window.EditOpenButton then
        pcall(function()
            Window:EditOpenButton({
                Title = "KX Pro",
                Icon = "shield",
                CornerRadius = UDim.new(0, 14),
                StrokeThickness = 1.5,
                Draggable = true,
            })
        end)
    end
    if Window.SetToggleKey then
        pcall(function() Window:SetToggleKey(Enum.KeyCode.RightShift) end)
    end

    -- 1. Shield & Safe
    local TShield = Window:Tab({ Title = "Shield & Safe", Icon = "shield" })
    TShield:Section({ Title = "Protection & Anti-Ban" })
    TShield:Toggle({
        Title = "Anti-Ban SafeMode (Error 600 Guard)",
        Desc = "Caps FireRate <=15, KillAura/Arrest <=10m, Fly/Speed bounds.",
        Value = State.AntiBanSafeMode,
        Callback = function(v) State.AntiBanSafeMode = v; ApplyGunModsAll() end,
    })
    TShield:Toggle({
        Title = "5-Mode Holo-Shield [B]",
        Desc = "FE bullet dodge + ForceField barrier + ReplicateEvent interception.",
        Value = State.HoloShield,
        Callback = function(v)
            State.HoloShield = v
            if v then CreateHoloShield() else DestroyHoloShield() end
        end,
    })
    TShield:Dropdown({
        Title = "Shield Dodge Mode",
        Values = { "Hybrid", "UndergroundPeek", "DesyncBox", "RiotOnly", "FEGhost" },
        Value = State.ShieldMode,
        Callback = function(v)
            local picked = NormalizeDropdownValue(v)
            if picked ~= "" then State.ShieldMode = picked end
            if State.HoloShield then CreateHoloShield() end
        end,
    })
    TShield:Slider({
        Title = "Shield Size",
        Step = 0.2,
        Value = { Min = 3, Max = 11, Default = State.ShieldSize },
        Callback = function(v) State.ShieldSize = v; if State.HoloShield then CreateHoloShield() end end,
    })
    TShield:Slider({
        Title = "Shield Transparency",
        Step = 0.02,
        Value = { Min = 0.55, Max = 0.96, Default = State.ShieldTransparency },
        Callback = function(v) State.ShieldTransparency = v end,
    })
    TShield:Toggle({
        Title = "Auto-Face Enemy Shooter",
        Value = State.ShieldAutoFaceShooter,
        Callback = function(v) State.ShieldAutoFaceShooter = v end,
    })
    TShield:Toggle({
        Title = "360° Spin Shield",
        Value = State.ShieldSpinBlock,
        Callback = function(v) State.ShieldSpinBlock = v end,
    })
    TShield:Toggle({
        Title = "Anti-Tase",
        Value = State.AntiTase,
        Callback = function(v) State.AntiTase = v; Core.SyncRemoteConnectionBypasses() end,
    })
    TShield:Toggle({
        Title = "Anti-Arrest",
        Value = State.AntiArrest,
        Callback = function(v) State.AntiArrest = v; Core.SyncRemoteConnectionBypasses() end,
    })
    TShield:Toggle({
        Title = "Anti-Fling & Anti-KillPlane",
        Value = State.AntiFling,
        Callback = function(v) State.AntiFling = v; State.AntiKillPlane = v end,
    })
    TShield:Section({ Title = "Quick Presets" })
    TShield:Button({ Title = "Preset: Safe", Callback = function() Actions.ApplyPresetProfile("safe") end })
    TShield:Button({ Title = "Preset: Legit", Callback = function() Actions.ApplyPresetProfile("legit") end })
    TShield:Button({ Title = "Preset: Rage", Callback = function() Actions.ApplyPresetProfile("rage") end })
    TShield:Button({ Title = "Preset: AutoHvH", Callback = function() Actions.ApplyPresetProfile("hvh") end })

    -- 2. Rage & AutoHvH
    local TRage = Window:Tab({ Title = "Rage & AutoHvH", Icon = "crosshair" })
    TRage:Section({ Title = "KX AutoHvH & Ragebot" })
    TRage:Toggle({
        Title = "AutoHvH Mode [H]",
        Desc = "Counters enemy shooters first with 360° Ragebot + Auto-Switch + Shield Peek.",
        Value = State.AutoHvH,
        Callback = function(v)
            State.AutoHvH = v
            if v then State.Ragebot = true; State.SilentAim = true; State.HoloShield = true; CreateHoloShield() end
        end,
    })
    TRage:Toggle({ Title = "Ragebot", Value = State.Ragebot, Callback = function(v) State.Ragebot = v end })
    TRage:Toggle({ Title = "Ragebot 360°", Value = State.Ragebot360, Callback = function(v) State.Ragebot360 = v end })
    TRage:Toggle({ Title = "Ragebot Auto-Switch Gun", Value = State.RagebotAutoSwitch, Callback = function(v) State.RagebotAutoSwitch = v end })
    TRage:Slider({ Title = "Ragebot Fire Rate (SPS)", Step = 1, Value = { Min = 2, Max = 25, Default = State.RagebotRate }, Callback = function(v) State.RagebotRate = v end })
    TRage:Section({ Title = "Silent Aim & AimAssist" })
    TRage:Toggle({ Title = "Silent Aim [X]", Value = State.SilentAim, Callback = function(v) State.SilentAim = v end })
    TRage:Toggle({ Title = "Show Silent FOV", Value = State.SilentAimShowFOV, Callback = function(v) State.SilentAimShowFOV = v end })
    TRage:Slider({ Title = "Silent FOV Radius", Step = 5, Value = { Min = 40, Max = 500, Default = State.SilentAimFOV }, Callback = function(v) State.SilentAimFOV = v end })
    TRage:Slider({ Title = "Silent Hit Chance %", Step = 5, Value = { Min = 10, Max = 100, Default = State.SilentAimHitChance }, Callback = function(v) State.SilentAimHitChance = v end })
    TRage:Slider({ Title = "Headshot %", Step = 5, Value = { Min = 0, Max = 100, Default = State.SilentAimHeadChance }, Callback = function(v) State.SilentAimHeadChance = v end })
    TRage:Toggle({ Title = "Wallbang Scanner", Value = State.SilentAimWallbang, Callback = function(v) State.SilentAimWallbang = v end })
    TRage:Toggle({ Title = "Guard Hostile-Only Fix (No Innocent Kick)", Value = State.SilentAimHostileCheck, Callback = function(v) State.SilentAimHostileCheck = v end })
    TRage:Toggle({ Title = "Camera AimAssist", Value = State.AimAssist, Callback = function(v) State.AimAssist = v end })
    TRage:Toggle({ Title = "Triggerbot", Value = State.Triggerbot, Callback = function(v) State.Triggerbot = v end })
    TRage:Section({ Title = "Melee KillAura & Hitbox" })
    TRage:Toggle({ Title = "Melee KillAura", Value = State.KillAura, Callback = function(v) State.KillAura = v end })
    TRage:Slider({ Title = "KillAura Range", Step = 1, Value = { Min = 5, Max = 18, Default = State.KillAuraRange }, Callback = function(v) State.KillAuraRange = v end })
    TRage:Toggle({ Title = "Expand Enemy Hitbox", Value = State.ExpandHitbox, Callback = function(v) State.ExpandHitbox = v; if not v then Runtime.RestoreHitboxes() end end })
    TRage:Slider({ Title = "Hitbox Size", Step = 1, Value = { Min = 4, Max = 20, Default = State.HitboxSize }, Callback = function(v) State.HitboxSize = v end })
    TRage:Toggle({ Title = "Anti-Riot Shield", Value = State.AntiRiotShield, Callback = function(v) State.AntiRiotShield = v end })

    -- 3. Guns & .combo1
    local TGuns = Window:Tab({ Title = "Guns & .combo1", Icon = "zap" })
    TGuns:Section({ Title = ".combo1 Multi-Gun Burst" })
    TGuns:Button({ Title = "Execute .combo1 Burst [G]", Callback = function() task.spawn(ExecuteCombo1) end })
    TGuns:Toggle({ Title = "Combo Loop", Value = State.ComboLoop, Callback = function(v) State.ComboLoop = v end })
    TGuns:Toggle({ Title = "Combo Auto-Grab Guns", Value = State.ComboAutoGrabGuns, Callback = function(v) State.ComboAutoGrabGuns = v end })
    TGuns:Toggle({ Title = "Show Top-Left .combo1 Pill", Value = State.ShowComboButton, Callback = function(v) State.ShowComboButton = v end })
    TGuns:Section({ Title = "Weapon Grabber (Armory, CrimBase & Yard)" })
    TGuns:Button({ Title = "Grab Full Loadout (Shotgun + AK-47 + MP5)", Callback = function() task.spawn(GrabWeapons, { "Remington 870", "AK-47", "MP5", "M9" }, false) end })
    TGuns:Button({ Title = "Grab Hammer (.hammer)", Callback = function() task.spawn(GrabWeapons, { "Hammer" }, false) end })
    TGuns:Button({ Title = "Grab Crude Knife (.knife)", Callback = function() task.spawn(GrabWeapons, { "Crude Knife" }, false) end })
    TGuns:Button({ Title = "Grab Riot Shield", Callback = function() task.spawn(GrabWeapons, { "Riot Shield" }, false) end })
    TGuns:Toggle({ Title = "Auto-Get Guns on Spawn", Value = State.AutoGetGuns, Callback = function(v) State.AutoGetGuns = v end })
    TGuns:Section({ Title = "Gun Mods & Survival" })
    TGuns:Toggle({ Title = "Enable Gun Mods", Value = State.GunMods, Callback = function(v) State.GunMods = v; ApplyGunModsAll() end })
    TGuns:Slider({ Title = "Fire Rate (SPS)", Step = 1, Value = { Min = 2, Max = 25, Default = State.GunFireRateSPS }, Callback = function(v) State.GunFireRateSPS = v; ApplyGunModsAll() end })
    TGuns:Toggle({ Title = "No Spread", Value = State.GunNoSpread, Callback = function(v) State.GunNoSpread = v; ApplyGunModsAll() end })
    TGuns:Toggle({ Title = "Full Auto", Value = State.GunFullAuto, Callback = function(v) State.GunFullAuto = v; ApplyGunModsAll() end })
    TGuns:Toggle({ Title = "Auto Reload", Value = State.AutoReload, Callback = function(v) State.AutoReload = v end })
    TGuns:Toggle({ Title = "Reload Hot-Swap Gun", Value = State.AutoReloadHotSwap, Callback = function(v) State.AutoReloadHotSwap = v end })
    TGuns:Toggle({ Title = "Auto Armor", Value = State.AutoArmor, Callback = function(v) State.AutoArmor = v end })
    TGuns:Toggle({ Title = "Auto Heal (< Threshold HP)", Value = State.AutoHeal, Callback = function(v) State.AutoHeal = v end })

    -- 4. Prison & Guard
    local TPrison = Window:Tab({ Title = "Prison & Guard", Icon = "lock" })
    TPrison:Section({ Title = "Instant Team Switch" })
    TPrison:Button({ Title = "Switch -> Inmates", Callback = function() Core.SwitchToTeam("Inmates") end })
    TPrison:Button({ Title = "Switch -> Guards", Callback = function() Core.SwitchToTeam("Guards") end })
    TPrison:Button({ Title = "Switch -> Criminals", Callback = function() Core.SwitchToTeam("Criminals") end })
    TPrison:Button({ Title = "Fast Respawn (.re)", Callback = function() Core.PerformFastRespawn() end })
    TPrison:Toggle({ Title = "Auto Fast Respawn", Value = State.FastRespawn, Callback = function(v) State.FastRespawn = v end })
    TPrison:Toggle({ Title = "Keep Position on Respawn", Value = State.KeepPositionOnRespawn, Callback = function(v) State.KeepPositionOnRespawn = v end })
    TPrison:Section({ Title = "Guard Automation" })
    TPrison:Toggle({ Title = "Auto-Arrest Near (Unseated Only)", Value = State.AutoArrest, Callback = function(v) State.AutoArrest = v end })
    TPrison:Toggle({ Title = "Show Arrest Cooldown Bar", Value = State.AutoArrestCooldownBar, Callback = function(v) State.AutoArrestCooldownBar = v end })
    TPrison:Toggle({ Title = "Auto-Taze Near", Value = State.AutoTaze, Callback = function(v) State.AutoTaze = v end })
    TPrison:Button({ Title = "Bulk Arrest All Arrestable", Callback = function() Actions.RunArrestTargets(ResolveTargetPlayers("others")) end })
    TPrison:Button({ Title = "Bulk Tase All Arrestable", Callback = function() Actions.RunTaseTargets(ResolveTargetPlayers("others")) end })
    TPrison:Section({ Title = "Prison World" })
    TPrison:Toggle({ Title = "Open All Doors Locally", Value = State.OpenAllDoors, Callback = function(v) State.OpenAllDoors = v; if not v then Runtime.RestoreDoors() end end })
    TPrison:Toggle({ Title = "Fence Godmode", Value = State.FenceGodmode, Callback = function(v) State.FenceGodmode = v; if not v then Runtime.RestoreFences() end end })
    TPrison:Toggle({ Title = "Always Show Backpack", Value = State.AlwaysBackpack, Callback = function(v) State.AlwaysBackpack = v end })
    TPrison:Toggle({ Title = "Auto-Criminal if Arrested", Value = State.AutoCriminalOnArrest, Callback = function(v) State.AutoCriminalOnArrest = v end })
    TPrison:Toggle({ Title = "Auto-Detonate C4", Value = State.AutoDetonateC4, Callback = function(v) State.AutoDetonateC4 = v end })

    -- 5. Cars & SavedCars
    local TCars = Window:Tab({ Title = "Cars & Target", Icon = "car" })
    TCars:Section({ Title = "KX Saved Cars (.savecar)" })
    TCars:Button({ Title = "Save 1 Car (.savecar 1)", Callback = function() SaveCarsCommand(1) end })
    TCars:Button({ Title = "Save 2 Cars (.savecar 2)", Callback = function() SaveCarsCommand(2) end })
    TCars:Button({ Title = "Spawn & Enter Nearest Car", Callback = function() SpawnAndEnterNearestCar() end })
    TCars:Toggle({ Title = "Wheel Aura (.wheelaura)", Value = State.WheelAura, Callback = function(v) State.WheelAura = v end })
    TCars:Toggle({ Title = "Vehicle Fly", Value = State.VehicleFly, Callback = function(v) State.VehicleFly = v end })
    TCars:Slider({ Title = "Vehicle Fly Speed", Step = 5, Value = { Min = 25, Max = 140, Default = State.VehicleFlySpeed }, Callback = function(v) State.VehicleFlySpeed = v end })
    TCars:Toggle({ Title = "Vehicle Speed Mod", Value = State.VehicleSpeedMod, Callback = function(v) State.VehicleSpeedMod = v end })
    TCars:Slider({ Title = "Vehicle Speed Multiplier", Step = 0.25, Value = { Min = 1.0, Max = 4.0, Default = State.VehicleSpeedMult }, Callback = function(v) State.VehicleSpeedMult = v end })
    TCars:Section({ Title = "Target Player Actions" })
    local targetDropdown = TCars:Dropdown({
        Title = "Target Player",
        Values = BuildPlayerListStrings(),
        Value = BuildPlayerListStrings()[1],
        Callback = function(v) UI.SelectedTargetName = NormalizeDropdownValue(v) end,
    })
    UI.SelectedTargetName = BuildPlayerListStrings()[1] or ""
    TCars:Button({
        Title = "Refresh Player List",
        Callback = function()
            local list = BuildPlayerListStrings()
            if targetDropdown and targetDropdown.Refresh then pcall(function() targetDropdown:Refresh(list) end) end
            UI.SelectedTargetName = list[1] or ""
        end,
    })
    local function getPickedTarget()
        local t = ResolveTargetPlayers(UI.SelectedTargetName)[1]
        if not t then Notify("Target", "Select a valid player first!", 2) end
        return t
    end
    TCars:Button({ Title = "Bring Target (.bring)", Callback = function() local t = getPickedTarget(); if t then ExecuteCarTargetAction(t, "bring") end end })
    TCars:Button({ Title = "Force Criminal (.forcecrim)", Callback = function() local t = getPickedTarget(); if t then ExecuteCarTargetAction(t, "forcecrim") end end })
    TCars:Button({ Title = "Vehicle Void (.void)", Callback = function() local t = getPickedTarget(); if t then ExecuteCarTargetAction(t, "void") end end })
    TCars:Button({ Title = "Car Fling Target (.fling)", Callback = function() local t = getPickedTarget(); if t then ExecuteCarTargetAction(t, "fling") end end })
    TCars:Button({ Title = "Teleport To Target", Callback = function() local t = getPickedTarget(); if t then Commands.Execute("goto " .. t.Name) end end })
    TCars:Button({ Title = "Spectate Target (.view)", Callback = function() local t = getPickedTarget(); if t then Commands.Execute("view " .. t.Name) end end })
    TCars:Button({ Title = "Stop Spectate (.unview)", Callback = function() Commands.Execute("unview") end })
    TCars:Button({ Title = "Toggle LoopKill on Target", Callback = function()
        local t = getPickedTarget()
        if not t then return end
        if State.LoopKillTargets[t.UserId] then
            State.LoopKillTargets[t.UserId] = nil
            Notify("LoopKill", "Stopped LoopKill on " .. t.Name, 2)
        else
            State.LoopKillTargets[t.UserId] = true
            Notify("LoopKill", "LoopKilling " .. t.Name, 2)
        end
    end })

    -- 6. Movement
    local TMove = Window:Tab({ Title = "Movement", Icon = "wind" })
    TMove:Section({ Title = "Flight, Speed & Stealth" })
    TMove:Toggle({ Title = "Character Fly [F]", Value = State.Fly, Callback = function(v) State.Fly = v end })
    TMove:Slider({ Title = "Fly Speed", Step = 5, Value = { Min = 20, Max = 120, Default = State.FlySpeed }, Callback = function(v) State.FlySpeed = v end })
    TMove:Toggle({ Title = "Enable WalkSpeed Mod", Value = State.MaxSpeed, Callback = function(v) State.MaxSpeed = v end })
    TMove:Dropdown({
        Title = "WalkSpeed Mode",
        Values = { "RegionSafe", "Custom", "AlwaysSprint" },
        Value = State.MaxSpeedMode,
        Callback = function(v) local p = NormalizeDropdownValue(v); if p ~= "" then State.MaxSpeedMode = p end end,
    })
    TMove:Slider({ Title = "Custom WalkSpeed", Step = 2, Value = { Min = 16, Max = 65, Default = State.CustomWalkSpeed }, Callback = function(v) State.CustomWalkSpeed = v end })
    TMove:Toggle({ Title = "JumpPower Override", Value = State.JumpPowerEnabled, Callback = function(v) State.JumpPowerEnabled = v; Core.BypassAntiJump() end })
    TMove:Slider({ Title = "JumpPower", Step = 5, Value = { Min = 50, Max = 110, Default = State.JumpPower }, Callback = function(v) State.JumpPower = v end })
    TMove:Toggle({ Title = "Infinite Jump", Value = State.InfiniteJump, Callback = function(v) State.InfiniteJump = v end })
    TMove:Toggle({ Title = "Noclip [N]", Value = State.Noclip, Callback = function(v) State.Noclip = v; if not v then Runtime.RestoreNoclip() end end })
    TMove:Toggle({ Title = "FE Invisible [V] (Clean Translucent)", Value = State.FEInvisible, Callback = function(v) Stealth.SetFEInvisibleState(v) end })
    TMove:Section({ Title = "Map Teleports" })
    local locNames = BuildLocationListStrings()
    UI.SelectedTeleportLoc = locNames[1] or "Prison Yard"
    TMove:Dropdown({
        Title = "Select Location",
        Values = locNames,
        Value = UI.SelectedTeleportLoc,
        Callback = function(v) UI.SelectedTeleportLoc = NormalizeDropdownValue(v) end,
    })
    TMove:Button({ Title = "Teleport to Location", Callback = function() Actions.TeleportToLocation(UI.SelectedTeleportLoc) end })

    -- 7. ESP & Admin
    local TVis = Window:Tab({ Title = "ESP & Admin", Icon = "eye" })
    TVis:Section({ Title = "Role-Colored ESP & Combat VFX" })
    TVis:Toggle({ Title = "Player ESP (Cap 30)", Value = State.ESP, Callback = function(v) State.ESP = v end })
    TVis:Toggle({ Title = "ESP Highlights", Value = State.ESPHighlight, Callback = function(v) State.ESPHighlight = v end })
    TVis:Toggle({ Title = "Hide Teammates", Value = State.ESPHideTeam, Callback = function(v) State.ESPHideTeam = v end })
    TVis:Toggle({ Title = "C4 ESP", Value = State.C4ESP, Callback = function(v) State.C4ESP = v end })
    TVis:Toggle({ Title = "Bullet Tracers", Value = State.BulletTracers, Callback = function(v) State.BulletTracers = v end })
    TVis:Toggle({ Title = "Crosshair Hitmarker & Sounds", Value = State.Hitmarker, Callback = function(v) State.Hitmarker = v; State.HitSound = v end })
    TVis:Toggle({ Title = "3-Line Transparent Mini-Killfeed", Value = State.ShowMiniKillfeed, Callback = function(v) State.ShowMiniKillfeed = v end })
    TVis:Toggle({ Title = "Anomaly Alerts (Speed / Car-TP)", Value = State.CheaterAlerts, Callback = function(v) State.CheaterAlerts = v; State.CarTPAlerts = v end })
    TVis:Section({ Title = "KX Admin & Session" })
    TVis:Toggle({ Title = "Show Top-Left ⌘ CMD Pill", Value = State.ShowCommandPill, Callback = function(v) State.ShowCommandPill = v end })
    TVis:Toggle({ Title = "Chat Commands (. / ;)", Value = State.ChatCommands, Callback = function(v) State.ChatCommands = v end })
    if TVis.Input then
        pcall(function()
            TVis:Input({
                Title = "Run KX Command",
                Placeholder = ".savecar 2, .fc all, .autohvh",
                Callback = function(v) if Trim(v) ~= "" then Commands.Execute(v) end end,
            })
        end)
    end
    TVis:Button({ Title = "Rejoin Server (.rj)", Callback = function() Actions.RejoinServer() end })
    TVis:Button({ Title = "Server Hop (.shop)", Callback = function() Actions.ServerHop() end })
    TVis:Button({ Title = "Unload Script Cleanly", Callback = function() if Env.PrisonLife2026Cleanup then Env.PrisonLife2026Cleanup() end end })
end

local function BuildFallbackUI()
    local gui = TrackInstance(Instance.new("ScreenGui"))
    gui.Name = "PL2026_FallbackUI"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = GetSafeGuiParent()
    UI.FallbackGui = gui

    local panel = Instance.new("Frame")
    panel.Position = UDim2.new(0.5, -165, 0.5, -135)
    panel.Size = UDim2.fromOffset(330, 270)
    panel.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
    panel.BorderSizePixel = 0
    panel.Parent = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    MakeDraggable(panel)

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 32)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.GothamBold
    header.TextSize = 13
    header.TextColor3 = Color3.fromRGB(95, 225, 255)
    header.Text = "Prison Life KX Pro v4.0 (Fallback)"
    header.Parent = panel

    local scroll = Instance.new("ScrollingFrame")
    scroll.Position = UDim2.fromOffset(10, 36)
    scroll.Size = UDim2.new(1, -20, 1, -46)
    scroll.CanvasSize = UDim2.fromOffset(0, 420)
    scroll.ScrollBarThickness = 4
    scroll.BackgroundTransparency = 1
    scroll.Parent = panel
    local list = Instance.new("UIListLayout", scroll)
    list.Padding = UDim.new(0, 6)

    local function addRow(label, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -6, 0, 30)
        b.BackgroundColor3 = Color3.fromRGB(28, 36, 52)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Text = label
        b.Parent = scroll
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        b.Activated:Connect(onClick)
    end

    addRow("Preset: AutoHvH", function() Actions.ApplyPresetProfile("hvh") end)
    addRow("Preset: Safe Mode", function() Actions.ApplyPresetProfile("safe") end)
    addRow("Grab Guns (.guns)", function() Commands.Execute("guns") end)
    addRow("Execute .combo1", function() Commands.Execute("combo1") end)
    addRow("Toggle Holo-Shield [B]", function() Commands.Execute("shield") end)
    addRow("Toggle Silent Aim [X]", function() Commands.Execute("silentaim") end)
    addRow("Save 2 Cars (.savecar 2)", function() SaveCarsCommand(2) end)
    addRow("Toggle Fly [F]", function() Commands.Execute("fly") end)
    addRow("Toggle ESP", function() Commands.Execute("esp") end)
    addRow("Unload Script", function() if Env.PrisonLife2026Cleanup then Env.PrisonLife2026Cleanup() end end)
end

local uiOk = false
if WindUI and WindUI.CreateWindow then
    uiOk = pcall(BuildWindUI)
end
if not uiOk then
    BuildFallbackUI()
end

SetupGunControllerHooks()
ApplyGunModsAll()
Core.SyncRemoteConnectionBypasses()
Notify("Prison Life KX Pro v4.0", "Loaded cleanly! Use Top-Left ⚡ .combo1 or ⌘ CMD pill.", 3.5)

-- ============================================================================
-- // SECTION 15: CLEANUP & COMPLETE STATE RESTORATION
-- ============================================================================
Env.PrisonLife2026Cleanup = function()
    Env.PrisonLife2026Running = false

    pcall(DestroyHoloShield)
    pcall(Stealth.StopFEInvisible)
    pcall(Runtime.DestroyFlyMovers)
    pcall(Runtime.RestoreNoclip)
    pcall(Runtime.RestoreDoors)
    pcall(Runtime.RestoreHitboxes)
    pcall(Runtime.RestoreFences)
    pcall(function() UpdateVehicleWheelAura(nil) end)
    pcall(Visuals.ClearAllESP)

    for _, c in ipairs(Core.DisabledTaseConns) do pcall(function() c:Enable() end) end
    for _, c in ipairs(Core.DisabledArrestConns) do pcall(function() c:Enable() end) end

    local myHum = GetHumanoid(LocalPlayer.Character)
    if myHum then pcall(function() Camera.CameraSubject = myHum end) end

    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}

    for _, inst in ipairs(CreatedInstances) do
        pcall(function() inst:Destroy() end)
    end
    CreatedInstances = {}

    if UI.Window and UI.Window.Destroy then
        pcall(function() UI.Window:Destroy() end)
    end
    Env.PrisonLife2026Cleanup = nil
end
