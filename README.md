# 🚔 Prison Life — Ultimate 2026 Script (PC & Mobile) [v5.0 Architect KX Pro]

Complete, anti-ban-hardened script for **Roblox Prison Life** (`PlaceId: 155615604`), engineered for the **Late 2026 ("Sniper Update!")** client/server architecture (`M700`, `Revolver`, `Light Vest`). Built with a clean 7-tab **WindUI** menu (plus a built-in **Native PC/Mobile Touch GUI Fallback**) and a **clutter-free HUD**.

## ⚡ Quick Loadstring
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/reizure87-create/prison-life-script/main/PrisonLife.lua"))()
```

---

## 🛠️ What Was Upgraded in v5.0 (Architectural Video Analysis + Gameplay Test + KX Research)

1. **Centralized Scheduler, Event-Driven `WorldCache` & Circular VFX Pooling**:
   - Consolidated polling loops into a single `Heartbeat` scheduler (`App.Scheduler`) gated by `os.clock()` deltas and sharing **one per-tick `Players` snapshot** across ESP, Anomaly Detection, Aim/Ragebot, KillAura, and AutoArrest.
   - Replaced per-frame `GetDescendants()` and `Workspace:GetChildren()` scans with event-driven `WorldCache` tables (`CarCache`, `DoorCache`, `FenceCache`, `DroppedItemCache`, `GiverCache`, `PlayerCache`) updated via `ChildAdded` / `DescendantAdded` / `CollectionService`.
   - Replaced runtime `Instance.new` / `:Destroy()` VFX churn with **pre-allocated circular Object Pools** (`32` neon bullet tracers, `14` damage number billboards, `10` shield impact sparks parked off-world at `(0, -9000, 0)`).
2. **Future-Proof Dynamic Type-Signature `GunController` Hooks + 2026 Sniper Update**:
   - Upgraded `SetupGunControllerHooks` to inspect closure constants (`Raycast`, `canBeDamaged`, `Local_ReloadSession`, `Local_IsShooting`) and upvalue types (`RaycastParams`, `GunData`) dynamically (`ActionArea` + `CharacterAdded` + `getgc` fallback), eliminating brittle fixed upvalue-index lookups.
   - Added full `M700` Sniper & `Revolver` grab/command/combo support (`.m700` / `.sniper`, `.revolver`) plus `Zero Sniper / Taser ChargeTime Delay` in Gun Mods.
3. **Fixed UndergroundPeek Camera Drop, Car-Bring Upside-Down Flip & Mobile Hotbar Overlap**:
   - Restores standing `CFrame` via `RunService:BindToRenderStep` at `RenderPriority.Camera.Value - 15` (`185` < Camera `200`) so `UndergroundPeek` and `DesyncBox` **never** snap or flip your camera into the floor or sky.
   - Fixed `.bring` / `.forcecrim` / `.void` vehicle manipulation (`flat` upright yaw pivot, locked `passSeat` offset, non-wheel collision suppress during scoop, linear + angular velocity zeroing, safe `+3.0` stud arrival height).
   - Adjusted the bottom Shield/Arrest status strip offset (`-88` on mobile) so it sits cleanly above the 3-slot hotbar.
4. **Distance-Sorted 30-Highlight Budget, LOD ESP & Grace-Hardened Anti-Exploiter Suite**:
   - Sorts players by nearest distance before allocating `Highlight` instances (strictly within Roblox's `30` Highlight limit alongside `C4ESP`), and collapses distant player tags beyond `ESPDetailDistance` (`140m`) into compact `◆ 185m` diamond LOD pips.
   - Added 3s grace windows (`CharacterAdded`, `Team` change, `Arrested`/`Tased` transitions, and lag spikes `dt > 0.45s`) to eliminate false-positive Speed/TP alerts; confirmed cheaters, FE-Invis, and active `ReplicateEvent` shooters receive priority focus in `AutoHvH`, reactive shield auto-evade, and `ToolArbiter` conflict-free tool switching.
5. **Embedded JSON Persistence & Named Config Profiles**:
   - Save, load, delete, list, and auto-load named JSON profiles under `PrisonLife2026Hub/profiles/<name>.json` (`HttpService` with pure-Lua JSON encoder/decoder fallback; `.savecfg`, `.loadcfg`, `.delcfg`, `.configs`, `.autoload`).

---

## ✨ Core Features & Commands
- **Clutter-Free Mobile & PC HUD**: Top-left draggable `⚡ .combo1` pill, top-right collapsible `⌘ CMD` pill with autocomplete, top-left 3-line mini-killfeed & anomaly feed, contextual Fly `▲` / `▼` buttons, and bottom Shield durability / Arrest cooldown bars.
- **Anti-Ban Safe Mode (`Error Code 600` Guard • ON by default)**: Enforces `Hostile == true`-only lethal guard targeting, 20-subregion Indoor SafeSpeed (`32 / 50 / 92`), `15 SPS` FireRate cap, `10m` KillAura/Arrest range, and non-destructive `getconnections` signal bypassing.
- **KX Admin Commands**: `.savecar [1..5]`, `.bring <plr>`, `.forcecrim <plr|all>`, `.void <plr>`, `.fling <plr>`, `.autohvh`, `.evade`, `.wheelaura`, `.combo1`, `.loopcombo`, `.shield`, `.shieldmode <mode>`, `.m700`, `.revolver`, `.hammer`, `.knife`, `.guns`, `.savecfg <name>`, `.loadcfg <name>`, `.preset <safe|legit|rage|hvh>`.

---

## ⌨️ Default PC Hotkeys
- **`RightShift`** — Toggle WindUI Hub Window
- **`G`** — Toggle 5-Mode 3D Bullet Shield
- **`H`** — Toggle AutoHvH Mode
- **`X`** — Execute `.combo1` Multi-Gun Burst
- **`B`** — Toggle 360° Ragebot
- **`F`** — Toggle Character Fly
- **`N`** — Toggle Noclip
- **`;` (`Semicolon`)** — Open & Focus Top-Right Command Bar
