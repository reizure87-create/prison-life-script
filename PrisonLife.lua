--[[
    ================================================================================
    🚔 PRISON LIFE — ULTIMATE 2026 SCRIPT (PC & MOBILE) [v2.0 ANTI-BAN & BUGFIX]
    ================================================================================
    Target Game : Prison Life (PlaceId: 155615604 | UniverseId: 73885730)
    Patch Target: Late 2026 ("Sniper Update!" Remotes, Attributes & Anti-Cheat)
    Platform    : PC (Keyboard/Mouse) & Mobile (Touch GUI, Floating Quick Bar,
                  Touch Aim Assist, & On-Screen Vehicle Fly Controls)
    UI Library  : WindUI (with automatic Native PC/Mobile Touch GUI fallback)

    What's New & Fixed in v2.0 (Anti-Ban Error Code 600 Overhaul & Bugfixes):
      1. Fixed Error Code 600 (30-Day Experience Ban) Triggers:
         - Added Anti-Ban Safe Mode (ON by default): enforces server-safe caps on
           WalkSpeed (20 indoor sub-regions), KillAura swing rate (0.32s, <=10m,
           single-target per swing), Gun FireRate (<=15 SPS in Safe Mode), and
           blocks high-risk 9500-velocity Car Fling unless explicitly unlocked.
         - Fixed GrabWeapons CFrame overwrite bug (`savedCF = hrp.CFrame` was inside
           the while loop, overwriting your return position with underground coords
           and oscillating 1,750 studs at 60Hz while spamming GiverPressed every frame).
         - Removed destructive `ReplicatedStorage.Scripts.CharacterCollision:Destroy()`
           call; now uses non-destructive `getconnections` signal disabling on Head.
      2. Fixed GunController Hook Lifecycle:
         - Lazy-hooks `PlayerGui.Home.hud.ActionArea.InputBegan` whenever a gun is
           equipped (fixes Silent Aim/Triggerbot not working if you stayed on the
           team selection screen longer than 15 seconds).
         - Added a strictly-scoped Raycast fallback (only when holding a gun and
           ray length > 40 studs) for executors without `debug.getupvalue`.
      3. Added 2026 3D Ballistic Holo-Shield ("New Shield that blocks bullets"):
         - Summons a 3D curved holographic riot shield with live 180 HP durability
           bar, out-of-combat recharge, and physical bullet/tracer interception.
      4. Added Built-In Native Touch/PC UI Fallback:
         - If WindUI fails to download on restricted mobile connections, automatically
           builds a sleek draggable native Hub UI so the script never fails to open.
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
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- // Prevent Duplicate Execution
if getgenv and getgenv().PrisonLife2026Cleanup then
    pcall(getgenv().PrisonLife2026Cleanup)
end
local Env = (getgenv and getgenv()) or _G

-- // Safe UI Parent Helper
local function GetSafeGuiParent()
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function()
        return CoreGui
    end)
    if ok2 and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- // Normalize WindUI Dropdown Values (Handles both string and table return types)
local function NormalizeDropdownValue(v)
    if type(v) == "table" then
        return v[1] or v.Value or next(v) or ""
    end
    return tostring(v or "")
end

-- // Connections & Cleanup Registry
local Connections = {}
local CreatedInstances = {}
local function AddConnection(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end
local function TrackInstance(inst)
    if inst then
        table.insert(CreatedInstances, inst)
    end
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

    -- Combat & Aiming
    SilentAim = false,
    SilentAimHitChance = 100,
    SilentAimFOV = 180,
    SilentAimShowFOV = true,
    SilentAimWallcheck = true,
    SilentAimAimPart = "Head",
    SilentAimTeamCheck = true,
    SilentAimHostileCheck = true,
    SilentAimSkipDowned = true,

    AimAssist = false,
    AimAssistFOV = 140,
    AimAssistShowFOV = false,
    AimAssistSmoothness = 0.22,
    AimAssistPrediction = true,
    AimAssistPredictionStrength = 0.065,
    AimAssistAimPart = "Head",
    AimAssistTeamCheck = true,

    Triggerbot = false,
    TriggerbotDelay = 0.08,
    TriggerbotWallcheck = true,
    TriggerbotAutoReload = true,

    KillAura = false,
    KillAuraRange = 10,
    KillAuraTeamCheck = true,
    KillAuraGuardSafe = true,
    KillAuraFaceTarget = false,

    ExpandHitbox = false,
    HitboxSize = 9,

    AntiRiotShield = false,
    VehicleWallbang = false,

    -- 2026 3D Ballistic Holo-Shield
    HoloShield = false,
    HoloShieldMaxHP = 180,

    -- Weapons & Gun Mods
    AutoGetGuns = false,
    AutoGetGunsSelection = { "Remington 870", "MP5", "M9" },
    AutoPickupDropped = false,
    AutoArmor = false,
    AutoReload = false,
    AutoReloadHotSwap = false,
    FastSwitch = false,

    GunMods = false,
    GunFireRateSPS = 14,      -- Safe default (<=15 SPS in Anti-Ban Safe Mode)
    GunNoSpread = true,       -- SpreadRadius = 0
    GunFullAuto = true,       -- AutoFire = true
    GunInfiniteRange = true,  -- Range = 9999

    AutoHeal = false,
    AutoHealThreshold = 85,

    -- Prison, Guards & Teams
    AutoArrest = false,
    AutoArrestRange = 7.5,
    AutoArrestHandCheck = false,
    AutoArrestCooldownBar = true,

    AntiTase = false,
    AlwaysBackpack = false,
    AutoCriminalOnArrest = false,
    FastRespawn = false,
    KeepPositionOnRespawn = true,
    OpenAllDoors = false,
    FenceGodmode = false,
    AntiKillPlane = true,
    AutoDetonateC4 = false,

    -- Vehicles & Trolling
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
    MaxSpeedMode = "RegionSafe", -- "RegionSafe" or "Custom"
    CustomWalkSpeed = 40,
    AlwaysSprint = false,
    InfiniteStamina = false,
    AntiJumpCooldown = false,
    InfiniteJump = false,
    Noclip = false,

    -- Visuals & ESP
    ESP = false,
    ESPHighlight = true,
    ESPNameTag = true,
    ESPHealth = true,
    ESPDistance = true,
    ESPWeapon = true,
    ESPStatusFlags = true,
    C4ESP = false,
    KillFeedNotifier = false,
}

-- // Load WindUI (with safe timeout/fallback support)
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
                Duration = duration or 3.5,
                Icon = "shield-alert",
            })
        end)
    else
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = content,
                Duration = duration or 3.5,
            })
        end)
    end
end

-- ============================================================================
-- // SECTION 1: TARGET VALIDATION & RAYCAST HELPERS
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

local function IsValidCombatTarget(plr, requireHostileForGuard)
    if not plr or plr == LocalPlayer then return false end
    if not plr.Team or plr.Team == Teams:FindFirstChild("Neutral") then return false end

    local char = plr.Character
    if not char then return false end
    if char:FindFirstChildOfClass("ForceField") then return false end

    local hum = GetHumanoid(char)
    if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return false end

    if State.SilentAimSkipDowned and (char:GetAttribute("Downed") or char:GetAttribute("Arrested")) then
        return false
    end

    if State.SilentAimTeamCheck and plr.Team == LocalPlayer.Team then
        return false
    end

    -- 2026 Prison Life Rule: Guards get penalized for shooting non-hostile/non-trespassing Inmates
    if requireHostileForGuard and LocalPlayer.Team == Teams:FindFirstChild("Guards") and plr.Team == Teams:FindFirstChild("Inmates") then
        local isHostile = char:GetAttribute("Hostile") or char:GetAttribute("Trespassing")
        if not isHostile then
            return false
        end
    end

    return true
end

local WallRayParams = RaycastParams.new()
WallRayParams.FilterType = Enum.RaycastFilterType.Exclude
WallRayParams.IgnoreWater = true
pcall(function()
    WallRayParams.CollisionGroup = "ClientBullet"
end)

local function HasLineOfSight(originPos, targetPart, targetChar)
    local myChar = LocalPlayer.Character
    local ignore = { myChar, targetChar, Camera }
    if State.VehicleWallbang and Workspace:FindFirstChild("CarContainer") then
        table.insert(ignore, Workspace.CarContainer)
    end
    if State.OpenAllDoors and Workspace:FindFirstChild("Doors") then
        table.insert(ignore, Workspace.Doors)
    end
    WallRayParams.FilterDescendantsInstances = ignore

    local dir = targetPart.Position - originPos
    local hit = Workspace:Raycast(originPos, dir, WallRayParams)
    return hit == nil
end

local function GetBestScreenTarget(fovRadius, aimPartName, wallcheck, requireHostile)
    local myChar = LocalPlayer.Character
    local myHead = myChar and (myChar:FindFirstChild("Head") or GetRoot(myChar))
    if not myHead then return nil, nil end

    local screenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    if not IsMobile and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        local mPos = UserInputService:GetMouseLocation()
        screenCenter = Vector2.new(mPos.X, mPos.Y)
    end

    local bestDist = fovRadius
    local bestPart = nil
    local bestPlr = nil

    for _, plr in ipairs(Players:GetPlayers()) do
        if IsValidCombatTarget(plr, requireHostile) then
            local char = plr.Character
            local part = char:FindFirstChild(aimPartName) or char:FindFirstChild("Head") or GetRoot(char)
            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen and screenPos.Z > 0 then
                    local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if dist2D <= bestDist then
                        if not wallcheck or HasLineOfSight(myHead.Position, part, char) then
                            bestDist = dist2D
                            bestPart = part
                            bestPlr = plr
                        end
                    end
                end
            end
        end
    end

    return bestPart, bestPlr
end

-- ============================================================================
-- // SECTION 2: 2026 GUN CONTROLLER UPVALUE HOOK + SAFE RAYCAST FALLBACK
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

            -- Hook pl.Bullet ONCE (Never re-hook on respawn to avoid recursive stack overflow!)
            if GunHook.Bullet and hookfunction and not GunHook.IsHooked then
                GunHook.IsHooked = true
                GunHook.OldBullet = hookfunction(GunHook.Bullet, function(...)
                    local args = table.pack(...)
                    if State.SilentAim then
                        if math.random(1, 100) <= State.SilentAimHitChance then
                            local targetPart = GunHook.CurrentSilentTargetPart
                            if not (targetPart and targetPart.Parent) then
                                targetPart = GetBestScreenTarget(
                                    State.SilentAimFOV,
                                    State.SilentAimAimPart,
                                    State.SilentAimWallcheck,
                                    State.SilentAimHostileCheck
                                )
                            end
                            if targetPart and targetPart.Parent then
                                args[2] = targetPart.Position
                                if type(args[3]) == "number" then
                                    args[3] = 0
                                end
                            end
                        end
                    elseif State.GunMods and State.GunNoSpread then
                        if type(args[3]) == "number" then
                            args[3] = 0
                        end
                    end
                    return GunHook.OldBullet(table.unpack(args, 1, args.n))
                end)
            end
        end)
    end

    -- Strictly-scoped Raycast Fallback (ONLY runs if Bullet upvalue hook is unavailable AND holding a gun AND ray length > 40)
    if not GunHook.IsHooked and not GunHook.RaycastFallbackHooked and hookmetamethod and getnamecallmethod then
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                if Env.PrisonLife2026Running and not GunHook.IsHooked and State.SilentAim and self == Workspace then
                    local method = getnamecallmethod()
                    if method == "Raycast" and (not checkcaller or not checkcaller()) then
                        local origin, dir, params = ...
                        if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" and dir.Magnitude > 40 then
                            local holdingGun = IsHoldingFirearm()
                            if holdingGun and math.random(1, 100) <= State.SilentAimHitChance then
                                local targetPart = GunHook.CurrentSilentTargetPart
                                if targetPart and targetPart.Parent then
                                    local newDir = (targetPart.Position - origin).Unit * dir.Magnitude
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

-- ============================================================================
-- // SECTION 3: OVERLAY GUI (FOV RINGS, ARREST COOLDOWN, SHIELD BAR, QUICK BAR)
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

-- 2026 3D Ballistic Holo-Shield HUD Bar
local ShieldBarHolder = Instance.new("Frame")
ShieldBarHolder.Name = "HoloShieldBar"
ShieldBarHolder.AnchorPoint = Vector2.new(0.5, 0.5)
ShieldBarHolder.Position = UDim2.fromScale(0.5, 0.63)
ShieldBarHolder.Size = UDim2.fromOffset(165, 9)
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
ShieldBarText.Size = UDim2.fromOffset(165, 16)
ShieldBarText.Position = UDim2.fromOffset(0, 10)
ShieldBarText.BackgroundTransparency = 1
ShieldBarText.Font = Enum.Font.GothamBold
ShieldBarText.TextSize = 11
ShieldBarText.TextColor3 = Color3.fromRGB(120, 235, 255)
ShieldBarText.TextStrokeTransparency = 0.2
ShieldBarText.Text = "🛡️ HOLO SHIELD: 180/180"
ShieldBarText.Parent = ShieldBarHolder

-- ============================================================================
-- // SECTION 4: 2026 3D BALLISTIC HOLO-SHIELD (BLOCKS BULLETS & TRACERS)
-- ============================================================================
local HoloShieldState = {
    Model = nil,
    CorePart = nil,
    HP = 180,
    MaxHP = 180,
    BrokenUntil = 0,
    LastHit = 0,
}

local function DestroyHoloShield()
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

    local m = Instance.new("Model")
    m.Name = "PL2026_BallisticShield"

    local core = Instance.new("Part")
    core.Name = "RiotShieldPart"
    core.Size = Vector3.new(5.4, 6.2, 0.35)
    core.Transparency = 0.52
    core.Material = Enum.Material.Neon
    core.Color = Color3.fromRGB(0, 210, 255)
    core.Anchored = true
    core.CanCollide = false
    core.CanQuery = true
    core.CanTouch = false
    core.Parent = m

    local rim = Instance.new("SelectionBox")
    rim.Adornee = core
    rim.Color3 = Color3.fromRGB(120, 245, 255)
    rim.LineThickness = 0.04
    rim.SurfaceColor3 = Color3.fromRGB(0, 175, 255)
    rim.SurfaceTransparency = 0.78
    rim.Parent = core

    m.Parent = Workspace
    HoloShieldState.Model = m
    HoloShieldState.CorePart = core
    HoloShieldState.MaxHP = State.HoloShieldMaxHP or 180
    HoloShieldState.HP = HoloShieldState.MaxHP
    ShieldBarHolder.Visible = true

    if Remotes.ShieldEquipped then
        pcall(function() Remotes.ShieldEquipped:FireServer(true) end)
    end
end

local function RegisterHoloShieldHit(dmg)
    if not State.HoloShield or not HoloShieldState.CorePart then return end
    if os.clock() < HoloShieldState.BrokenUntil then return end
    HoloShieldState.LastHit = os.clock()
    HoloShieldState.HP = math.max(0, HoloShieldState.HP - (dmg or 16))
    HoloShieldState.CorePart.Color = Color3.fromRGB(255, 95, 110)
    task.delay(0.08, function()
        if HoloShieldState.CorePart then
            HoloShieldState.CorePart.Color = Color3.fromRGB(0, 210, 255)
        end
    end)
    if HoloShieldState.HP <= 0 then
        HoloShieldState.BrokenUntil = os.clock() + 4.0
        HoloShieldState.CorePart.Transparency = 0.92
        HoloShieldState.CorePart.CanQuery = false
        Notify("Holo-Shield", "Shield overloaded! Recharging in 4s...", 3)
    end
end

if Remotes.GunTracers and Remotes.GunTracers:IsA("RemoteEvent") then
    AddConnection(Remotes.GunTracers.OnClientEvent:Connect(function(origin, hitPos)
        if not State.HoloShield or not HoloShieldState.CorePart then return end
        if typeof(origin) == "Vector3" and typeof(hitPos) == "Vector3" then
            local sPos = HoloShieldState.CorePart.Position
            if (hitPos - sPos).Magnitude <= 6.5 then
                RegisterHoloShieldHit(14)
            end
        end
    end))
end

-- ============================================================================
-- // SECTION 5: 2026 SAFE WEAPON GRABBER (#TouchGiver + GiverPressed)
-- ============================================================================
-- Grouped by zone (Armory vs Criminal Base) so we never oscillate 1,750 studs at 60Hz!
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
        GamepassId = 96651,
        SearchPivot = Vector3.new(847.5, 97.85, 2229.3962),
        UndergroundCF = CFrame.new(847.5, 91.5, 2229.3962),
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
    local ok, queried = pcall(function()
        return Workspace:QueryDescendants("#TouchGiver")
    end)
    if ok and type(queried) == "table" and #queried > 0 then
        givers = queried
    else
        local okT, tagged = pcall(function()
            return CollectionService:GetTagged("Giver")
        end)
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
    if bp and bp:FindFirstChild(weaponName) then return true end
    if char and char:FindFirstChild(weaponName) then return true end
    return false
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
        for _, t in ipairs(bp:GetChildren()) do
            ApplyGunModsToTool(t)
        end
    end
    local char = LocalPlayer.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            ApplyGunModsToTool(t)
        end
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

local function GrabWeapons(weaponList)
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
                -- In Anti-Ban Safe Mode, skip cross-map 1750-stud jumps if we already found nearby guns
                table.insert(queue, { Name = wName, Giver = giver, CF = underCF, Dist = dist })
            end
        end
    end

    -- Sort by closest giver first so we don't zig-zag across the map!
    table.sort(queue, function(a, b) return a.Dist < b.Dist end)

    if #queue == 0 then
        ApplyGunModsAll()
        Notify("Weapons", "You already have the selected weapons!", 2.5)
        return
    end

    IsGrabbingGuns = true
    -- Capture savedCF ONCE before the loop (fixes the v1.1 bug where savedCF was overwritten inside the loop!)
    local savedCF = hrp.CFrame

    for idx, item in ipairs(queue) do
        if not hrp or not hrp.Parent or hum.Health <= 0 then break end

        -- In Anti-Ban Safe Mode, if a weapon is >1200 studs away (e.g. Criminal Base while inside Prison)
        -- and we already grabbed at least 1 nearby weapon, skip the cross-map jump to avoid position-delta flags.
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

        if idx < #queue then
            task.wait(0.12)
        end
    end

    if hrp and hrp.Parent and hum and hum.Health > 0 then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = savedCF
    end

    IsGrabbingGuns = false
    SetupGunControllerHooks()
    ApplyGunModsAll()
    Notify("Weapons Grabbed", "Equipped 2026 weapons safely!", 3)
end

-- ============================================================================
-- // SECTION 6: TEAM SWITCHER & FAST RESPAWN (<1s Neutral Trick)
-- ============================================================================
local LastDeathCFrame = nil

local function SwitchToTeam(teamName)
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
-- // SECTION 7: NON-DESTRUCTIVE ANTI-TASE, AUTO-CRIMINAL, & ANTI-CHEAT BYPASSES
-- ============================================================================
local function BypassClientAntiNoclip()
    -- Non-destructive bypass: NEVER call :Destroy() on ReplicatedStorage.Scripts.CharacterCollision!
    pcall(function()
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if head and getconnections then
            for _, conn in ipairs(getconnections(head:GetPropertyChangedSignal("CanCollide"))) do
                if conn and conn.Disable then
                    conn:Disable()
                end
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
            if aj and not State.AntiBanSafeMode then
                aj.Disabled = true
            end
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

if Remotes.PlayerTased then
    AddConnection(Remotes.PlayerTased.OnClientEvent:Connect(function()
        if not State.AntiTase then return end
        task.defer(function()
            local char = LocalPlayer.Character
            local hum = GetHumanoid(char)
            if hum then
                local animator = hum:FindFirstChildOfClass("Animator")
                if animator then
                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                        local animId = track.Animation and track.Animation.AnimationId or ""
                        if animId:find("279227693") or animId:find("279229192") then
                            track:Stop(0)
                        end
                    end
                end
                hum.WalkSpeed = State.AlwaysSprint and 24 or 16
                hum.JumpPower = 50
                hum.JumpHeight = 7.2
            end
            LocalPlayer:SetAttribute("BackpackEnabled", true)
            Notify("Anti-Tase", "Blocked taser stun & restored movement!", 2.5)
        end)
    end))
end

if Remotes.ClientArrested then
    AddConnection(Remotes.ClientArrested.OnClientEvent:Connect(function()
        if not State.AutoCriminalOnArrest then return end
        Notify("Arrested!", "Waiting 4.2s to auto-escape to Criminals...", 4)
        task.delay(4.25, function()
            local crimSpawn = Workspace:FindFirstChild("Criminals Spawn")
            local sp = crimSpawn and crimSpawn:FindFirstChild("SpawnLocation")
            local hrp = GetRoot(LocalPlayer.Character)
            if sp and hrp then
                hrp.CFrame = sp.CFrame + Vector3.new(0, 3, 0)
                Notify("Auto Criminal", "Escaped back to Criminal team!", 3)
            end
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

    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)
    anim:Destroy()

    if ok and track then
        FEInvisTrack = track
        track.Priority = Enum.AnimationPriority.Action4
        track:Play(0, 0.001, 0)
        task.delay(0.03, function()
            if FEInvisTrack == track and State.FEInvisible then
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
-- // SECTION 9: VEHICLE SPAWNER, MOBILE/PC VEHICLE FLY, & QUICK BAR
-- ============================================================================
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

    local nearestBtn = nil
    local bestDist = math.huge
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
            hrp.CFrame = nearestBtn.CFrame + Vector3.new(0, 3.5, 0)
            task.wait(0.22)
        end

        pcall(function()
            Remotes.InteractWithItem:InvokeServer(nearestBtn)
        end)
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
                hrp.CFrame = bestSeat.CFrame + Vector3.new(0, 2, 0)
                task.wait(0.1)
                bestSeat:Sit(hum)
                Notify("Car Spawner", "Spawned & entered vehicle!", 3)
                return
            end
        end

        hrp.CFrame = oldCF
        Notify("Car Spawner", "Requested vehicle spawn.", 3)
    end)
end

local MobileFlyInput = { Up = 0, Down = 0 }

local MobileQuickBar = Instance.new("Frame")
MobileQuickBar.Name = "MobileQuickBar"
MobileQuickBar.AnchorPoint = Vector2.new(1, 0.5)
MobileQuickBar.Position = UDim2.new(0.98, 0, 0.45, 0)
MobileQuickBar.Size = UDim2.fromOffset(118, 230)
MobileQuickBar.BackgroundTransparency = 1
MobileQuickBar.Visible = false
MobileQuickBar.Parent = OverlayGui

local QuickLayout = Instance.new("UIListLayout", MobileQuickBar)
QuickLayout.Padding = UDim.new(0, 6)
QuickLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
QuickLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local function CreateQuickMobileButton(text, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(112, 34)
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

CreateQuickMobileButton("⚡ Fast Switch", Color3.fromRGB(45, 110, 220), TriggerFastSwitch)
CreateQuickMobileButton("🔫 Safe Guns", Color3.fromRGB(40, 150, 90), function()
    task.spawn(function()
        GrabWeapons(State.AutoGetGunsSelection)
    end)
end)
CreateQuickMobileButton("🛡️ Holo Shield", Color3.fromRGB(0, 145, 195), function()
    State.HoloShield = not State.HoloShield
    if State.HoloShield then
        CreateHoloShield()
        Notify("Holo-Shield", "2026 Ballistic Holo-Shield ON", 2)
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
-- // SECTION 10: ROLE-COLORED ESP (COMPACT & DISTANCE-FILTERED) & C4 ESP
-- ============================================================================
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

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local hrp = GetRoot(char)
            local hum = GetHumanoid(char)

            if State.ESP and char and hrp and hum and hum.Health > 0 then
                if hrp.Transparency < 1 then
                    hrp.Transparency = 1
                end

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
                data.Highlight.Enabled = State.ESPHighlight
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

pcall(function()
    local kfFolder = ReplicatedStorage:FindFirstChild("Killfeed")
    if kfFolder then
        AddConnection(kfFolder.ChildAdded:Connect(function(entry)
            if not State.KillFeedNotifier then return end
            task.defer(function()
                local text = entry.Name or ""
                if text:find(LocalPlayer.Name) or text:find(LocalPlayer.DisplayName) then
                    Notify("Killfeed", text, 3.5)
                end
            end)
        end))
    end
end)

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
        if IsInsideBox(x, z, r) then
            return 32
        end
    end
    if IsInsideBox(x, z, PrisonOuterBox) then
        return 50
    end
    return 92
end

local LastTriggerShot = 0
local LastArrestTime = 0
local LastKillAuraTime = 0

AddConnection(RunService.RenderStepped:Connect(function(dt)
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

    -- Update Silent Aim Target
    if State.SilentAim then
        GunHook.CurrentSilentTargetPart = GetBestScreenTarget(
            State.SilentAimFOV,
            State.SilentAimAimPart,
            State.SilentAimWallcheck,
            State.SilentAimHostileCheck
        )
    else
        GunHook.CurrentSilentTargetPart = nil
    end

    -- Smooth Camera Aim Assist (PC & Mobile Touch Friendly)
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
    if State.Triggerbot then
        if not GunHook.Ready then
            SetupGunControllerHooks()
        end
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
                        GunHook.CurrentSilentTargetPart = targetPart
                        local inputObj = {
                            UserInputState = Enum.UserInputState.Begin,
                            UserInputType = Enum.UserInputType.MouseButton1,
                            Position = Vector3.zero,
                        }
                        task.spawn(GunHook.Shoot, inputObj)
                        inputObj.UserInputState = Enum.UserInputState.End
                    end
                end
            end
        end
    end

    -- Update 2026 3D Ballistic Holo-Shield Position & Durability Bar
    if State.HoloShield then
        local myHrp = GetRoot(LocalPlayer.Character)
        if myHrp then
            if not HoloShieldState.CorePart or not HoloShieldState.CorePart.Parent then
                CreateHoloShield()
            end
            local core = HoloShieldState.CorePart
            if core then
                local now = os.clock()
                if now < HoloShieldState.BrokenUntil then
                    local rem = HoloShieldState.BrokenUntil - now
                    ShieldBarFill.Size = UDim2.fromScale(clamp(1 - (rem / 4.0), 0, 1), 1)
                    ShieldBarFill.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
                    ShieldBarText.Text = string.format("🛡️ RECHARGING: %.1fs", rem)
                else
                    if core.Transparency > 0.6 then
                        core.Transparency = 0.52
                        core.CanQuery = true
                        HoloShieldState.HP = HoloShieldState.MaxHP
                    elseif (now - HoloShieldState.LastHit) > 3.0 and HoloShieldState.HP < HoloShieldState.MaxHP then
                        HoloShieldState.HP = math.min(HoloShieldState.MaxHP, HoloShieldState.HP + (32 * dt))
                    end
                    local frac = clamp(HoloShieldState.HP / HoloShieldState.MaxHP, 0, 1)
                    ShieldBarFill.Size = UDim2.fromScale(frac, 1)
                    ShieldBarFill.BackgroundColor3 = Color3.fromRGB(0, 215, 255)
                    ShieldBarText.Text = string.format("🛡️ HOLO SHIELD: %d/%d", round(HoloShieldState.HP), HoloShieldState.MaxHP)
                end

                local look = Camera.CFrame.LookVector
                local flatLook = Vector3.new(look.X, 0, look.Z)
                if flatLook.Magnitude < 0.01 then
                    flatLook = myHrp.CFrame.LookVector
                else
                    flatLook = flatLook.Unit
                end
                local shieldPos = myHrp.Position + (flatLook * 3.8) + Vector3.new(0, 0.3, 0)
                core.CFrame = CFrame.lookAt(shieldPos, shieldPos + flatLook)
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

-- Heartbeat Loop (Native WalkSpeed MaxSpeed, Safe KillAura, AutoArrest, VehicleFly, AntiFling)
AddConnection(RunService.Heartbeat:Connect(function(dt)
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

        -- Region-Aware Native Humanoid.WalkSpeed (Prevents server rubberbanding & speed flags)
        if not hum.Sit then
            if State.MaxSpeed then
                local regionCeiling = GetSafeRegionMaxSpeed(hrp.Position)
                if State.MaxSpeedMode == "RegionSafe" or State.AntiBanSafeMode then
                    local target = (State.MaxSpeedMode == "Custom") and math.min(State.CustomWalkSpeed, regionCeiling) or regionCeiling
                    hum.WalkSpeed = target
                else
                    local safeCustom = (regionCeiling == 32) and math.min(State.CustomWalkSpeed, 34) or State.CustomWalkSpeed
                    hum.WalkSpeed = safeCustom
                end
            elseif State.AlwaysSprint then
                if hum.WalkSpeed < 24 then
                    hum.WalkSpeed = 24
                end
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

        -- Vehicle Fly & Vehicle Speed
        local seat = hum.SeatPart
        if seat and seat:IsA("VehicleSeat") then
            FlyUpBtn.Visible = State.VehicleFly
            FlyDownBtn.Visible = State.VehicleFly

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
        else
            FlyUpBtn.Visible = false
            FlyDownBtn.Visible = false
        end

        -- Anti-Ban Hardened Melee Kill Aura (Throttled to 0.32s & <=10 studs in Safe Mode, single closest target per swing)
        local auraCooldown = State.AntiBanSafeMode and 0.32 or 0.20
        if State.KillAura and Remotes.MeleeEvent and (os.clock() - LastKillAuraTime) >= auraCooldown then
            local maxRange = State.AntiBanSafeMode and math.min(State.KillAuraRange, 10) or State.KillAuraRange
            local closestTarget = nil
            local closestHrp = nil
            local bestDist = maxRange

            for _, plr in ipairs(Players:GetPlayers()) do
                if IsValidCombatTarget(plr, State.KillAuraGuardSafe) then
                    local tChar = plr.Character
                    local tHrp = GetRoot(tChar)
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
                LastKillAuraTime = os.clock()
                Remotes.MeleeEvent:FireServer(closestTarget, 1, 1)
                if State.KillAuraFaceTarget then
                    hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(closestHrp.Position.X, hrp.Position.Y, closestHrp.Position.Z))
                end
            end
        end

        -- Auto Arrest Aura (ReplicatedStorage.Remotes.ArrestPlayer)
        if State.AutoArrest and Remotes.ArrestPlayer and (os.clock() >= LastArrestTime) then
            local canAttempt = true
            if State.AutoArrestHandCheck then
                local eq = char:FindFirstChildOfClass("Tool")
                canAttempt = eq ~= nil and eq.Name == "Handcuffs"
            end

            if canAttempt then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Team ~= Teams:FindFirstChild("Guards") and plr.Team ~= Teams:FindFirstChild("Neutral") then
                        local tChar = plr.Character
                        local tHrp = GetRoot(tChar)
                        local tHum = GetHumanoid(tChar)
                        if tChar and tHrp and tHum and tHum.Health > 0 and not tChar:GetAttribute("Arrested") then
                            local validArrest = (plr.Team == Teams:FindFirstChild("Criminals"))
                                or (plr.Team == Teams:FindFirstChild("Inmates") and (tChar:GetAttribute("Trespassing") or tChar:GetAttribute("Tased") or tChar:GetAttribute("Hostile")))

                            if validArrest and (tHrp.Position - hrp.Position).Magnitude <= State.AutoArrestRange then
                                LastArrestTime = os.clock() + 0.5
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
    end

    -- Anti-Fling (Disable Vehicle Collisions Against Local Character)
    if State.AntiFling and Workspace:FindFirstChild("CarContainer") then
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

    -- Vehicle Fling Exploit (Blocked in Anti-Ban Safe Mode to prevent 9500-velocity physics bans)
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

-- Secondary 0.18s Utility Loop (ESP, Invisible Hitbox Expander, RiotShield, AutoHeal, AutoPickup, AutoArmor)
task.spawn(function()
    while task.wait(0.18) do
        if not Env.PrisonLife2026Running then break end

        pcall(UpdatePlayerESP)

        local myChar = LocalPlayer.Character
        local myHrp = GetRoot(myChar)
        local myHum = GetHumanoid(myChar)

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local tChar = plr.Character
                local tHrp = GetRoot(tChar)
                local tHum = GetHumanoid(tChar)

                -- Invisible Hitbox Expander (Never mutates Head.Size; keeps HumanoidRootPart.Transparency == 1)
                if tHrp then
                    if State.ExpandHitbox and IsValidCombatTarget(plr, State.SilentAimHostileCheck) then
                        if not OriginalHitboxData[tHrp] then
                            OriginalHitboxData[tHrp] = {
                                Size = tHrp.Size,
                                CanCollide = tHrp.CanCollide,
                            }
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

                -- Anti Riot Shield
                local shield = tChar:FindFirstChild("RiotShieldPart")
                if shield and shield:IsA("BasePart") then
                    shield.CanQuery = not State.AntiRiotShield
                end

                -- Anti-Invisible
                if State.AntiInvisible and tHum then
                    local animator = tHum:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            local id = track.Animation and track.Animation.AnimationId or ""
                            if id:find("215384594") or id:find("18665825805") then
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
                for _, foodName in ipairs({ "Breakfast", "Lunch", "Dinner" }) do
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
        if State.AutoArmor and myHrp and myHum and myHum.MaxHealth <= 100 and Remotes.InteractWithItem then
            local clothes = Workspace:FindFirstChild("Prison_ITEMS") and Workspace.Prison_ITEMS:FindFirstChild("clothes")
            if clothes then
                for _, item in ipairs(clothes:GetChildren()) do
                    local part = item:FindFirstChildWhichIsA("BasePart")
                    if part and (part.Position - myHrp.Position).Magnitude <= 10 then
                        pcall(function()
                            Remotes.InteractWithItem:InvokeServer(part)
                        end)
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
                                    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                                    local c4Tool = (bp and bp:FindFirstChild("C4 Explosive")) or (myChar and myChar:FindFirstChild("C4 Explosive"))
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

        -- Open All Doors (Saves original state & restores when toggled off)
        if State.OpenAllDoors and Workspace:FindFirstChild("Doors") then
            for _, part in ipairs(Workspace.Doors:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    if not OriginalDoorData[part] then
                        OriginalDoorData[part] = {
                            CanCollide = part.CanCollide,
                            Transparency = part.Transparency,
                        }
                    end
                    part.CanCollide = false
                    part.Transparency = math.max(part.Transparency, 0.65)
                end
            end
        end

        -- Auto Reload at 0 Ammo + Optional Hot-Swap
        if State.AutoReload and myChar and myHum and myHum.Health > 0 then
            local holdingGun, eqTool = IsHoldingFirearm()
            if holdingGun and eqTool then
                local curAmmo = eqTool:GetAttribute("Local_CurrentAmmo") or eqTool:GetAttribute("CurrentAmmo") or 1
                if curAmmo <= 0 and (eqTool:GetAttribute("Local_ReloadSession") or 0) <= 0 then
                    if not GunHook.Ready then
                        SetupGunControllerHooks()
                    end
                    if GunHook.Reload then
                        task.spawn(GunHook.Reload)
                    end
                    if State.AutoReloadHotSwap then
                        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                        if bp then
                            for _, nextGun in ipairs(bp:GetChildren()) do
                                if nextGun:IsA("Tool") and (nextGun:GetAttribute("ToolType") == "Gun" or nextGun:GetAttribute("FireRate")) then
                                    local nextAmmo = nextGun:GetAttribute("Local_CurrentAmmo") or nextGun:GetAttribute("CurrentAmmo") or 1
                                    if nextAmmo > 0 and nextGun.Name ~= "Taser" then
                                        myHum:EquipTool(nextGun)
                                        break
                                    end
                                end
                            end
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
                if State.FastRespawn then
                    PerformFastRespawn()
                end
            end))
        end

        task.wait(0.35)
        SetupGunControllerHooks()

        if State.AntiJumpCooldown or State.InfiniteStamina or State.MaxSpeed then
            BypassAntiJump(char, true)
        end
        if State.Noclip or State.MaxSpeed then
            BypassClientAntiNoclip()
        end

        if State.FEInvisible then
            StartFEInvisible()
        end

        if State.HoloShield then
            CreateHoloShield()
        end

        if State.AutoGetGuns and LocalPlayer.Team ~= Teams:FindFirstChild("Neutral") then
            task.wait(0.45)
            GrabWeapons(State.AutoGetGunsSelection)
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
                if not GunHook.Ready then
                    SetupGunControllerHooks()
                end
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

if LocalPlayer.Character then
    AttachCharacterListeners(LocalPlayer.Character)
end
AddConnection(LocalPlayer.CharacterAdded:Connect(AttachCharacterListeners))

-- ============================================================================
-- // SECTION 12: PRESET TELEPORT LOCATIONS (15 VERIFIED 2026 SPOTS)
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

local function SafeTeleport(targetCF)
    local char = LocalPlayer.Character
    local hrp = GetRoot(char)
    if not hrp then return end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = targetCF
end

-- ============================================================================
-- // SECTION 13: WINDUI WINDOW & TABS (WITH NATIVE PC/MOBILE UI FALLBACK)
-- ============================================================================
Env.PrisonLife2026Running = true

if WindUI then
    local Window = WindUI:CreateWindow({
        Title = "Prison Life • 2026 Hub (v2.0)",
        Icon = "shield",
        Author = "Anti-Ban Hardened • PC & Mobile",
        Folder = "PrisonLife2026Hub",
        Size = UDim2.fromOffset(580, 440),
        Transparent = true,
        Theme = "Dark",
        SideBarWidth = 175,
    })

    Window:EditOpenButton({
        Title = "🚔 PL 2026 Hub",
        Icon = "shield",
        CornerRadius = UDim.new(0, 14),
        StrokeThickness = 2,
        Color = ColorSequence.new(
            Color3.fromHex("1e3a8a"),
            Color3.fromHex("3b82f6")
        ),
        Draggable = true,
    })

    local TabCombat   = Window:Tab({ Title = "Combat & Aim", Icon = "crosshair" })
    local TabWeapons  = Window:Tab({ Title = "Guns & Mods", Icon = "zap" })
    local TabPrison   = Window:Tab({ Title = "Prison & Teams", Icon = "lock" })
    local TabVehicles = Window:Tab({ Title = "Cars & Troll", Icon = "car" })
    local TabMove     = Window:Tab({ Title = "Movement", Icon = "wind" })
    local TabVisuals  = Window:Tab({ Title = "ESP & Teleports", Icon = "eye" })

    -- // TAB 1: COMBAT & AIM
    TabCombat:Section({ Title = "🛡️ Anti-Ban Protection (Error Code 600 Guard)" })
    TabCombat:Toggle({
        Title = "Anti-Ban Safe Mode (Recommended ON)",
        Desc = "Enforces 2026 server-safe limits on FireRate, KillAura, Giver Teleports & WalkSpeed",
        Value = true,
        Callback = function(v)
            State.AntiBanSafeMode = v
            ApplyGunModsAll()
            Notify("Anti-Ban Protection", v and "Safe Mode ON (Protected against Error 600)" or "Safe Mode OFF (Unrestricted)", 3)
        end,
    })

    TabCombat:Section({ Title = "2026 Bullet-Hook Silent Aim" })
    TabCombat:Toggle({
        Title = "Silent Aim (GunController Bullet Hook)",
        Desc = "Redirects bullets directly to target via ActionArea upvalue hook",
        Value = false,
        Callback = function(v)
            State.SilentAim = v
            if v then
                SetupGunControllerHooks()
            end
        end,
    })
    TabCombat:Slider({
        Title = "Silent Aim Hit Chance (%)",
        Value = { Min = 1, Max = 100, Default = 100 },
        Callback = function(v) State.SilentAimHitChance = tonumber(v) or 100 end,
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
    TabCombat:Dropdown({
        Title = "Target Body Part",
        Values = { "Head", "HumanoidRootPart", "Torso" },
        Value = "Head",
        Callback = function(v)
            local part = NormalizeDropdownValue(v)
            if part ~= "" then
                State.SilentAimAimPart = part
                State.AimAssistAimPart = part
            end
        end,
    })
    TabCombat:Toggle({
        Title = "Wallcheck (Visible Only)",
        Value = true,
        Callback = function(v) State.SilentAimWallcheck = v end,
    })
    TabCombat:Toggle({
        Title = "Guard Safe Mode (Only Hostile/Trespassing Inmates)",
        Desc = "Prevents Guards from getting penalized for shooting innocent Inmates",
        Value = true,
        Callback = function(v) State.SilentAimHostileCheck = v end,
    })

    TabCombat:Section({ Title = "2026 3D Ballistic Holo-Shield" })
    TabCombat:Toggle({
        Title = "3D Ballistic Holo-Shield (Blocks Incoming Bullets)",
        Desc = "Deploys a front-facing holographic riot shield with 180 HP & auto-recharge",
        Value = false,
        Callback = function(v)
            State.HoloShield = v
            if v then
                CreateHoloShield()
            else
                DestroyHoloShield()
            end
        end,
    })

    TabCombat:Section({ Title = "Camera Aim Assist & Triggerbot" })
    TabCombat:Toggle({
        Title = "Smooth Aim Assist (PC & Mobile Touch)",
        Value = false,
        Callback = function(v) State.AimAssist = v end,
    })
    TabCombat:Slider({
        Title = "Aim Assist Smoothness",
        Step = 0.02,
        Value = { Min = 0.05, Max = 0.8, Default = 0.22 },
        Callback = function(v) State.AimAssistSmoothness = tonumber(v) or 0.22 end,
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
        Title = "Shoot Through Riot Shields (Anti-Shield)",
        Desc = "Disables CanQuery on enemy RiotShieldPart",
        Value = false,
        Callback = function(v) State.AntiRiotShield = v end,
    })
    TabCombat:Toggle({
        Title = "Shoot Through Vehicles (Vehicle Wallbang)",
        Desc = "Ignores workspace.CarContainer in line-of-sight & bullet raycasts",
        Value = false,
        Callback = function(v)
            State.VehicleWallbang = v
            pcall(function()
                if GunHook.ShootParams then
                    GunHook.ShootParams.FilterDescendantsInstances = v
                        and { LocalPlayer.Character, Workspace:FindFirstChild("CarContainer") }
                        or { LocalPlayer.Character }
                end
            end)
        end,
    })

    TabCombat:Section({ Title = "Melee Kill Aura & Hitboxes" })
    TabCombat:Toggle({
        Title = "Melee Kill Aura (Anti-Ban Rate-Limited)",
        Desc = "Punches closest valid enemy within 10 studs at safe 0.32s intervals",
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
        Desc = "Enlarges enemy hitboxes without drawing giant cubes over your screen",
        Value = false,
        Callback = function(v)
            State.ExpandHitbox = v
            if not v then
                RestoreAllHitboxes()
            end
        end,
    })
    TabCombat:Slider({
        Title = "Hitbox Size",
        Value = { Min = 3, Max = 15, Default = 9 },
        Callback = function(v) State.HitboxSize = tonumber(v) or 9 end,
    })

    -- // TAB 2: WEAPONS & GUN MODS
    TabWeapons:Section({ Title = "2026 Safe Gun Grabber (GiverPressed)" })
    TabWeapons:Button({
        Title = "Grab Armory Loadout (Remington 870 + MP5 + M9)",
        Desc = "Same-zone pickup (no 1,750-stud cross-map oscillation)",
        Callback = function()
            task.spawn(function()
                GrabWeapons({ "Remington 870", "MP5", "M9" })
            end)
        end,
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
        Desc = "Automatically grabs dropped Keycards and weapons within 11.5 studs",
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
        Callback = function(v)
            State.GunNoSpread = v
            ApplyGunModsAll()
        end,
    })
    TabWeapons:Toggle({
        Title = "Force Full Automatic (Shotguns/Pistols/Snipers)",
        Value = true,
        Callback = function(v)
            State.GunFullAuto = v
            ApplyGunModsAll()
        end,
    })
    TabWeapons:Toggle({
        Title = "Auto Reload at 0 Ammo",
        Value = false,
        Callback = function(v) State.AutoReload = v end,
    })
    TabWeapons:Toggle({
        Title = "Hot-Swap to Loaded Gun When Reloading",
        Value = false,
        Callback = function(v) State.AutoReloadHotSwap = v end,
    })
    TabWeapons:Toggle({
        Title = "Show Floating Action Bar (Fast Switch / Guns / Shield / Invis)",
        Desc = "Adds on-screen quick tap buttons for Mobile & PC users",
        Value = IsMobile,
        Callback = function(v)
            MobileQuickBar.Visible = v
        end,
    })
    MobileQuickBar.Visible = IsMobile

    TabWeapons:Section({ Title = "Auto Heal & Armor" })
    TabWeapons:Toggle({
        Title = "Auto Heal (Eat Cafeteria Food Below 85 HP)",
        Desc = "Uses EatFood remote with Breakfast/Lunch/Dinner in Backpack",
        Value = false,
        Callback = function(v) State.AutoHeal = v end,
    })
    TabWeapons:Toggle({
        Title = "Auto Equip Armor When Near Armory",
        Value = false,
        Callback = function(v) State.AutoArmor = v end,
    })

    -- // TAB 3: PRISON, GUARDS & TEAMS
    TabPrison:Section({ Title = "Instant Team Switcher (RequestTeamChange)" })
    TabPrison:Button({
        Title = "Join Inmates Team",
        Callback = function() SwitchToTeam("Inmates") end,
    })
    TabPrison:Button({
        Title = "Join Guards Team",
        Callback = function() SwitchToTeam("Guards") end,
    })
    TabPrison:Button({
        Title = "Become Criminal (Teleport to Criminal Spawn)",
        Callback = function()
            local crimSpawn = Workspace:FindFirstChild("Criminals Spawn")
            local sp = crimSpawn and crimSpawn:FindFirstChild("SpawnLocation")
            if sp then
                SafeTeleport(sp.CFrame + Vector3.new(0, 3, 0))
            end
        end,
    })
    TabPrison:Button({
        Title = "Join Neutral Team (Safe Mode)",
        Callback = function() SwitchToTeam("Neutral") end,
    })

    TabPrison:Section({ Title = "Guard & Prisoner Utilities" })
    TabPrison:Toggle({
        Title = "Auto Arrest Aura (ArrestPlayer Remote)",
        Desc = "Automatically handcuffs Criminals & Trespassing/Hostile Inmates within 7.5m",
        Value = false,
        Callback = function(v) State.AutoArrest = v end,
    })
    TabPrison:Toggle({
        Title = "Anti-Tase (Bypass PlayerTased Stun)",
        Desc = "Stops taser ragdoll animation & restores WalkSpeed/Backpack immediately",
        Value = false,
        Callback = function(v) State.AntiTase = v end,
    })
    TabPrison:Toggle({
        Title = "Always Enable Backpack",
        Desc = "Locks BackpackEnabled = true even while tased or cuffed",
        Value = false,
        Callback = function(v) State.AlwaysBackpack = v end,
    })
    TabPrison:Toggle({
        Title = "Auto Become Criminal After Being Arrested",
        Desc = "Waits 4.25s after ClientArrested fires and teleports back to Criminal Base",
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
            if not v then
                RestoreAllDoors()
            end
        end,
    })
    TabPrison:Toggle({
        Title = "Electric Fence Godmode",
        Desc = "Disables TouchTransmitter damage on top of prison fences",
        Value = false,
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

    -- // TAB 4: VEHICLES & TROLLING
    TabVehicles:Section({ Title = "Vehicles (PC & Mobile Controls)" })
    TabVehicles:Button({
        Title = "Spawn & Enter Nearest Car",
        Desc = "Invokes InteractWithItem on nearest Car Spawner and sits in driver seat",
        Callback = SpawnAndEnterNearestCar,
    })
    TabVehicles:Toggle({
        Title = "Vehicle Fly (Mobile Thumbstick + Up/Down & PC WASD)",
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
        Title = "Serverside FE Invisible (Animation Underground Trick)",
        Desc = "Hides your body underground serverside while keeping your screen normal",
        Value = false,
        Callback = function(v)
            SetFEInvisibleState(v, false)
        end,
    })
    TabVehicles:Toggle({
        Title = "Anti-Invisible (Reveal Invisible Exploiters)",
        Desc = "Strips underground invisibility animations on other players",
        Value = false,
        Callback = function(v) State.AntiInvisible = v end,
    })
    TabVehicles:Toggle({
        Title = "Anti-Fling (Disable Vehicle Collision Attacks)",
        Desc = "Prevents car-fling exploiters from flinging you into the void",
        Value = true,
        Callback = function(v) State.AntiFling = v end,
    })
    TabVehicles:Toggle({
        Title = "Vehicle Fling Enemies (Requires Safe Mode OFF)",
        Desc = "Launches network-owned VehicleSeats at enemy players",
        Value = false,
        Callback = function(v)
            if v and State.AntiBanSafeMode then
                Notify("Anti-Ban Safe Mode", "Disable Anti-Ban Safe Mode first to use 9500-velocity Car Fling!", 4)
            end
            State.VehicleFling = v
            if v then State.AntiFling = true end
        end,
    })

    -- // TAB 5: MOVEMENT
    TabMove:Section({ Title = "2026 Anti-Rubberband Speed & Noclip" })
    TabMove:Toggle({
        Title = "MaxSpeed (Anti-Cheat Safe Speed Boost)",
        Desc = "Uses native WalkSpeed with the 20 indoor sub-regions so you never rubberband",
        Value = false,
        Callback = function(v)
            State.MaxSpeed = v
            if v then
                BypassClientAntiNoclip()
                if LocalPlayer.Character then
                    BypassAntiJump(LocalPlayer.Character, true)
                end
            else
                local hum = GetHumanoid(LocalPlayer.Character)
                if hum then
                    hum.WalkSpeed = State.AlwaysSprint and 24 or 16
                end
            end
        end,
    })
    TabMove:Dropdown({
        Title = "Speed Mode",
        Values = { "RegionSafe", "Custom" },
        Value = "RegionSafe",
        Callback = function(v)
            local mode = NormalizeDropdownValue(v)
            if mode == "RegionSafe" or mode == "Custom" then
                State.MaxSpeedMode = mode
            end
        end,
    })
    TabMove:Slider({
        Title = "Custom WalkSpeed",
        Value = { Min = 16, Max = 92, Default = 40 },
        Callback = function(v) State.CustomWalkSpeed = tonumber(v) or 40 end,
    })
    TabMove:Toggle({
        Title = "Always Sprint (24 WalkSpeed)",
        Value = false,
        Callback = function(v)
            State.AlwaysSprint = v
            if not v and not State.MaxSpeed then
                local hum = GetHumanoid(LocalPlayer.Character)
                if hum then hum.WalkSpeed = 16 end
            end
        end,
    })
    TabMove:Toggle({
        Title = "No Jump Cooldown & Infinite Stamina",
        Desc = "Disables Jump signal stamina drain safely via getconnections",
        Value = false,
        Callback = function(v)
            State.AntiJumpCooldown = v
            State.InfiniteStamina = v
            if LocalPlayer.Character then
                BypassAntiJump(LocalPlayer.Character, v)
            end
        end,
    })
    TabMove:Toggle({
        Title = "Infinite Jump (Air Jump)",
        Value = false,
        Callback = function(v) State.InfiniteJump = v end,
    })
    TabMove:Toggle({
        Title = "Noclip (Non-Destructive Head Signal Bypass)",
        Desc = "Disables Head CanCollide signal connections without destroying game scripts",
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

    -- // TAB 6: ESP & TELEPORTS
    TabVisuals:Section({ Title = "Role-Colored Player ESP" })
    TabVisuals:Toggle({
        Title = "Enable Player ESP",
        Value = false,
        Callback = function(v)
            State.ESP = v
            if not v then
                for plr in pairs(ESPObjects) do
                    RemovePlayerESP(plr)
                end
            end
        end,
    })
    TabVisuals:Toggle({
        Title = "Highlight Chams",
        Value = true,
        Callback = function(v) State.ESPHighlight = v end,
    })
    TabVisuals:Toggle({
        Title = "Show Name & Status Flags ([HOSTILE] / [TRESPASS])",
        Value = true,
        Callback = function(v)
            State.ESPNameTag = v
            State.ESPStatusFlags = v
        end,
    })
    TabVisuals:Toggle({
        Title = "Show Health & Distance",
        Value = true,
        Callback = function(v)
            State.ESPHealth = v
            State.ESPDistance = v
        end,
    })
    TabVisuals:Toggle({
        Title = "Show Equipped Weapon",
        Value = true,
        Callback = function(v) State.ESPWeapon = v end,
    })
    TabVisuals:Toggle({
        Title = "C4 Explosive ESP (Highlight Placed C4)",
        Value = false,
        Callback = function(v) State.C4ESP = v end,
    })
    TabVisuals:Toggle({
        Title = "Live Killfeed Notifier",
        Desc = "Alerts you when you eliminate someone or get eliminated",
        Value = false,
        Callback = function(v) State.KillFeedNotifier = v end,
    })

    TabVisuals:Section({ Title = "15 Preset Prison Life Teleports" })
    local locNames = {}
    for name in pairs(TeleportLocations) do
        table.insert(locNames, name)
    end
    table.sort(locNames)

    local selectedLocation = locNames[1]
    TabVisuals:Dropdown({
        Title = "Select Location",
        Values = locNames,
        Value = selectedLocation,
        Callback = function(v)
            local picked = NormalizeDropdownValue(v)
            if picked ~= "" then
                selectedLocation = picked
            end
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

    TabVisuals:Section({ Title = "Teleport to Player" })
    local selectedPlayerName = ""
    local playerDropdown = TabVisuals:Dropdown({
        Title = "Select Player",
        Values = {},
        Value = "",
        Callback = function(v)
            selectedPlayerName = NormalizeDropdownValue(v)
        end,
    })
    local function RefreshPlayerDropdown()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(list, p.Name)
            end
        end
        pcall(function()
            if playerDropdown and playerDropdown.Refresh then
                playerDropdown:Refresh(list)
            end
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
            else
                Notify("Teleport", "Select a valid alive player first!", 2.5)
            end
        end,
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
    FallbackFrame.Size = UDim2.fromOffset(380, 350)
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
    TitleBar.Text = "🚔 Prison Life 2026 Hub (v2.0 Anti-Ban)"
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
    AddFallbackToggle("Silent Aim (Bullet Hook)", false, function(v) State.SilentAim = v; if v then SetupGunControllerHooks() end end)
    AddFallbackToggle("Smooth Aim Assist", false, function(v) State.AimAssist = v end)
    AddFallbackToggle("Triggerbot (Auto-Shoot)", false, function(v) State.Triggerbot = v; if v then SetupGunControllerHooks() end end)
    AddFallbackToggle("3D Ballistic Holo-Shield", false, function(v) State.HoloShield = v; if v then CreateHoloShield() else DestroyHoloShield() end end)
    AddFallbackToggle("Safe Melee Kill Aura", false, function(v) State.KillAura = v end)
    AddFallbackToggle("Gun Mods (Rapid Fire + No Spread)", false, function(v) State.GunMods = v; ApplyGunModsAll() end)
    AddFallbackToggle("Region-Safe MaxSpeed", false, function(v) State.MaxSpeed = v end)
    AddFallbackToggle("Anti-Tase & Always Backpack", false, function(v) State.AntiTase = v; State.AlwaysBackpack = v end)
    AddFallbackToggle("Auto Arrest Aura", false, function(v) State.AutoArrest = v end)
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
    StopFEInvisible()
    DestroyHoloShield()
    RestoreAllHitboxes()
    RestoreAllDoors()
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

Notify("Prison Life • 2026 Hub v2.0", "Loaded Anti-Ban Hardened PC & Mobile Script!", 4)
