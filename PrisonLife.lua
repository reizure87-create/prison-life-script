--[[
    ================================================================================
    🚔 PRISON LIFE — ULTIMATE 2026 SCRIPT (PC & MOBILE) [v7.0 APEX KX PRO EDITION]
    ================================================================================
    Target Game : Prison Life (PlaceId: 155615604 | UniverseId: 73885730)
    Patch Target: Late 2026 ("Sniper Update!" — M700, Revolver, Light Vest, Remotes)
    Platform    : PC (Keyboard/Mouse + Hotkeys) & Mobile (Clean Clutter-Free HUD)
    UI Library  : Clean 7-Tab WindUI (with Built-In Native Touch/PC UI Fallback)

    Upgrades in v7.0 (Apex KX Pro Overhaul):
      1. Zero Connection Leaks & Self-Healing Hooks:
         - Scoped Player/Character lifecycle listeners (`App.CreateScope`) & Watchers.
         - Live `Workspace.CurrentCamera` updater, 4-source PC+Mobile `GunController`
           hooking with `.rehook` recovery & live `Bullet` hook verification, plus
           `ActionArea`-centered synthetic firing (`SilentAimLead` prediction).
      2. Mobile & PC HUD Polish:
         - Drag-guarded HUD pills (`WasDraggedAt`) clamped safely inside viewport.
         - Top-center mobile Command Bar/Suggestions & jump-adjacent vertical Fly Pad.
      3. Complete Defense & World Awareness:
         - `AntiCarBring` passenger-seat snatch protection, non-yielding `AutoArmor`,
           fixed `HoloShield` pre-rotation `SavedCF` order & 3 `ShieldVisualStyle`s.
         - Guard-aware Inmate threat ESP, 3px Health Bars, and dropped `ItemESP`.
      4. Full KX Command Parity, Kits & TextChatService:
         - Working `.fencegod`/`.noclip`/`.esp`/batch car ops, `.target`/`.refill`/
           `.rehook`/`.anticarbring`/`.itemesp`/`.status`, Weapon Kits & `TextChatService`.
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
    if not guiObj or guiObj:GetAttribute("DragHooked") then return end
    guiObj:SetAttribute("DragHooked", true)
    local dragging, activeInput, dragStart, startPos, movedDist = false, nil, nil, nil, 0

    AddConnection(guiObj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            activeInput = input
            dragStart = input.Position
            startPos = guiObj.Position
            movedDist = 0
        end
    end))

    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if not dragging or not dragStart or not startPos then return end
        local isValidMove = (input == activeInput and input.UserInputType == Enum.UserInputType.Touch)
            or (input.UserInputType == Enum.UserInputType.MouseMovement)
        if not isValidMove then return end
        local delta = input.Position - dragStart
        movedDist = math.max(movedDist, delta.Magnitude)
        if movedDist > 6 then
            guiObj:SetAttribute("WasDraggedAt", os.clock())
        end
        local cam = Camera or Workspace.CurrentCamera
        local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
        local sz = guiObj.AbsoluteSize
        local ap = guiObj.AnchorPoint
        local minX = sz.X * ap.X + 4
        local maxX = math.max(minX, vp.X - sz.X * (1 - ap.X) - 4)
        local minY = sz.Y * ap.Y + 4
        local maxY = math.max(minY, vp.Y - sz.Y * (1 - ap.Y) - 4)
        local targetX = math.clamp(startPos.X.Scale * vp.X + startPos.X.Offset + delta.X, minX, maxX)
        local targetY = math.clamp(startPos.Y.Scale * vp.Y + startPos.Y.Offset + delta.Y, minY, maxY)
        guiObj.Position = UDim2.new(
            startPos.X.Scale, targetX - startPos.X.Scale * vp.X,
            startPos.Y.Scale, targetY - startPos.Y.Scale * vp.Y
        )
    end))

    AddConnection(UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if movedDist > 6 then
                guiObj:SetAttribute("WasDraggedAt", os.clock())
            end
            dragging = false
            activeInput = nil
        end
    end))
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

AddConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local cam = Workspace.CurrentCamera
    if cam then
        Camera = cam
    end
end))

-- // Central Configuration State
local State = {
    -- Anti-Ban Protection (Prevents Error Code 600 30-Day Experience Bans)
    AntiBanSafeMode = true,

    -- 5-Mode 3D Bullet Shield & Anti-Aim (Zero Ray-Blocking Ground Halo)
    HoloShield = false,
    ShieldMode = "UndergroundPeek", -- "UndergroundPeek", "Hybrid", "AntiLockDesync", "RiotOnly", "FEGhost"
    ShieldVisualStyle = "CyberHex", -- "CyberHex", "NeonRing", "Minimal"
    ShieldSize = 4.2,
    ShieldDepth = 10.5,             -- Depth (studs) buried under solid map concrete
    ShieldTransparency = 0.72,      -- Non-blocking ground ring opacity
    ShieldShowVisual = true,
    ShieldAutoEquip = false,        -- Does NOT forcefully unequip your gun by default
    ShieldAutoFaceShooter = false,
    ShieldSpinBlock = false,
    ShieldSpinSpeed = 18,
    DesyncJitterRadius = 5.5,
    HoloShieldMaxHP = 180,

    -- AutoHvH, Ragebot & .combo1 Burst
    AutoHvH = false,
    HvHTargetExploitersFirst = true,
    AutoHvHReactiveEvade = true,
    Ragebot = false,
    Ragebot360 = true,
    RagebotAutoSwitch = true,
    RagebotRate = 14,
    RagebotPeekShield = false,      -- Disabled by default: fires via restored CFrame/origin without leaving body exposed!
    FocusTargetUserId = nil,        -- Priority target UserId set via .target <plr>

    ComboAutoGrabGuns = true,
    ComboReEquipShield = false,
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
    SilentAimLead = true,           -- Velocity lead compensation on moving targets
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
    KillAuraAutoMelee = false,      -- Optionally plays local swing/activates held melee tool
    KillAuraWhitelist = {},
    LoopKillTargets = {},

    ExpandHitbox = false,
    HitboxSize = 9,

    AntiRiotShield = false,
    VehicleWallbang = false,

    -- Weapons & Gun Mods
    AutoGetGuns = false,
    AutoGetGunsSelection = { "Remington 870", "AK-47", "MP5" },
    AutoLoadoutKit = "None",        -- "None", "Light", "Sniper", "Riot", "Full"
    AutoPickupDropped = false,
    AutoArmor = false,
    AutoReload = true,
    AutoReloadHotSwap = false,

    GunMods = false,
    GunFireRateSPS = 14,
    GunNoSpread = true,
    GunFullAuto = true,
    GunInfiniteRange = true,
    GunZeroChargeTime = true,

    AutoHeal = false,
    AutoHealThreshold = 80,

    -- Prison, Guards & Teams
    AutoArrest = false,
    AutoArrestRange = 10,
    AutoArrestHandCheck = false,
    AutoArrestEquipHandcuffs = true,
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
    AntiCarBring = true,            -- Prevents exploits from snatching you into passenger seats
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
    ESPHighlightMax = 30,
    ESPDetailDistance = 140,
    ESPNameTag = true,
    ESPHealth = true,
    ESPHealthBar = true,
    ESPDistance = true,
    ESPWeapon = true,
    ESPStatusFlags = true,
    ESPHideTeam = false,
    C4ESP = false,
    ItemESP = false,

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

    -- KX Command Pill, Chat Commands & Profile Persistence
    ShowCommandPill = true,
    ChatCommands = true,
    ConfigAutoLoad = true,
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
-- // SECTION 1: CORE ARCHITECT NAMESPACE, WORLD CACHE & TARGET VALIDATION
-- ============================================================================
local App = {
    Scheduler = {
        Players = {},
        PlayersUpdated = 0,
        Paused = false,
    },
    WorldCache = {
        Cars = setmetatable({}, { __mode = "k" }),      -- [Model] = { drv, pass, nonWheels, wheels }
        Doors = {},                                     -- array of BaseParts in Workspace.Doors
        DoorSet = setmetatable({}, { __mode = "k" }),
        Fences = {},                                    -- array of TouchTransmitter BaseParts in Prison_Fences
        FenceSet = setmetatable({}, { __mode = "k" }),
        ArmorParts = {},                                -- cached armor giver BaseParts (no 0.16s Workspace scan)
        ArmorPartSet = setmetatable({}, { __mode = "k" }),
        Dropped = setmetatable({}, { __mode = "k" }),   -- [Tool/Model] = true for dropped Tools
        DroppedItems = setmetatable({}, { __mode = "k" }), -- [Instance] = { obj, part, name } for ItemESP
        Players = setmetatable({}, { __mode = "k" }),   -- [Player] = { char, hrp, hum, head, animator, riotShield, tool, graceUntil }
        PlayerScopes = setmetatable({}, { __mode = "k" }), -- [Player] = { playerScope, charScope }
        LocalParts = {},                                -- cached local character BaseParts for Noclip
        LocalCollideOrig = setmetatable({}, { __mode = "k" }),
        GiversByName = {},                              -- [lowerToolName] = { giver, ... }
        GiversAll = {},
        GiverBuiltAt = 0,
        CarContainer = nil,
        DoorsFolder = nil,
        VFXPoolFolder = nil,
        ShieldModel = nil,
    },
    ToolArbiter = {
        Owner = nil,
        Priority = 0,
        Until = 0,
    },
    Anomaly = {
        Flagged = {},       -- [UserId] = expiresAt
        StrikeInfo = {},    -- [UserId] = { count, streak, lastAlert, lastStrike }
        GraceUntil = {},    -- [UserId] = os.clock() + graceSec
        LastAttackers = {}, -- [Player] = os.clock()
    },
    Persistence = {},
}

function App.CreateScope()
    local scope = { conns = {}, insts = {} }
    function scope:Add(conn)
        if conn then table.insert(self.conns, conn) end
        return conn
    end
    function scope:Track(inst)
        if inst then table.insert(self.insts, inst) end
        return inst
    end
    function scope:Clean()
        for i = #self.conns, 1, -1 do
            local c = self.conns[i]
            self.conns[i] = nil
            if c then pcall(function() c:Disconnect() end) end
        end
        for i = #self.insts, 1, -1 do
            local inst = self.insts[i]
            self.insts[i] = nil
            if inst then pcall(function() inst:Destroy() end) end
        end
    end
    return scope
end

function App.ToolArbiter.Acquire(owner, priority, duration)
    local now = os.clock()
    if App.ToolArbiter.Owner ~= owner and now < App.ToolArbiter.Until and priority < App.ToolArbiter.Priority then
        return false
    end
    App.ToolArbiter.Owner = owner
    App.ToolArbiter.Priority = priority
    App.ToolArbiter.Until = now + (duration or 0.18)
    return true
end

function App.ToolArbiter.Release(owner)
    if App.ToolArbiter.Owner == owner then
        App.ToolArbiter.Owner = nil
        App.ToolArbiter.Priority = 0
        App.ToolArbiter.Until = 0
    end
end

function App.ToolArbiter.CanUse(owner, priority)
    local now = os.clock()
    if App.ToolArbiter.Owner == owner or now >= App.ToolArbiter.Until then
        return true
    end
    return priority > App.ToolArbiter.Priority
end

function App.GetCachedPlayerInfo(plr)
    return plr and App.WorldCache.Players[plr] or nil
end

function App.IsPlayerExploiterThreat(plr)
    if not plr then return false end
    local now = os.clock()
    if (App.Anomaly.Flagged[plr.UserId] or 0) > now then return true end
    local info = App.WorldCache.Players[plr]
    local hrp = info and info.hrp
    if hrp and hrp.Parent then
        if hrp.AssemblyAngularVelocity.Magnitude > 55 then return true end
        if hrp.Position.Y < 86 and hrp.Position.Y > -30 then return true end
    end
    return false
end

local function GetCharacter(plr)
    local info = App.WorldCache.Players[plr]
    if info and info.char and info.char.Parent then return info.char end
    return plr and plr.Character
end

local function GetRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
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
    if (tonumber(char:GetAttribute("Armor")) or 0) > 0 or (tonumber(char:GetAttribute("VestHealth")) or 0) > 0 then
        return true
    end
    if char:FindFirstChild("Light Vest") or char:FindFirstChild("Armor") or char:FindFirstChild("Vest") then
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

-- CRITICAL FIX:
-- Lethal weapons (forArrest == false) on Guards MUST ONLY shoot Inmates with `Hostile == true`!
-- Shooting a Trespassing-only inmate triggers "Do not kill innocent people!" and kicks you off Guards!
-- Non-lethal arrest/taze (forArrest == true) allows Criminals + Hostile/Trespassing/Tased Inmates.
local function IsValidCombatTarget(plr, requireHostileForGuard, whitelistTbl, forArrest)
    if not plr or plr == LocalPlayer then return false end
    if whitelistTbl and whitelistTbl[plr.UserId] then return false end
    if not plr.Team or plr.Team == Teams:FindFirstChild("Neutral") then return false end

    local info = App.WorldCache.Players[plr]
    local char = (info and info.char and info.char.Parent and info.char) or plr.Character
    if not char or char:FindFirstChildOfClass("ForceField") then return false end

    local hum = (info and info.hum and info.hum.Parent == char and info.hum) or GetHumanoid(char)
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
    local wc = App.WorldCache
    if (State.VehicleWallbang or State.SilentAimWallbang) and wc.CarContainer and wc.CarContainer.Parent then
        table.insert(ignore, wc.CarContainer)
    end
    if State.OpenAllDoors and wc.DoorsFolder and wc.DoorsFolder.Parent then
        table.insert(ignore, wc.DoorsFolder)
    end
    if wc.VFXPoolFolder then
        table.insert(ignore, wc.VFXPoolFolder)
    end
    if wc.ShieldModel and wc.ShieldModel.Parent then
        table.insert(ignore, wc.ShieldModel)
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
    Vector3.new(0, 1.25, 0), Vector3.new(0, 2.4, 0),
    Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
    Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
    Vector3.new(0, -0.6, 0),
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
    local now = os.clock()

    local screenCenter = Vector2.new(640, 360)
    local activeCam = Camera or Workspace.CurrentCamera
    if activeCam then
        Camera = activeCam
        screenCenter = Vector2.new(activeCam.ViewportSize.X * 0.5, activeCam.ViewportSize.Y * 0.5)
    end
    if not IsMobile and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        local mPos = UserInputService:GetMouseLocation()
        screenCenter = Vector2.new(mPos.X, mPos.Y)
    end

    local snapshot = App.Scheduler.Players
    if #snapshot == 0 then
        snapshot = Players:GetPlayers()
        App.Scheduler.Players = snapshot
    end

    local focusId = State.FocusTargetUserId
    local candidates = {}
    for _, plr in ipairs(snapshot) do
        if IsValidCombatTarget(plr, requireHostile, State.KillAuraWhitelist, false) then
            local info = App.WorldCache.Players[plr]
            local char = (info and info.char) or plr.Character
            local part = (forceHead and info and info.head and info.head.Parent == char and info.head) or PickAimPart(char, forceHead)
            if part then
                local worldDist = (part.Position - baseOrigin).Magnitude
                if worldDist <= maxRange then
                    local score = worldDist
                    local validScreen = true
                    if not use360 and activeCam then
                        local screenPos, onScreen = activeCam:WorldToViewportPoint(part.Position)
                        if not onScreen or screenPos.Z <= 0 then
                            validScreen = false
                        else
                            score = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                            if score > fovRadius then validScreen = false end
                        end
                    end
                    if validScreen then
                        -- Prioritize manual .target focus first, then AutoHvH threats
                        if focusId and plr.UserId == focusId then
                            score = score * 0.08
                        end
                        -- In AutoHvH mode, strongly prioritize cheaters/exploiters, recent shooters & armed threats!
                        if prioritizeArmed then
                            local eq = (info and info.tool and info.tool.Parent == char and info.tool) or char:FindFirstChildOfClass("Tool")
                            if eq and (eq:GetAttribute("FireRate") or eq:GetAttribute("ToolType") == "Gun") then
                                score = score * 0.45
                            end
                            if (App.Anomaly.LastAttackers[plr] or 0) > (now - 4.0) then
                                score = score * 0.35
                            end
                            if State.HvHTargetExploitersFirst and App.IsPlayerExploiterThreat(plr) then
                                score = score * 0.22
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

-- Clean Bottom-Center Status Strip (Above Hotbar — NEVER covers your character or mobile hotbar!)
local BottomStatusStrip = Instance.new("Frame")
BottomStatusStrip.Name = "PL2026_BottomStrip"
BottomStatusStrip.AnchorPoint = Vector2.new(0.5, 1)
BottomStatusStrip.Position = UDim2.new(0.5, 0, 1, IsMobile and -88 or -78)
BottomStatusStrip.Size = UDim2.fromOffset(300, 40)
BottomStatusStrip.BackgroundTransparency = 1
BottomStatusStrip.Parent = OverlayGui
local StripLayout = Instance.new("UIListLayout", BottomStatusStrip)
StripLayout.Padding = UDim.new(0, 3)
StripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
StripLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

local ShieldBarHolder = Instance.new("Frame")
ShieldBarHolder.Name = "HoloShieldBar"
ShieldBarHolder.Size = UDim2.fromOffset(174, 16)
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
ShieldBarText.TextSize = 10
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

local VFXPools = {
    Tracers = {},
    TracerIdx = 0,
    TracerCount = 32,
    Damages = {},
    DamageIdx = 0,
    DamageCount = 14,
    Sparks = {},
    SparkIdx = 0,
    SparkCount = 10,
}

do
    local parkedCF = CFrame.new(0, -9000, 0)
    for i = 1, VFXPools.TracerCount do
        local p = Instance.new("Part")
        p.Name = "PL2026_Tracer"
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.CastShadow = false
        p.Material = Enum.Material.Neon
        p.Size = Vector3.new(0.08, 0.08, 1)
        p.Transparency = 1
        p.CFrame = parkedCF
        p.Parent = VFXPool
        VFXPools.Tracers[i] = { part = p, gen = 0, tween = nil }
    end

    for i = 1, VFXPools.DamageCount do
        local anchor = Instance.new("Part")
        anchor.Name = "PL2026_DmgAnchor"
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false
        anchor.CastShadow = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(0.2, 0.2, 0.2)
        anchor.CFrame = parkedCF
        anchor.Parent = VFXPool

        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.fromOffset(76, 26)
        bb.AlwaysOnTop = true
        bb.Enabled = false
        bb.Adornee = anchor
        bb.Parent = anchor

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextStrokeTransparency = 0.15
        lbl.Text = ""
        lbl.Parent = bb

        VFXPools.Damages[i] = { part = anchor, bb = bb, lbl = lbl, gen = 0, tween = nil }
    end

    for i = 1, VFXPools.SparkCount do
        local p = Instance.new("Part")
        p.Name = "PL2026_ShieldSpark"
        p.Shape = Enum.PartType.Ball
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.CastShadow = false
        p.Material = Enum.Material.Neon
        p.Color = Color3.fromRGB(255, 230, 80)
        p.Size = Vector3.new(0.45, 0.45, 0.45)
        p.Transparency = 1
        p.CFrame = parkedCF
        p.Parent = VFXPool
        VFXPools.Sparks[i] = { part = p, gen = 0, tween = nil }
    end
end

local function SpawnBulletTracer(origin, hitPos, isRage)
    if not State.BulletTracers or typeof(origin) ~= "Vector3" or typeof(hitPos) ~= "Vector3" then return end
    local dist = (hitPos - origin).Magnitude
    if dist < 0.5 or dist > 4000 then return end

    VFXPools.TracerIdx = (VFXPools.TracerIdx % VFXPools.TracerCount) + 1
    local slot = VFXPools.Tracers[VFXPools.TracerIdx]
    local p = slot.part
    if not p or not p.Parent then return end

    slot.gen = slot.gen + 1
    local token = slot.gen
    if slot.tween then pcall(function() slot.tween:Cancel() end) end

    p.Color = isRage and Color3.fromRGB(255, 55, 85) or Color3.fromRGB(0, 225, 255)
    p.Transparency = 0.15
    p.Size = Vector3.new(0.08, 0.08, dist)
    p.CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -dist * 0.5)

    local fade = clamp(tonumber(State.TracerFadeTime) or 0.22, 0.08, 0.6)
    local tw = TweenService:Create(p, TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0.015, 0.015, dist),
    })
    slot.tween = tw
    tw:Play()
    task.delay(fade + 0.05, function()
        if slot.gen == token and p and p.Parent then
            p.Transparency = 1
            p.CFrame = CFrame.new(0, -9000, 0)
        end
    end)
end

local function SpawnDamageNumber(worldPos, dmg, isHead)
    if not State.DamageNumbers or typeof(worldPos) ~= "Vector3" then return end
    local amt = round(tonumber(dmg) or 0)
    if amt <= 0 then return end

    VFXPools.DamageIdx = (VFXPools.DamageIdx % VFXPools.DamageCount) + 1
    local slot = VFXPools.Damages[VFXPools.DamageIdx]
    local anchor = slot.part
    if not anchor or not anchor.Parent then return end

    slot.gen = slot.gen + 1
    local token = slot.gen
    if slot.tween then pcall(function() slot.tween:Cancel() end) end

    local startPos = worldPos + Vector3.new((math.random() - 0.5) * 1.1, 1.2, (math.random() - 0.5) * 1.1)
    anchor.CFrame = CFrame.new(startPos)
    slot.lbl.TextSize = isHead and 15 or 13
    slot.lbl.TextColor3 = isHead and Color3.fromRGB(255, 75, 75) or Color3.fromRGB(255, 235, 110)
    slot.lbl.Text = "-" .. tostring(amt) .. (isHead and " HS" or "")
    slot.bb.Enabled = true

    local tw = TweenService:Create(anchor, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = startPos + Vector3.new(0, 2.4, 0),
    })
    slot.tween = tw
    tw:Play()
    task.delay(0.54, function()
        if slot.gen == token and anchor and anchor.Parent then
            slot.bb.Enabled = false
            anchor.CFrame = CFrame.new(0, -9000, 0)
        end
    end)
end

local function SpawnShieldSparkVFX(hitPos)
    if not State.ShieldHitVFX or typeof(hitPos) ~= "Vector3" then return end
    pcall(function() RicochetSound:Play() end)

    VFXPools.SparkIdx = (VFXPools.SparkIdx % VFXPools.SparkCount) + 1
    local slot = VFXPools.Sparks[VFXPools.SparkIdx]
    local p = slot.part
    if not p or not p.Parent then return end

    slot.gen = slot.gen + 1
    local token = slot.gen
    if slot.tween then pcall(function() slot.tween:Cancel() end) end

    p.Size = Vector3.new(0.45, 0.45, 0.45)
    p.Transparency = 0.15
    p.CFrame = CFrame.new(hitPos)

    local tw = TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(1.4, 1.4, 1.4),
        Transparency = 1,
    })
    slot.tween = tw
    tw:Play()
    task.delay(0.18, function()
        if slot.gen == token and p and p.Parent then
            p.Transparency = 1
            p.CFrame = CFrame.new(0, -9000, 0)
        end
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
    BulletHookFiredCount = 0,
    ActionArea = nil,
    HookSource = "none",
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
                if HealthWatchers[hum] == conn then HealthWatchers[hum] = nil end
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
        task.delay(0.5, function()
            if HealthWatchers[hum] == conn then HealthWatchers[hum] = nil end
            if conn and conn.Connected then conn:Disconnect() end
        end)
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

local function GetClosureConstantsSafe(fn)
    local gc = (debug and debug.getconstants) or getconstants
    if type(fn) ~= "function" or type(gc) ~= "function" then return nil end
    local ok, list = pcall(gc, fn)
    return (ok and type(list) == "table") and list or nil
end

local function ClosureHasConstant(consts, needle)
    if type(consts) ~= "table" then return false end
    for _, c in pairs(consts) do
        if type(c) == "string" and c == needle then return true end
    end
    return false
end

local function InspectUpvaluesFromClosure(fn, visited, depth)
    if type(fn) ~= "function" or depth > 3 then return end
    visited = visited or {}
    if visited[fn] then return end
    visited[fn] = true

    local consts = GetClosureConstantsSafe(fn)
    local hasRaycast = ClosureHasConstant(consts, "Raycast")
    local hasCanBeDamaged = ClosureHasConstant(consts, "canBeDamaged")
    local hasFireServer = ClosureHasConstant(consts, "FireServer")
    local hasReloadSess = ClosureHasConstant(consts, "Local_ReloadSession")
    local hasReloadTime = ClosureHasConstant(consts, "ReloadTime")
    local hasIsShooting = ClosureHasConstant(consts, "Local_IsShooting")
    local hasFireRate = ClosureHasConstant(consts, "FireRate")
    local hasCurAmmo = ClosureHasConstant(consts, "Local_CurrentAmmo")

    local foundRayParams = nil
    for i = 1, 32 do
        local ok, uv = pcall(debug.getupvalue, fn, i)
        if not ok then break end
        local tv = typeof(uv)
        if tv == "RaycastParams" then
            foundRayParams = uv
            if not GunHook.ShootParams then GunHook.ShootParams = uv end
        elseif tv == "table" and not GunHook.GunData then
            if rawget(uv, "Range") ~= nil and rawget(uv, "FireRate") ~= nil then
                GunHook.GunData = uv
            end
        elseif tv == "function" then
            InspectUpvaluesFromClosure(uv, visited, depth + 1)
        end
    end

    local bulletScore = (foundRayParams and 3 or 0) + (hasRaycast and 2 or 0) + (hasCanBeDamaged and 2 or 0) + (hasFireServer and 1 or 0)
    if bulletScore >= 3 and bulletScore > (GunHook._BulletScore or 0) then
        GunHook._BulletScore = bulletScore
        GunHook.Bullet = fn
    end

    local shootScore = (hasIsShooting and 3 or 0) + (hasFireRate and 1 or 0) + (hasCurAmmo and 1 or 0) - ((fn == GunHook.Bullet) and 3 or 0)
    if shootScore >= 2 and shootScore > (GunHook._ShootScore or 0) then
        GunHook._ShootScore = shootScore
        GunHook.Shoot = fn
    end

    local reloadScore = (hasReloadSess and 3 or 0) + (hasReloadTime and 2 or 0) - ((fn == GunHook.Bullet or fn == GunHook.Shoot) and 4 or 0)
    if reloadScore >= 2 and reloadScore > (GunHook._ReloadScore or 0) then
        GunHook._ReloadScore = reloadScore
        GunHook.Reload = fn
    end
end

local function SetupGunControllerHooks(forceRehook)
    if forceRehook then
        GunHook.Shoot = nil
        GunHook.Reload = nil
        GunHook.ShootParams = nil
        GunHook.GunData = nil
        GunHook._BulletScore = 0
        GunHook._ShootScore = 0
        GunHook._ReloadScore = 0
        GunHook.BulletHookFiredCount = 0
        GunHook.HookSource = "rehook"
        if not GunHook.IsHooked then
            GunHook.Bullet = nil
        end
    end

    if debug and debug.getupvalue then
        pcall(function()
            local visited = {}
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local home = pg and pg:FindFirstChild("Home")
            local hud = home and home:FindFirstChild("hud")
            local actionArea = hud and hud:FindFirstChild("ActionArea")
            if actionArea then GunHook.ActionArea = actionArea end

            local function scanClosure(fn, sourceTag, allowPositionalHint)
                if type(fn) ~= "function" then return end
                local prevBullet = GunHook.Bullet
                local prevShoot = GunHook.Shoot
                InspectUpvaluesFromClosure(fn, visited, 1)
                if allowPositionalHint and not GunHook.Shoot then
                    local okS, maybeShoot = pcall(debug.getupvalue, fn, 2)
                    if okS and type(maybeShoot) == "function" then
                        InspectUpvaluesFromClosure(maybeShoot, visited, 1)
                        if not GunHook.Shoot then GunHook.Shoot = maybeShoot end
                    end
                end
                if (GunHook.Bullet ~= prevBullet or GunHook.Shoot ~= prevShoot) and sourceTag then
                    GunHook.HookSource = sourceTag
                end
            end

            -- 1. Primary (Mobile & HUD fire button): scan ActionArea.InputBegan
            if getconnections and actionArea then
                for _, conn in ipairs(getconnections(actionArea.InputBegan)) do
                    if type(conn.Function) == "function" then
                        scanClosure(conn.Function, "ActionArea", true)
                    end
                end
            end

            -- 2. Primary-PC: scan UserInputService.InputBegan GunController listeners
            if getconnections then
                for _, conn in ipairs(getconnections(UserInputService.InputBegan)) do
                    if type(conn.Function) == "function" then
                        local okS, src = pcall(debug.info, conn.Function, "s")
                        if okS and type(src) == "string" and src:find("GunController") then
                            scanClosure(conn.Function, "UIS.InputBegan", false)
                        end
                    end
                end
            end

            -- 3. Secondary: CharacterAdded connections belonging to GunController
            if getconnections and (not GunHook.Bullet or not GunHook.Shoot) then
                for _, conn in ipairs(getconnections(LocalPlayer.CharacterAdded)) do
                    if type(conn.Function) == "function" then
                        local okS, src = pcall(debug.info, conn.Function, "s")
                        if okS and type(src) == "string" and src:find("GunController") then
                            scanClosure(conn.Function, "CharacterAdded", false)
                        end
                    end
                end
            end

            -- 4. Tertiary: getgc GunController closure scan (resilient across patches & respawns)
            if (not GunHook.Bullet or not GunHook.Shoot) and getgc then
                for _, obj in ipairs(getgc(false)) do
                    if type(obj) == "function" then
                        local okS, src = pcall(debug.info, obj, "s")
                        if okS and type(src) == "string" and src:find("GunController") then
                            scanClosure(obj, "getgc", false)
                            if GunHook.Bullet and GunHook.Shoot then break end
                        end
                    end
                end
            end

            GunHook.Ready = (GunHook.Shoot ~= nil and GunHook.Bullet ~= nil)

            if GunHook.Bullet and hookfunction and (not GunHook.IsHooked or (GunHook._HookedBulletTarget and GunHook.Bullet ~= GunHook._HookedBulletTarget)) then
                GunHook.IsHooked = true
                GunHook._HookedBulletTarget = GunHook.Bullet
                GunHook.OldBullet = hookfunction(GunHook.Bullet, function(...)
                    GunHook.BulletHookFiredCount = (GunHook.BulletHookFiredCount or 0) + 1
                    local args = table.pack(...)
                    local rawOrigOrigin = args[1]
                    local origOrigin = rawOrigOrigin
                    if typeof(origOrigin) == "Vector3" and HoloShieldState.DesyncActive and HoloShieldState.SavedCF then
                        local deltaY = HoloShieldState.SavedCF.Position.Y - origOrigin.Y
                        if deltaY > 3.5 then
                            origOrigin = origOrigin + Vector3.new(0, deltaY, 0)
                            SyncOriginOnStack(rawOrigOrigin, origOrigin)
                            args[1] = origOrigin
                            rawOrigOrigin = origOrigin
                        end
                    end
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
                        if State.SilentAimLead and activeTargetPart:IsA("BasePart") then
                            local vel = activeTargetPart.AssemblyLinearVelocity
                            if vel.Magnitude > 4 then
                                local ping = 0.04
                                pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000 end)
                                local leadTime = clamp((tonumber(ping) or 0.04) * 0.45, 0.015, 0.075)
                                local leadOffset = vel * leadTime
                                if leadOffset.Magnitude > 2.2 then
                                    leadOffset = leadOffset.Unit * 2.2
                                end
                                finalHit = finalHit + leadOffset
                            end
                        end
                        args[2] = finalHit
                        if type(args[3]) == "number" then args[3] = 0 end
                        if activeOrigin and typeof(origOrigin) == "Vector3" and activeOrigin ~= origOrigin then
                            SyncOriginOnStack(rawOrigOrigin, activeOrigin)
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

    if not GunHook.RaycastFallbackHooked and hookmetamethod and getnamecallmethod then
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                if Env.PrisonLife2026Running
                    and (not GunHook.IsHooked or (GunHook.BulletHookFiredCount or 0) == 0)
                    and (State.SilentAim or State.Ragebot or State.AutoHvH or GunHook.ForceRageShot or GunHook.TaseTargetPart)
                    and self == Workspace
                then
                    local method = getnamecallmethod()
                    if method == "Raycast" and (not checkcaller or not checkcaller()) then
                        local origin, dir, params = ...
                        if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" and dir.Magnitude > 40 then
                            local holdingGun = IsHoldingFirearm()
                            if holdingGun then
                                local targetPart = GunHook.TaseTargetPart or GunHook.RageTargetPart or GunHook.CurrentSilentTargetPart
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

function App.RehookGunController(notifyUser)
    local ok = SetupGunControllerHooks(true)
    if notifyUser then
        Notify("GunController", ("Re-hook %s (source: %s, Shoot=%s, Bullet=%s)"):format(
            ok and "ready" or "partial",
            tostring(GunHook.HookSource),
            tostring(GunHook.Shoot ~= nil),
            tostring(GunHook.Bullet ~= nil)
        ), 2.5)
    end
    return ok
end

task.spawn(function()
    for _ = 1, 20 do
        if SetupGunControllerHooks(false) and GunHook.IsHooked then break end
        task.wait(1)
    end
end)

local FiringBusy = false
local function FireToolAtTarget(tool, targetPart, isRage, isTase, isCombo)
    local char = LocalPlayer.Character
    local hum = GetHumanoid(char)
    local hrp = GetRoot(char)
    if not char or not hum or hum.Health <= 0 or not tool or not targetPart then return false end
    if FiringBusy then return false end

    local ownerName = isCombo and "Combo1" or (isTase and "AutoTaze" or (isRage and "Ragebot" or "Triggerbot"))
    local arbiterPrio = isCombo and 5 or (isRage and 4 or 3)
    if not App.ToolArbiter.Acquire(ownerName, arbiterPrio, 0.16) then return false end

    -- Temporarily restore standing pose before GunController raycasts so bullets never spawn below floor!
    if hrp and HoloShieldState.DesyncActive and HoloShieldState.SavedCF then
        pcall(function() hrp.CFrame = HoloShieldState.SavedCF end)
    end

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
    if tool.Parent ~= char then
        App.ToolArbiter.Release(ownerName)
        return false
    end

    local ammo = tool:GetAttribute("Local_CurrentAmmo") or tool:GetAttribute("CurrentAmmo") or 1
    if ammo <= 0 or (tool:GetAttribute("Local_ReloadSession") or 0) > 0 then
        App.ToolArbiter.Release(ownerName)
        return false
    end

    GunHook.ShotToken = (GunHook.ShotToken or 0) + 1
    local myToken = GunHook.ShotToken

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

    local clickPos = Vector3.zero
    local aa = GunHook.ActionArea
    if not (aa and aa.Parent) then
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local home = pg and pg:FindFirstChild("Home")
        local hud = home and home:FindFirstChild("hud")
        aa = hud and hud:FindFirstChild("ActionArea")
        if aa then GunHook.ActionArea = aa end
    end
    if aa and aa.Parent then
        local ap = aa.AbsolutePosition
        local as = aa.AbsoluteSize
        clickPos = Vector3.new(ap.X + as.X * 0.5, ap.Y + as.Y * 0.5, 0)
    end

    local inputObj = nil
    if GunHook.Shoot then
        inputObj = {
            UserInputState = Enum.UserInputState.Begin,
            UserInputType = IsMobile and Enum.UserInputType.Touch or Enum.UserInputType.MouseButton1,
            KeyCode = Enum.KeyCode.Unknown,
            Position = clickPos,
        }
        pcall(task.spawn, GunHook.Shoot, inputObj)
    else
        pcall(function() tool:Activate() end)
    end

    local chargeAttr = tonumber(tool:GetAttribute("ChargeTime")) or 0
    if State.GunMods and State.GunZeroChargeTime then chargeAttr = 0 end
    local holdTime = math.max(0.05, chargeAttr + 0.05)
    task.delay(holdTime, function()
        if inputObj then
            inputObj.UserInputState = Enum.UserInputState.End
        end
        if GunHook.ShotToken == myToken then
            GunHook.ForceRageShot = false
            GunHook.RageTargetPart = nil
            GunHook.TaseTargetPart = nil
            App.ToolArbiter.Release(ownerName)
        end
    end)
    return true
end

-- ============================================================================
-- // SECTION 4: 5-MODE BULLET SHIELD (NON-BLOCKING HALO + ANTI-HIT DESYNC)
-- ============================================================================
local HoloShieldState = {
    Model = nil,
    CorePart = nil,
    HP = 180,
    MaxHP = 180,
    LastHit = 0,
    DesyncActive = false,
    SavedCF = nil,
    SavedVel = nil,
    JitterAngle = 0,
    LastAttacker = nil,
    LastAttackClock = 0,
}

local function HasEquippedRiotShield()
    local char = LocalPlayer.Character
    if not char then return false end
    return (char:FindFirstChild("Riot Shield") or char:FindFirstChild("RiotShieldPart")) ~= nil
end

local function DestroyHoloShield()
    if HoloShieldState.DesyncActive and HoloShieldState.SavedCF then
        local hrp = GetRoot(LocalPlayer.Character)
        if hrp then
            pcall(function()
                hrp.CFrame = HoloShieldState.SavedCF
                if HoloShieldState.SavedVel then hrp.AssemblyLinearVelocity = HoloShieldState.SavedVel end
            end)
        end
    end
    HoloShieldState.DesyncActive = false
    HoloShieldState.SavedCF = nil
    HoloShieldState.SavedVel = nil
    App.WorldCache.ShieldModel = nil
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

    -- Sleek non-blocking ground halo (`CanQuery = false` ALWAYS — NEVER blocks shots, cursor, or clicks!)
    local sz = clamp(tonumber(State.ShieldSize) or 4.2, 2.5, 10)
    local style = tostring(State.ShieldVisualStyle or "CyberHex")
    local baseTrans = clamp(tonumber(State.ShieldTransparency) or 0.72, 0.35, 0.96)
    local m = Instance.new("Model")
    m.Name = "PL2026_BallisticShield"

    local core = Instance.new("Part")
    core.Name = "PL2026_ShieldHalo"
    core.Shape = Enum.PartType.Cylinder
    core.Size = Vector3.new(style == "Minimal" and 0.08 or 0.14, sz, sz)
    if not State.ShieldShowVisual then
        core.Transparency = 1
    elseif style == "NeonRing" then
        core.Transparency = clamp(baseTrans + 0.18, 0.78, 0.96)
    elseif style == "Minimal" then
        core.Transparency = clamp(baseTrans + 0.12, 0.45, 0.96)
    else
        core.Transparency = baseTrans
    end
    core.Material = Enum.Material.Neon
    core.Color = (style == "Minimal") and Color3.fromRGB(70, 185, 255) or Color3.fromRGB(0, 195, 255)
    core.Anchored = true
    core.CanCollide = false
    core.CanQuery = false
    core.CanTouch = false
    core.CastShadow = false
    core.Parent = m

    if State.ShieldShowVisual and (style == "CyberHex" or style == "NeonRing") then
        local sg = Instance.new("SurfaceGui")
        sg.Name = "PL2026_ShieldFace"
        sg.Face = Enum.NormalId.Right
        sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud = 40
        sg.AlwaysOnTop = false
        sg.LightInfluence = 0
        sg.Parent = core

        local outer = Instance.new("Frame")
        outer.Size = UDim2.fromScale(0.92, 0.92)
        outer.Position = UDim2.fromScale(0.5, 0.5)
        outer.AnchorPoint = Vector2.new(0.5, 0.5)
        outer.BackgroundTransparency = 1
        outer.Parent = sg
        local oc = Instance.new("UICorner")
        oc.CornerRadius = UDim.new(1, 0)
        oc.Parent = outer
        local osStroke = Instance.new("UIStroke")
        osStroke.Color = Color3.fromRGB(0, 225, 255)
        osStroke.Thickness = (style == "NeonRing") and 8 or 6
        osStroke.Transparency = 0.12
        osStroke.Parent = outer

        if style == "CyberHex" then
            local inner = Instance.new("Frame")
            inner.Size = UDim2.fromScale(0.62, 0.62)
            inner.Position = UDim2.fromScale(0.5, 0.5)
            inner.AnchorPoint = Vector2.new(0.5, 0.5)
            inner.Rotation = 45
            inner.BackgroundTransparency = 1
            inner.Parent = sg
            local isStroke = Instance.new("UIStroke")
            isStroke.Color = Color3.fromRGB(115, 235, 255)
            isStroke.Thickness = 3
            isStroke.Transparency = 0.25
            isStroke.Parent = inner
        end
    end

    m.Parent = Workspace
    HoloShieldState.Model = m
    HoloShieldState.CorePart = core
    App.WorldCache.ShieldModel = m
    HoloShieldState.MaxHP = State.HoloShieldMaxHP or 180
    HoloShieldState.HP = HoloShieldState.MaxHP
    ShieldBarHolder.Visible = true

    if Remotes.ShieldEquipped and (State.ShieldMode == "RiotOnly" or (State.ShieldMode == "Hybrid" and State.ShieldAutoEquip)) then
        pcall(function() Remotes.ShieldEquipped:FireServer(true) end)
    end
end
App.CreateHoloShield = CreateHoloShield

local function RegisterHoloShieldHit(dmg, worldHitPos)
    if not State.HoloShield or IsOnTeamsMenu() then return end
    HoloShieldState.LastHit = os.clock()
    HoloShieldState.HP = math.max(15, HoloShieldState.HP - (dmg or 15))
    -- Visual pulse ONLY (never disables dodge protection!)
    if HoloShieldState.CorePart then
        HoloShieldState.CorePart.Color = Color3.fromRGB(255, 95, 110)
        task.delay(0.10, function()
            if HoloShieldState.CorePart then
                HoloShieldState.CorePart.Color = Color3.fromRGB(0, 195, 255)
            end
        end)
    end
    if worldHitPos then SpawnShieldSparkVFX(worldHitPos) end
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
        if IsOnTeamsMenu() then return end
        local myHrp = GetRoot(LocalPlayer.Character)
        if not myHrp then return end
        local realPos = (HoloShieldState.DesyncActive and HoloShieldState.SavedCF and HoloShieldState.SavedCF.Position) or myHrp.Position
        local pts = ExtractPointsFromReplicatePayload(...)
        if #pts >= 2 then
            local origin, hitPos = pts[1], pts[2]
            if (origin - realPos).Magnitude > 6 then
                local shieldPos = (HoloShieldState.CorePart and HoloShieldState.CorePart.Position) or realPos
                local seg = hitPos - origin
                local len = seg.Magnitude
                if len > 1 then
                    local t = clamp((shieldPos - origin):Dot(seg) / (len * len), 0, 1)
                    local closest = origin + (seg * t)
                    local nearUs = (closest - realPos).Magnitude <= 10.0 or (hitPos - realPos).Magnitude <= 10.0

                    -- Identify shooter shooting near/at us for Reactive Auto-Evade & AutoHvH Threat Focus!
                    if nearUs then
                        local now = os.clock()
                        local bestPlr, bestD = nil, 14
                        local list = (#App.Scheduler.Players > 0 and App.Scheduler.Players) or Players:GetPlayers()
                        for _, plr in ipairs(list) do
                            if plr ~= LocalPlayer then
                                local info = App.WorldCache.Players[plr]
                                local pHead = (info and info.head) or (info and info.hrp) or GetRoot(plr.Character)
                                if pHead and pHead.Parent then
                                    local d = (pHead.Position - origin).Magnitude
                                    if d < bestD then bestD = d; bestPlr = plr end
                                end
                            end
                        end
                        if bestPlr then
                            App.Anomaly.LastAttackers[bestPlr] = now
                            HoloShieldState.LastAttacker = bestPlr
                            HoloShieldState.LastAttackClock = now
                        end
                    end

                    if State.HoloShield and ((closest - shieldPos).Magnitude <= 5.2 or (hitPos - realPos).Magnitude <= 6.0) then
                        RegisterHoloShieldHit(15, closest)
                    end
                end
            end
        end
    end))
end

-- ============================================================================
-- // SECTION 5: CACHED WEAPON GRABBER (2026 SNIPER + MELEE) & .COMBO1
-- ============================================================================
local KnownGunLocations = {
    ["Remington 870"] = {
        SearchPivot = Vector3.new(820.2986, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(820.2986, 93.05, 2229.3962),
    },
    ["MP5"] = {
        SearchPivot = Vector3.new(813.6987, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(813.6987, 93.05, 2229.3962),
    },
    ["M9"] = {
        SearchPivot = Vector3.new(820.2986, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(820.2986, 93.05, 2229.3962),
    },
    ["M4A1"] = {
        GamepassId = 643697197,
        SearchPivot = Vector3.new(847.5, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(847.5, 93.05, 2229.3962),
    },
    ["Riot Shield"] = {
        GamepassId = 643697197,
        SearchPivot = Vector3.new(840.0, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(840.0, 93.05, 2229.3962),
    },
    ["AK-47"] = {
        SearchPivot = Vector3.new(-931.7928, 91.2783, 2039.2555),
        UndergroundCF = CFrame.new(-931.7928, 86.48, 2039.2555),
    },
    ["FAL"] = {
        GamepassId = 1443271,
        SearchPivot = Vector3.new(-938.5, 91.2783, 2039.2555),
        UndergroundCF = CFrame.new(-938.5, 86.48, 2039.2555),
    },
    ["M700"] = {
        SearchPivot = Vector3.new(834.5, 97.85, 2229.4),
        UndergroundCF = CFrame.new(834.5, 93.05, 2229.4),
    },
    ["Revolver"] = {
        SearchPivot = Vector3.new(827.5, 97.85, 2229.4),
        UndergroundCF = CFrame.new(827.5, 93.05, 2229.4),
    },
    ["Hammer"] = {
        SearchPivot = Vector3.new(778.0, 97.5, 2480.0),
        UndergroundCF = CFrame.new(778.0, 92.7, 2480.0),
    },
    ["Crude Knife"] = {
        SearchPivot = Vector3.new(778.0, 97.5, 2480.0),
        UndergroundCF = CFrame.new(778.0, 92.7, 2480.0),
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

local function RebuildGiverCache()
    local wc = App.WorldCache
    table.clear(wc.GiversByName)
    table.clear(wc.GiversAll)
    local seen = {}

    local function pushGiver(inst)
        if not inst or seen[inst] then return end
        seen[inst] = true
        table.insert(wc.GiversAll, inst)
        local toolAttr = inst:GetAttribute("ToolName") or (inst.Parent and inst.Parent:GetAttribute("ToolName"))
        local keys = { string.lower(inst.Name) }
        if type(toolAttr) == "string" then table.insert(keys, string.lower(toolAttr)) end
        if inst.Parent then table.insert(keys, string.lower(inst.Parent.Name)) end
        for _, k in ipairs(keys) do
            if k ~= "" then
                wc.GiversByName[k] = wc.GiversByName[k] or {}
                table.insert(wc.GiversByName[k], inst)
            end
        end
    end

    local ok, queried = pcall(function() return Workspace:QueryDescendants("#TouchGiver") end)
    if ok and type(queried) == "table" then
        for _, g in ipairs(queried) do pushGiver(g) end
    end
    local okT, tagged = pcall(function() return CollectionService:GetTagged("Giver") end)
    if okT and type(tagged) == "table" then
        for _, g in ipairs(tagged) do pushGiver(g) end
    end
    local piFolder = Workspace:FindFirstChild("Prison_ITEMS")
    if piFolder then
        for _, sub in ipairs({ "single", "giver" }) do
            local f = piFolder:FindFirstChild(sub)
            if f then
                for _, g in ipairs(f:GetChildren()) do pushGiver(g) end
            end
        end
    end
    wc.GiverBuiltAt = os.clock()
end

local function FindTouchGiverForWeapon(weaponName)
    local info = KnownGunLocations[weaponName]
    if info and info.GamepassId and not OwnsGamepass(info.GamepassId) then
        return nil, nil
    end

    local wc = App.WorldCache
    if #wc.GiversAll == 0 or (os.clock() - wc.GiverBuiltAt) > 25 then
        RebuildGiverCache()
    end

    local lowTarget = string.lower(weaponName)
    local bucket = wc.GiversByName[lowTarget]
    if bucket then
        for _, giver in ipairs(bucket) do
            if giver and giver.Parent and IsGiverTeamAllowed(giver) then
                local okP, piv = pcall(function() return giver:GetPivot() end)
                if okP and piv then
                    local pos = piv.Position
                    return giver, CFrame.new(pos.X, pos.Y - 4.8, pos.Z)
                end
            end
        end
    end

    -- Partial name fallback in case attribute or giver name contains weapon name
    for _, giver in ipairs(wc.GiversAll) do
        if giver and giver.Parent and IsGiverTeamAllowed(giver) then
            local attr = giver:GetAttribute("ToolName") or (giver.Parent and giver.Parent:GetAttribute("ToolName")) or giver.Name
            if type(attr) == "string" and string.lower(attr):find(lowTarget, 1, true) then
                local okP, piv = pcall(function() return giver:GetPivot() end)
                if okP and piv then
                    local pos = piv.Position
                    return giver, CFrame.new(pos.X, pos.Y - 4.8, pos.Z)
                end
            end
        end
    end

    if info then
        local closest, bestDist = nil, 25
        for _, giver in ipairs(wc.GiversAll) do
            if giver and giver.Parent then
                local okP, pivot = pcall(function() return giver:GetPivot() end)
                if okP and pivot then
                    local dist = (pivot.Position - info.SearchPivot).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        closest = giver
                    end
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
            ChargeTime = tool:GetAttribute("ChargeTime"),
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
            if State.GunZeroChargeTime and orig.ChargeTime ~= nil then
                tool:SetAttribute("ChargeTime", 0)
            elseif orig.ChargeTime ~= nil then
                tool:SetAttribute("ChargeTime", orig.ChargeTime)
            end
        elseif orig then
            if orig.FireRate then tool:SetAttribute("FireRate", orig.FireRate) end
            if orig.SpreadRadius then tool:SetAttribute("SpreadRadius", orig.SpreadRadius) end
            if orig.AutoFire ~= nil then tool:SetAttribute("AutoFire", orig.AutoFire) end
            if orig.Range then tool:SetAttribute("Range", orig.Range) end
            if orig.AccurateRange then tool:SetAttribute("AccurateRange", orig.AccurateRange) end
            if orig.ChargeTime ~= nil then tool:SetAttribute("ChargeTime", orig.ChargeTime) end
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
    App.ToolArbiter.Acquire("GrabWeapons", 6, 4.0)
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
    App.ToolArbiter.Release("GrabWeapons")
    SetupGunControllerHooks()
    ApplyGunModsAll()
    if not silent then Notify("Weapons Grabbed", "Equipped weapons safely!", 2.2) end
end

App.LoadoutKits = {
    None = nil,
    Light = { "M9", "MP5", "Revolver" },
    Sniper = { "M700", "Revolver", "MP5" },
    Riot = { "Remington 870", "M4A1", "Riot Shield" },
    Full = { "Remington 870", "AK-47", "MP5", "M700", "Revolver", "M9", "Hammer" },
}

function App.SetAutoLoadoutKit(kitName, grabNow)
    local norm = Trim(tostring(kitName or "None")):lower()
    local canonical = "None"
    for k in pairs(App.LoadoutKits) do
        if k:lower() == norm then
            canonical = k
            break
        end
    end
    State.AutoLoadoutKit = canonical
    local kitList = App.LoadoutKits[canonical]
    if kitList then
        local copy = {}
        for _, w in ipairs(kitList) do table.insert(copy, w) end
        State.AutoGetGunsSelection = copy
        State.AutoGetGuns = true
        if UIRefs.SyncVisualUI then pcall(UIRefs.SyncVisualUI) end
        if grabNow ~= false then
            task.spawn(GrabWeapons, copy, false)
        end
        Notify("Loadout Kit", ("Applied kit '%s' (%d items)."):format(canonical, #copy), 2.4)
    else
        if UIRefs.SyncVisualUI then pcall(UIRefs.SyncVisualUI) end
        Notify("Loadout Kit", "Cleared active loadout kit (None).", 2.0)
    end
    return canonical
end

function App.RefillEmptyWeapons()
    if IsGrabbingGuns then
        Notify("Refill", "Weapon grabber is busy!", 1.8)
        return
    end
    local char = LocalPlayer.Character
    local hrp = GetRoot(char)
    local hum = GetHumanoid(char)
    if not char or not hrp or not hum or hum.Health <= 0 then return end

    local lowWeapons = {}
    local seen = {}
    local function inspectContainer(container)
        if not container then return end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") and (t:GetAttribute("ToolType") == "Gun" or t:GetAttribute("FireRate")) and not seen[t.Name] then
                seen[t.Name] = true
                local curAmmo = tonumber(t:GetAttribute("Local_CurrentAmmo") or t:GetAttribute("CurrentAmmo")) or 0
                local storedAmmo = tonumber(t:GetAttribute("Local_StoredAmmo") or t:GetAttribute("StoredAmmo")) or 0
                local maxAmmo = tonumber(t:GetAttribute("MaxAmmo")) or 15
                if (curAmmo + storedAmmo) < (maxAmmo * 2) then
                    local giver, underCF = FindTouchGiverForWeapon(t.Name)
                    if giver and underCF then
                        table.insert(lowWeapons, { Name = t.Name, Giver = giver, CF = underCF })
                    end
                elseif curAmmo < maxAmmo and t == char:FindFirstChildOfClass("Tool") and GunHook.Reload then
                    pcall(task.spawn, GunHook.Reload)
                end
            end
        end
    end
    inspectContainer(char)
    inspectContainer(LocalPlayer:FindFirstChildOfClass("Backpack"))

    if #lowWeapons == 0 then
        if GunHook.Reload then pcall(task.spawn, GunHook.Reload) end
        Notify("Refill", "Reloaded mags (all reserves healthy)!", 2.0)
        return
    end

    task.spawn(function()
        IsGrabbingGuns = true
        App.ToolArbiter.Acquire("RefillEmptyWeapons", 6, 4.0)
        local savedCF = (HoloShieldState.DesyncActive and HoloShieldState.SavedCF) or hrp.CFrame
        HoloShieldState.DesyncActive = false
        for _, item in ipairs(lowWeapons) do
            if not hrp or not hrp.Parent or hum.Health <= 0 then break end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = item.CF
            task.wait(0.12)
            FireGiverPickup(hrp, item.Giver)
            task.wait(0.14)
        end
        if hrp and hrp.Parent and hum and hum.Health > 0 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = savedCF
        end
        IsGrabbingGuns = false
        App.ToolArbiter.Release("RefillEmptyWeapons")
        ApplyGunModsAll()
        if GunHook.Reload then pcall(task.spawn, GunHook.Reload) end
        Notify("Refill", ("Refilled %d low-ammo weapon(s)!"):format(#lowWeapons), 2.2)
    end)
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
    local entry = App.WorldCache.Cars[carModel]
    if entry and entry.drv then
        local drv = (entry.drv.Parent and (not entry.drv.Occupant or entry.drv.Occupant == myHum)) and entry.drv or nil
        local pass = nil
        for _, ps in ipairs(entry.passSeats) do
            if ps.Parent and not ps.Occupant then pass = ps; break end
        end
        return drv, pass
    end
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

-- Unified KX Vehicle Target Manipulation Engine (Fixed Upright Chassis + Collision-Free Scoop)
local function SetCarBodyCollide(carModel, enabled, origStates)
    if not carModel or not carModel.Parent then return end
    local entry = App.WorldCache.Cars[carModel]
    local parts = entry and entry.nonWheels
    if not parts then
        parts = {}
        for _, desc in ipairs(carModel:GetDescendants()) do
            if desc:IsA("BasePart") and desc.CollisionGroup ~= "Wheels" then
                table.insert(parts, desc)
            end
        end
    end
    for _, p in ipairs(parts) do
        if p and p.Parent then
            pcall(function()
                if not enabled then
                    if origStates[p] == nil then origStates[p] = p.CanCollide end
                    p.CanCollide = false
                elseif origStates[p] ~= nil then
                    p.CanCollide = origStates[p]
                end
            end)
        end
    end
end

local function ZeroCarVelocity(carModel, drvSeat)
    pcall(function()
        if drvSeat and drvSeat.Parent then
            drvSeat.AssemblyLinearVelocity = Vector3.zero
            drvSeat.AssemblyAngularVelocity = Vector3.zero
        end
        local entry = App.WorldCache.Cars[carModel]
        if entry and entry.nonWheels then
            for _, p in ipairs(entry.nonWheels) do
                if p and p.Parent then
                    p.AssemblyLinearVelocity = Vector3.zero
                    p.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    end)
end

local function RunCarTargetActionSync(targetPlr, actionMode, silentNotify)
    if not targetPlr or targetPlr == LocalPlayer then
        if not silentNotify then Notify("KX Car Action", "Select a valid target player first!", 2.5) end
        return false
    end
    local myChar = LocalPlayer.Character
    local myHrp = GetRoot(myChar)
    local myHum = GetHumanoid(myChar)
    local tHrp = GetRoot(targetPlr.Character)
    local tHum = GetHumanoid(targetPlr.Character)
    if not myHrp or not myHum or myHum.Health <= 0 or not tHrp or not tHum or tHum.Health <= 0 then
        if not silentNotify then Notify("KX Car Action", "Target player is not alive!", 2.2) end
        return false
    end
    if tHum.Sit and tHum.SeatPart ~= nil then
        if not silentNotify then Notify("KX Car Action", targetPlr.Name .. " is already seated elsewhere!", 2.2) end
        return false
    end

    local returnCF = CFrame.new(myHrp.Position)
    local carModel, drvSeat, passSeat = AcquireUsableCar(myHum)
    if not carModel or not drvSeat or not passSeat then
        if not silentNotify then Notify("KX Car Action", "No vehicle available! Run .savecar first.", 3) end
        return false
    end

    if myHum.SeatPart ~= drvSeat then
        SafeTeleport(drvSeat.CFrame + Vector3.new(0, 2.4, 0))
        task.wait(0.1)
        pcall(function() drvSeat:Sit(myHum) end)
        task.wait(0.22)
    end
    if myHum.SeatPart ~= drvSeat then
        if not silentNotify then Notify("KX Car Action", "Could not enter driver seat!", 2.5) end
        return false
    end

    -- Lock upright yaw + seat local offset ONCE so bumps/curbs never flip car or camera upside down!
    local carPivot = carModel:GetPivot()
    local _, yaw, _ = carPivot:ToEulerAnglesYXZ()
    local flatRot = CFrame.fromEulerAnglesYXZ(0, yaw, 0)
    local seatOffsetFlat = flatRot:VectorToWorldSpace(carPivot:PointToObjectSpace(passSeat.Position))
    local origCollide = {}
    local didSuccess = false

    local okRun, errMsg = pcall(function()
        SetCarBodyCollide(carModel, false, origCollide)

        local deadline = os.clock() + 1.65
        local seated = false
        while os.clock() < deadline do
            if not Env.PrisonLife2026Running or myHum.Health <= 0 or not carModel.Parent then break end
            local curTHrp = GetRoot(targetPlr.Character)
            if not curTHrp or tHum.Health <= 0 then break end
            if passSeat.Occupant == tHum or tHum.SeatPart == passSeat then
                seated = true
                break
            end
            if tHum.Sit and tHum.SeatPart ~= nil and tHum.SeatPart ~= passSeat then
                break
            end
            local velLead = (curTHrp.AssemblyLinearVelocity or Vector3.zero) * 0.14
            local goalPos = (curTHrp.Position + velLead) - seatOffsetFlat
            carModel:PivotTo(CFrame.new(goalPos) * flatRot)
            ZeroCarVelocity(carModel, drvSeat)
            RunService.Heartbeat:Wait()
        end

        local arrivalCF = CFrame.new(returnCF.Position + Vector3.new(0, 3.0, 0)) * flatRot
        if seated then
            didSuccess = true
            if actionMode == "bring" then
                carModel:PivotTo(arrivalCF)
                ZeroCarVelocity(carModel, drvSeat)
                task.wait(0.14)
                ZeroCarVelocity(carModel, drvSeat)
                SetCarBodyCollide(carModel, true, origCollide)
                myHum.Sit = false
                if not silentNotify then Notify("KX Bring", "Brought " .. targetPlr.Name .. "!", 2.5) end
            elseif actionMode == "forcecrim" then
                local crimSpawn = Workspace:FindFirstChild("Criminals Spawn")
                local sp = crimSpawn and (crimSpawn:FindFirstChild("SpawnLocation") or crimSpawn:FindFirstChildWhichIsA("BasePart", true))
                if sp then
                    carModel:PivotTo(CFrame.new(sp.Position + Vector3.new(0, 3.8, 0)) * flatRot)
                    ZeroCarVelocity(carModel, drvSeat)
                    task.wait(0.32)
                end
                carModel:PivotTo(arrivalCF)
                ZeroCarVelocity(carModel, drvSeat)
                SetCarBodyCollide(carModel, true, origCollide)
                if not silentNotify then Notify("KX ForceCrim", "Forced " .. targetPlr.Name .. " to Criminals!", 2.5) end
            elseif actionMode == "void" or actionMode == "forcekick" then
                carModel:PivotTo(CFrame.new(returnCF.X, -420, returnCF.Z) * flatRot)
                ZeroCarVelocity(carModel, drvSeat)
                task.wait(0.28)
                SetCarBodyCollide(carModel, true, origCollide)
                myHum.Sit = false
                task.wait(0.06)
                SafeTeleport(returnCF + Vector3.new(0, 1.5, 0))
                if not silentNotify then Notify("KX Void", "Dropped " .. targetPlr.Name .. " into the void!", 2.5) end
            elseif actionMode == "fling" then
                SetCarBodyCollide(carModel, true, origCollide)
                drvSeat.AssemblyLinearVelocity = Vector3.new(0, 650, 0)
                drvSeat.AssemblyAngularVelocity = Vector3.new(120, 260, 120)
                task.wait(0.22)
                myHum.Sit = false
                task.wait(0.06)
                SafeTeleport(returnCF + Vector3.new(0, 1.5, 0))
                if not silentNotify then Notify("KX Car Fling", "Flung " .. targetPlr.Name .. "!", 2.5) end
            else
                SetCarBodyCollide(carModel, true, origCollide)
            end
        else
            carModel:PivotTo(arrivalCF)
            ZeroCarVelocity(carModel, drvSeat)
            SetCarBodyCollide(carModel, true, origCollide)
            if not silentNotify then Notify("KX Car Action", targetPlr.Name .. " moved out of seat range.", 2.2) end
        end
    end)

    SetCarBodyCollide(carModel, true, origCollide)
    if not okRun and not silentNotify then
        Notify("KX Car Action", "Aborted safely: " .. tostring(errMsg), 2.2)
    end
    return didSuccess
end

local function ExecuteCarTargetAction(targetPlr, actionMode)
    if App.ActiveCarAction then
        Notify("KX Car Action", "A car action is already running!", 2.0)
        return
    end
    App.ActiveCarAction = true
    task.spawn(function()
        pcall(function() RunCarTargetActionSync(targetPlr, actionMode, false) end)
        App.ActiveCarAction = false
    end)
end

function App.ExecuteCarActionBatch(targets, actionMode)
    if type(targets) ~= "table" or #targets == 0 then
        Notify("KX Car Action", "No valid target players found!", 2.2)
        return
    end
    if App.ActiveCarAction then
        Notify("KX Car Action", "Car batch/action already in progress!", 2.0)
        return
    end
    App.ActiveCarAction = true
    task.spawn(function()
        local count = 0
        pcall(function()
            for _, plr in ipairs(targets) do
                if not Env.PrisonLife2026Running then break end
                local ok = RunCarTargetActionSync(plr, actionMode, true)
                if ok then count = count + 1 end
                task.wait(0.25)
            end
        end)
        App.ActiveCarAction = false
        Notify("KX Car Batch", ("Completed %s on %d/%d target(s)."):format(tostring(actionMode), count, #targets), 2.6)
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

-- KX WheelAura Visual Customization (Uses cached WorldCache.Cars — ZERO GetDescendants per Heartbeat!)
local WheelAuraParts = setmetatable({}, { __mode = "k" })
local LastWheelAuraSeat = nil
local function UpdateVehicleWheelAura(seat)
    if not State.WheelAura or not seat then
        if LastWheelAuraSeat ~= nil then
            for inst, fx in pairs(WheelAuraParts) do
                pcall(function() fx:Destroy() end)
                WheelAuraParts[inst] = nil
            end
            LastWheelAuraSeat = nil
        end
        return
    end
    if seat == LastWheelAuraSeat then return end
    LastWheelAuraSeat = seat

    local car = seat:FindFirstAncestorOfClass("Model")
    if not car then return end
    local entry = App.WorldCache.Cars[car]
    local wheelList = entry and entry.wheels
    if not wheelList then
        wheelList = {}
        for _, desc in ipairs(car:GetDescendants()) do
            if desc:IsA("BasePart") and (desc.Name:lower():find("wheel") or desc.CollisionGroup == "Wheels") then
                table.insert(wheelList, desc)
            end
        end
    end
    for _, desc in ipairs(wheelList) do
        if desc and desc.Parent and not WheelAuraParts[desc] then
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

-- Shared cross-section tables (keeps file-level locals well under Lua's 200-local limit)
local Core = {}
local Admin = {}
local UIRefs = {}

-- ============================================================================
-- // SECTION 7: TEAM SWITCHER, FAST RESPAWN, ANTI-TASE & ANTI-ARREST
-- ============================================================================
do
    local LastDeathCFrame = nil
    local DisabledJumpConns = {}

    function Core.GetLastDeathCFrame()
        return LastDeathCFrame
    end
    function Core.SetLastDeathCFrame(cf)
        LastDeathCFrame = cf
    end

    function Core.SwitchToTeam(teamName)
        if teamName == "Criminals" then
            local crimSpawn = Workspace:FindFirstChild("Criminals Spawn")
            local sp = crimSpawn and (crimSpawn:FindFirstChild("SpawnLocation") or crimSpawn:FindFirstChildWhichIsA("BasePart", true))
            local hrp = GetRoot(LocalPlayer.Character)
            local crimTeam = Teams:FindFirstChild("Criminals")
            if sp and hrp then
                local savedCF = hrp.CFrame
                SafeTeleport(sp.CFrame + Vector3.new(0, 3, 0))
                task.spawn(function()
                    local deadline = os.clock() + 1.25
                    while os.clock() < deadline and hrp and hrp.Parent do
                        if LocalPlayer.Team == crimTeam then break end
                        if firetouchinterest then
                            pcall(function()
                                firetouchinterest(hrp, sp, 0)
                                firetouchinterest(hrp, sp, 1)
                            end)
                        end
                        task.wait(0.08)
                    end
                    if hrp and hrp.Parent then
                        SafeTeleport(savedCF)
                    end
                end)
                return true
            end
            return false
        end

        if not Remotes.RequestTeamChange then
            Notify("Team Switch", "RequestTeamChange remote unavailable.", 2.5)
            return false
        end
        local targetTeam = Teams:FindFirstChild(teamName)
        if not targetTeam then return false end

        local ok, res = pcall(function()
            return Remotes.RequestTeamChange:InvokeServer(targetTeam, 1)
        end)
        return ok and res
    end

    function Core.PerformFastRespawn()
        local char = LocalPlayer.Character
        local hrp = GetRoot(char)
        local savedCF = (HoloShieldState.DesyncActive and HoloShieldState.SavedCF) or (hrp and hrp.CFrame) or LastDeathCFrame
        local currentTeam = LocalPlayer.Team
        if not currentTeam or currentTeam == Teams:FindFirstChild("Neutral") then
            currentTeam = Teams:FindFirstChild("Inmates")
        end

        local function waitForNewChar(timeout)
            local t0 = os.clock()
            local oldChar = LocalPlayer.Character
            while (os.clock() - t0) < (timeout or 3.2) do
                local nc = LocalPlayer.Character
                if nc and nc ~= oldChar and GetRoot(nc) then return nc end
                task.wait(0.06)
            end
            return LocalPlayer.Character
        end

        task.spawn(function()
            if currentTeam == Teams:FindFirstChild("Criminals") then
                Core.SwitchToTeam("Inmates")
                local newChar = waitForNewChar(3.0)
                local newHrp = newChar and newChar:WaitForChild("HumanoidRootPart", 4)
                if newHrp then
                    local crimSpawn = Workspace:FindFirstChild("Criminals Spawn")
                    local sp = crimSpawn and (crimSpawn:FindFirstChild("SpawnLocation") or crimSpawn:FindFirstChildWhichIsA("BasePart", true))
                    if sp then
                        SafeTeleport(sp.CFrame + Vector3.new(0, 3, 0))
                        task.wait(0.32)
                    end
                    if State.KeepPositionOnRespawn and savedCF and not State.AntiBanSafeMode then
                        SafeTeleport(savedCF)
                    end
                end
            else
                Core.SwitchToTeam("Neutral")
                task.wait(0.12)
                Core.SwitchToTeam(currentTeam.Name)
                local newChar = waitForNewChar(3.2)
                local newHrp = newChar and newChar:WaitForChild("HumanoidRootPart", 4)
                if newHrp and State.KeepPositionOnRespawn and savedCF then
                    task.wait(0.18)
                    if not State.AntiBanSafeMode or (newHrp.Position - savedCF.Position).Magnitude <= 450 then
                        SafeTeleport(savedCF)
                    end
                end
            end
        end)
    end

    function Core.BypassClientAntiNoclip()
        -- Non-destructive signal disable ONLY (never :Destroy() CharacterCollision)
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

    function Core.BypassAntiJump(char, enableBypass)
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

    function Core.PurgeTaseAndRagdoll()
        pcall(function() LocalPlayer:SetAttribute("BackpackEnabled", true) end)
        local char = LocalPlayer.Character
        local hum = GetHumanoid(char)
        local hrp = GetRoot(char)
        if not hum or hum.Health <= 0 then return end

        pcall(function()
            char:SetAttribute("Tased", nil)
            hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        end)

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

    function Core.InstallAntiTaseAndAntiArrestHooks()
        if getconnections and hookfunction then
            if Remotes.PlayerTased then
                pcall(function()
                    for _, conn in ipairs(getconnections(Remotes.PlayerTased.OnClientEvent)) do
                        if conn.Function and not conn._pl2026Hooked then
                            local orig
                            orig = hookfunction(conn.Function, function(...)
                                if Env.PrisonLife2026Running and (State.AntiTase or State.AutoHvH) then
                                    Core.PurgeTaseAndRagdoll()
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
                                if Env.PrisonLife2026Running and (State.AntiArrest or State.AutoHvH) then
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

    Core.InstallAntiTaseAndAntiArrestHooks()

    if Remotes.PlayerTased then
        AddConnection(Remotes.PlayerTased.OnClientEvent:Connect(function()
            if not (State.AntiTase or State.AutoHvH) then return end
            task.defer(Core.PurgeTaseAndRagdoll)
        end))
    end

    if Remotes.ClientArrested then
        AddConnection(Remotes.ClientArrested.OnClientEvent:Connect(function()
            if State.AntiArrest or State.AutoHvH then
                task.defer(Core.PurgeTaseAndRagdoll)
            end
            if not State.AutoCriminalOnArrest then return end
            Notify("Arrested", "Escaping back to Criminal Base in 4.2s...", 3.5)
            task.delay(4.25, function()
                Core.SwitchToTeam("Criminals")
            end)
        end))
    end
end

-- ============================================================================
-- // SECTION 8: CLEAN SERVERSIDE FE INVISIBLE (NO STUCK OUTLINE) & SPECTATE
-- ============================================================================
do
    local FEInvisTrack = nil
    local FEInvisSavedTransparencies = {}
    local IsSyncingFEInvis = false

    function Core.IsFEInvisPlaying()
        return FEInvisTrack ~= nil
    end

    function Core.StopFEInvisible()
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
    end

    function Core.StartFEInvisible(fromShieldMode)
        Core.StopFEInvisible()
        local char = LocalPlayer.Character
        local hum = GetHumanoid(char)
        local hrp = GetRoot(char)
        if not char or not hum or not hrp or hum.Health <= 0 or IsOnTeamsMenu() then return end

        Core._GhostFromShieldMode = (fromShieldMode == true)

        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end)

        -- Clean semi-transparency ONLY (zero stuck cyan Highlight outline!)
        for _, desc in ipairs(char:GetDescendants()) do
            if (desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture")) and desc ~= hrp then
                if desc.Transparency < 0.45 then
                    FEInvisSavedTransparencies[desc] = desc.Transparency
                    desc.Transparency = 0.45
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
        end
    end

    function Core.ApplyToolFEInvisTransparency(tool)
        if not (State.FEInvisible or (State.HoloShield and State.ShieldMode == "FEGhost")) then return end
        for _, desc in ipairs(tool:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Transparency < 0.45 then
                FEInvisSavedTransparencies[desc] = desc.Transparency
                desc.Transparency = 0.45
            end
        end
    end

    function Core.SetFEInvisibleState(newState, notifyUser)
        if IsSyncingFEInvis then return end
        IsSyncingFEInvis = true
        State.FEInvisible = newState
        if newState then
            Core.StartFEInvisible(false)
        else
            Core._GhostFromShieldMode = false
            Core.StopFEInvisible()
        end
        if UIRefs.FEInvisToggle and UIRefs.FEInvisToggle.Set then
            pcall(function() UIRefs.FEInvisToggle:Set(newState) end)
        end
        if notifyUser then
            Notify("FE Invisible", newState and "Serverside Invisibility ON" or "Serverside Invisibility OFF", 2)
        end
        IsSyncingFEInvis = false
    end

    function Core.SetSpectatePlayer(targetPlr)
        Core.SpectateTarget = targetPlr
        if not targetPlr or targetPlr == LocalPlayer then
            Core.SpectateTarget = nil
            local myHum = GetHumanoid(LocalPlayer.Character)
            if myHum then Camera.CameraSubject = myHum end
            return
        end
        local tHum = GetHumanoid(targetPlr.Character)
        if tHum then
            Camera.CameraSubject = tHum
            Notify("Spectate", "Viewing " .. targetPlr.Name, 2)
        end
    end
end

-- ============================================================================
-- // SECTION 9: CLUTTER-FREE HUD CONTROLS (DRAGGABLE .combo1, ⌘ CMD, FLY PAD)
-- ============================================================================
do
    -- 1. Top-Left Compact Draggable `.combo1` Burst Pill
    local ComboTopLeftBtn = Instance.new("TextButton")
    ComboTopLeftBtn.Name = "KX_Combo1Btn"
    ComboTopLeftBtn.Position = UDim2.new(0, 14, 0, 56)
    ComboTopLeftBtn.Size = UDim2.fromOffset(78, 26)
    ComboTopLeftBtn.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
    ComboTopLeftBtn.BackgroundTransparency = 0.18
    ComboTopLeftBtn.Font = Enum.Font.GothamBold
    ComboTopLeftBtn.TextSize = 11
    ComboTopLeftBtn.TextColor3 = Color3.fromRGB(0, 225, 255)
    ComboTopLeftBtn.Text = "⚡ .combo1"
    ComboTopLeftBtn.Visible = State.ShowComboButton
    ComboTopLeftBtn.Parent = OverlayGui
    Instance.new("UICorner", ComboTopLeftBtn).CornerRadius = UDim.new(1, 0)
    local comboStroke = Instance.new("UIStroke", ComboTopLeftBtn)
    comboStroke.Color = Color3.fromRGB(0, 195, 255)
    comboStroke.Thickness = 1.2
    comboStroke.Transparency = 0.25
    MakeDraggable(ComboTopLeftBtn)
    AddConnection(ComboTopLeftBtn.Activated:Connect(function()
        local lastDrag = tonumber(ComboTopLeftBtn:GetAttribute("WasDraggedAt")) or 0
        if (os.clock() - lastDrag) < 0.25 then return end
        task.spawn(ExecuteCombo1)
    end))
    UIRefs.ComboTopLeftBtn = ComboTopLeftBtn

    -- 2. Top-Right Collapsible `⌘ CMD` Pill (Anchored BELOW Roblox Menu, NEVER blocks Ammo!)
    local CmdTogglePill = Instance.new("TextButton")
    CmdTogglePill.Name = "KX_CmdPill"
    CmdTogglePill.AnchorPoint = Vector2.new(1, 0)
    CmdTogglePill.Position = UDim2.new(1, -14, 0, 56)
    CmdTogglePill.Size = UDim2.fromOffset(68, 26)
    CmdTogglePill.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
    CmdTogglePill.BackgroundTransparency = 0.18
    CmdTogglePill.Font = Enum.Font.GothamBold
    CmdTogglePill.TextSize = 11
    CmdTogglePill.TextColor3 = Color3.new(1, 1, 1)
    CmdTogglePill.Text = "⌘ CMD"
    CmdTogglePill.Visible = State.ShowCommandPill
    CmdTogglePill.Parent = OverlayGui
    Instance.new("UICorner", CmdTogglePill).CornerRadius = UDim.new(1, 0)
    local pillStroke = Instance.new("UIStroke", CmdTogglePill)
    pillStroke.Color = Color3.fromRGB(59, 130, 246)
    pillStroke.Thickness = 1.2
    pillStroke.Transparency = 0.25
    MakeDraggable(CmdTogglePill)
    UIRefs.CmdTogglePill = CmdTogglePill

    -- On mobile, place CmdBar & SuggestDropdown top-center away from top-right HUD icons & bottom thumb pads
    local CmdBarFrame = Instance.new("Frame")
    CmdBarFrame.Name = "KX_CommandBar"
    CmdBarFrame.AnchorPoint = IsMobile and Vector2.new(0.5, 0) or Vector2.new(1, 0)
    CmdBarFrame.Position = IsMobile and UDim2.new(0.5, 0, 0, 52) or UDim2.new(1, -14, 0, 86)
    CmdBarFrame.Size = IsMobile and UDim2.fromOffset(270, 32) or UDim2.fromOffset(240, 28)
    CmdBarFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
    CmdBarFrame.BackgroundTransparency = 0.12
    CmdBarFrame.BorderSizePixel = 0
    CmdBarFrame.Visible = false
    CmdBarFrame.Parent = OverlayGui
    Instance.new("UICorner", CmdBarFrame).CornerRadius = UDim.new(0, 8)
    local cmdStroke = Instance.new("UIStroke", CmdBarFrame)
    cmdStroke.Color = Color3.fromRGB(59, 130, 246)
    cmdStroke.Thickness = 1.2
    UIRefs.CmdBarFrame = CmdBarFrame

    local CmdInput = Instance.new("TextBox")
    CmdInput.Size = UDim2.new(1, -46, 1, 0)
    CmdInput.Position = UDim2.fromOffset(8, 0)
    CmdInput.BackgroundTransparency = 1
    CmdInput.Font = Enum.Font.GothamMedium
    CmdInput.TextSize = IsMobile and 12 or 11
    CmdInput.TextColor3 = Color3.new(1, 1, 1)
    CmdInput.PlaceholderText = ".savecar 2 / .forcecrim / ;guns"
    CmdInput.PlaceholderColor3 = Color3.fromRGB(140, 155, 180)
    CmdInput.TextXAlignment = Enum.TextXAlignment.Left
    CmdInput.ClearTextOnFocus = false
    CmdInput.Text = ""
    CmdInput.Parent = CmdBarFrame
    UIRefs.CmdInput = CmdInput

    local CmdRunBtn = Instance.new("TextButton")
    CmdRunBtn.Size = UDim2.fromOffset(36, 22)
    CmdRunBtn.Position = UDim2.new(1, -40, 0.5, -11)
    CmdRunBtn.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
    CmdRunBtn.Font = Enum.Font.GothamBold
    CmdRunBtn.TextSize = 10
    CmdRunBtn.TextColor3 = Color3.new(1, 1, 1)
    CmdRunBtn.Text = "OK"
    CmdRunBtn.Parent = CmdBarFrame
    Instance.new("UICorner", CmdRunBtn).CornerRadius = UDim.new(0, 6)

    local SuggestFrame = Instance.new("Frame")
    SuggestFrame.Name = "KX_SuggestDropdown"
    SuggestFrame.AnchorPoint = CmdBarFrame.AnchorPoint
    SuggestFrame.Position = IsMobile and UDim2.new(0.5, 0, 0, 88) or UDim2.new(1, -14, 0, 118)
    SuggestFrame.Size = IsMobile and UDim2.fromOffset(270, 0) or UDim2.fromOffset(240, 0)
    SuggestFrame.AutomaticSize = Enum.AutomaticSize.Y
    SuggestFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
    SuggestFrame.BackgroundTransparency = 0.08
    SuggestFrame.Visible = false
    SuggestFrame.Parent = OverlayGui
    Instance.new("UICorner", SuggestFrame).CornerRadius = UDim.new(0, 8)
    local sLayout = Instance.new("UIListLayout", SuggestFrame)
    sLayout.Padding = UDim.new(0, 2)
    UIRefs.SuggestFrame = SuggestFrame

    AddConnection(CmdTogglePill.Activated:Connect(function()
        local lastDrag = tonumber(CmdTogglePill:GetAttribute("WasDraggedAt")) or 0
        if (os.clock() - lastDrag) < 0.25 then return end
        CmdBarFrame.Visible = not CmdBarFrame.Visible
        if CmdBarFrame.Visible then
            task.defer(function() CmdInput:CaptureFocus() end)
        else
            SuggestFrame.Visible = false
        end
    end))

    AddConnection(CmdRunBtn.Activated:Connect(function()
        if Trim(CmdInput.Text) ~= "" and Admin.ExecuteLine then
            Admin.ExecuteLine(CmdInput.Text)
            CmdInput.Text = ""
            CmdBarFrame.Visible = false
            SuggestFrame.Visible = false
        end
    end))

    -- 3. Contextual Circular Fly Up/Down Pad (Left of mobile JumpButton; tracks active touches so slide-off never sticks)
    Core.MobileFlyInput = { Up = 0, Down = 0 }
    local ActiveFlyInputs = { Up = {}, Down = {} }
    local flyBtnX = IsMobile and -142 or -24

    local function MakeCircleFlyBtn(text, yOffset, flagKey)
        local btn = Instance.new("TextButton")
        btn.AnchorPoint = Vector2.new(1, 0)
        btn.Position = UDim2.new(1, flyBtnX, 1, yOffset)
        btn.Size = UDim2.fromOffset(42, 42)
        btn.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
        btn.BackgroundTransparency = 0.2
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 15
        btn.TextColor3 = Color3.fromRGB(0, 220, 255)
        btn.Text = text
        btn.Visible = false
        btn.Parent = OverlayGui
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
        local st = Instance.new("UIStroke", btn)
        st.Color = Color3.fromRGB(0, 200, 255)
        st.Thickness = 1.2
        st.Transparency = 0.3

        AddConnection(btn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                ActiveFlyInputs[flagKey][inp] = true
                Core.MobileFlyInput[flagKey] = 1
            end
        end))
        AddConnection(btn.InputEnded:Connect(function(inp)
            if ActiveFlyInputs[flagKey][inp] then
                ActiveFlyInputs[flagKey][inp] = nil
                Core.MobileFlyInput[flagKey] = (next(ActiveFlyInputs[flagKey]) ~= nil) and 1 or 0
            end
        end))
        return btn
    end

    AddConnection(UserInputService.InputEnded:Connect(function(inp)
        for _, flagKey in ipairs({ "Up", "Down" }) do
            if ActiveFlyInputs[flagKey][inp] then
                ActiveFlyInputs[flagKey][inp] = nil
                Core.MobileFlyInput[flagKey] = (next(ActiveFlyInputs[flagKey]) ~= nil) and 1 or 0
            end
        end
    end))

    UIRefs.FlyUpBtn = MakeCircleFlyBtn("▲", IsMobile and -138 or -162, "Up")
    UIRefs.FlyDownBtn = MakeCircleFlyBtn("▼", IsMobile and -90 or -114, "Down")
end

-- ============================================================================
-- // SECTION 10: DISTANCE-LOD ESP (30-CAP), MINI-KILLFEED & GRACE ANOMALIES
-- ============================================================================
do
    local ESPObjects = {}
    local C4Highlights = {}
    local ItemBillboards = {}
    Core.ESPObjects = ESPObjects

    function Core.IsAnomalyFlagged(plr)
        if not plr then return false end
        return (App.Anomaly.Flagged[plr.UserId] or 0) > os.clock()
    end

    function Core.RemovePlayerESP(plr)
        local data = ESPObjects[plr]
        if data then
            if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
            if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
            ESPObjects[plr] = nil
        end
        App.Anomaly.LastPos = App.Anomaly.LastPos or setmetatable({}, { __mode = "k" })
    end

    function Core.RemoveAllC4ESP()
        for c4, hl in pairs(C4Highlights) do
            pcall(function() hl:Destroy() end)
            C4Highlights[c4] = nil
        end
    end

    function Core.RemoveAllItemESP()
        for item, bb in pairs(ItemBillboards) do
            pcall(function() bb:Destroy() end)
            ItemBillboards[item] = nil
        end
    end

    function Core.UpdatePlayerESP()
        local myHrp = GetRoot(LocalPlayer.Character)
        local activeCam = Camera or Workspace.CurrentCamera
        local originPos = (myHrp and myHrp.Position) or (activeCam and activeCam.CFrame.Position) or Vector3.zero
        local maxTotalHL = clamp(tonumber(State.ESPHighlightMax) or 30, 1, 30)
        local detailDist = clamp(tonumber(State.ESPDetailDistance) or 140, 40, 600)

        -- Reserve C4 highlight slots first inside the strict 30-Highlight Roblox budget
        local usedC4HL = 0
        if State.C4ESP then
            local c4s = CollectionService:GetTagged("C4")
            for _, c4 in ipairs(c4s) do
                if usedC4HL < math.min(6, maxTotalHL) then
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
                    usedC4HL = usedC4HL + 1
                elseif C4Highlights[c4] then
                    pcall(function() C4Highlights[c4]:Destroy() end)
                    C4Highlights[c4] = nil
                end
            end
            for c4, hl in pairs(C4Highlights) do
                if not c4 or not c4.Parent then
                    pcall(function() hl:Destroy() end)
                    C4Highlights[c4] = nil
                end
            end
        else
            Core.RemoveAllC4ESP()
        end

        -- Dropped Weapons / Keycard ItemESP (uses WorldCache.Dropped; zero Workspace scan)
        if State.ItemESP then
            local shownItems = 0
            for itemInst in pairs(App.WorldCache.Dropped) do
                if itemInst and itemInst.Parent then
                    local attachPart = itemInst:IsA("BasePart") and itemInst or itemInst:FindFirstChildWhichIsA("BasePart", true)
                    local itemDist = attachPart and (attachPart.Position - originPos).Magnitude or 9999
                    if attachPart and itemDist <= 320 and shownItems < 16 then
                        shownItems = shownItems + 1
                        local bb = ItemBillboards[itemInst]
                        if not bb then
                            bb = Instance.new("BillboardGui")
                            bb.Name = "PL2026_ItemBB"
                            bb.Size = UDim2.fromOffset(130, 20)
                            bb.StudsOffset = Vector3.new(0, 1.5, 0)
                            bb.AlwaysOnTop = true
                            bb.Parent = OverlayGui
                            local lbl = Instance.new("TextLabel")
                            lbl.Name = "Txt"
                            lbl.Size = UDim2.fromScale(1, 1)
                            lbl.BackgroundTransparency = 1
                            lbl.Font = Enum.Font.GothamBold
                            lbl.TextSize = 10
                            lbl.TextStrokeTransparency = 0.2
                            lbl.TextColor3 = Color3.fromRGB(255, 220, 95)
                            lbl.Parent = bb
                            ItemBillboards[itemInst] = bb
                        end
                        bb.Enabled = true
                        bb.Adornee = attachPart
                        local tName = tostring(itemInst:GetAttribute("ToolName") or itemInst.Name)
                        local lbl = bb:FindFirstChild("Txt")
                        if lbl then
                            if tName:lower():find("key") then
                                lbl.TextColor3 = Color3.fromRGB(115, 245, 255)
                            else
                                lbl.TextColor3 = Color3.fromRGB(255, 220, 95)
                            end
                            lbl.Text = string.format("[%s] %dm", tName, round(itemDist))
                        end
                    elseif ItemBillboards[itemInst] then
                        ItemBillboards[itemInst].Enabled = false
                    end
                end
            end
            for itemInst, bb in pairs(ItemBillboards) do
                if not itemInst or not itemInst.Parent or not App.WorldCache.Dropped[itemInst] then
                    pcall(function() bb:Destroy() end)
                    ItemBillboards[itemInst] = nil
                end
            end
        else
            Core.RemoveAllItemESP()
        end

        local playerBudget = math.max(0, maxTotalHL - usedC4HL)
        local snapshot = (#App.Scheduler.Players > 0 and App.Scheduler.Players) or Players:GetPlayers()
        local candidates = {}
        local amGuard = LocalPlayer.Team and LocalPlayer.Team.Name == "Guards"

        for _, plr in ipairs(snapshot) do
            if plr ~= LocalPlayer then
                local info = App.WorldCache.Players[plr]
                local char = (info and info.char and info.char.Parent and info.char) or plr.Character
                local hrp = (info and info.hrp and info.hrp.Parent == char and info.hrp) or GetRoot(char)
                local hum = (info and info.hum and info.hum.Parent == char and info.hum) or GetHumanoid(char)
                local hideTeammate = State.ESPHideTeam and (plr.Team == LocalPlayer.Team)

                if State.ESP and not hideTeammate and char and hrp and hum and hum.Health > 0 then
                    if hrp.Transparency < 1 then hrp.Transparency = 1 end
                    local dist = (hrp.Position - originPos).Magnitude
                    table.insert(candidates, { plr = plr, info = info, char = char, hrp = hrp, hum = hum, dist = dist })
                else
                    Core.RemovePlayerESP(plr)
                end
            end
        end

        -- Sort closest players first so the nearest 30 ALWAYS receive 3D Highlight chams!
        table.sort(candidates, function(a, b) return a.dist < b.dist end)

        for rank, item in ipairs(candidates) do
            local plr, info, char, hrp, hum, dist = item.plr, item.info, item.char, item.hrp, item.hum, item.dist
            local data = ESPObjects[plr]
            if not data then
                data = {}
                local hl = Instance.new("Highlight")
                hl.Name = "PL2026_HL"
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.FillTransparency = 0.72
                hl.OutlineTransparency = 0.14
                hl.Parent = OverlayGui
                data.Highlight = hl

                local bb = Instance.new("BillboardGui")
                bb.Name = "PL2026_BB"
                bb.Size = UDim2.fromOffset(170, 44)
                bb.StudsOffset = Vector3.new(0, 3.1, 0)
                bb.AlwaysOnTop = true
                bb.Parent = OverlayGui
                data.Billboard = bb

                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 1, -7)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamBold
                lbl.TextSize = 11
                lbl.TextStrokeTransparency = 0.15
                lbl.Parent = bb
                data.Label = lbl

                local hpBg = Instance.new("Frame")
                hpBg.Name = "HPBarBg"
                hpBg.Size = UDim2.new(0.68, 0, 0, 3)
                hpBg.Position = UDim2.new(0.16, 0, 1, -4)
                hpBg.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
                hpBg.BackgroundTransparency = 0.2
                hpBg.BorderSizePixel = 0
                hpBg.Parent = bb
                Instance.new("UICorner", hpBg).CornerRadius = UDim.new(1, 0)
                local hpStroke = Instance.new("UIStroke", hpBg)
                hpStroke.Color = Color3.fromRGB(0, 0, 0)
                hpStroke.Thickness = 0.8
                hpStroke.Transparency = 0.25

                local hpFill = Instance.new("Frame")
                hpFill.Name = "HPBarFill"
                hpFill.Size = UDim2.fromScale(1, 1)
                hpFill.BackgroundColor3 = Color3.fromRGB(50, 240, 120)
                hpFill.BorderSizePixel = 0
                hpFill.Parent = hpBg
                Instance.new("UICorner", hpFill).CornerRadius = UDim.new(1, 0)

                data.HPBarBg = hpBg
                data.HPBarFill = hpFill

                ESPObjects[plr] = data
            end

            local isCheat = Core.IsAnomalyFlagged(plr)
            local isFocused = (State.FocusTargetUserId and plr.UserId == State.FocusTargetUserId)
            local isHostile = char:GetAttribute("Hostile") == true
            local isTrespass = char:GetAttribute("Trespassing") == true
            local teamColor
            if isCheat then
                teamColor = Color3.fromRGB(255, 65, 220)
            elseif isFocused then
                teamColor = Color3.fromRGB(0, 255, 175)
            elseif amGuard and plr.Team and plr.Team.Name == "Inmates" then
                if isHostile then
                    teamColor = Color3.fromRGB(255, 75, 65)
                elseif isTrespass then
                    teamColor = Color3.fromRGB(255, 195, 55)
                else
                    teamColor = Color3.fromRGB(210, 220, 232)
                end
            else
                teamColor = (plr.Team and plr.Team.TeamColor.Color) or Color3.fromRGB(220, 220, 220)
            end

            local allowHL = State.ESPHighlight and (rank <= playerBudget)
            data.Highlight.Enabled = allowHL
            data.Highlight.Adornee = allowHL and char or nil
            data.Highlight.FillColor = teamColor
            data.Highlight.OutlineColor = teamColor

            local anyText = State.ESPNameTag or State.ESPHealth or State.ESPDistance or State.ESPWeapon or State.ESPHealthBar
            data.Billboard.Enabled = anyText
            data.Billboard.Adornee = (info and info.head and info.head.Parent == char and info.head) or hrp

            local roundedDist = round(dist)
            -- Distance-LOD: Full details inside ESPDetailDistance & Top-30, compact ◆ diamond pip beyond!
            if roundedDist > detailDist then
                data.Billboard.Size = UDim2.fromOffset(88, 22)
                data.Label.Size = UDim2.fromScale(1, 1)
                data.HPBarBg.Visible = false
                data.Label.TextSize = 10
                data.Label.TextColor3 = teamColor
                data.Label.Text = isCheat and string.format("◆ %dm [CHEAT]", roundedDist) or string.format("◆ %dm", roundedDist)
            else
                data.Billboard.Size = UDim2.fromOffset(170, State.ESPHealthBar and 44 or 38)
                data.Label.Size = State.ESPHealthBar and UDim2.new(1, 0, 1, -7) or UDim2.fromScale(1, 1)
                data.Label.TextSize = 11
                local tool = (info and info.tool and info.tool.Parent == char and info.tool) or char:FindFirstChildOfClass("Tool")
                local lines = {}
                if State.ESPNameTag then
                    local flags = isFocused and " [TARGET]" or ""
                    if isCheat then flags = flags .. " [CHEAT]" end
                    if State.ESPStatusFlags then
                        if isHostile then flags = flags .. " [HOSTILE]"
                        elseif isTrespass then flags = flags .. " [TRESPASS]" end
                        if char:GetAttribute("Tased") then flags = flags .. " [TASED]" end
                    end
                    table.insert(lines, string.format("%s%s", plr.DisplayName or plr.Name, flags))
                end

                local infoParts = {}
                if State.ESPHealth then table.insert(infoParts, string.format("%dHP", round(hum.Health))) end
                if State.ESPDistance then table.insert(infoParts, string.format("%dm", roundedDist)) end
                if State.ESPWeapon and tool then table.insert(infoParts, string.format("[%s]", tool.Name)) end
                if #infoParts > 0 then table.insert(lines, table.concat(infoParts, " • ")) end

                data.Label.TextColor3 = teamColor
                data.Label.Text = table.concat(lines, "\n")

                if State.ESPHealthBar then
                    data.HPBarBg.Visible = true
                    local frac = clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
                    data.HPBarFill.Size = UDim2.fromScale(frac, 1)
                    if frac > 0.55 then
                        data.HPBarFill.BackgroundColor3 = Color3.fromRGB(50, 235, 115)
                    elseif frac > 0.25 then
                        data.HPBarFill.BackgroundColor3 = Color3.fromRGB(255, 195, 45)
                    else
                        data.HPBarFill.BackgroundColor3 = Color3.fromRGB(255, 65, 70)
                    end
                else
                    data.HPBarBg.Visible = false
                end
            end
        end
    end

    AddConnection(Players.PlayerRemoving:Connect(function(plr)
        Core.RemovePlayerESP(plr)
        App.Anomaly.GraceUntil[plr.UserId] = nil
        App.Anomaly.StrikeInfo[plr.UserId] = nil
        App.Anomaly.Flagged[plr.UserId] = nil
        App.Anomaly.LastAttackers[plr] = nil
    end))

    -- Crisp Mini-Killfeed Watcher (ZERO WindUI Toast Spam!)
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
                        if State.ShowMiniKillfeed and (isMe or rest:find(LocalPlayer.Name, 1, true) or streak >= 5) then
                            local tag = ""
                            local now = os.clock()
                            if isMe then
                                if (now - GunHook.LastComboShotClock) <= 1.2 then tag = "[.combo1] "
                                elseif State.AutoHvH and (now - GunHook.LastRageShotClock) <= 1.2 then tag = "[AutoHvH] "
                                elseif (now - GunHook.LastRageShotClock) <= 1.2 then tag = "[RAGEBOT] " end
                            end
                            local col = isMe and Color3.fromRGB(0, 235, 165) or Color3.fromRGB(255, 185, 85)
                            PushMiniKillfeedLine(string.format("%s%s (%dx)", tag, text, streak), col)
                        end
                    end
                end)
            end))
        end
    end)

    -- False-Positive-Hardened Multi-Strike Anomaly Detector (With Spawn/Team/Arrest/Ping Grace!)
    local PrevPos = setmetatable({}, { __mode = "k" })
    local PrevSeated = setmetatable({}, { __mode = "k" })

    function Core.EvaluateAnomalies()
        if not State.CheaterAlerts and not State.CarTPAlerts and not State.AutoHvH then return end
        local now = os.clock()
        for uid, st in pairs(App.Anomaly.StrikeInfo) do
            if (now - st.lastStrike) > 14 then App.Anomaly.StrikeInfo[uid] = nil end
        end
        for uid, exp in pairs(App.Anomaly.Flagged) do
            if exp <= now then App.Anomaly.Flagged[uid] = nil end
        end

        local snapshot = (#App.Scheduler.Players > 0 and App.Scheduler.Players) or Players:GetPlayers()
        for _, plr in ipairs(snapshot) do
            if plr ~= LocalPlayer then
                local info = App.WorldCache.Players[plr]
                local char = (info and info.char and info.char.Parent and info.char) or plr.Character
                local hrp = (info and info.hrp and info.hrp.Parent == char and info.hrp) or GetRoot(char)
                local hum = (info and info.hum and info.hum.Parent == char and info.hum) or GetHumanoid(char)
                if hrp and hum and hum.Health > 0 then
                    local seated = (hum.SeatPart and hum.SeatPart:IsA("VehicleSeat")) ~= nil
                    local prev = PrevPos[plr]
                    local wasSeated = PrevSeated[plr]
                    local curPos = hrp.Position
                    local inGrace = (App.Anomaly.GraceUntil[plr.UserId] or 0) > now or char:FindFirstChildOfClass("ForceField") ~= nil

                    if not inGrace and prev and prev.char == char then
                        local dt = now - prev.t
                        -- Skip lag spikes (dt > 0.45s or dt < 0.04s) to prevent false rubberband alerts!
                        if dt >= 0.04 and dt <= 0.45 then
                            local dist = (curPos - prev.pos).Magnitude
                            local horizSpeed = Vector3.new(curPos.X - prev.pos.X, 0, curPos.Z - prev.pos.Z).Magnitude / dt
                            local st = App.Anomaly.StrikeInfo[plr.UserId] or { count = 0, consec = 0, lastAlert = 0, lastStrike = 0 }
                            if (now - st.lastStrike) > 12 then st.count = 0; st.consec = 0 end

                            if State.CarTPAlerts and seated and not wasSeated and dist > 130 then
                                st.count = st.count + 2
                                st.lastStrike = now
                                App.Anomaly.Flagged[plr.UserId] = now + 22
                                if State.ShowMiniKillfeed and (now - st.lastAlert) > 10 then
                                    st.lastAlert = now
                                    PushMiniKillfeedLine(string.format("⚠ Car-TP: %s snapped %.0fm", plr.Name, dist), Color3.fromRGB(255, 110, 110))
                                end
                            elseif not seated and horizSpeed > 185 and dist > 62 then
                                st.consec = st.consec + 1
                                st.count = st.count + 1
                                st.lastStrike = now
                                if st.consec >= 2 and st.count >= 2 then
                                    App.Anomaly.Flagged[plr.UserId] = now + 24
                                    if State.CheaterAlerts and State.ShowMiniKillfeed and (now - st.lastAlert) > 10 then
                                        st.lastAlert = now
                                        PushMiniKillfeedLine(string.format("⚠ Speed/TP: %s (%.0f st/s)", plr.Name, horizSpeed), Color3.fromRGB(255, 165, 65))
                                    end
                                end
                            else
                                st.consec = 0
                            end
                            App.Anomaly.StrikeInfo[plr.UserId] = st
                        end
                    end
                    PrevPos[plr] = { pos = curPos, t = now, char = char }
                    PrevSeated[plr] = seated
                end
            end
        end
    end
end

-- ============================================================================
-- // SECTION 11: MAXSPEED SUB-REGIONS, WORLDCACHE & CENTRALIZED SCHEDULER
-- ============================================================================
do
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

    -- Event-Driven WorldCache Wiring (Zero per-frame GetDescendants!)
    local OriginalDoorData = setmetatable({}, { __mode = "k" })
    local OriginalHitboxData = setmetatable({}, { __mode = "k" })
    local OriginalFenceData = setmetatable({}, { __mode = "k" })

    local function RegisterCarModel(carModel)
        if not carModel or not carModel:IsA("Model") or App.WorldCache.Cars[carModel] then return end
        local carScope = App.CreateScope()
        local entry = { model = carModel, drv = nil, passSeats = {}, nonWheels = {}, wheels = {}, scope = carScope }
        local function indexPart(d)
            if d:IsA("VehicleSeat") then
                entry.drv = d
                table.insert(entry.nonWheels, d)
            elseif d:IsA("Seat") then
                table.insert(entry.passSeats, d)
                table.insert(entry.nonWheels, d)
            elseif d:IsA("BasePart") then
                if d.Name:lower():find("wheel") or d.CollisionGroup == "Wheels" then
                    table.insert(entry.wheels, d)
                else
                    table.insert(entry.nonWheels, d)
                end
            end
        end
        for _, d in ipairs(carModel:GetDescendants()) do indexPart(d) end
        carScope:Add(carModel.DescendantAdded:Connect(indexPart))
        App.WorldCache.Cars[carModel] = entry
    end

    local function HookCarContainer(cc)
        if not cc then return end
        App.WorldCache.CarContainer = cc
        for _, m in ipairs(cc:GetChildren()) do RegisterCarModel(m) end
        AddConnection(cc.ChildAdded:Connect(RegisterCarModel))
        AddConnection(cc.ChildRemoved:Connect(function(m)
            local entry = App.WorldCache.Cars[m]
            if entry and entry.scope then entry.scope:Clean() end
            App.WorldCache.Cars[m] = nil
        end))
    end

    local function HookDoorsFolder(df)
        if not df then return end
        App.WorldCache.DoorsFolder = df
        local function trackDoorPart(d)
            if d:IsA("BasePart") and not App.WorldCache.DoorSet[d] then
                App.WorldCache.DoorSet[d] = true
                table.insert(App.WorldCache.Doors, d)
            end
        end
        for _, d in ipairs(df:GetDescendants()) do trackDoorPart(d) end
        AddConnection(df.DescendantAdded:Connect(trackDoorPart))
    end

    Core.RehookGunController = App.RehookGunController
    Core.CreateHoloShield = App.CreateHoloShield
    Core.SetAutoLoadoutKit = App.SetAutoLoadoutKit
    Core.RefillEmptyWeapons = App.RefillEmptyWeapons
    Core.ExecuteCarActionBatch = App.ExecuteCarActionBatch

    local function HookFencesFolder(ff)
        if not ff then return end
        local function trackFencePart(d)
            if d:IsA("BasePart") and d:FindFirstChildOfClass("TouchTransmitter") and not App.WorldCache.FenceSet[d] then
                App.WorldCache.FenceSet[d] = true
                table.insert(App.WorldCache.Fences, d)
                if State.FenceGodmode then
                    OriginalFenceData[d] = d.CanTouch
                    d.CanTouch = false
                end
            end
        end
        for _, d in ipairs(ff:GetDescendants()) do trackFencePart(d) end
        AddConnection(ff.DescendantAdded:Connect(trackFencePart))
    end

    local function HookClothesFolder(cf)
        if not cf then return end
        local function trackArmorItem(item)
            local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
            if part and not App.WorldCache.ArmorPartSet[part] then
                App.WorldCache.ArmorPartSet[part] = true
                table.insert(App.WorldCache.ArmorParts, part)
            end
        end
        for _, item in ipairs(cf:GetChildren()) do trackArmorItem(item) end
        AddConnection(cf.ChildAdded:Connect(trackArmorItem))
    end

    function Core.ApplyFenceGodmode(enabled)
        State.FenceGodmode = enabled
        for _, part in ipairs(App.WorldCache.Fences) do
            if part and part.Parent then
                if enabled then
                    if OriginalFenceData[part] == nil then OriginalFenceData[part] = part.CanTouch end
                    part.CanTouch = false
                elseif OriginalFenceData[part] ~= nil then
                    part.CanTouch = OriginalFenceData[part]
                end
            end
        end
    end

    App.WorldCache.VFXPoolFolder = VFXPool
    if Workspace:FindFirstChild("CarContainer") then HookCarContainer(Workspace.CarContainer) end
    if Workspace:FindFirstChild("Doors") then HookDoorsFolder(Workspace.Doors) end
    if Workspace:FindFirstChild("Prison_Fences") then HookFencesFolder(Workspace.Prison_Fences) end
    do
        local pi = Workspace:FindFirstChild("Prison_ITEMS")
        if pi then
            local clothes = pi:FindFirstChild("clothes")
            if clothes then HookClothesFolder(clothes) end
            AddConnection(pi.ChildAdded:Connect(function(sub)
                if sub.Name == "clothes" then HookClothesFolder(sub) end
            end))
        end
    end

    local function IsDroppedWorldItem(ch)
        if not ch then return false end
        if ch:IsA("Tool") then return true end
        if ch:IsA("Model") and not Players:GetPlayerFromCharacter(ch) and not ch:FindFirstChildOfClass("Humanoid") then
            if ch:GetAttribute("ToolName") ~= nil or ch.Name:lower():find("key") then
                return true
            end
        end
        return false
    end

    for _, ch in ipairs(Workspace:GetChildren()) do
        if IsDroppedWorldItem(ch) then
            App.WorldCache.Dropped[ch] = true
        end
    end
    AddConnection(Workspace.ChildAdded:Connect(function(ch)
        if ch.Name == "CarContainer" then HookCarContainer(ch)
        elseif ch.Name == "Doors" then HookDoorsFolder(ch)
        elseif ch.Name == "Prison_Fences" then HookFencesFolder(ch)
        elseif ch.Name == "Prison_ITEMS" then
            local clothes = ch:FindFirstChild("clothes")
            if clothes then HookClothesFolder(clothes) end
            AddConnection(ch.ChildAdded:Connect(function(sub)
                if sub.Name == "clothes" then HookClothesFolder(sub) end
            end))
        elseif IsDroppedWorldItem(ch) then
            App.WorldCache.Dropped[ch] = true
        end
    end))
    AddConnection(Workspace.ChildRemoved:Connect(function(ch)
        App.WorldCache.Dropped[ch] = nil
    end))

    pcall(function()
        AddConnection(CollectionService:GetInstanceAddedSignal("Giver"):Connect(function()
            App.WorldCache.GiverBuiltAt = 0
        end))
    end)

    -- Event-Driven Remote Player Character Cache + Scoped Listeners (Zero respawn leaks!)
    local function CacheRemotePlayerCharacter(plr, char)
        if not plr or plr == LocalPlayer or not char then return end
        local scopes = App.WorldCache.PlayerScopes[plr]
        if not scopes then
            scopes = { player = App.CreateScope(), char = nil }
            App.WorldCache.PlayerScopes[plr] = scopes
        end
        if scopes.char then scopes.char:Clean() end
        local cs = App.CreateScope()
        scopes.char = cs

        App.Anomaly.GraceUntil[plr.UserId] = os.clock() + 3.0
        local info = {
            char = char,
            hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"),
            head = char:FindFirstChild("Head"),
            hum = char:FindFirstChildOfClass("Humanoid"),
            animator = nil,
            riotShield = char:FindFirstChild("RiotShieldPart"),
            tool = char:FindFirstChildOfClass("Tool"),
            parts = {},
        }
        if info.hum then info.animator = info.hum:FindFirstChildOfClass("Animator") end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then table.insert(info.parts, d) end
        end
        App.WorldCache.Players[plr] = info

        cs:Add(char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                info.tool = child
            elseif child.Name == "HumanoidRootPart" then
                info.hrp = child
                table.insert(info.parts, child)
            elseif child.Name == "Head" then
                info.head = child
                table.insert(info.parts, child)
            elseif child.Name == "RiotShieldPart" and child:IsA("BasePart") then
                info.riotShield = child
                child.CanQuery = not State.AntiRiotShield
            elseif child:IsA("Humanoid") then
                info.hum = child
                info.animator = child:FindFirstChildOfClass("Animator")
            elseif child:IsA("BasePart") then
                table.insert(info.parts, child)
            end
        end))
        cs:Add(char.ChildRemoved:Connect(function(child)
            if child == info.tool then info.tool = char:FindFirstChildOfClass("Tool") end
            if child == info.riotShield then info.riotShield = nil end
        end))
        cs:Add(char:GetAttributeChangedSignal("Arrested"):Connect(function()
            App.Anomaly.GraceUntil[plr.UserId] = os.clock() + 3.0
        end))
        cs:Add(char:GetAttributeChangedSignal("Tased"):Connect(function()
            App.Anomaly.GraceUntil[plr.UserId] = os.clock() + 2.0
        end))
    end

    local function HookPlayerTracking(plr)
        if not plr or plr == LocalPlayer then return end
        local oldScopes = App.WorldCache.PlayerScopes[plr]
        if oldScopes then
            if oldScopes.char then oldScopes.char:Clean() end
            if oldScopes.player then oldScopes.player:Clean() end
        end
        local ps = App.CreateScope()
        App.WorldCache.PlayerScopes[plr] = { player = ps, char = nil }

        App.Anomaly.GraceUntil[plr.UserId] = os.clock() + 3.0
        if plr.Character then CacheRemotePlayerCharacter(plr, plr.Character) end
        ps:Add(plr.CharacterAdded:Connect(function(c) CacheRemotePlayerCharacter(plr, c) end))
        ps:Add(plr:GetPropertyChangedSignal("Team"):Connect(function()
            App.Anomaly.GraceUntil[plr.UserId] = os.clock() + 3.0
        end))
    end

    for _, plr in ipairs(Players:GetPlayers()) do HookPlayerTracking(plr) end
    AddConnection(Players.PlayerAdded:Connect(function(plr)
        HookPlayerTracking(plr)
        App.Scheduler.PlayersUpdated = 0
    end))
    AddConnection(Players.PlayerRemoving:Connect(function(plr)
        local scopes = App.WorldCache.PlayerScopes[plr]
        if scopes then
            if scopes.char then scopes.char:Clean() end
            if scopes.player then scopes.player:Clean() end
            App.WorldCache.PlayerScopes[plr] = nil
        end
        App.WorldCache.Players[plr] = nil
        App.Scheduler.PlayersUpdated = 0
    end))

    local LastTriggerShot = 0
    local LastRageShot = 0
    local LastArrestTime = 0
    local LastKillAuraTime = 0
    local LastAutoTazeTime = 0
    local LastLoopKillTime = 0
    local LastComboLoopTime = 0
    local LastUtilityTick = 0
    local LoopKillCursor = 1
    local FlyBV, FlyBG = nil, nil

    function Core.CleanupCharFly()
        if FlyBV then pcall(function() FlyBV:Destroy() end); FlyBV = nil end
        if FlyBG then pcall(function() FlyBG:Destroy() end); FlyBG = nil end
        local hum = GetHumanoid(LocalPlayer.Character)
        if hum and hum.PlatformStand then hum.PlatformStand = false end
    end

    function Core.RestoreAllHitboxes()
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

    function Core.RestoreAllDoors()
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

    -- CRITICAL CAMERA FIX:
    -- BindToRenderStep BEFORE Camera (priority 185 < Camera 200) ALWAYS restores
    -- standing SavedCF + SavedVel before Camera, Input, Stepped & Physics run!
    pcall(RunService.UnbindFromRenderStep, RunService, "PL2026_ShieldRestore")
    RunService:BindToRenderStep("PL2026_ShieldRestore", Enum.RenderPriority.Camera.Value - 15, function()
        if HoloShieldState.DesyncActive and HoloShieldState.SavedCF then
            local myHrp = GetRoot(LocalPlayer.Character)
            if myHrp then
                myHrp.CFrame = HoloShieldState.SavedCF
                if HoloShieldState.SavedVel then
                    myHrp.AssemblyLinearVelocity = HoloShieldState.SavedVel
                end
            end
            HoloShieldState.DesyncActive = false
            HoloShieldState.SavedCF = nil
            HoloShieldState.SavedVel = nil
        end
    end)

    -- Render-Rate Visual Aim & Triggerbot Loop
    AddConnection(RunService.RenderStepped:Connect(function(dt)
        local activeCam = Camera or Workspace.CurrentCamera
        if activeCam then Camera = activeCam else return end
        local screenCenter = Vector2.new(activeCam.ViewportSize.X * 0.5, activeCam.ViewportSize.Y * 0.5)
        if not IsMobile and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
            local mPos = UserInputService:GetMouseLocation()
            screenCenter = Vector2.new(mPos.X, mPos.Y)
        end

        local char = LocalPlayer.Character
        local hum = GetHumanoid(char)
        local myHrp = GetRoot(char)
        local aliveInGame = (char and myHrp and hum and hum.Health > 0 and not IsOnTeamsMenu()) == true

        SilentFOVFrame.Visible = aliveInGame and State.SilentAim and State.SilentAimShowFOV
        if SilentFOVFrame.Visible then
            SilentFOVFrame.Position = UDim2.fromOffset(screenCenter.X, screenCenter.Y)
            SilentFOVFrame.Size = UDim2.fromOffset(State.SilentAimFOV * 2, State.SilentAimFOV * 2)
        end

        AimAssistFOVFrame.Visible = aliveInGame and State.AimAssist and State.AimAssistShowFOV
        if AimAssistFOVFrame.Visible then
            AimAssistFOVFrame.Position = UDim2.fromOffset(screenCenter.X, screenCenter.Y)
            AimAssistFOVFrame.Size = UDim2.fromOffset(State.AimAssistFOV * 2, State.AimAssistFOV * 2)
        end

        if aliveInGame and State.SilentAim then
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

        if aliveInGame and State.AimAssist then
            local holdingGun = IsHoldingFirearm()
            if holdingGun then
                local targetPart = GetBestCombatTarget({
                    use360 = false,
                    fov = State.AimAssistFOV,
                    wallcheck = true,
                    wallbang = false,
                    requireHostile = State.SilentAimHostileCheck,
                    forceHead = (State.AimAssistAimPart == "Head"),
                })
                if targetPart then
                    local aimPos = targetPart.Position
                    if State.AimAssistPrediction then
                        aimPos = aimPos + ((targetPart.AssemblyLinearVelocity or Vector3.zero) * State.AimAssistPredictionStrength)
                    end
                    local goalCF = CFrame.lookAt(Camera.CFrame.Position, aimPos)
                    local alpha = clamp(State.AimAssistSmoothness * (IsMobile and 1.35 or 1), 0.05, 1)
                    Camera.CFrame = Camera.CFrame:Lerp(goalCF, alpha)
                end
            end
        end

        if aliveInGame and State.Triggerbot and not (State.Ragebot or State.AutoHvH) then
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
                        local targetPart = GunHook.CurrentSilentTargetPart or GetBestCombatTarget({
                            use360 = false,
                            fov = State.SilentAimFOV,
                            wallcheck = State.TriggerbotWallcheck,
                            wallbang = State.SilentAimWallbang,
                            requireHostile = State.SilentAimHostileCheck,
                        })
                        if targetPart then
                            LastTriggerShot = os.clock()
                            FireToolAtTarget(tool, targetPart, false, false, false)
                        end
                    end
                end
            end
        end

        if not aliveInGame then
            if HoloShieldState.Model then DestroyHoloShield() end
            ShieldBarHolder.Visible = false
            ArrestBarHolder.Visible = false
            return
        end

        -- Non-Blocking Ground Halo Ring (Never in front of camera/crosshair, CanQuery = false always!)
        if State.HoloShield then
            if State.ShieldMode == "FEGhost" then
                if HoloShieldState.Model then DestroyHoloShield() end
                ShieldBarHolder.Visible = true
                ShieldBarFill.Size = UDim2.fromScale(1, 1)
                ShieldBarFill.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
                ShieldBarText.Text = "👻 FEGHOST • ACTIVE"
                if not Core.IsFEInvisPlaying() then Core.StartFEInvisible(true) end
            else
                if Core._GhostFromShieldMode and not State.FEInvisible then
                    Core._GhostFromShieldMode = false
                    Core.StopFEInvisible()
                end
                if not HoloShieldState.CorePart or not HoloShieldState.CorePart.Parent then
                    CreateHoloShield()
                end
                local core = HoloShieldState.CorePart
                if core then
                    ShieldBarHolder.Visible = true
                    local sz = clamp(tonumber(State.ShieldSize) or 4.2, 2.5, 10)
                    local style = tostring(State.ShieldVisualStyle or "CyberHex")
                    if (core:FindFirstChild("PL2026_ShieldFace") ~= nil) ~= (style ~= "Minimal") then
                        CreateHoloShield()
                        core = HoloShieldState.CorePart
                    end
                    if core then
                        core.Size = Vector3.new(style == "Minimal" and 0.08 or 0.14, sz, sz)
                        local now = os.clock()
                        if (now - HoloShieldState.LastHit) > 2.2 and HoloShieldState.HP < HoloShieldState.MaxHP then
                            HoloShieldState.HP = math.min(HoloShieldState.MaxHP, HoloShieldState.HP + (45 * dt))
                        end
                        local baseTrans = clamp(tonumber(State.ShieldTransparency) or 0.72, 0.35, 0.96)
                        if not State.ShieldShowVisual then
                            core.Transparency = 1
                        elseif style == "NeonRing" then
                            core.Transparency = clamp(baseTrans + 0.18, 0.78, 0.96)
                        elseif style == "Minimal" then
                            core.Transparency = clamp(baseTrans + 0.12, 0.45, 0.96)
                        else
                            core.Transparency = baseTrans
                        end
                        core.CanQuery = false
                        core.CFrame = CFrame.new(myHrp.Position - Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90))

                        local modeTag = (State.ShieldMode == "DesyncBox" and "ANTILOCK" or State.ShieldMode:upper())
                        ShieldBarFill.Size = UDim2.fromScale(clamp(HoloShieldState.HP / HoloShieldState.MaxHP, 0.12, 1), 1)
                        ShieldBarFill.BackgroundColor3 = (now - HoloShieldState.LastHit < 0.25) and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(0, 190, 240)
                        ShieldBarText.Text = string.format("🛡️ %s • ACTIVE", modeTag)
                    end
                end
            end
        else
            if Core._GhostFromShieldMode and not State.FEInvisible then
                Core._GhostFromShieldMode = false
                Core.StopFEInvisible()
            end
            ShieldBarHolder.Visible = false
        end

        if State.AutoArrest and State.AutoArrestCooldownBar and (LastArrestTime > os.clock()) then
            ArrestBarHolder.Visible = true
            local rem = math.max(0, LastArrestTime - os.clock())
            ArrestBarFill.Size = UDim2.fromScale(clamp(rem / 7, 0, 1), 1)
            ArrestBarText.Text = string.format("Arrest Cooldown: %.1fs", rem)
        else
            ArrestBarHolder.Visible = false
        end
    end))

    local NoclipApplied = false
    local AntiCarBringApplied = false
    local TargetArrestCooldowns = {}
    local NextArrestAttempt = 0
    local LastArmorInvoke = 0
    function Core.RestoreLocalNoclip()
        if not NoclipApplied then return end
        NoclipApplied = false
        for _, part in ipairs(App.WorldCache.LocalParts) do
            if part and part.Parent and App.WorldCache.LocalCollideOrig[part] ~= nil then
                pcall(function() part.CanCollide = App.WorldCache.LocalCollideOrig[part] end)
            end
        end
    end

    -- Unified Centralized Scheduler (Single Heartbeat + Clock-Gated 0.16s Utility Pass!)
    AddConnection(RunService.Heartbeat:Connect(function(dt)
        local now = os.clock()
        if (now - App.Scheduler.PlayersUpdated) >= 0.45 or #App.Scheduler.Players == 0 then
            App.Scheduler.Players = Players:GetPlayers()
            App.Scheduler.PlayersUpdated = now
        end
        local playersSnapshot = App.Scheduler.Players

        local char = LocalPlayer.Character
        local hrp = GetRoot(char)
        local hum = GetHumanoid(char)

        if char and hrp and hum and hum.Health > 0 and not IsOnTeamsMenu() then
            Core.SetLastDeathCFrame(hrp.CFrame)

            if State.AlwaysBackpack then
                LocalPlayer:SetAttribute("BackpackEnabled", true)
            end

            -- Anti-KillPlane
            if State.AntiKillPlane and not HoloShieldState.DesyncActive then
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

            -- Cached Noclip (Zero GetDescendants per Heartbeat + Clean Restore on OFF!)
            if State.Noclip then
                NoclipApplied = true
                for _, part in ipairs(App.WorldCache.LocalParts) do
                    if part and part.Parent and part.CanCollide then
                        if App.WorldCache.LocalCollideOrig[part] == nil then
                            App.WorldCache.LocalCollideOrig[part] = true
                        end
                        part.CanCollide = false
                    end
                end
            elseif NoclipApplied then
                Core.RestoreLocalNoclip()
            end

            -- Smooth 3D Character Fly & Vehicle Fly (Zero gravity downward jitter!)
            local seat = hum.SeatPart
            local isDriving = (seat and seat:IsA("VehicleSeat")) ~= nil
            if UIRefs.FlyUpBtn then UIRefs.FlyUpBtn.Visible = State.VehicleFly or State.Fly end
            if UIRefs.FlyDownBtn then UIRefs.FlyDownBtn.Visible = State.VehicleFly or State.Fly end

            UpdateVehicleWheelAura(isDriving and seat or nil)

            if State.Fly and not isDriving then
                local flySpd = State.AntiBanSafeMode and math.min(State.FlySpeed, 85) or State.FlySpeed
                local camCF = Camera.CFrame
                local moveDir = hum.MoveDirection
                local horizMove = Vector3.new(moveDir.X, 0, moveDir.Z)
                local vel = Vector3.zero
                if horizMove.Magnitude > 0.02 then
                    local camFlatFwd = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
                    local fwdDot = (camFlatFwd.Magnitude > 0.01) and horizMove.Unit:Dot(camFlatFwd.Unit) or 0
                    local dir3D = horizMove.Unit + Vector3.new(0, camCF.LookVector.Y * fwdDot, 0)
                    vel = (dir3D.Magnitude > 0.01 and dir3D.Unit or horizMove.Unit) * flySpd
                end
                local vert = (Core.MobileFlyInput.Up - Core.MobileFlyInput.Down)
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then vert = 1
                elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then vert = -1 end
                vel = vel + Vector3.new(0, vert * (flySpd * 0.78), 0)

                if State.AntiBanSafeMode then
                    Core.CleanupCharFly()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.CFrame = hrp.CFrame + (vel * dt)
                else
                    if not FlyBV or FlyBV.Parent ~= hrp then
                        Core.CleanupCharFly()
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
                Core.CleanupCharFly()
            end

            if isDriving then
                if State.VehicleFly then
                    local camCF = Camera.CFrame
                    local moveDir = hum.MoveDirection
                    local vel = Vector3.zero
                    local flySpeed = State.AntiBanSafeMode and math.min(State.VehicleFlySpeed, 110) or State.VehicleFlySpeed

                    if moveDir.Magnitude > 0 then vel = vel + (moveDir.Unit * flySpeed) end
                    local vertical = (Core.MobileFlyInput.Up - Core.MobileFlyInput.Down)
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then vertical = 1
                    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then vertical = -1 end
                    vel = vel + Vector3.new(0, (vertical ~= 0) and (vertical * flySpeed * 0.78) or 1.4, 0)

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

            -- 360° Ragebot / AutoHvH Combat Engine
            if State.Ragebot or State.AutoHvH then
                local rateSPS = State.AntiBanSafeMode and math.min(State.RagebotRate, 15) or State.RagebotRate
                local interval = 1 / math.max(1, rateSPS)
                if (now - LastRageShot) >= interval then
                    local targetPart = GetBestCombatTarget({
                        use360 = State.Ragebot360 or State.AutoHvH,
                        fov = State.SilentAimFOV,
                        wallcheck = true,
                        wallbang = State.SilentAimWallbang,
                        requireHostile = State.SilentAimHostileCheck,
                        forceHead = true,
                        prioritizeArmed = State.AutoHvH,
                    })
                    if targetPart then
                        local holdingGun, gun = IsHoldingFirearm()
                        local ammo = (gun and (gun:GetAttribute("Local_CurrentAmmo") or gun:GetAttribute("CurrentAmmo"))) or 0
                        if holdingGun and gun and ammo <= 0 and State.AutoReload and (gun:GetAttribute("Local_ReloadSession") or 0) <= 0 and GunHook.Reload then
                            task.spawn(GunHook.Reload)
                        end
                        if not holdingGun or ammo <= 0 or gun.Name == "Taser" then
                            if State.RagebotAutoSwitch or State.AutoHvH then
                                gun = GetOwnedLoadedGuns()[1]
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

            -- Shield Tool Auto-Equip (Only when Idle & AutoEquip ON)
            if State.HoloShield and not hum.Sit then
                local mode = State.ShieldMode or "UndergroundPeek"
                if (mode == "RiotOnly" or mode == "Hybrid") and State.ShieldAutoEquip and not HasEquippedRiotShield() then
                    if App.ToolArbiter.CanUse("IdleShield", 1) and not IsHoldingFirearm() then
                        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                        local riot = bp and bp:FindFirstChild("Riot Shield")
                        if riot and not IsComboRunning and not State.Ragebot and not State.AutoHvH then
                            pcall(function() hum:EquipTool(riot) end)
                        end
                    end
                end
            end

            -- Anti-Ban Hardened Melee Kill Aura (Strictly 1-arg MeleeEvent)
            local auraCooldown = State.AntiBanSafeMode and 0.32 or 0.20
            if State.KillAura and Remotes.MeleeEvent and (now - LastKillAuraTime) >= auraCooldown then
                local maxRange = State.AntiBanSafeMode and math.min(State.KillAuraRange, 10) or State.KillAuraRange
                local closestTarget, closestHrp, bestDist = nil, nil, maxRange

                for _, plr in ipairs(playersSnapshot) do
                    if IsValidCombatTarget(plr, State.KillAuraGuardSafe, State.KillAuraWhitelist, false) then
                        local pInfo = App.WorldCache.Players[plr]
                        local tHrp = (pInfo and pInfo.hrp and pInfo.hrp.Parent and pInfo.hrp) or GetRoot(plr.Character)
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
                    Remotes.MeleeEvent:FireServer(closestTarget)
                    if State.KillAuraAutoMelee then
                        local eqMelee = char:FindFirstChildOfClass("Tool")
                        if eqMelee and (eqMelee:GetAttribute("ToolType") == "Melee" or eqMelee.Name == "Hammer" or eqMelee.Name == "Crude Knife") then
                            pcall(function() eqMelee:Activate() end)
                        end
                    end
                    if State.KillAuraFaceTarget then
                        hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(closestHrp.Position.X, hrp.Position.Y, closestHrp.Position.Z))
                    end
                end
            end

            -- Auto-Taze Aura (Guards Taser Automation with ToolArbiter coordination)
            if State.AutoTaze and (now - LastAutoTazeTime) >= 1.15 and App.ToolArbiter.CanUse("AutoTaze", 3) then
                local taser = HasWeapon("Taser")
                local taserAmmo = taser and (taser:GetAttribute("Local_CurrentAmmo") or taser:GetAttribute("CurrentAmmo") or 1) or 0
                if taser and taserAmmo > 0 then
                    local bestHead, bestDist = nil, 46
                    for _, plr in ipairs(playersSnapshot) do
                        if IsValidCombatTarget(plr, true, State.ArrestWhitelist, true) then
                            local pInfo = App.WorldCache.Players[plr]
                            local tChar = (pInfo and pInfo.char) or plr.Character
                            local tHead = (pInfo and pInfo.head) or (tChar and tChar:FindFirstChild("Head"))
                            local tHrp = (pInfo and pInfo.hrp) or GetRoot(tChar)
                            if tHead and tHrp and tChar and not tChar:GetAttribute("Tased") then
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
                            if prevTool and prevTool ~= taser and hum and hum.Health > 0 and App.ToolArbiter.CanUse("AutoTaze", 3) then
                                pcall(function() hum:EquipTool(prevTool) end)
                            end
                        end)
                    end
                end
            end

            -- Auto Arrest Aura (Per-target 7.5s cooldown so crowds arrest rapidly)
            if State.AutoArrest and Remotes.ArrestPlayer and (now >= NextArrestAttempt) then
                local eq = char:FindFirstChildOfClass("Tool")
                local canAttempt = true
                if State.AutoArrestHandCheck then
                    canAttempt = eq ~= nil and eq.Name == "Handcuffs"
                end

                if canAttempt and LocalPlayer.Team == Teams:FindFirstChild("Guards") then
                    for _, plr in ipairs(playersSnapshot) do
                        if (TargetArrestCooldowns[plr.UserId] or 0) <= now and IsValidCombatTarget(plr, true, State.ArrestWhitelist, true) then
                            local pInfo = App.WorldCache.Players[plr]
                            local tHrp = (pInfo and pInfo.hrp and pInfo.hrp.Parent and pInfo.hrp) or GetRoot(plr.Character)
                            local maxArRange = State.AntiBanSafeMode and math.min(State.AutoArrestRange, 10) or State.AutoArrestRange
                            if tHrp and (tHrp.Position - hrp.Position).Magnitude <= maxArRange then
                                NextArrestAttempt = now + (State.AntiBanSafeMode and 0.36 or 0.22)
                                if not State.AutoArrestHandCheck and State.AutoArrestEquipHandcuffs and (not eq or eq.Name ~= "Handcuffs") then
                                    local cuffs = HasWeapon("Handcuffs")
                                    if cuffs and App.ToolArbiter.Acquire("AutoArrest", 3, 0.22) then
                                        pcall(function() hum:EquipTool(cuffs) end)
                                    end
                                end
                                task.spawn(function()
                                    local ok, arrested = pcall(function()
                                        return Remotes.ArrestPlayer:InvokeServer(plr, 1)
                                    end)
                                    if ok and arrested then
                                        TargetArrestCooldowns[plr.UserId] = os.clock() + 7.5
                                        LastArrestTime = os.clock() + 7
                                        PushMiniKillfeedLine("⛓ Arrested " .. plr.Name, Color3.fromRGB(96, 165, 250))
                                    else
                                        TargetArrestCooldowns[plr.UserId] = os.clock() + 0.9
                                    end
                                    App.ToolArbiter.Release("AutoArrest")
                                end)
                                break
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
        else
            Core.CleanupCharFly()
            UpdateVehicleWheelAura(nil)
            if UIRefs.FlyUpBtn then UIRefs.FlyUpBtn.Visible = false end
            if UIRefs.FlyDownBtn then UIRefs.FlyDownBtn.Visible = false end
        end

        -- Cached Anti-Fling (ZERO GetDescendants inside Heartbeat!)
        if State.AntiFling then
            local mySeat = hum and hum.SeatPart
            local myCar = mySeat and mySeat:FindFirstAncestorOfClass("Model")
            for carModel, entry in pairs(App.WorldCache.Cars) do
                if carModel.Parent and carModel ~= myCar then
                    for _, part in ipairs(entry.nonWheels) do
                        if part and part.Parent and part.CanCollide then
                            part.CanCollide = false
                            part.CanTouch = false
                        end
                    end
                end
            end
            for _, plr in ipairs(playersSnapshot) do
                if plr ~= LocalPlayer then
                    local info = App.WorldCache.Players[plr]
                    local tHrp = info and info.hrp
                    if tHrp and tHrp.Parent and tHrp.AssemblyAngularVelocity.Magnitude > 85 then
                        for _, desc in ipairs(info.parts) do
                            if desc and desc.Parent and desc.CanCollide then desc.CanCollide = false end
                        end
                    end
                end
            end
        end

        -- Anti-CarBring Protection (Disables passenger Seat TouchInterests on other cars & blocks forced kidnapping)
        if State.AntiCarBring then
            AntiCarBringApplied = true
            local mySeat = hum and hum.SeatPart
            local myCar = mySeat and mySeat:FindFirstAncestorOfClass("Model")
            for carModel, entry in pairs(App.WorldCache.Cars) do
                if carModel.Parent and carModel ~= myCar then
                    for _, ps in ipairs(entry.passSeats) do
                        if ps and ps.Parent and ps.CanTouch then
                            ps.CanTouch = false
                        end
                    end
                end
            end
            if mySeat and mySeat:IsA("Seat") and not mySeat:IsA("VehicleSeat") then
                local carEntry = myCar and App.WorldCache.Cars[myCar]
                local drv = carEntry and carEntry.drv
                if drv and drv.Occupant and drv.Occupant ~= hum and hrp then
                    hum.Sit = false
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end
        elseif AntiCarBringApplied then
            AntiCarBringApplied = false
            for carModel, entry in pairs(App.WorldCache.Cars) do
                if carModel.Parent then
                    for _, ps in ipairs(entry.passSeats) do
                        if ps and ps.Parent then ps.CanTouch = true end
                    end
                end
            end
        end

        -- Vehicle Fling Exploit (Blocked in Anti-Ban Safe Mode; uses cached Cars!)
        if State.VehicleFling and not State.AntiBanSafeMode then
            for carModel, entry in pairs(App.WorldCache.Cars) do
                local drv = entry.drv
                if carModel.Parent and drv and drv.Parent then
                    local owned = true
                    pcall(function()
                        if isnetworkowner then owned = isnetworkowner(drv) end
                    end)
                    if owned then
                        local targetPlr = (State.VehicleFlingTarget ~= "All") and Players:FindFirstChild(State.VehicleFlingTarget) or nil
                        if not targetPlr then
                            for _, p in ipairs(playersSnapshot) do
                                if IsValidCombatTarget(p, false, nil, false) then
                                    local pInfo = App.WorldCache.Players[p]
                                    local tHum = (pInfo and pInfo.hum) or GetHumanoid(p.Character)
                                    if tHum and not tHum.Sit then targetPlr = p; break end
                                end
                            end
                        end
                        local tInfo = targetPlr and App.WorldCache.Players[targetPlr]
                        local tHrp = (tInfo and tInfo.hrp) or (targetPlr and GetRoot(targetPlr.Character))
                        if tHrp then
                            drv.AssemblyLinearVelocity = Vector3.new(9500, 9500, 0)
                            drv.CFrame = CFrame.new(tHrp.Position) * CFrame.new(-1.5, 0, -8)
                        end
                    end
                end
            end
        end

        -- Clock-Gated 0.16s Utility & Visuals Slice (Consolidated into Single Scheduler!)
        if (now - LastUtilityTick) >= 0.16 then
            LastUtilityTick = now

            pcall(Core.UpdatePlayerESP)
            pcall(Core.EvaluateAnomalies)

            for _, plr in ipairs(playersSnapshot) do
                if plr ~= LocalPlayer then
                    local info = App.WorldCache.Players[plr]
                    local tChar = (info and info.char and info.char.Parent and info.char) or plr.Character
                    if tChar then
                        local tHrp = (info and info.hrp and info.hrp.Parent and info.hrp) or GetRoot(tChar)
                        local tHum = (info and info.hum and info.hum.Parent and info.hum) or GetHumanoid(tChar)

                        if tHrp then
                            if State.ExpandHitbox and IsValidCombatTarget(plr, State.SilentAimHostileCheck, nil, false) then
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

                        local shield = (info and info.riotShield and info.riotShield.Parent and info.riotShield) or tChar:FindFirstChild("RiotShieldPart")
                        if shield and shield:IsA("BasePart") then
                            shield.CanQuery = not State.AntiRiotShield
                        end

                        if State.AntiInvisible and tHum then
                            local animator = (info and info.animator and info.animator.Parent and info.animator) or tHum:FindFirstChildOfClass("Animator")
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
            end

            -- Auto Heal (Uses ToolArbiter)
            if State.AutoHeal and char and hum and hum.Health > 0 and hum.Health <= State.AutoHealThreshold and Remotes.EatFood then
                if App.ToolArbiter.Acquire("AutoHeal", 2, 0.2) then
                    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                    if bp then
                        for _, foodName in ipairs({ "Breakfast", "Lunch", "Dinner", "Donut", "Soda" }) do
                            local food = bp:FindFirstChild(foodName) or char:FindFirstChild(foodName)
                            if food and (now - (food:GetAttribute("Client_LastConsumedAt") or 0)) >= 3.1 then
                                local prevTool = char:FindFirstChildOfClass("Tool")
                                hum:EquipTool(food)
                                food:SetAttribute("Client_LastConsumedAt", now)
                                Remotes.EatFood:FireServer()
                                if prevTool and prevTool ~= food then hum:EquipTool(prevTool)
                                else hum:UnequipTools() end
                                break
                            end
                        end
                    end
                    App.ToolArbiter.Release("AutoHeal")
                end
            end

            -- Auto Pickup Dropped Keycards & Weapons (Uses WorldCache.Dropped — ZERO Workspace scan!)
            if State.AutoPickupDropped and hrp and Remotes.GiverPressed then
                for child in pairs(App.WorldCache.Dropped) do
                    if child and child.Parent then
                        local tName = child:GetAttribute("ToolName")
                        if tName and not HasWeapon(tName) then
                            local okP, piv = pcall(function() return child:GetPivot() end)
                            if okP and piv and (piv.Position - hrp.Position).Magnitude <= 11.5 then
                                Remotes.GiverPressed:FireServer(child)
                            end
                        end
                    else
                        App.WorldCache.Dropped[child] = nil
                    end
                end
            end

            -- Non-Yielding Cached Auto Armor (spawns InvokeServer so Heartbeat never blocks!)
            if State.AutoArmor and hrp and hum and not HasTargetArmor(char) and Remotes.InteractWithItem and (now - LastArmorInvoke) >= 1.1 then
                local candidates = App.WorldCache.ArmorParts
                if #candidates == 0 then
                    local clothes = Workspace:FindFirstChild("Prison_ITEMS") and Workspace.Prison_ITEMS:FindFirstChild("clothes")
                    if clothes then
                        for _, item in ipairs(clothes:GetChildren()) do
                            local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
                            if part then table.insert(candidates, part) end
                        end
                    end
                end
                for _, part in ipairs(candidates) do
                    if part and part.Parent and (part.Position - hrp.Position).Magnitude <= 12 then
                        LastArmorInvoke = now
                        task.spawn(function()
                            pcall(function() Remotes.InteractWithItem:InvokeServer(part) end)
                        end)
                        break
                    end
                end
            end

            -- Auto Detonate C4 (Uses ToolArbiter)
            if State.AutoDetonateC4 and hrp and Remotes.C4Folder and App.ToolArbiter.CanUse("AutoC4", 2) then
                local activateRemote = Remotes.C4Folder:FindFirstChild("ActivateC4")
                if activateRemote then
                    for _, c4 in ipairs(CollectionService:GetTagged("C4")) do
                        if c4:GetAttribute("UserId") == LocalPlayer.UserId and c4:IsA("BasePart") then
                            for _, plr in ipairs(playersSnapshot) do
                                if IsValidCombatTarget(plr, false, nil, false) then
                                    local pInfo = App.WorldCache.Players[plr]
                                    local tHrp = (pInfo and pInfo.hrp) or GetRoot(plr.Character)
                                    if tHrp and (tHrp.Position - c4.Position).Magnitude <= 22 and (hrp.Position - c4.Position).Magnitude > 26 then
                                        local c4Tool = HasWeapon("C4 Explosive")
                                        if c4Tool and hum and App.ToolArbiter.Acquire("AutoC4", 2, 0.25) then
                                            local prev = char:FindFirstChildOfClass("Tool")
                                            hum:EquipTool(c4Tool)
                                            task.spawn(function() pcall(function() activateRemote:InvokeServer() end) end)
                                            if prev then hum:EquipTool(prev) end
                                            App.ToolArbiter.Release("AutoC4")
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Cached Open All Doors (ZERO Doors:GetDescendants() in loop!)
            if State.OpenAllDoors then
                for _, part in ipairs(App.WorldCache.Doors) do
                    if part and part.Parent and part.CanCollide then
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
            if State.AutoReload and char and hum and hum.Health > 0 then
                local holdingGun, eqTool = IsHoldingFirearm()
                if holdingGun and eqTool then
                    local curAmmo = eqTool:GetAttribute("Local_CurrentAmmo") or eqTool:GetAttribute("CurrentAmmo") or 1
                    if curAmmo <= 0 and (eqTool:GetAttribute("Local_ReloadSession") or 0) <= 0 then
                        if not GunHook.Ready then SetupGunControllerHooks() end
                        if GunHook.Reload then task.spawn(GunHook.Reload) end
                        if State.AutoReloadHotSwap and App.ToolArbiter.CanUse("AutoReload", 1) then
                            local loaded = GetOwnedLoadedGuns()
                            if loaded[1] and loaded[1] ~= eqTool then hum:EquipTool(loaded[1]) end
                        end
                    end
                end
            end
        end

        -- FINAL HEARTBEAT STEP (Right before Roblox Network Replication Send!):
        -- Capture pre-rotation SavedCF/SavedVel FIRST so ShieldAutoFaceShooter & ShieldSpinBlock
        -- never spin the client's camera or movement vector; only the outgoing packet desyncs!
        if State.HoloShield and char and hrp and hum and hum.Health > 0 and not hum.Sit and not IsOnTeamsMenu() then
            local mode = State.ShieldMode or "UndergroundPeek"
            local reactiveUnderAttack = State.AutoHvH and State.AutoHvHReactiveEvade and HoloShieldState.LastAttacker and (now - HoloShieldState.LastAttackClock) < 1.6
            local origCF = hrp.CFrame
            local origVel = hrp.AssemblyLinearVelocity
            local outgoingCF = origCF
            local didRotate = false

            if (State.ShieldAutoFaceShooter or reactiveUnderAttack) and not State.ShieldSpinBlock then
                local atkInfo = reactiveUnderAttack and App.WorldCache.Players[HoloShieldState.LastAttacker]
                local atkPos = (atkInfo and atkInfo.hrp and atkInfo.hrp.Parent and atkInfo.hrp.Position)
                if not atkPos then
                    local threatPart = GetBestCombatTarget({ use360 = true, wallcheck = false, range = 95 })
                    atkPos = threatPart and threatPart.Position
                end
                if atkPos then
                    outgoingCF = CFrame.lookAt(origCF.Position, Vector3.new(atkPos.X, origCF.Position.Y, atkPos.Z))
                    didRotate = true
                end
            end

            if State.ShieldSpinBlock then
                local spinSpd = tonumber(State.ShieldSpinSpeed) or 18
                HoloShieldState.SpinAngle = ((HoloShieldState.SpinAngle or 0) + spinSpd * dt) % (math.pi * 2)
                outgoingCF = origCF * CFrame.Angles(0, HoloShieldState.SpinAngle, 0)
                didRotate = true
            end

            local firingNow = ((now - GunHook.LastRageShotClock) < 0.025) or ((now - GunHook.LastComboShotClock) < 0.025) or FiringBusy
            local useUnderground = (mode == "UndergroundPeek") or (mode == "Hybrid") or (reactiveUnderAttack and mode ~= "FEGhost")
            local useAntiLock = (mode == "AntiLockDesync" or mode == "DesyncBox") and not useUnderground
            local depth = clamp(tonumber(State.ShieldDepth) or 10.5, 6.0, 14.0)
            local canOffset = (useUnderground or useAntiLock) and not (State.RagebotPeekShield and firingNow) and not IsGrabbingGuns and (origCF.Position.Y - depth) > -5

            if canOffset or didRotate then
                HoloShieldState.SavedCF = origCF
                HoloShieldState.SavedVel = origVel
                HoloShieldState.DesyncActive = true
                if canOffset and useUnderground then
                    HoloShieldState.JitterAngle = (HoloShieldState.JitterAngle + 2.8) % (math.pi * 2)
                    local micro = Vector3.new(math.cos(HoloShieldState.JitterAngle) * 1.4, -depth, math.sin(HoloShieldState.JitterAngle) * 1.4)
                    hrp.CFrame = outgoingCF + micro
                elseif canOffset and useAntiLock then
                    local rad = clamp(tonumber(State.DesyncJitterRadius) or 5.5, 1.5, State.AntiBanSafeMode and 6.5 or 9.0)
                    HoloShieldState.JitterAngle = (HoloShieldState.JitterAngle + 2.65) % (math.pi * 2)
                    local yOsc = -3.5 - (3.5 * (0.5 + 0.5 * math.sin(HoloShieldState.JitterAngle * 1.7)))
                    hrp.CFrame = outgoingCF + Vector3.new(math.cos(HoloShieldState.JitterAngle) * rad, yOsc, math.sin(HoloShieldState.JitterAngle) * rad)
                    hrp.AssemblyLinearVelocity = Vector3.new(math.cos(HoloShieldState.JitterAngle) * 95, -160, math.sin(HoloShieldState.JitterAngle) * 95)
                else
                    hrp.CFrame = outgoingCF
                end
            end
        end
    end))

    AddConnection(UserInputService.JumpRequest:Connect(function()
        if State.InfiniteJump then
            local hum = GetHumanoid(LocalPlayer.Character)
            if hum and hum.Health > 0 then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end))

    local LocalCharScope = App.CreateScope()
    App.WorldCache.LocalCharScope = LocalCharScope
    local function AttachCharacterListeners(char)
        if not char then return end
        LocalCharScope:Clean()
        table.clear(App.WorldCache.LocalParts)
        table.clear(App.WorldCache.LocalCollideOrig)
        NoclipApplied = false
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then table.insert(App.WorldCache.LocalParts, d) end
        end
        LocalCharScope:Add(char.DescendantAdded:Connect(function(d)
            if d:IsA("BasePart") then table.insert(App.WorldCache.LocalParts, d) end
        end))

        task.spawn(function()
            local hum = char:WaitForChild("Humanoid", 8)
            if hum then
                LocalCharScope:Add(hum.Died:Connect(function()
                    DestroyHoloShield()
                    if State.FastRespawn then Core.PerformFastRespawn() end
                end))
            end

            task.wait(0.35)
            if LocalPlayer.Character ~= char then return end
            SetupGunControllerHooks()
            Core.InstallAntiTaseAndAntiArrestHooks()

            if State.AntiJumpCooldown or State.InfiniteStamina or State.MaxSpeed or State.JumpPowerEnabled then
                Core.BypassAntiJump(char, true)
            end
            if State.Noclip or State.MaxSpeed then
                Core.BypassClientAntiNoclip()
            end
            if not IsOnTeamsMenu() then
                if State.FEInvisible or (State.HoloShield and State.ShieldMode == "FEGhost") then
                    Core.StartFEInvisible(State.HoloShield and State.ShieldMode == "FEGhost")
                end
                if State.HoloShield and State.ShieldMode ~= "FEGhost" then
                    CreateHoloShield()
                end
                if State.AutoGetGuns and LocalPlayer.Team ~= Teams:FindFirstChild("Neutral") then
                    task.wait(0.45)
                    GrabWeapons(State.AutoGetGunsSelection, true)
                end
            end

            local bp = LocalPlayer:WaitForChild("Backpack", 5)
            if bp and LocalPlayer.Character == char then
                LocalCharScope:Add(bp.ChildAdded:Connect(function(child)
                    task.wait(0.05)
                    ApplyGunModsToTool(child)
                end))
            end
            if LocalPlayer.Character == char then
                LocalCharScope:Add(char.ChildAdded:Connect(function(child)
                    task.wait(0.05)
                    if child:IsA("Tool") then
                        if not GunHook.Ready then SetupGunControllerHooks() end
                        ApplyGunModsToTool(child)
                        Core.ApplyToolFEInvisTransparency(child)
                    end
                end))
            end
        end)
    end

    if LocalPlayer.Character then AttachCharacterListeners(LocalPlayer.Character) end
    AddConnection(LocalPlayer.CharacterAdded:Connect(AttachCharacterListeners))
end

-- ============================================================================
-- // SECTION 12: TELEPORTS, BULK ACTIONS, PRESETS & SERVER UTILITIES
-- ============================================================================
do
    Core.TeleportLocations = {
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

    Core.TeleportAliases = {
        yard = "Prison Yard", nexus = "Nexus / Main Hall", cafeteria = "Cafeteria",
        cells = "Cellblock", cellblock = "Cellblock", armory = "Guard Armory (Guns)",
        crimbase = "Criminal Base (AK)", roof = "Prison Roof", tower = "Yard Watchtower",
        gate = "Front Gate", sewer = "Sewer Escape", hideout = "Secret Hideout",
        cars = "City Car Spawner", store = "Grocery Store", gas = "Gas Station",
        neutral = "Neutral Spawn Room",
    }

    function Core.RunArrestAll(targetQuery)
        if not Remotes.ArrestPlayer then Notify("ArrestAll", "ArrestPlayer remote unavailable!", 2.5); return end
        if LocalPlayer.Team ~= Teams:FindFirstChild("Guards") then Notify("ArrestAll", "Switch to Guards team first (;guard)!", 2.5); return end
        local hrp = GetRoot(LocalPlayer.Character)
        if not hrp then return end

        local list = ResolveTargetPlayers(targetQuery or "others")
        local savedCF = hrp.CFrame
        task.spawn(function()
            local count = 0
            for _, p in ipairs(list) do
                if IsValidCombatTarget(p, true, State.ArrestWhitelist, true) then
                    local tHrp = GetRoot(p.Character)
                    if tHrp and (not State.AntiBanSafeMode or (tHrp.Position - hrp.Position).Magnitude <= 350) then
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
            SafeTeleport(savedCF)
            Notify("ArrestAll", "Arrested " .. tostring(count) .. " target(s)!", 2.5)
        end)
    end

    function Core.RunTaseTargets(targetQuery)
        local taser = HasWeapon("Taser")
        if not taser then Notify("Tase", "Need a Taser (Guards team)!", 2.5); return end
        local list = ResolveTargetPlayers(targetQuery or "nearest")
        task.spawn(function()
            local count = 0
            for _, p in ipairs(list) do
                if IsValidCombatTarget(p, true, State.ArrestWhitelist, true) then
                    local tHead = p.Character and (p.Character:FindFirstChild("Head") or GetRoot(p.Character))
                    if tHead and FireToolAtTarget(taser, tHead, false, true, false) then
                        count = count + 1
                    end
                    task.wait(0.15)
                end
            end
            Notify("Tase", "Tased " .. tostring(count) .. " target(s)!", 2.2)
        end)
    end

    function Core.RunShootKillTargets(targetQuery)
        local loaded = GetOwnedLoadedGuns()
        if #loaded == 0 then Notify("Kill", "Grab a loaded weapon first (;guns)!", 2.5); return end
        local list = ResolveTargetPlayers(targetQuery or "nearest")
        task.spawn(function()
            local count = 0
            for _, p in ipairs(list) do
                if IsValidCombatTarget(p, State.SilentAimHostileCheck, State.KillAuraWhitelist, false) then
                    local tHum = GetHumanoid(p.Character)
                    local tPart = p.Character and (p.Character:FindFirstChild("Head") or GetRoot(p.Character))
                    if tPart and tHum then
                        for _ = 1, 4 do
                            if tHum.Health <= 0 then break end
                            local g = GetOwnedLoadedGuns()[1] or loaded[1]
                            FireToolAtTarget(g, tPart, true, false, false)
                            task.wait(0.08)
                        end
                        count = count + 1
                    end
                end
            end
            Notify("Engage", "Engaged " .. tostring(count) .. " target(s)!", 2.2)
        end)
    end

    function Core.ApplyPresetProfile(presetName)
        local low = string.lower(Trim(presetName))
        if low == "safe" or low == "default" then
            State.AntiBanSafeMode = true
            State.SilentAim = true
            State.SilentAimFOV = 160
            State.SilentAimWallbang = false
            State.Ragebot = false
            State.AutoHvH = false
            State.GunMods = true
            State.GunFireRateSPS = 14
            State.MaxSpeed = true
            State.MaxSpeedMode = "RegionSafe"
            State.AntiTase = true
            State.AntiFling = true
            State.ESP = true
            Core.SyncAfterStateLoad()
            Notify("Preset", "Applied Anti-Ban SAFE Preset!", 2.5)
        elseif low == "legit" then
            State.AntiBanSafeMode = true
            State.SilentAim = true
            State.SilentAimFOV = 110
            State.SilentAimHitChance = 90
            State.SilentAimWallbang = false
            State.AimAssist = true
            State.Ragebot = false
            State.AutoHvH = false
            State.GunMods = false
            State.MaxSpeed = true
            State.MaxSpeedMode = "AlwaysSprint"
            State.AntiTase = true
            State.ESP = true
            Core.SyncAfterStateLoad()
            Notify("Preset", "Applied LEGIT Closet Preset!", 2.5)
        elseif low == "rage" or low == "hvh" then
            State.AntiBanSafeMode = true
            State.HoloShield = true
            State.ShieldMode = (low == "hvh") and "UndergroundPeek" or "AntiLockDesync"
            State.RagebotPeekShield = false
            State.AutoHvH = (low == "hvh")
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
            Core.SyncAfterStateLoad()
            Notify("Preset", "Applied KX " .. string.upper(low) .. " + Anti-Hit Shield Preset!", 2.5)
        end
    end

    function Core.RejoinServer()
        Notify("Rejoin", "Rejoining Prison Life server...", 2)
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    end

    function Core.ServerHop()
        Notify("Server Hop", "Finding populated Prison Life server...", 2.5)
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

    function Core.SyncAfterStateLoad()
        ApplyGunModsAll()
        if State.HoloShield then CreateHoloShield() else DestroyHoloShield() end
        if not State.ExpandHitbox and Core.RestoreAllHitboxes then Core.RestoreAllHitboxes() end
        if not State.OpenAllDoors and Core.RestoreAllDoors then Core.RestoreAllDoors() end
        if not State.Fly and Core.CleanupCharFly then Core.CleanupCharFly() end
        if not State.Noclip and Core.RestoreLocalNoclip then Core.RestoreLocalNoclip() end
        if Core.ApplyFenceGodmode then Core.ApplyFenceGodmode(State.FenceGodmode) end
        if Core.SetFEInvisibleState then Core.SetFEInvisibleState(State.FEInvisible, false) end
        if UIRefs.ComboTopLeftBtn then UIRefs.ComboTopLeftBtn.Visible = State.ShowComboButton end
        if UIRefs.CmdTogglePill then UIRefs.CmdTogglePill.Visible = State.ShowCommandPill end
        if not State.ESP and Core.ESPObjects then
            for plr in pairs(Core.ESPObjects) do Core.RemovePlayerESP(plr) end
        end
        if Core.SyncVisualUI then Core.SyncVisualUI() end
    end
end

-- ============================================================================
-- // SECTION 12B: EMBEDDED JSON PERSISTENCE & CONFIG PROFILE ENGINE
-- ============================================================================
do
    local P = App.Persistence
    local RootDir = "PrisonLife2026Hub"
    local ProfilesDir = RootDir .. "/profiles"
    local MetaFile = RootDir .. "/meta.json"
    local VolatileKeys = {
        KillAuraWhitelist = true,
        LoopKillTargets = true,
        ArrestWhitelist = true,
    }

    local function HasFS()
        return type(writefile) == "function" and type(readfile) == "function"
    end

    local function EnsureDirs()
        if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
        pcall(function()
            if not isfolder(RootDir) then makefolder(RootDir) end
            if not isfolder(ProfilesDir) then makefolder(ProfilesDir) end
        end)
    end

    -- Pure-Lua JSON Encoder / Recursive-Descent Decoder Fallback
    local function escapeStr(s)
        s = tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
        return '"' .. s .. '"'
    end

    local function PureEncode(val)
        local t = type(val)
        if t == "nil" then return "null"
        elseif t == "boolean" then return val and "true" or "false"
        elseif t == "number" then
            if val ~= val or val == math.huge or val == -math.huge then return "0" end
            return tostring(val)
        elseif t == "string" then return escapeStr(val)
        elseif t == "table" then
            local maxIdx, count = 0, 0
            for k in pairs(val) do
                count = count + 1
                if type(k) == "number" and k >= 1 and math.floor(k) == k then
                    if k > maxIdx then maxIdx = k end
                else
                    maxIdx = -1
                end
            end
            if maxIdx == count and count > 0 then
                local parts = {}
                for i = 1, count do parts[i] = PureEncode(val[i]) end
                return "[" .. table.concat(parts, ",") .. "]"
            else
                local parts = {}
                for k, v in pairs(val) do
                    if type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then
                        table.insert(parts, escapeStr(k) .. ":" .. PureEncode(v))
                    end
                end
                table.sort(parts)
                return "{" .. table.concat(parts, ",") .. "}"
            end
        end
        return "null"
    end

    local function PureDecode(str)
        if type(str) ~= "string" then return nil end
        local pos, len = 1, #str
        local function skipWS()
            local _, nxt = str:find("^[ \t\r\n]+", pos)
            if nxt then pos = nxt + 1 end
        end
        local parseVal
        local function parseStr()
            pos = pos + 1
            local out = {}
            while pos <= len do
                local c = str:sub(pos, pos)
                if c == '"' then pos = pos + 1; return table.concat(out)
                elseif c == "\\" then
                    local nx = str:sub(pos + 1, pos + 1)
                    local map = { ['"'] = '"', ['\\'] = '\\', n = "\n", r = "\r", t = "\t", ['/'] = '/' }
                    table.insert(out, map[nx] or nx)
                    pos = pos + 2
                else
                    table.insert(out, c)
                    pos = pos + 1
                end
            end
            return table.concat(out)
        end
        parseVal = function()
            skipWS()
            local c = str:sub(pos, pos)
            if c == '"' then return parseStr()
            elseif c == "{" then
                pos = pos + 1
                local obj = {}
                skipWS()
                if str:sub(pos, pos) == "}" then pos = pos + 1; return obj end
                while pos <= len do
                    skipWS()
                    if str:sub(pos, pos) ~= '"' then break end
                    local k = parseStr()
                    skipWS()
                    if str:sub(pos, pos) == ":" then pos = pos + 1 end
                    obj[k] = parseVal()
                    skipWS()
                    local sep = str:sub(pos, pos)
                    if sep == "}" then pos = pos + 1; return obj end
                    if sep == "," then pos = pos + 1 else break end
                end
                return obj
            elseif c == "[" then
                pos = pos + 1
                local arr = {}
                skipWS()
                if str:sub(pos, pos) == "]" then pos = pos + 1; return arr end
                while pos <= len do
                    table.insert(arr, parseVal())
                    skipWS()
                    local sep = str:sub(pos, pos)
                    if sep == "]" then pos = pos + 1; return arr end
                    if sep == "," then pos = pos + 1 else break end
                end
                return arr
            elseif str:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
            elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
            elseif str:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
            else
                local numStr = str:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
                if numStr and #numStr > 0 then
                    pos = pos + #numStr
                    return tonumber(numStr)
                end
                pos = pos + 1
                return nil
            end
        end
        local ok, res = pcall(parseVal)
        return ok and res or nil
    end

    function P.EncodeJSON(tbl)
        local ok, res = pcall(function() return HttpService:JSONEncode(tbl) end)
        if ok and type(res) == "string" and #res > 0 then return res end
        return PureEncode(tbl)
    end

    function P.DecodeJSON(str)
        if type(str) ~= "string" or str == "" then return nil end
        local ok, res = pcall(function() return HttpService:JSONDecode(str) end)
        if ok and type(res) == "table" then return res end
        local pRes = PureDecode(str)
        return type(pRes) == "table" and pRes or nil
    end

    local function SanitizeName(name)
        local s = Trim(tostring(name or "default")):gsub("[^%w%._%-]", "_")
        return (s == "" and "default") or s
    end

    function P.SaveMeta(autoLoad, defaultName)
        if not HasFS() then return false end
        EnsureDirs()
        local raw = P.EncodeJSON({ autoLoad = (autoLoad == true), defaultProfile = SanitizeName(defaultName or "default") })
        return pcall(writefile, MetaFile, raw)
    end

    function P.LoadMeta()
        if not HasFS() or type(isfile) ~= "function" then return { autoLoad = true, defaultProfile = "default" } end
        local okE, exists = pcall(isfile, MetaFile)
        if okE and exists then
            local okR, raw = pcall(readfile, MetaFile)
            local dec = okR and P.DecodeJSON(raw)
            if type(dec) == "table" then
                return {
                    autoLoad = (dec.autoLoad ~= false),
                    defaultProfile = SanitizeName(dec.defaultProfile or "default"),
                }
            end
        end
        return { autoLoad = true, defaultProfile = "default" }
    end

    function P.ListProfiles()
        local names = { "default" }
        local seen = { default = true }
        if type(listfiles) ~= "function" then return names end
        EnsureDirs()
        local ok, files = pcall(listfiles, ProfilesDir)
        if ok and type(files) == "table" then
            for _, fPath in ipairs(files) do
                local n = tostring(fPath):match("([^/\\]+)%.json$")
                if n and not seen[n] then
                    seen[n] = true
                    table.insert(names, n)
                end
            end
        end
        table.sort(names)
        return names
    end

    function P.SaveProfile(name, silent)
        if not HasFS() then
            if not silent then Notify("Config", "Executor filesystem API unavailable.", 2.5) end
            return false
        end
        EnsureDirs()
        local clean = SanitizeName(name)
        local snapshot = {}
        for k, v in pairs(State) do
            if not VolatileKeys[k] and type(v) ~= "function" and type(v) ~= "userdata" then
                snapshot[k] = v
            end
        end
        local path = ProfilesDir .. "/" .. clean .. ".json"
        local ok = pcall(writefile, path, P.EncodeJSON(snapshot))
        if not silent then
            Notify("Config", ok and ("Saved profile '" .. clean .. "'!") or "Failed to write config.", 2.4)
        end
        return ok
    end

    function P.LoadProfile(name, silent)
        if not HasFS() then return false end
        local clean = SanitizeName(name)
        local path = ProfilesDir .. "/" .. clean .. ".json"
        if type(isfile) == "function" then
            local okE, ex = pcall(isfile, path)
            if not okE or not ex then
                if not silent then Notify("Config", "Profile '" .. clean .. "' not found.", 2.2) end
                return false
            end
        end
        local okR, raw = pcall(readfile, path)
        local dec = okR and P.DecodeJSON(raw)
        if type(dec) ~= "table" then
            if not silent then Notify("Config", "Corrupted JSON in '" .. clean .. "'.", 2.2) end
            return false
        end
        for k, v in pairs(dec) do
            if not VolatileKeys[k] and State[k] ~= nil and type(v) == type(State[k]) then
                State[k] = v
            end
        end
        Core.SyncAfterStateLoad()
        if not silent then
            Notify("Config", "Loaded profile '" .. clean .. "'!", 2.4)
        end
        return true
    end

    function P.DeleteProfile(name, silent)
        local clean = SanitizeName(name)
        if type(delfile) ~= "function" then return false end
        local path = ProfilesDir .. "/" .. clean .. ".json"
        local ok = pcall(delfile, path)
        if not silent then
            Notify("Config", ok and ("Deleted profile '" .. clean .. "'.") or "Profile could not be deleted.", 2.2)
        end
        return ok
    end

    function P.TryAutoLoad()
        local meta = P.LoadMeta()
        State.ConfigAutoLoad = meta.autoLoad
        if meta.autoLoad then
            P.LoadProfile(meta.defaultProfile or "default", true)
        end
    end
end

-- ============================================================================
-- // SECTION 13: KX COMMAND ENGINE (. / ; / ! / / PREFIXES) & PC HOTKEYS
-- ============================================================================
do
    local GunNameAliases = {
        remington = "Remington 870", rem = "Remington 870", ["870"] = "Remington 870", shotgun = "Remington 870",
        ak = "AK-47", ak47 = "AK-47", ["ak-47"] = "AK-47",
        m4 = "M4A1", m4a1 = "M4A1", rifle = "M4A1",
        m9 = "M9", pistol = "M9",
        mp5 = "MP5", smg = "MP5",
        fal = "FAL",
        m700 = "M700", sniper = "M700", awp = "M700",
        revolver = "Revolver", rev = "Revolver",
        riot = "Riot Shield", shield = "Riot Shield",
        hammer = "Hammer", knife = "Crude Knife", crudeknife = "Crude Knife",
    }

    local CommandCatalog = {
        { cmd = ".savecar [1..5]", desc = "Save car pool for Bring / ForceCrim / Void" },
        { cmd = ".forcecrim <plr|all>", desc = "Force target(s) to Criminal team via car" },
        { cmd = ".bring <plr|all>", desc = "FE bring player(s) via Saved Car seat" },
        { cmd = ".void <plr|all>", desc = "Drop target(s) into void via Saved Car" },
        { cmd = ".fling <plr|all>", desc = "Car-fling target player(s)" },
        { cmd = ".target <plr> / .untarget", desc = "Prioritize specific player in Aim/Ragebot" },
        { cmd = ".autohvh [on|off]", desc = "Full Hack-vs-Hack suite (Hotkey: H)" },
        { cmd = ".evade [on|off]", desc = "Reactive Auto-Evade vs incoming shooters" },
        { cmd = ".wheelaura [on|off]", desc = "Neon particle aura on vehicle wheels" },
        { cmd = ".anticarbring [on|off]", desc = "Block passenger-seat kidnapping attempts" },
        { cmd = ".hammer / .knife", desc = "Instant grab Hammer or Crude Knife" },
        { cmd = ".m700 / .revolver", desc = "Grab Sniper Update M700 or Revolver" },
        { cmd = ".guns / .gun <name>", desc = "Grab loadout or specific firearm" },
        { cmd = ".loadout <light|sniper|riot|full>", desc = "Apply & grab weapon loadout kit" },
        { cmd = ".refill", desc = "Reload & refill low-ammo firearms" },
        { cmd = ".rehook", desc = "Re-scan PC/Mobile GunController hooks" },
        { cmd = ".combo1 / .loopcombo", desc = "Multi-gun burst (Hotkey: X)" },
        { cmd = ".shield / .shieldmode <mode>", desc = "5-Mode 3D Bullet Shield (Hotkey: G)" },
        { cmd = ".shieldstyle <cyberhex|neonring|minimal>", desc = "Switch ground halo visual style" },
        { cmd = ".rage / .silentaim / .wallbang", desc = "Ragebot / Silent Aim / Wallbang" },
        { cmd = ".killaura / .hitbox", desc = "Melee Kill Aura & Hitbox Expander" },
        { cmd = ".kill / .loopkill <plr>", desc = "Engage or LoopKill player(s)" },
        { cmd = ".guard / .inmate / .crim", desc = "Instant team switch" },
        { cmd = ".re / .arrestall / .tase", desc = "Fast respawn, ArrestAll & Tase" },
        { cmd = ".antitase / .antiarrest", desc = "Toggle stun & cuff immunity" },
        { cmd = ".invis / .fly / .car / .carfly", desc = "FE Invis, Character Fly, Car Fly" },
        { cmd = ".speed <16..92|off> / .safespeed", desc = "WalkSpeed or 20-Region SafeSpeed" },
        { cmd = ".noclip / .opendoors / .fencegod", desc = "Noclip, Doors & Fence Godmode" },
        { cmd = ".esp / .itemesp", desc = "Toggle Player ESP & Dropped ItemESP" },
        { cmd = ".goto <loc|plr> / .view <plr>", desc = "Teleport or Spectate player" },
        { cmd = ".status", desc = "Show hook/pool/shield diagnostics" },
        { cmd = ".preset <safe|legit|rage|hvh>", desc = "Load configuration preset" },
        { cmd = ".savecfg [name] / .loadcfg [name]", desc = "Save or load JSON config profile" },
        { cmd = ".rejoin / .serverhop", desc = "Rejoin or hop server" },
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
        for w in string.gmatch(seg, "%S+") do table.insert(words, w) end
        if #words == 0 then return end

        local cmd = string.lower((words[1]:gsub("^[-;/!%.]+", "")))
        local arg1 = words[2]
        local rest = Trim(table.concat(words, " ", 2))

        -- Signature KX Admin Vehicle / HvH Commands
        local function dispatchCarAction(targets, mode)
            if #targets == 0 then
                Notify("KX Car Action", "No valid target players matched!", 2.2)
            elseif #targets == 1 then
                ExecuteCarTargetAction(targets[1], mode)
            else
                Core.ExecuteCarActionBatch(targets, mode)
            end
        end

        if cmd == "savecar" or cmd == "sc" then
            SaveCarsCommand(tonumber(arg1) or 1)
        elseif cmd == "forcecrim" or cmd == "fc" then
            dispatchCarAction(ResolveTargetPlayers(rest ~= "" and rest or "nearest"), "forcecrim")
        elseif cmd == "bring" then
            dispatchCarAction(ResolveTargetPlayers(rest), "bring")
        elseif cmd == "void" or cmd == "forcekick" or cmd == "fkm" then
            dispatchCarAction(ResolveTargetPlayers(rest), "void")
        elseif cmd == "fling" or cmd == "cfling" then
            dispatchCarAction(ResolveTargetPlayers(rest), "fling")
        elseif cmd == "target" or cmd == "focus" then
            local plrs = ResolveTargetPlayers(rest ~= "" and rest or "nearest")
            if plrs[1] and plrs[1] ~= LocalPlayer then
                State.FocusTargetUserId = plrs[1].UserId
                Notify("Target Focus", "Prioritizing " .. plrs[1].Name .. " in combat", 2.2)
            else
                Notify("Target Focus", "Player not found.", 2.0)
            end
        elseif cmd == "untarget" or cmd == "unfocus" or cmd == "cleartarget" then
            State.FocusTargetUserId = nil
            Notify("Target Focus", "Cleared priority target.", 2.0)
        elseif cmd == "rehook" or cmd == "rehookguns" then
            Core.RehookGunController(true)
        elseif cmd == "refill" or cmd == "ammo" then
            App.RefillEmptyWeapons()
        elseif cmd == "anticarbring" or cmd == "antibring" then
            State.AntiCarBring = ParseToggleArg(arg1, State.AntiCarBring)
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Anti-CarBring", State.AntiCarBring and "ON" or "OFF", 2.0)
        elseif cmd == "itemesp" or cmd == "drops" then
            State.ItemESP = ParseToggleArg(arg1, State.ItemESP)
            if not State.ItemESP and Core.RemoveAllItemESP then Core.RemoveAllItemESP() end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Item ESP", State.ItemESP and "ON" or "OFF", 2.0)
        elseif cmd == "status" or cmd == "diag" or cmd == "info" then
            local msg = ("Hook:%s (%s, fired=%d) | Shield:%s (%s/%s) | HvH:%s | Safe:%s | AntiBring:%s | Cars:%d"):format(
                GunHook.Ready and "OK" or "WAIT",
                tostring(GunHook.HookSource),
                tonumber(GunHook.BulletHookFiredCount) or 0,
                State.HoloShield and "ON" or "OFF",
                tostring(State.ShieldMode),
                tostring(State.ShieldVisualStyle),
                State.AutoHvH and "ON" or "OFF",
                State.AntiBanSafeMode and "ON" or "OFF",
                State.AntiCarBring and "ON" or "OFF",
                #SavedCars
            )
            Notify("PL 2026 Diagnostics", msg, 4.5)
        elseif cmd == "autohvh" or cmd == "hvh" then
            State.AutoHvH = ParseToggleArg(arg1, State.AutoHvH)
            if State.AutoHvH then
                State.HoloShield = true
                State.AntiTase = true
                State.AntiArrest = true
                CreateHoloShield()
                SetupGunControllerHooks()
            end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("AutoHvH", State.AutoHvH and "AutoHvH ON (Threat Priority + Shield + Anti-Stun)" or "AutoHvH OFF", 2.5)
        elseif cmd == "wheelaura" or cmd == "wheelfx" then
            State.WheelAura = ParseToggleArg(arg1, State.WheelAura)
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("WheelAura", "Vehicle Wheel Aura: " .. (State.WheelAura and "ON" or "OFF"), 2)
        elseif cmd == "hammer" or cmd == "gethammer" then
            task.spawn(function() GrabWeapons({ "Hammer" }) end)
        elseif cmd == "knife" or cmd == "getknife" or cmd == "crudeknife" or cmd == "getmethod" then
            task.spawn(function() GrabWeapons({ "Crude Knife", "Hammer" }) end)
        elseif cmd == "m700" or cmd == "sniper" then
            task.spawn(function() GrabWeapons({ "M700" }) end)
        elseif cmd == "revolver" or cmd == "rev" then
            task.spawn(function() GrabWeapons({ "Revolver" }) end)
        elseif cmd == "evade" or cmd == "reactiveevade" then
            State.AutoHvHReactiveEvade = ParseToggleArg(arg1, State.AutoHvHReactiveEvade)
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("AutoHvH Evade", "Reactive Shooter Evade: " .. (State.AutoHvHReactiveEvade and "ON" or "OFF"), 2)
        elseif cmd == "savecfg" or cmd == "saveprofile" then
            App.Persistence.SaveProfile(rest ~= "" and rest or "default", false)
        elseif cmd == "loadcfg" or cmd == "loadprofile" then
            App.Persistence.LoadProfile(rest ~= "" and rest or "default", false)
        elseif cmd == "delcfg" or cmd == "delprofile" then
            App.Persistence.DeleteProfile(rest ~= "" and rest or "default", false)
        elseif cmd == "configs" or cmd == "profiles" then
            Notify("Config Profiles", table.concat(App.Persistence.ListProfiles(), ", "), 3.2)
        elseif cmd == "autoload" then
            State.ConfigAutoLoad = ParseToggleArg(arg1, State.ConfigAutoLoad)
            App.Persistence.SaveMeta(State.ConfigAutoLoad, "default")
            Notify("Config Auto-Load", State.ConfigAutoLoad and "ON (default)" or "OFF", 2)
        elseif cmd == "detaillod" or cmd == "lod" then
            if tonumber(arg1) then
                State.ESPDetailDistance = clamp(tonumber(arg1), 40, 600)
                if Core.SyncVisualUI then Core.SyncVisualUI() end
                Notify("ESP LOD", "Detail distance: " .. tostring(State.ESPDetailDistance) .. "m", 2)
            end
        -- Weapons & Combat Commands
        elseif cmd == "guns" or cmd == "getguns" or cmd == "grabguns" then
            task.spawn(function() GrabWeapons(State.AutoGetGunsSelection) end)
        elseif cmd == "gun" or cmd == "weapon" then
            local g = GunNameAliases[string.lower(rest)] or rest
            if g ~= "" then task.spawn(function() GrabWeapons({ g }) end) end
        elseif cmd == "loadout" or cmd == "kit" then
            local k = string.lower(arg1 or "cop")
            if k == "none" or k == "light" or k == "sniper" or k == "riot" or k == "full" then
                App.SetAutoLoadoutKit(k, true)
            elseif k == "crim" or k == "criminal" then
                task.spawn(function() GrabWeapons({ "AK-47", "FAL", "Remington 870" }) end)
            else
                task.spawn(function() GrabWeapons({ "Remington 870", "MP5", "M9", "M4A1", "Riot Shield" }) end)
            end
        elseif cmd == "combo1" or cmd == "combo" then
            task.spawn(ExecuteCombo1)
        elseif cmd == "loopcombo" or cmd == "autocombo" then
            State.ComboLoop = ParseToggleArg(arg1, State.ComboLoop)
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Command", "Loop .combo1: " .. (State.ComboLoop and "ON" or "OFF"), 2)
        elseif cmd == "shield" or cmd == "shieldbox" then
            State.HoloShield = ParseToggleArg(arg1, State.HoloShield)
            if State.HoloShield then CreateHoloShield() else DestroyHoloShield() end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Bullet Shield", (State.HoloShield and ("ON (" .. State.ShieldMode .. ")") or "OFF"), 2)
        elseif cmd == "unshield" or cmd == "noshield" then
            State.HoloShield = false
            DestroyHoloShield()
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Bullet Shield", "OFF", 2)
        elseif cmd == "shieldmode" or cmd == "smode" then
            local m = string.lower(arg1 or "underground")
            local map = {
                hybrid = "Hybrid", underground = "UndergroundPeek", undergroundpeek = "UndergroundPeek",
                desync = "AntiLockDesync", desyncbox = "AntiLockDesync", antilock = "AntiLockDesync", antilockdesync = "AntiLockDesync",
                riot = "RiotOnly", riotonly = "RiotOnly", ghost = "FEGhost", feghost = "FEGhost",
            }
            if map[m] then
                State.ShieldMode = map[m]
                if State.HoloShield then CreateHoloShield() end
                if Core.SyncVisualUI then Core.SyncVisualUI() end
                Notify("Shield Mode", State.ShieldMode, 2)
            end
        elseif cmd == "shieldstyle" or cmd == "sstyle" then
            local st = string.lower(arg1 or "cyberhex")
            local stMap = { cyberhex = "CyberHex", cyber = "CyberHex", neonring = "NeonRing", neon = "NeonRing", ring = "NeonRing", minimal = "Minimal", min = "Minimal" }
            if stMap[st] then
                State.ShieldVisualStyle = stMap[st]
                if State.HoloShield then CreateHoloShield() end
                if Core.SyncVisualUI then Core.SyncVisualUI() end
                Notify("Shield Style", State.ShieldVisualStyle, 2)
            end
        elseif cmd == "antiaim" or cmd == "desync" or cmd == "antilock" then
            State.ShieldMode = "AntiLockDesync"
            State.HoloShield = true
            CreateHoloShield()
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("AntiLock Desync", "ON", 2)
        elseif cmd == "unantiaim" or cmd == "undesync" then
            State.ShieldMode = "UndergroundPeek"
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("AntiLock Desync", "Switched to UndergroundPeek", 2)
        elseif cmd == "spinblock" then
            State.ShieldSpinBlock = ParseToggleArg(arg1, State.ShieldSpinBlock)
            Notify("Shield Spin-Block", State.ShieldSpinBlock and "ON" or "OFF", 2)
        elseif cmd == "autofaceshield" or cmd == "autoshield" then
            State.ShieldAutoFaceShooter = ParseToggleArg(arg1, State.ShieldAutoFaceShooter)
            Notify("Auto-Face Shooter", State.ShieldAutoFaceShooter and "ON" or "OFF", 2)
        elseif cmd == "rage" or cmd == "ragebot" or cmd == "rb" then
            if tonumber(arg1) then
                State.RagebotRate = clamp(tonumber(arg1), 2, 30)
                State.Ragebot = true
            else
                State.Ragebot = ParseToggleArg(arg1, State.Ragebot)
            end
            if State.Ragebot then SetupGunControllerHooks() end
            Notify("Ragebot", State.Ragebot and "ON" or "OFF", 2)
        elseif cmd == "unrage" or cmd == "unrb" then
            State.Ragebot = false
            Notify("Ragebot", "OFF", 2)
        elseif cmd == "silentaim" or cmd == "sa" or cmd == "silent" then
            State.SilentAim = ParseToggleArg(arg1, State.SilentAim)
            if State.SilentAim then SetupGunControllerHooks() end
            Notify("Silent Aim", State.SilentAim and "ON" or "OFF", 2)
        elseif cmd == "unsa" or cmd == "unsilent" then
            State.SilentAim = false
            Notify("Silent Aim", "OFF", 2)
        elseif cmd == "wallbang" or cmd == "wb" then
            State.SilentAimWallbang = ParseToggleArg(arg1, State.SilentAimWallbang)
            Notify("Wallbang Scanner", State.SilentAimWallbang and "ON" or "OFF", 2)
        elseif cmd == "killaura" or cmd == "ka" or cmd == "aura" then
            if tonumber(arg1) then
                State.KillAuraRange = clamp(tonumber(arg1), 4, 14)
                State.KillAura = true
            else
                State.KillAura = ParseToggleArg(arg1, State.KillAura)
            end
            Notify("Kill Aura", State.KillAura and "ON" or "OFF", 2)
        elseif cmd == "unka" or cmd == "unaura" then
            State.KillAura = false
            Notify("Kill Aura", "OFF", 2)
        elseif cmd == "hitbox" or cmd == "hb" or cmd == "expand" then
            if tonumber(arg1) then
                State.HitboxSize = clamp(tonumber(arg1), 3, 18)
                State.ExpandHitbox = true
            else
                State.ExpandHitbox = ParseToggleArg(arg1, State.ExpandHitbox)
                if not State.ExpandHitbox then Core.RestoreAllHitboxes() end
            end
            Notify("Hitbox Expander", State.ExpandHitbox and ("ON (" .. State.HitboxSize .. ")") or "OFF", 2)
        elseif cmd == "unhb" or cmd == "unexpand" then
            State.ExpandHitbox = false
            Core.RestoreAllHitboxes()
            Notify("Hitbox Expander", "OFF", 2)
        elseif cmd == "kill" then
            Core.RunShootKillTargets(rest ~= "" and rest or "nearest")
        elseif cmd == "killall" then
            Core.RunShootKillTargets(rest ~= "" and rest or "others")
        elseif cmd == "loopkill" or cmd == "lk" then
            local targets = ResolveTargetPlayers(rest)
            for _, p in ipairs(targets) do
                if p ~= LocalPlayer then State.LoopKillTargets[p.UserId] = true end
            end
            Notify("LoopKill", "Added " .. tostring(#targets) .. " player(s)", 2)
        elseif cmd == "unloopkill" or cmd == "unlk" then
            table.clear(State.LoopKillTargets)
            Notify("LoopKill", "Cleared list", 2)
        elseif cmd == "kawl" then
            local targets = ResolveTargetPlayers(rest)
            for _, p in ipairs(targets) do State.KillAuraWhitelist[p.UserId] = true end
            Notify("Combat Whitelist", "Added " .. tostring(#targets) .. " player(s)", 2)
        elseif cmd == "unkawl" then
            table.clear(State.KillAuraWhitelist)
            Notify("Combat Whitelist", "Cleared", 2)
        elseif cmd == "aawl" then
            local targets = ResolveTargetPlayers(rest)
            for _, p in ipairs(targets) do State.ArrestWhitelist[p.UserId] = true end
            Notify("Arrest Whitelist", "Added " .. tostring(#targets) .. " player(s)", 2)
        elseif cmd == "unaawl" then
            table.clear(State.ArrestWhitelist)
            Notify("Arrest Whitelist", "Cleared", 2)
        elseif cmd == "guard" or cmd == "guards" or cmd == "cop" then
            Core.SwitchToTeam("Guards")
        elseif cmd == "inmate" or cmd == "inmates" or cmd == "prisoner" then
            Core.SwitchToTeam("Inmates")
        elseif cmd == "crim" or cmd == "criminal" or cmd == "criminals" then
            Core.SwitchToTeam("Criminals")
        elseif cmd == "neutral" then
            Core.SwitchToTeam("Neutral")
        elseif cmd == "team" then
            local map = { g = "Guards", guard = "Guards", guards = "Guards", i = "Inmates", inmate = "Inmates", inmates = "Inmates", c = "Criminals", crim = "Criminals", criminals = "Criminals", n = "Neutral", neutral = "Neutral" }
            local t = map[string.lower(arg1 or "")]
            if t then Core.SwitchToTeam(t) end
        elseif cmd == "re" or cmd == "respawn" then
            Core.PerformFastRespawn()
        elseif cmd == "autorespawn" or cmd == "autore" then
            State.FastRespawn = ParseToggleArg(arg1, State.FastRespawn)
        elseif cmd == "arrest" or cmd == "ar" then
            Core.RunArrestAll(rest ~= "" and rest or "nearest")
        elseif cmd == "arrestall" or cmd == "aa" then
            Core.RunArrestAll(rest ~= "" and rest or "others")
        elseif cmd == "tase" or cmd == "taze" then
            Core.RunTaseTargets(rest ~= "" and rest or "nearest")
        elseif cmd == "taseall" or cmd == "tazeall" then
            Core.RunTaseTargets(rest ~= "" and rest or "others")
        elseif cmd == "autoarrest" or cmd == "araura" then
            State.AutoArrest = ParseToggleArg(arg1, State.AutoArrest)
            Notify("Auto-Arrest", State.AutoArrest and "ON" or "OFF", 2)
        elseif cmd == "autotaze" or cmd == "autotase" then
            State.AutoTaze = ParseToggleArg(arg1, State.AutoTaze)
            Notify("Auto-Taze", State.AutoTaze and "ON" or "OFF", 2)
        elseif cmd == "antitase" or cmd == "antitaze" then
            State.AntiTase = ParseToggleArg(arg1, State.AntiTase)
        elseif cmd == "antiarrest" or cmd == "antiar" then
            State.AntiArrest = ParseToggleArg(arg1, State.AntiArrest)
        elseif cmd == "invis" or cmd == "ghost" or cmd == "feghost" then
            Core.SetFEInvisibleState(ParseToggleArg(arg1, State.FEInvisible), true)
        elseif cmd == "uninvis" or cmd == "unghost" then
            Core.SetFEInvisibleState(false, true)
        elseif cmd == "fly" then
            if tonumber(arg1) then
                State.FlySpeed = clamp(tonumber(arg1), 20, 180)
                State.Fly = true
            else
                State.Fly = ParseToggleArg(arg1, State.Fly)
            end
            if not State.Fly then Core.CleanupCharFly() end
            Notify("Character Fly", State.Fly and "ON" or "OFF", 2)
        elseif cmd == "unfly" then
            State.Fly = false
            Core.CleanupCharFly()
        elseif cmd == "car" or cmd == "spawncar" then
            SpawnAndEnterNearestCar()
        elseif cmd == "carfly" then
            if tonumber(arg1) then
                State.VehicleFlySpeed = clamp(tonumber(arg1), 25, 180)
                State.VehicleFly = true
            else
                State.VehicleFly = ParseToggleArg(arg1, State.VehicleFly)
            end
        elseif cmd == "uncarfly" then
            State.VehicleFly = false
        elseif cmd == "carspeed" then
            State.VehicleSpeedMod = ParseToggleArg(arg1, State.VehicleSpeedMod)
        elseif cmd == "speed" or cmd == "ws" then
            if tonumber(arg1) then
                State.CustomWalkSpeed = clamp(tonumber(arg1), 16, 92)
                State.MaxSpeedMode = "Custom"
                State.MaxSpeed = true
            else
                State.MaxSpeed = ParseToggleArg(arg1, State.MaxSpeed)
            end
        elseif cmd == "unspeed" then
            State.MaxSpeed = false
            local hum = GetHumanoid(LocalPlayer.Character)
            if hum then hum.WalkSpeed = 16 end
        elseif cmd == "safespeed" then
            State.MaxSpeedMode = "RegionSafe"
            State.MaxSpeed = true
        elseif cmd == "jp" or cmd == "jumppower" then
            if tonumber(arg1) then
                State.JumpPower = clamp(tonumber(arg1), 50, 110)
                State.JumpPowerEnabled = true
            else
                State.JumpPowerEnabled = ParseToggleArg(arg1, State.JumpPowerEnabled)
            end
        elseif cmd == "noclip" or cmd == "nc" then
            State.Noclip = ParseToggleArg(arg1, State.Noclip)
            if State.Noclip then Core.BypassClientAntiNoclip()
            elseif Core.RestoreLocalNoclip then Core.RestoreLocalNoclip() end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Noclip", State.Noclip and "ON" or "OFF", 2)
        elseif cmd == "clip" or cmd == "unnoclip" then
            State.Noclip = false
            if Core.RestoreLocalNoclip then Core.RestoreLocalNoclip() end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Noclip", "OFF", 2)
        elseif cmd == "opendoors" or cmd == "doors" then
            State.OpenAllDoors = ParseToggleArg(arg1, State.OpenAllDoors)
            if not State.OpenAllDoors then Core.RestoreAllDoors() end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
        elseif cmd == "fencegod" or cmd == "nofence" then
            local nextFence = ParseToggleArg(arg1, State.FenceGodmode)
            Core.ApplyFenceGodmode(nextFence)
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Fence Godmode", nextFence and "ON" or "OFF", 2)
        elseif cmd == "goto" or cmd == "to" or cmd == "tp" then
            local key = Core.TeleportAliases[string.lower(rest)] or rest
            if Core.TeleportLocations[key] then
                SafeTeleport(Core.TeleportLocations[key])
                Notify("Teleport", "Moved to " .. key, 2)
            else
                local plrs = ResolveTargetPlayers(rest)
                local tHrp = plrs[1] and GetRoot(plrs[1].Character)
                if tHrp then
                    SafeTeleport(tHrp.CFrame * CFrame.new(0, 0, 3.2))
                    Notify("Teleport", "Teleported to " .. plrs[1].Name, 2)
                end
            end
        elseif cmd == "view" or cmd == "spectate" then
            local plrs = ResolveTargetPlayers(rest)
            Core.SetSpectatePlayer(plrs[1])
        elseif cmd == "unview" or cmd == "unspectate" then
            Core.SetSpectatePlayer(nil)
        elseif cmd == "esp" then
            State.ESP = ParseToggleArg(arg1, State.ESP)
            if not State.ESP and Core.ESPObjects then
                for plr in pairs(Core.ESPObjects) do Core.RemovePlayerESP(plr) end
            end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Player ESP", State.ESP and "ON" or "OFF", 2)
        elseif cmd == "tracers" or cmd == "bullettracers" then
            State.BulletTracers = ParseToggleArg(arg1, State.BulletTracers)
            if Core.SyncVisualUI then Core.SyncVisualUI() end
        elseif cmd == "hitmarker" then
            State.Hitmarker = ParseToggleArg(arg1, State.Hitmarker)
        elseif cmd == "preset" then
            Core.ApplyPresetProfile(arg1 or "safe")
        elseif cmd == "rejoin" or cmd == "rj" then
            Core.RejoinServer()
        elseif cmd == "serverhop" or cmd == "shop" then
            Core.ServerHop()
        elseif cmd == "safemode" or cmd == "antiban" then
            State.AntiBanSafeMode = ParseToggleArg(arg1, State.AntiBanSafeMode)
            ApplyGunModsAll()
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Anti-Ban Safe Mode", State.AntiBanSafeMode and "Safe Mode ON" or "Safe Mode OFF", 2)
        end
    end

    function Admin.ExecuteLine(rawLine)
        local line = Trim(rawLine)
        if line == "" then return end
        for segment in string.gmatch(line, "[^;]+") do
            ExecuteSingleCommand(segment)
        end
    end

    -- Autocomplete wiring for UIRefs.CmdInput & UIRefs.SuggestFrame (Race-free mobile tap support)
    local SuggestClickAt = 0
    local function UpdateSuggestions()
        local sf = UIRefs.SuggestFrame
        local ci = UIRefs.CmdInput
        if not sf or not ci then return end
        for _, ch in ipairs(sf:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        local txt = Trim(ci.Text):lower():gsub("^[%.;!/]+", "")
        if txt == "" or not ci:IsFocused() then
            sf.Visible = false
            return
        end
        local shown = 0
        for _, item in ipairs(CommandCatalog) do
            local clean = item.cmd:lower():gsub("^[%.;!/]+", "")
            if clean:find(txt, 1, true) then
                shown = shown + 1
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, 0, 0, IsMobile and 26 or 22)
                b.BackgroundColor3 = Color3.fromRGB(24, 32, 48)
                b.BackgroundTransparency = 0.25
                b.Font = Enum.Font.GothamMedium
                b.TextSize = IsMobile and 11 or 10
                b.TextColor3 = Color3.fromRGB(210, 225, 255)
                b.Text = "  " .. item.cmd .. " — " .. item.desc
                b.TextXAlignment = Enum.TextXAlignment.Left
                b.TextTruncate = Enum.TextTruncate.AtEnd
                b.Parent = sf
                local function applySuggestion()
                    SuggestClickAt = os.clock()
                    local baseCmd = item.cmd:match("^([%.;!/]%S+)") or item.cmd
                    ci.Text = baseCmd .. " "
                    task.defer(function()
                        ci:CaptureFocus()
                        pcall(function() ci.CursorPosition = #ci.Text + 1 end)
                    end)
                end
                b.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        applySuggestion()
                    end
                end)
                b.Activated:Connect(function()
                    if (os.clock() - SuggestClickAt) > 0.18 then applySuggestion() end
                end)
                if shown >= 6 then break end
            end
        end
        sf.Visible = (shown > 0)
    end

    if UIRefs.CmdInput then
        AddConnection(UIRefs.CmdInput:GetPropertyChangedSignal("Text"):Connect(UpdateSuggestions))
        AddConnection(UIRefs.CmdInput.Focused:Connect(UpdateSuggestions))
        AddConnection(UIRefs.CmdInput.FocusLost:Connect(function(enterPressed)
            task.delay(0.24, function()
                if (os.clock() - SuggestClickAt) < 0.28 then return end
                if UIRefs.CmdInput and UIRefs.CmdInput:IsFocused() then return end
                if UIRefs.SuggestFrame then UIRefs.SuggestFrame.Visible = false end
            end)
            if enterPressed and Trim(UIRefs.CmdInput.Text) ~= "" then
                Admin.ExecuteLine(UIRefs.CmdInput.Text)
                UIRefs.CmdInput.Text = ""
                if UIRefs.CmdBarFrame then UIRefs.CmdBarFrame.Visible = false end
            end
        end))
    end

    local LastChatExecMsg, LastChatExecClock = "", 0
    local function HandleChatCommand(msg)
        if not State.ChatCommands or type(msg) ~= "string" then return end
        local trimmed = Trim(msg)
        local first = trimmed:sub(1, 1)
        if first == ";" or first == "!" or first == "." or first == "/" then
            local now = os.clock()
            if trimmed == LastChatExecMsg and (now - LastChatExecClock) < 0.35 then return end
            LastChatExecMsg = trimmed
            LastChatExecClock = now
            Admin.ExecuteLine(trimmed)
        end
    end

    AddConnection(LocalPlayer.Chatted:Connect(HandleChatCommand))
    pcall(function()
        local tcs = game:GetService("TextChatService")
        if tcs and tcs.MessageReceived then
            AddConnection(tcs.MessageReceived:Connect(function(textMsg)
                if textMsg and textMsg.TextSource and textMsg.TextSource.UserId == LocalPlayer.UserId then
                    HandleChatCommand(textMsg.Text)
                end
            end))
        end
    end)

    -- PC Hotkeys (G = Shield, X = .combo1, B = Ragebot, H = AutoHvH, F = Fly, N = Noclip, ; = CmdBar)
    AddConnection(UserInputService.InputBegan:Connect(function(inp, gameProcessed)
        if gameProcessed or UserInputService:GetFocusedTextBox() then return end
        if inp.KeyCode == Enum.KeyCode.G then
            State.HoloShield = not State.HoloShield
            if State.HoloShield then CreateHoloShield() else DestroyHoloShield() end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Hotkey [G]", "Bullet Shield: " .. (State.HoloShield and "ON" or "OFF"), 2)
        elseif inp.KeyCode == Enum.KeyCode.X then
            task.spawn(ExecuteCombo1)
        elseif inp.KeyCode == Enum.KeyCode.B then
            State.Ragebot = not State.Ragebot
            if State.Ragebot then SetupGunControllerHooks() end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Hotkey [B]", "360° Ragebot: " .. (State.Ragebot and "ON" or "OFF"), 2)
        elseif inp.KeyCode == Enum.KeyCode.H then
            State.AutoHvH = not State.AutoHvH
            if State.AutoHvH then
                State.HoloShield = true
                CreateHoloShield()
                SetupGunControllerHooks()
            end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Hotkey [H]", "AutoHvH Mode: " .. (State.AutoHvH and "ON" or "OFF"), 2)
        elseif inp.KeyCode == Enum.KeyCode.F then
            State.Fly = not State.Fly
            if not State.Fly then Core.CleanupCharFly() end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Hotkey [F]", "Character Fly: " .. (State.Fly and "ON" or "OFF"), 2)
        elseif inp.KeyCode == Enum.KeyCode.N then
            State.Noclip = not State.Noclip
            if State.Noclip then Core.BypassClientAntiNoclip()
            elseif Core.RestoreLocalNoclip then Core.RestoreLocalNoclip() end
            if Core.SyncVisualUI then Core.SyncVisualUI() end
            Notify("Hotkey [N]", "Noclip: " .. (State.Noclip and "ON" or "OFF"), 2)
        elseif inp.KeyCode == Enum.KeyCode.Semicolon then
            if UIRefs.CmdBarFrame and UIRefs.CmdInput then
                UIRefs.CmdBarFrame.Visible = true
                task.defer(function() UIRefs.CmdInput:CaptureFocus() end)
            end
        end
    end))
end

-- ============================================================================
-- // SECTION 14: CLEAN 7-TAB WINDUI HUB (WITH NATIVE PC/MOBILE UI FALLBACK)
-- ============================================================================
Env.PrisonLife2026Running = true

do
    if WindUI then
        local Window = WindUI:CreateWindow({
            Title = "Prison Life • 2026 Hub (v7.0 Apex KX Pro)",
            Icon = "shield",
            Author = "Apex Engine • AntiCarBring • Scoped Caches • Kits",
            Folder = "PrisonLife2026HubV7",
            Size = IsMobile and UDim2.fromOffset(520, 360) or UDim2.fromOffset(600, 450),
            Transparent = true,
            Theme = "Dark",
            SideBarWidth = 170,
        })

        UIRefs.Controls = UIRefs.Controls or {}
        UIRefs.IsSyncing = false
        local function BindCtrl(key, ctrl)
            if ctrl then UIRefs.Controls[key] = ctrl end
            return ctrl
        end
        function Core.SyncVisualUI()
            if UIRefs.IsSyncing then return end
            UIRefs.IsSyncing = true
            for key, ctrl in pairs(UIRefs.Controls) do
                if State[key] ~= nil and ctrl and ctrl.Set then
                    pcall(function() ctrl:Set(State[key]) end)
                end
            end
            UIRefs.IsSyncing = false
        end

        Window:EditOpenButton({
            Title = "🚔 PL 2026 Pro",
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
        local TabCombat   = Window:Tab({ Title = "HvH & Aim", Icon = "crosshair" })
        local TabWeapons  = Window:Tab({ Title = "Guns & .combo1", Icon = "zap" })
        local TabPrison   = Window:Tab({ Title = "Prison & Guard", Icon = "lock" })
        local TabVehicles = Window:Tab({ Title = "Cars & KX", Icon = "car" })
        local TabMove     = Window:Tab({ Title = "Movement", Icon = "wind" })
        local TabVisuals  = Window:Tab({ Title = "ESP & Admin", Icon = "eye" })

        -- // TAB 1: SHIELD & SAFE
        TabShield:Section({ Title = "🛡️ Anti-Ban Safe Mode & Quick Presets" })
        BindCtrl("AntiBanSafeMode", TabShield:Toggle({
            Title = "Anti-Ban Safe Mode (Error Code 600 Guard • ON)",
            Desc = "Enforces 2026 server-safe FireRate, KillAura, Teleport & WalkSpeed caps",
            Value = true,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.AntiBanSafeMode = v
                ApplyGunModsAll()
                Notify("Anti-Ban", v and "Safe Mode ON" or "Safe Mode OFF", 2.5)
            end,
        }))
        TabShield:Dropdown({
            Title = "Configuration Preset",
            Values = { "Safe (Anti-Ban Default)", "Legit (Closet)", "Rage (AntiLock + 360)", "HvH (AutoHvH + UndergroundPeek)" },
            Value = "Safe (Anti-Ban Default)",
            Callback = function(v)
                local p = NormalizeDropdownValue(v)
                if p:find("Legit") then Core.ApplyPresetProfile("legit")
                elseif p:find("HvH") then Core.ApplyPresetProfile("hvh")
                elseif p:find("Rage") then Core.ApplyPresetProfile("rage")
                else Core.ApplyPresetProfile("safe") end
            end,
        })

        TabShield:Section({ Title = "2026 Anti-Hit Shield (Hotkey: G • Zero Ray-Block)" })
        BindCtrl("HoloShield", TabShield:Toggle({
            Title = "Enable Anti-Hit Shield & Incoming Ray Monitor",
            Desc = "Buried/desynced server hitbox + non-blocking feet halo (never blocks shots)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.HoloShield = v
                if v then CreateHoloShield() else DestroyHoloShield() end
            end,
        }))
        BindCtrl("ShieldMode", TabShield:Dropdown({
            Title = "Shield Protection Mode",
            Values = { "UndergroundPeek", "Hybrid", "AntiLockDesync", "RiotOnly", "FEGhost" },
            Value = "UndergroundPeek",
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                local mode = NormalizeDropdownValue(v)
                if mode ~= "" then
                    State.ShieldMode = mode
                    if State.HoloShield then CreateHoloShield() end
                end
            end,
        }))
        BindCtrl("ShieldVisualStyle", TabShield:Dropdown({
            Title = "Ground Halo Visual Style",
            Values = { "CyberHex", "NeonRing", "Minimal" },
            Value = "CyberHex",
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                local st = NormalizeDropdownValue(v)
                if st ~= "" then
                    State.ShieldVisualStyle = st
                    if State.HoloShield then CreateHoloShield() end
                end
            end,
        }))
        BindCtrl("ShieldDepth", TabShield:Slider({
            Title = "Underground Burial Depth (Studs)",
            Step = 0.5,
            Value = { Min = 6.0, Max = 14.0, Default = 10.5 },
            Callback = function(v) State.ShieldDepth = tonumber(v) or 10.5 end,
        }))
        BindCtrl("ShieldShowVisual", TabShield:Toggle({
            Title = "Show Ground Halo Ring Visual",
            Desc = "Sleek neon ring around your feet (CanQuery = false, never blocks aim/clicks)",
            Value = true,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.ShieldShowVisual = v
                if State.HoloShield then CreateHoloShield() end
            end,
        }))
        BindCtrl("ShieldTransparency", TabShield:Slider({
            Title = "Halo Visual Transparency",
            Step = 0.04,
            Value = { Min = 0.35, Max = 0.96, Default = 0.72 },
            Callback = function(v) State.ShieldTransparency = tonumber(v) or 0.72 end,
        }))
        BindCtrl("ShieldSize", TabShield:Slider({
            Title = "Ground Halo Diameter",
            Step = 0.2,
            Value = { Min = 2.5, Max = 10.0, Default = 4.2 },
            Callback = function(v)
                State.ShieldSize = tonumber(v) or 4.2
                if State.HoloShield and not UIRefs.IsSyncing then CreateHoloShield() end
            end,
        }))
        BindCtrl("ShieldAutoEquip", TabShield:Toggle({
            Title = "Auto-Equip SWAT Riot Shield When Idle",
            Desc = "Only equips Riot Shield when not holding a firearm",
            Value = false,
            Callback = function(v) State.ShieldAutoEquip = v end,
        }))
        BindCtrl("ShieldAutoFaceShooter", TabShield:Toggle({
            Title = "Auto-Face Nearest Armed Shooter",
            Value = false,
            Callback = function(v) State.ShieldAutoFaceShooter = v end,
        }))
        BindCtrl("ShieldSpinBlock", TabShield:Toggle({
            Title = "Spin-Block Anti-Aim",
            Value = false,
            Callback = function(v) State.ShieldSpinBlock = v end,
        }))
        BindCtrl("DesyncJitterRadius", TabShield:Slider({
            Title = "AntiLock Desync Jitter Radius",
            Step = 0.5,
            Value = { Min = 1.5, Max = 9.0, Default = 5.5 },
            Callback = function(v) State.DesyncJitterRadius = tonumber(v) or 5.5 end,
        }))

        -- // TAB 2: HVH & AIM
        TabCombat:Section({ Title = "⚔️ KX AutoHvH & 360° Ragebot (Hotkeys: H / B)" })
        BindCtrl("AutoHvH", TabCombat:Toggle({
            Title = "AutoHvH Mode (Threat Priority + Shield + Anti-Stun)",
            Desc = "Prioritizes armed exploiters, auto-switches loaded guns & dodges shots",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.AutoHvH = v
                if v then
                    State.HoloShield = true
                    CreateHoloShield()
                    SetupGunControllerHooks()
                end
            end,
        }))
        BindCtrl("HvHTargetExploitersFirst", TabCombat:Toggle({
            Title = "Prioritize Exploiters & Cheaters First",
            Desc = "Targets Anomaly-flagged speed/TP/spin/invis players first in HvH",
            Value = true,
            Callback = function(v) State.HvHTargetExploitersFirst = v end,
        }))
        BindCtrl("AutoHvHReactiveEvade", TabCombat:Toggle({
            Title = "Reactive Auto-Evade Incoming Shooters",
            Desc = "Automatically faces & ducks attackers detected via ReplicateEvent",
            Value = true,
            Callback = function(v) State.AutoHvHReactiveEvade = v end,
        }))
        BindCtrl("Ragebot", TabCombat:Toggle({
            Title = "360° Ragebot (Auto-Shoot Hostile Targets)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.Ragebot = v
                if v then SetupGunControllerHooks() end
            end,
        }))
        BindCtrl("RagebotAutoSwitch", TabCombat:Toggle({
            Title = "Ragebot Auto-Switch Loaded Firearm",
            Value = true,
            Callback = function(v) State.RagebotAutoSwitch = v end,
        }))
        BindCtrl("RagebotPeekShield", TabCombat:Toggle({
            Title = "Ragebot Un-Duck Peek (Leaves You Vulnerable — Off Recommended)",
            Value = false,
            Callback = function(v) State.RagebotPeekShield = v end,
        }))
        BindCtrl("RagebotRate", TabCombat:Slider({
            Title = "Ragebot Fire Rate (SPS)",
            Value = { Min = 2, Max = 25, Default = 14 },
            Callback = function(v) State.RagebotRate = tonumber(v) or 14 end,
        }))

        TabCombat:Section({ Title = "2026 Bullet-Hook Silent Aim & Wallbang Scanner" })
        BindCtrl("SilentAim", TabCombat:Toggle({
            Title = "Silent Aim (GunController Bullet Hook)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.SilentAim = v
                if v then SetupGunControllerHooks() end
            end,
        }))
        BindCtrl("SilentAimWallbang", TabCombat:Toggle({
            Title = "Wallbang Origin Scanner (Shoot Around Cover)",
            Value = true,
            Callback = function(v) State.SilentAimWallbang = v end,
        }))
        BindCtrl("AutoArmorPen", TabCombat:Toggle({
            Title = "Auto Armor Penetration (Force Headshot on Vests)",
            Value = true,
            Callback = function(v) State.AutoArmorPen = v end,
        }))
        BindCtrl("SilentAimAimPart", TabCombat:Dropdown({
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
        }))
        BindCtrl("SilentAimFOV", TabCombat:Slider({
            Title = "Silent Aim FOV Radius",
            Value = { Min = 30, Max = 450, Default = 180 },
            Callback = function(v) State.SilentAimFOV = tonumber(v) or 180 end,
        }))
        BindCtrl("SilentAimShowFOV", TabCombat:Toggle({
            Title = "Show Silent Aim FOV Circle",
            Value = true,
            Callback = function(v) State.SilentAimShowFOV = v end,
        }))
        BindCtrl("SilentAimHostileCheck", TabCombat:Toggle({
            Title = "Guard Safe Mode (Strictly Hostile Only — Prevents Innocent Kick)",
            Value = true,
            Callback = function(v) State.SilentAimHostileCheck = v end,
        }))
        BindCtrl("SilentAimLead", TabCombat:Toggle({
            Title = "Velocity Lead Prediction (Moving Targets)",
            Value = true,
            Callback = function(v) State.SilentAimLead = v end,
        }))
        TabCombat:Button({
            Title = "Re-Hook GunController (.rehook)",
            Desc = "Re-scans PC/Mobile shoot & bullet closures if aiming desyncs",
            Callback = function() App.RehookGunController(true) end,
        })
        TabCombat:Button({
            Title = "Clear Priority Focus Target (.untarget)",
            Callback = function()
                State.FocusTargetUserId = nil
                Notify("Target Focus", "Cleared priority target.", 2)
            end,
        })

        TabCombat:Section({ Title = "Aim Assist, Triggerbot, Kill Aura & Hitboxes" })
        BindCtrl("AimAssist", TabCombat:Toggle({
            Title = "Smooth Aim Assist (PC & Mobile Touch)",
            Value = false,
            Callback = function(v) State.AimAssist = v end,
        }))
        BindCtrl("Triggerbot", TabCombat:Toggle({
            Title = "Triggerbot (Auto-Shoot in FOV)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.Triggerbot = v
                if v then SetupGunControllerHooks() end
            end,
        }))
        TabCombat:Toggle({
            Title = "Shoot Through Riot Shields & Vehicles",
            Value = false,
            Callback = function(v)
                State.AntiRiotShield = v
                State.VehicleWallbang = v
            end,
        })
        BindCtrl("KillAura", TabCombat:Toggle({
            Title = "Melee Kill Aura (Anti-Ban Rate-Limited)",
            Value = false,
            Callback = function(v) State.KillAura = v end,
        }))
        BindCtrl("KillAuraAutoMelee", TabCombat:Toggle({
            Title = "Kill Aura Auto-Trigger Held Melee Tool",
            Value = false,
            Callback = function(v) State.KillAuraAutoMelee = v end,
        }))
        BindCtrl("KillAuraRange", TabCombat:Slider({
            Title = "Kill Aura Range (Studs)",
            Value = { Min = 4, Max = 12, Default = 10 },
            Callback = function(v) State.KillAuraRange = tonumber(v) or 10 end,
        }))
        BindCtrl("ExpandHitbox", TabCombat:Toggle({
            Title = "Expand Enemy Hitboxes (Invisible Box)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.ExpandHitbox = v
                if not v then Core.RestoreAllHitboxes() end
            end,
        }))
        BindCtrl("HitboxSize", TabCombat:Slider({
            Title = "Hitbox Size",
            Value = { Min = 3, Max = 15, Default = 9 },
            Callback = function(v) State.HitboxSize = tonumber(v) or 9 end,
        }))

        -- // TAB 3: GUNS & .COMBO1
        TabWeapons:Section({ Title = "💥 KX .combo1 Multi-Gun Burst (Hotkey: X)" })
        TabWeapons:Button({
            Title = "Execute .combo1 Burst Now",
            Callback = function() task.spawn(ExecuteCombo1) end,
        })
        BindCtrl("ShowComboButton", TabWeapons:Toggle({
            Title = "Show Top-Left .combo1 HUD Pill",
            Value = true,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.ShowComboButton = v
                if UIRefs.ComboTopLeftBtn then UIRefs.ComboTopLeftBtn.Visible = v end
            end,
        }))
        BindCtrl("ComboLoop", TabWeapons:Toggle({
            Title = "Loop .combo1 Continuously",
            Value = false,
            Callback = function(v) State.ComboLoop = v end,
        }))
        BindCtrl("ComboAutoGrabGuns", TabWeapons:Toggle({
            Title = "Auto-Grab Guns Before .combo1 If Unarmed",
            Value = true,
            Callback = function(v) State.ComboAutoGrabGuns = v end,
        }))
        BindCtrl("ComboReEquipShield", TabWeapons:Toggle({
            Title = "Re-Equip Riot Shield After .combo1 Burst",
            Value = false,
            Callback = function(v) State.ComboReEquipShield = v end,
        }))

        TabWeapons:Section({ Title = "2026 Safe Weapon Kits & Grabber" })
        BindCtrl("AutoLoadoutKit", TabWeapons:Dropdown({
            Title = "Weapon Loadout Kit (.loadout)",
            Values = { "None", "Light", "Sniper", "Riot", "Full" },
            Value = "None",
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                local picked = NormalizeDropdownValue(v)
                if picked ~= "" then App.SetAutoLoadoutKit(picked, true) end
            end,
        }))
        TabWeapons:Button({
            Title = "Refill Low-Ammo Weapons (.refill)",
            Desc = "Reloads mags and refills empty reserves via touch givers",
            Callback = function() App.RefillEmptyWeapons() end,
        })
        TabWeapons:Button({
            Title = "Grab Full Loadout (Remington 870 + AK-47 + MP5)",
            Desc = "Grabs Armory & Criminal Base guns with anti-ban zone pacing",
            Callback = function() task.spawn(function() GrabWeapons({ "Remington 870", "AK-47", "MP5" }) end) end,
        })
        TabWeapons:Button({
            Title = "Grab Remington 870 (Shotgun)",
            Callback = function() task.spawn(function() GrabWeapons({ "Remington 870" }) end) end,
        })
        TabWeapons:Button({
            Title = "Grab AK-47 (Criminal Base Rifle)",
            Callback = function() task.spawn(function() GrabWeapons({ "AK-47" }) end) end,
        })
        TabWeapons:Button({
            Title = "Grab MP5 (SMG)",
            Callback = function() task.spawn(function() GrabWeapons({ "MP5" }) end) end,
        })
        TabWeapons:Button({
            Title = "Grab M700 (Sniper Update)",
            Callback = function() task.spawn(function() GrabWeapons({ "M700" }) end) end,
        })
        TabWeapons:Button({
            Title = "Grab Revolver (Sniper Update)",
            Callback = function() task.spawn(function() GrabWeapons({ "Revolver" }) end) end,
        })
        TabWeapons:Button({
            Title = "Grab Hammer & Crude Knife (.hammer / .knife)",
            Callback = function() task.spawn(function() GrabWeapons({ "Hammer", "Crude Knife" }) end) end,
        })
        BindCtrl("AutoGetGuns", TabWeapons:Toggle({
            Title = "Auto Grab Loadout on Respawn",
            Value = false,
            Callback = function(v) State.AutoGetGuns = v end,
        }))
        BindCtrl("AutoPickupDropped", TabWeapons:Toggle({
            Title = "Auto Pickup Dropped Keycards & Guns",
            Value = false,
            Callback = function(v) State.AutoPickupDropped = v end,
        }))

        TabWeapons:Section({ Title = "2026 Gun Attribute Modifications" })
        BindCtrl("GunMods", TabWeapons:Toggle({
            Title = "Enable Gun Mods (Rapid Fire, No Spread, Full Auto)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.GunMods = v
                ApplyGunModsAll()
            end,
        }))
        BindCtrl("GunFireRateSPS", TabWeapons:Slider({
            Title = "FireRate (SPS • Capped at 15 in Safe Mode)",
            Value = { Min = 5, Max = 25, Default = 14 },
            Callback = function(v) State.GunFireRateSPS = tonumber(v) or 14; ApplyGunModsAll() end,
        }))
        TabWeapons:Toggle({
            Title = "Zero Bullet Spread & Force Full Auto",
            Value = true,
            Callback = function(v) State.GunNoSpread = v; State.GunFullAuto = v; ApplyGunModsAll() end,
        })
        BindCtrl("GunZeroChargeTime", TabWeapons:Toggle({
            Title = "Zero Sniper / Taser ChargeTime Delay",
            Value = true,
            Callback = function(v) State.GunZeroChargeTime = v; ApplyGunModsAll() end,
        }))
        BindCtrl("AutoReload", TabWeapons:Toggle({
            Title = "Auto Reload at 0 Ammo",
            Value = true,
            Callback = function(v) State.AutoReload = v end,
        }))
        TabWeapons:Toggle({
            Title = "Auto Heal (<80 HP) & Auto Armor Vest",
            Value = false,
            Callback = function(v) State.AutoHeal = v; State.AutoArmor = v end,
        })

        -- // TAB 4: PRISON & GUARD
        TabPrison:Section({ Title = "Instant Team Switcher" })
        TabPrison:Button({ Title = "Join Guards (;guard)", Callback = function() Core.SwitchToTeam("Guards") end })
        TabPrison:Button({ Title = "Join Inmates (;inmate)", Callback = function() Core.SwitchToTeam("Inmates") end })
        TabPrison:Button({ Title = "Become Criminal (;crim)", Callback = function() Core.SwitchToTeam("Criminals") end })
        TabPrison:Button({ Title = "Join Neutral (;neutral)", Callback = function() Core.SwitchToTeam("Neutral") end })

        TabPrison:Section({ Title = "Guard & Prisoner Automation" })
        BindCtrl("AutoArrest", TabPrison:Toggle({
            Title = "Auto-Arrest Aura (Criminals & Hostile/Trespass Inmates)",
            Value = false,
            Callback = function(v) State.AutoArrest = v end,
        }))
        BindCtrl("AutoArrestEquipHandcuffs", TabPrison:Toggle({
            Title = "Auto-Equip Handcuffs Before Arresting",
            Value = true,
            Callback = function(v) State.AutoArrestEquipHandcuffs = v end,
        }))
        BindCtrl("AutoTaze", TabPrison:Toggle({
            Title = "Auto-Taze Aura",
            Value = false,
            Callback = function(v) State.AutoTaze = v end,
        }))
        TabPrison:Button({
            Title = "Arrest Valid Targets Now (;arrestall)",
            Callback = function() Core.RunArrestAll("others") end,
        })
        TabPrison:Button({
            Title = "Tase Nearest Target (;tase)",
            Callback = function() Core.RunTaseTargets("nearest") end,
        })
        BindCtrl("AntiTase", TabPrison:Toggle({
            Title = "Anti-Tase (Block Stun & Ragdoll)",
            Value = true,
            Callback = function(v) State.AntiTase = v end,
        }))
        BindCtrl("AntiArrest", TabPrison:Toggle({
            Title = "Anti-Arrest (Block ClientArrested Handler)",
            Value = false,
            Callback = function(v) State.AntiArrest = v end,
        }))
        BindCtrl("AlwaysBackpack", TabPrison:Toggle({
            Title = "Always Enable Backpack",
            Value = false,
            Callback = function(v) State.AlwaysBackpack = v end,
        }))
        BindCtrl("AutoCriminalOnArrest", TabPrison:Toggle({
            Title = "Auto Criminal After Being Arrested",
            Value = false,
            Callback = function(v) State.AutoCriminalOnArrest = v end,
        }))
        BindCtrl("FastRespawn", TabPrison:Toggle({
            Title = "Fast Respawn (<1s)",
            Value = false,
            Callback = function(v) State.FastRespawn = v end,
        }))
        BindCtrl("OpenAllDoors", TabPrison:Toggle({
            Title = "Open / Noclip All Prison Doors",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.OpenAllDoors = v
                if not v then Core.RestoreAllDoors() end
            end,
        }))
        BindCtrl("FenceGodmode", TabPrison:Toggle({
            Title = "Electric Fence Godmode",
            Value = true,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                Core.ApplyFenceGodmode(v)
            end,
        }))
        BindCtrl("AutoDetonateC4", TabPrison:Toggle({
            Title = "Auto Detonate C4 Near Enemies",
            Value = false,
            Callback = function(v) State.AutoDetonateC4 = v end,
        }))

        -- // TAB 5: CARS & KX VEHICLE EXPLOITS
        TabVehicles:Section({ Title = "🚗 KX Saved Cars (.savecar) & Target Manipulation" })
        TabVehicles:Button({
            Title = "Save 2 Cars to Pool (.savecar 2)",
            Desc = "Saves unoccupied cars for instant Bring / ForceCrim / Void",
            Callback = function() SaveCarsCommand(2) end,
        })
        TabVehicles:Button({
            Title = "Spawn & Enter Nearest Car (.car)",
            Callback = SpawnAndEnterNearestCar,
        })
        local kxCarPlayerName = ""
        local kxCarPlayerDropdown = TabVehicles:Dropdown({
            Title = "Target Player (for Bring / ForceCrim / Void)",
            Values = {},
            Value = "",
            Callback = function(v) kxCarPlayerName = NormalizeDropdownValue(v) end,
        })
        TabVehicles:Button({
            Title = "KX Bring Selected Player (.bring)",
            Callback = function()
                local target = Players:FindFirstChild(kxCarPlayerName)
                if target then ExecuteCarTargetAction(target, "bring") end
            end,
        })
        TabVehicles:Button({
            Title = "KX ForceCrim Selected Player (.forcecrim)",
            Callback = function()
                local target = Players:FindFirstChild(kxCarPlayerName)
                if target then ExecuteCarTargetAction(target, "forcecrim") end
            end,
        })
        TabVehicles:Button({
            Title = "KX Void / ForceKick Selected Player (.void)",
            Callback = function()
                local target = Players:FindFirstChild(kxCarPlayerName)
                if target then ExecuteCarTargetAction(target, "void") end
            end,
        })
        TabVehicles:Button({
            Title = "KX Car Fling Selected Player (.fling)",
            Callback = function()
                local target = Players:FindFirstChild(kxCarPlayerName)
                if target then ExecuteCarTargetAction(target, "fling") end
            end,
        })

        TabVehicles:Section({ Title = "Vehicle Fly, WheelAura, FE Invis & Protections" })
        BindCtrl("WheelAura", TabVehicles:Toggle({
            Title = "WheelAura (Neon Particle Trails on Car Wheels)",
            Value = false,
            Callback = function(v) State.WheelAura = v end,
        }))
        BindCtrl("VehicleFly", TabVehicles:Toggle({
            Title = "Vehicle Fly (.carfly)",
            Value = false,
            Callback = function(v) State.VehicleFly = v end,
        }))
        BindCtrl("VehicleFlySpeed", TabVehicles:Slider({
            Title = "Vehicle Fly Speed",
            Value = { Min = 30, Max = 180, Default = 80 },
            Callback = function(v) State.VehicleFlySpeed = tonumber(v) or 80 end,
        }))
        BindCtrl("VehicleSpeedMod", TabVehicles:Toggle({
            Title = "Vehicle Speed Multiplier",
            Value = false,
            Callback = function(v) State.VehicleSpeedMod = v end,
        }))
        BindCtrl("Fly", TabVehicles:Toggle({
            Title = "Character Fly (Hotkey: F)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.Fly = v
                if not v then Core.CleanupCharFly() end
            end,
        }))
        BindCtrl("FlySpeed", TabVehicles:Slider({
            Title = "Character Fly Speed",
            Value = { Min = 25, Max = 140, Default = 65 },
            Callback = function(v) State.FlySpeed = tonumber(v) or 65 end,
        }))
        UIRefs.FEInvisToggle = TabVehicles:Toggle({
            Title = "Serverside FE Invisible (No Cyan Box • .invis)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                Core.SetFEInvisibleState(v, false)
            end,
        })
        BindCtrl("AntiInvisible", TabVehicles:Toggle({
            Title = "Anti-Invisible (Reveal Invisible Exploiters)",
            Value = false,
            Callback = function(v) State.AntiInvisible = v end,
        }))
        BindCtrl("AntiCarBring", TabVehicles:Toggle({
            Title = "Anti-CarBring (Block Passenger Seat Kidnapping)",
            Value = true,
            Callback = function(v) State.AntiCarBring = v end,
        }))
        BindCtrl("AntiFling", TabVehicles:Toggle({
            Title = "Anti-Fling (Disable Vehicle & Spin-Fling Collisions)",
            Value = true,
            Callback = function(v) State.AntiFling = v end,
        }))

        -- // TAB 6: MOVEMENT
        TabMove:Section({ Title = "2026 Anti-Rubberband Speed & Noclip (Hotkey: N)" })
        BindCtrl("MaxSpeed", TabMove:Toggle({
            Title = "MaxSpeed (20 Indoor Sub-Regions Anti-Rubberband)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.MaxSpeed = v
                if v then
                    Core.BypassClientAntiNoclip()
                    if LocalPlayer.Character then Core.BypassAntiJump(LocalPlayer.Character, true) end
                else
                    local hum = GetHumanoid(LocalPlayer.Character)
                    if hum then hum.WalkSpeed = State.AlwaysSprint and 24 or 16 end
                end
            end,
        }))
        BindCtrl("MaxSpeedMode", TabMove:Dropdown({
            Title = "Speed Mode",
            Values = { "RegionSafe", "Custom", "AlwaysSprint" },
            Value = "RegionSafe",
            Callback = function(v)
                local mode = NormalizeDropdownValue(v)
                if mode ~= "" then State.MaxSpeedMode = mode end
            end,
        }))
        BindCtrl("CustomWalkSpeed", TabMove:Slider({
            Title = "Custom WalkSpeed",
            Value = { Min = 16, Max = 92, Default = 40 },
            Callback = function(v) State.CustomWalkSpeed = tonumber(v) or 40 end,
        }))
        BindCtrl("JumpPowerEnabled", TabMove:Toggle({
            Title = "JumpPower Boost",
            Value = false,
            Callback = function(v)
                State.JumpPowerEnabled = v
                if not v then
                    local hum = GetHumanoid(LocalPlayer.Character)
                    if hum then hum.JumpPower = 50 end
                end
            end,
        }))
        BindCtrl("JumpPower", TabMove:Slider({
            Title = "Custom JumpPower",
            Value = { Min = 50, Max = 110, Default = 65 },
            Callback = function(v) State.JumpPower = tonumber(v) or 65 end,
        }))
        TabMove:Toggle({
            Title = "No Jump Cooldown & Infinite Jump",
            Value = false,
            Callback = function(v)
                State.AntiJumpCooldown = v
                State.InfiniteStamina = v
                State.InfiniteJump = v
                if LocalPlayer.Character then Core.BypassAntiJump(LocalPlayer.Character, v) end
            end,
        })
        BindCtrl("Noclip", TabMove:Toggle({
            Title = "Noclip (Non-Destructive + Clean Restore)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.Noclip = v
                if v then Core.BypassClientAntiNoclip()
                elseif Core.RestoreLocalNoclip then Core.RestoreLocalNoclip() end
            end,
        }))
        BindCtrl("AntiKillPlane", TabMove:Toggle({
            Title = "Anti-KillPlane",
            Value = true,
            Callback = function(v) State.AntiKillPlane = v end,
        }))

        -- // TAB 7: ESP & ADMIN
        TabVisuals:Section({ Title = "Role & Threat-Colored Player ESP & Clean VFX" })
        BindCtrl("ESP", TabVisuals:Toggle({
            Title = "Enable Player ESP",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.ESP = v
                if not v then
                    for plr in pairs(Core.ESPObjects) do Core.RemovePlayerESP(plr) end
                end
            end,
        }))
        BindCtrl("ESPHealthBar", TabVisuals:Toggle({
            Title = "Show 3px Player Health Bars",
            Value = true,
            Callback = function(v) State.ESPHealthBar = v end,
        }))
        BindCtrl("ESPHideTeam", TabVisuals:Toggle({
            Title = "Hide Teammates from ESP",
            Value = false,
            Callback = function(v) State.ESPHideTeam = v end,
        }))
        BindCtrl("ESPDetailDistance", TabVisuals:Slider({
            Title = "ESP Detail LOD Distance (m)",
            Step = 10,
            Value = { Min = 40, Max = 350, Default = 140 },
            Callback = function(v) State.ESPDetailDistance = tonumber(v) or 140 end,
        }))
        BindCtrl("BulletTracers", TabVisuals:Toggle({
            Title = "3D Neon Bullet Tracers",
            Value = true,
            Callback = function(v) State.BulletTracers = v end,
        }))
        TabVisuals:Toggle({
            Title = "Hitmarker, Hit Sounds & Damage Numbers",
            Value = true,
            Callback = function(v)
                State.Hitmarker = v
                State.HitSound = v
                State.DamageNumbers = v
            end,
        })
        BindCtrl("C4ESP", TabVisuals:Toggle({
            Title = "C4 Explosive ESP",
            Value = false,
            Callback = function(v) State.C4ESP = v end,
        }))
        BindCtrl("ItemESP", TabVisuals:Toggle({
            Title = "Dropped Weapons & Keycard ItemESP (.itemesp)",
            Value = false,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.ItemESP = v
                if not v and Core.RemoveAllItemESP then Core.RemoveAllItemESP() end
            end,
        }))
        TabVisuals:Toggle({
            Title = "Show Top-Left Mini-Killfeed & Cheater Alerts",
            Value = true,
            Callback = function(v)
                State.ShowMiniKillfeed = v
                State.CheaterAlerts = v
                State.CarTPAlerts = v
            end,
        })
        BindCtrl("ShowCommandPill", TabVisuals:Toggle({
            Title = "Show Top-Right ⌘ CMD Command Pill",
            Value = true,
            Callback = function(v)
                if UIRefs.IsSyncing then return end
                State.ShowCommandPill = v
                if UIRefs.CmdTogglePill then UIRefs.CmdTogglePill.Visible = v end
                if not v and UIRefs.CmdBarFrame then UIRefs.CmdBarFrame.Visible = false end
            end,
        }))

        TabVisuals:Section({ Title = "15 Preset Prison Life Teleports" })
        local locNames = {}
        for name in pairs(Core.TeleportLocations) do table.insert(locNames, name) end
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
                if selectedLocation and Core.TeleportLocations[selectedLocation] then
                    SafeTeleport(Core.TeleportLocations[selectedLocation])
                    Notify("Teleport", "Moved to " .. selectedLocation, 2)
                end
            end,
        })

        TabVisuals:Section({ Title = "Target Player & Server Utilities" })
        local selectedPlayerName = ""
        local playerDropdown = TabVisuals:Dropdown({
            Title = "Select Player",
            Values = {},
            Value = "",
            Callback = function(v) selectedPlayerName = NormalizeDropdownValue(v) end,
        })
        local function RefreshAllPlayerDropdowns()
            local list = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then table.insert(list, p.Name) end
            end
            pcall(function()
                if playerDropdown and playerDropdown.Refresh then playerDropdown:Refresh(list) end
                if kxCarPlayerDropdown and kxCarPlayerDropdown.Refresh then kxCarPlayerDropdown:Refresh(list) end
            end)
        end
        RefreshAllPlayerDropdowns()
        AddConnection(Players.PlayerAdded:Connect(RefreshAllPlayerDropdowns))
        AddConnection(Players.PlayerRemoving:Connect(RefreshAllPlayerDropdowns))

        TabVisuals:Button({
            Title = "Teleport Behind Selected Player (.goto)",
            Callback = function()
                local target = Players:FindFirstChild(selectedPlayerName)
                local tHrp = target and GetRoot(target.Character)
                if tHrp then SafeTeleport(tHrp.CFrame * CFrame.new(0, 0, 3.5)) end
            end,
        })
        TabVisuals:Button({
            Title = "Spectate / Unspectate Selected Player (.view)",
            Callback = function()
                if Core.SpectateTarget then
                    Core.SetSpectatePlayer(nil)
                else
                    local target = Players:FindFirstChild(selectedPlayerName)
                    if target then Core.SetSpectatePlayer(target) end
                end
            end,
        })
        TabVisuals:Button({
            Title = "Toggle LoopKill on Selected Player (.loopkill)",
            Callback = function()
                local target = Players:FindFirstChild(selectedPlayerName)
                if target then
                    State.LoopKillTargets[target.UserId] = not State.LoopKillTargets[target.UserId]
                    Notify("LoopKill", target.Name .. ": " .. (State.LoopKillTargets[target.UserId] and "ADDED" or "REMOVED"), 2)
                end
            end,
        })
        TabVisuals:Button({
            Title = "Focus Selected Player in Combat (.target)",
            Callback = function()
                local target = Players:FindFirstChild(selectedPlayerName)
                if target then
                    if State.FocusTargetUserId == target.UserId then
                        State.FocusTargetUserId = nil
                        Notify("Target Focus", "Cleared priority target.", 2)
                    else
                        State.FocusTargetUserId = target.UserId
                        Notify("Target Focus", "Prioritizing " .. target.Name, 2)
                    end
                end
            end,
        })
        TabVisuals:Button({ Title = "Rejoin Current Server (.rj)", Callback = Core.RejoinServer })
        TabVisuals:Button({ Title = "Server Hop (.shop)", Callback = Core.ServerHop })

        TabVisuals:Section({ Title = "📁 JSON Config Profiles (.savecfg / .loadcfg)" })
        local activeCfgName = "default"
        local cfgDropdown = TabVisuals:Dropdown({
            Title = "Select Config Profile",
            Values = App.Persistence.ListProfiles(),
            Value = "default",
            Callback = function(v)
                local p = NormalizeDropdownValue(v)
                if p ~= "" then activeCfgName = p end
            end,
        })
        if TabVisuals.Input then
            pcall(function()
                TabVisuals:Input({
                    Title = "Custom Profile Name",
                    Placeholder = "default (or type custom name)",
                    Callback = function(v)
                        local clean = Trim(tostring(v or ""))
                        if clean ~= "" then activeCfgName = clean end
                    end,
                })
            end)
        end
        local function RefreshProfileList()
            pcall(function()
                if cfgDropdown and cfgDropdown.Refresh then
                    cfgDropdown:Refresh(App.Persistence.ListProfiles())
                end
            end)
        end
        TabVisuals:Button({
            Title = "Save Current Settings to Profile",
            Callback = function()
                App.Persistence.SaveProfile(activeCfgName, false)
                RefreshProfileList()
            end,
        })
        TabVisuals:Button({
            Title = "Load Selected Profile",
            Callback = function()
                App.Persistence.LoadProfile(activeCfgName, false)
            end,
        })
        TabVisuals:Button({
            Title = "Delete Selected Profile",
            Callback = function()
                App.Persistence.DeleteProfile(activeCfgName, false)
                RefreshProfileList()
            end,
        })
        TabVisuals:Toggle({
            Title = "Auto-Load 'default' Profile on Startup",
            Value = State.ConfigAutoLoad,
            Callback = function(v)
                State.ConfigAutoLoad = v
                App.Persistence.SaveMeta(v, "default")
            end,
        })
    else
        -- Native PC/Mobile Fallback UI
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
        MakeDraggable(FallbackFrame)

        local TitleBar = Instance.new("TextLabel")
        TitleBar.Size = UDim2.new(1, -16, 0, 34)
        TitleBar.Position = UDim2.fromOffset(12, 4)
        TitleBar.BackgroundTransparency = 1
        TitleBar.Font = Enum.Font.GothamBold
        TitleBar.TextSize = 14
        TitleBar.TextColor3 = Color3.new(1, 1, 1)
        TitleBar.TextXAlignment = Enum.TextXAlignment.Left
        TitleBar.Text = "🚔 Prison Life 2026 Pro (v7.0 Apex)"
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
        AddFallbackToggle("AutoHvH Mode (Priority + Shield + Anti-Stun)", false, function(v) State.AutoHvH = v; if v then State.HoloShield = true; CreateHoloShield() end end)
        AddFallbackToggle("5-Mode 3D Bullet Shield", false, function(v) State.HoloShield = v; if v then CreateHoloShield() else DestroyHoloShield() end end)
        AddFallbackToggle("360° Ragebot (Hostile Only)", false, function(v) State.Ragebot = v; if v then SetupGunControllerHooks() end end)
        AddFallbackToggle("Silent Aim (Bullet Hook + Wallbang)", false, function(v) State.SilentAim = v; if v then SetupGunControllerHooks() end end)
        AddFallbackToggle("Safe Melee Kill Aura", false, function(v) State.KillAura = v end)
        AddFallbackToggle("Gun Mods (Rapid Fire + No Spread)", false, function(v) State.GunMods = v; ApplyGunModsAll() end)
        AddFallbackToggle("Region-Safe MaxSpeed", false, function(v) State.MaxSpeed = v end)
        AddFallbackToggle("Character Fly", false, function(v) State.Fly = v; if not v then Core.CleanupCharFly() end end)
        AddFallbackToggle("Anti-Tase & Anti-Arrest", true, function(v) State.AntiTase = v; State.AntiArrest = v end)
        AddFallbackToggle("Anti-CarBring (Block Seat Kidnap)", true, function(v) State.AntiCarBring = v end)
        AddFallbackToggle("Auto-Arrest & Auto-Taze Aura", false, function(v) State.AutoArrest = v; State.AutoTaze = v end)
        AddFallbackToggle("Role-Colored Player ESP", false, function(v) State.ESP = v end)

        local ToggleHubBtn = Instance.new("TextButton")
        ToggleHubBtn.Name = "PL2026_ToggleHubBtn"
        ToggleHubBtn.Size = UDim2.fromOffset(105, 34)
        ToggleHubBtn.Position = UDim2.new(0.02, 0, 0.22, 0)
        ToggleHubBtn.BackgroundColor3 = Color3.fromRGB(30, 58, 138)
        ToggleHubBtn.Font = Enum.Font.GothamBold
        ToggleHubBtn.TextSize = 12
        ToggleHubBtn.TextColor3 = Color3.new(1, 1, 1)
        ToggleHubBtn.Text = "🚔 PL 2026"
        ToggleHubBtn.Parent = OverlayGui
        Instance.new("UICorner", ToggleHubBtn).CornerRadius = UDim.new(0, 10)
        MakeDraggable(ToggleHubBtn)
        AddConnection(ToggleHubBtn.Activated:Connect(function()
            local lastDrag = tonumber(ToggleHubBtn:GetAttribute("WasDraggedAt")) or 0
            if (os.clock() - lastDrag) < 0.25 then return end
            FallbackFrame.Visible = not FallbackFrame.Visible
        end))
    end
end

-- // Cleanup Registration
Env.PrisonLife2026Cleanup = function()
    Env.PrisonLife2026Running = false
    pcall(RunService.UnbindFromRenderStep, RunService, "PL2026_ShieldRestore")
    if Core.CleanupCharFly then Core.CleanupCharFly() end
    if Core.StopFEInvisible then Core.StopFEInvisible() end
    DestroyHoloShield()
    if Core.RestoreAllHitboxes then Core.RestoreAllHitboxes() end
    if Core.RestoreAllDoors then Core.RestoreAllDoors() end
    if Core.RestoreLocalNoclip then Core.RestoreLocalNoclip() end
    if Core.SetSpectatePlayer then Core.SetSpectatePlayer(nil) end
    if Core.RemoveAllC4ESP then Core.RemoveAllC4ESP() end
    if Core.RemoveAllItemESP then Core.RemoveAllItemESP() end
    if Core.ESPObjects then
        for plr in pairs(Core.ESPObjects) do Core.RemovePlayerESP(plr) end
    end
    for carModel, entry in pairs(App.WorldCache.Cars) do
        if entry.scope then entry.scope:Clean() end
        if carModel and carModel.Parent then
            for _, ps in ipairs(entry.passSeats) do
                if ps and ps.Parent then pcall(function() ps.CanTouch = true end) end
            end
        end
    end
    if App.WorldCache.LocalCharScope then App.WorldCache.LocalCharScope:Clean() end
    for _, scopes in pairs(App.WorldCache.PlayerScopes) do
        if scopes.char then scopes.char:Clean() end
        if scopes.player then scopes.player:Clean() end
    end
    UpdateVehicleWheelAura(nil)
    if hookfunction then
        for _, pair in ipairs(HookedFunctions) do
            pcall(function() hookfunction(pair.fn, pair.orig) end)
        end
    end
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    for _, inst in ipairs(CreatedInstances) do
        pcall(function() inst:Destroy() end)
    end
end

App.Persistence.TryAutoLoad()
Notify("Prison Life • 2026 Pro v7.0", "Loaded Apex KX Pro Edition (Scoped Engine + AntiCarBring + Kits)!", 3.5)
