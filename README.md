# 🚔 Prison Life — Ultimate 2026 Script (PC & Mobile) [v2.0 Anti-Ban Edition]

Complete, anti-ban-hardened script for **Roblox Prison Life** (`PlaceId: 155615604`), engineered specifically for the **Late 2026 ("Sniper Update!")** client/server architecture. Built with **WindUI** (plus a built-in **Native PC/Mobile Touch GUI Fallback**) for 100% reliability on all PC and Mobile executors.

## ⚡ Quick Loadstring
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/reizure87-create/prison-life-script/main/PrisonLife.lua"))()
```

---

## 🛡️ What's New in v2.0 (Error Code 600 Anti-Ban Overhaul & Bugfixes)

1. **Anti-Ban Safe Mode (ON by Default — Prevents 30-Day Experience Bans / Error Code 600)**:
   - **Safe Same-Zone Gun Grabber**: Fixed the v1.1 `savedCF = hrp.CFrame` overwrite bug inside the `while` loop that caused 60Hz cross-map CFrame oscillation (1,750 studs between Prison Armory and Criminal Base) while firing `GiverPressed` every frame. Now checks gamepass/team eligibility, sorts givers by proximity, rate-limits `GiverPressed` / `TouchGiver` calls (`0.16s` interval), and restores your exact starting CFrame cleanly.
   - **Rate-Limited Single-Target Melee Kill Aura**: Throttled `ReplicatedStorage.meleeEvent:FireServer(target, 1, 1)` to a server-safe `0.32s` swing interval and `<= 10` studs range against the closest valid enemy instead of multi-target 12.5Hz spam.
   - **Server-Safe FireRate & Region-Aware WalkSpeed**: Caps modified firearm `FireRate` to `<= 15 SPS` in Safe Mode, enforces the exact 20 Indoor Sub-Regions WalkSpeed ceilings (`32` indoors, `50` prison yard, `92` city outdoors), and blocks 9500-velocity `VehicleFling` unless Safe Mode is explicitly turned off.
   - **Non-Destructive Noclip & Anti-Jump**: Removed `ReplicatedStorage.Scripts.CharacterCollision:Destroy()`; now uses non-destructive `getconnections` signal disabling on `Head:GetPropertyChangedSignal("CanCollide")` and `Humanoid:GetPropertyChangedSignal("Jump")`.
2. **2026 3D Ballistic Holo-Shield ("New Shield that blocks bullets")**:
   - Deploys a front-facing 3D curved holographic riot shield (`RiotShieldPart`) with a live **180 HP Durability Bar**, automatic out-of-combat recharge, and physical bullet/tracer interception.
3. **Lazy GunController Upvalue Hook + Strictly-Scoped Raycast Fallback**:
   - Automatically hooks `PlayerGui.Home.hud.ActionArea.InputBegan` whenever a firearm is equipped (fixing Silent Aim/Triggerbot when staying on the team selection screen >15s), with a safe fallback that only redirects long-range firearm raycasts (`Magnitude > 40`).
4. **Built-In Native PC & Mobile Touch Hub Fallback**:
   - If `WindUI` fails to download on restricted mobile connections, the script automatically renders a sleek, draggable native Roblox Hub UI with a floating `🚔 PL 2026` toggle button.

---

## 🔥 Full Feature List

### 1. Combat & Aiming (`ActionArea` / `GunController` Hooks)
- **Anti-Ban Safe Mode Toggle** (Enabled by default)
- **Silent Aim (`pl.Bullet` Hook + Safe Raycast Fallback)** with Hit Chance, FOV Circle, Target Part (`Head`, `HumanoidRootPart`, `Torso`), Wallcheck, and **Guard Safe Mode** (ignores innocent Inmates unless `Hostile` or `Trespassing`)
- **2026 3D Ballistic Holo-Shield** with live HUD durability bar (`180 HP`) & auto-recharge
- **Smooth Camera Aim Assist** (PC Mouse & Mobile Touch friendly with velocity prediction)
- **Triggerbot / Auto-Shoot** (`pl.Shoot` & `pl.Reload` upvalues)
- **Anti-Riot Shield** (`CanQuery = false` on enemy `RiotShieldPart`) & **Vehicle Wallbang**
- **Anti-Ban Melee Kill Aura** (`meleeEvent`) & **Invisible Hitbox Expander** (locks `HumanoidRootPart.Transparency = 1` so ESP Highlights never draw giant 3D cubes)

### 2. Weapons & 2026 Gun Mods
- **Safe Instant Gun Grabber (`GiverPressed` + `#TouchGiver`)**: Grab Armory Loadout (`Remington 870`, `MP5`, `M9`) or `AK-47` with zero screen flicker
- **Auto Grab Loadout on Respawn** & **Auto Pickup Dropped Keycards/Weapons**
- **2026 Gun Attribute Mods**: Rapid Fire (`FireRate`), Zero Spread (`SpreadRadius = 0`), Full Auto (`AutoFire = true`), and Infinite Range (`9999`)
- **Auto Reload at 0 Ammo** + **Hot-Swap to Loaded Gun**
- **Auto Heal** (`ReplicatedStorage.Remotes.EatFood`) & **Auto Equip Armor** (`InteractWithItem`)
- **Floating Mobile Quick Action Bar**: On-screen tap buttons for **⚡ Fast Switch**, **🔫 Safe Guns**, **🛡️ Holo Shield**, **👻 FE Invis**, and **▲/▼ Vehicle Fly**

### 3. Prison, Guards & Teams
- **Instant Team Switcher** (`ReplicatedStorage.Remotes.RequestTeamChange:InvokeServer(Team, 1)`) for `Inmates`, `Guards`, `Neutral`, and instant Criminal conversion
- **Auto Arrest Aura** (`ReplicatedStorage.Remotes.ArrestPlayer:InvokeServer(player, 1)`) with live 7-second cooldown bar
- **Anti-Tase** (`ReplicatedStorage.GunRemotes.PlayerTased`) & **Always Enable Backpack** (`BackpackEnabled = true`)
- **Auto Become Criminal After Being Arrested** (`ReplicatedStorage.Remotes.ClientArrested`)
- **Fast Respawn (`<1s`)** with death position restoration
- **Open / Noclip All Prison Doors**, **Electric Fence Godmode**, & **Auto Detonate C4**

### 4. Vehicles, Movement & Visuals
- **Remote Car Spawner** (`InteractWithItem` on nearest `Car Spawner` button)
- **PC & Mobile Vehicle Fly** + **Vehicle Speed Multiplier**
- **Serverside FE Invisible** (`215384594` R6 / `18665825805` R15 weight `0.001` technique — no floor tilt) & **Anti-Invisible**
- **Anti-Fling** (neutralizes `workspace.CarContainer` collisions)
- **Region-Safe MaxSpeed** (20 Indoor Sub-Regions anti-rubberband system), **Always Sprint**, **No Jump Cooldown**, **Infinite Jump**, **Non-Destructive Noclip**, & **Anti-KillPlane**
- **Role-Colored Player ESP**, **C4 Explosive ESP**, **Live Killfeed Notifier**, & **15 Verified 2026 Teleports + Teleport Behind Player**
