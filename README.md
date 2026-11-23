# 🚔 Prison Life — Ultimate 2026 Script (PC & Mobile) [v6.0 Refined KX Pro Edition]

Complete, anti-ban-hardened script for **Roblox Prison Life** (`PlaceId: 155615604`), engineered for the **Late 2026 ("Sniper Update!")** client/server architecture (`M700`, `Revolver`, `Light Vest`). Built with a clean 7-tab **WindUI** menu (plus a built-in **Native PC/Mobile Touch GUI Fallback**) and a **clutter-free HUD**.

## ⚡ Quick Loadstring
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/reizure87-create/prison-life-script/main/PrisonLife.lua"))()
```

---

## 🛠️ What Was Refined in v6.0

1. **Fixed Anti-Hit Shield (No More Getting Hit + Zero Ray/Movement Blocking)**:
   - **Zero Ray-Block**: Replaced the intrusive `CanQuery = true` box sitting in front of your face/crosshair with a sleek non-blocking **ground halo ring around your feet** (`CanQuery = false`, `CanCollide = false` always) — never blocks your own gunshots, cursor clicks, prompts, or camera view.
   - **Never Disables Protection**: Removed the fake 3.8s `BrokenUntil` shield shutdown on incoming gunfire, removed the 90ms Ragebot standing gap (`RagebotPeekShield = false` default), and fixed `Hybrid` so holding a Riot Shield no longer turns off Underground/Desync protection or forcefully unequips your firearm.
   - **Final-Heartbeat Network Timing + `-10.5` Burial Depth**: Buries/desyncs your outgoing `CFrame` + velocity (`UndergroundPeek`, `Hybrid`, `AntiLockDesync`) at the very end of `Heartbeat` **after** `KillAura`, `AutoArrest`, `AutoTaze`, `AutoPickupDropped`, and movement finish measuring from your standing position, and restores exact `SavedCF` + `SavedVel` cleanly at `RenderPriority.Camera.Value - 15` (`185`).
   - **Restored Shoot Origin**: `FireToolAtTarget` + `GunHook.Bullet` normalize origin back to standing `SavedCF` so your bullets never hit the underside of the floor while shielded.
2. **Smooth 3D Fly, Cached Noclip Restore, ShotToken & Team Switch Refinements**:
   - Fixed `Character Fly` downward clamping (`math.max(vel.Y, 0)`), removed gravity flutter while hovering/diving, added camera-pitched 3D flight + subtle `Vehicle Fly` hover compensation.
   - Added cached `LocalParts` Noclip collision restoration when toggled OFF, `ShotToken` overlap guard in `FireToolAtTarget` for rapid Ragebot/.combo1 fire, `ToolArbiter` lock during `GrabWeapons`, `LocalPlayer.Team` polling in `SwitchToTeam("Criminals")`, and timeout-safe `PerformFastRespawn()`.
   - Added WindUI control syncing (`BindCtrl` + `Core.SyncVisualUI()`) so `.preset` and JSON `.loadcfg` visually sync UI controls immediately.

---

## 🛠️ Architecture & Performance Highlights (v5.0 + v6.0)
- **Single Centralized Scheduler & `WorldCache`**: Consolidated loops into `Heartbeat` (`os.clock()` gated) with one shared `Players` snapshot per tick + event-driven `Cars`, `Doors`, `Fences`, `Dropped`, `Players`, and `Givers` caches (`0` per-frame `GetDescendants()` workspace scans).
- **Pre-Allocated Circular VFX Pools**: `32` bullet tracers, `14` floating damage numbers, and `10` shield sparks parked off-world at `(0, -9000, 0)`.
- **Dynamic Signature `GunController` Hooks + 2026 Sniper Support**: Upvalue type/constant scanner (`RaycastParams`, `Local_ReloadSession`, `getgc` fallback), `M700` & `Revolver` grab/commands (`.m700`, `.sniper`, `.revolver`), and `Zero Sniper / Taser ChargeTime Delay`.
- **Distance-Sorted 30-Highlight LOD ESP & Grace-Hardened Anomalies**: Closest `30` players keep `Highlight` chams while distant targets collapse to `◆ 185m` LOD pips (`ESPDetailDistance`); 3s spawn/team/arrest/lag grace windows isolate confirmed cheaters (`[CHEAT]`) for priority targeting & reactive shooter evade.
- **Embedded JSON Persistence & Config Profiles**: Save, load, delete, and auto-load named JSON config profiles under `PrisonLife2026Hub/profiles/<name>.json`.

---

## ⌨️ Default PC Hotkeys
- **`RightShift`** — Toggle WindUI Hub Window
- **`G`** — Toggle Anti-Hit Shield
- **`H`** — Toggle AutoHvH Mode
- **`X`** — Execute `.combo1` Multi-Gun Burst
- **`B`** — Toggle 360° Ragebot
- **`F`** — Toggle Character Fly
- **`N`** — Toggle Noclip
- **`;` (`Semicolon`)** — Open & Focus Top-Right Command Bar
