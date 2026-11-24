# 🚔 Prison Life — Ultimate 2026 Script (PC & Mobile) [v7.0 Apex KX Pro Edition]

Complete, anti-ban-hardened script for **Roblox Prison Life** (`PlaceId: 155615604`), engineered for the **Late 2026 ("Sniper Update!")** client/server architecture (`M700`, `Revolver`, `Light Vest`). Built with a clean 7-tab **WindUI** menu (plus a built-in **Native PC/Mobile Touch GUI Fallback**) and a **clutter-free HUD**.

## ⚡ Quick Loadstring
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/reizure87-create/prison-life-script/main/PrisonLife.lua"))()
```

---

## 🚀 What's New in v7.0 (Apex KX Pro Overhaul)

1. **Zero Connection Leaks & Self-Healing Weapon Hooks**:
   - **Scoped Listeners (`App.CreateScope`)**: Remote player tracking, car parts, and local character/backpack spawn hooks clean up cleanly across every respawn and unload (`Env.PrisonLife2026Cleanup`). Fixed `WatchTargetHitDamage` so transient health listeners never accumulate in `Connections`.
   - **Live Camera & 4-Source `GunController` Hooking**: Updates `Camera` dynamically via `Workspace:GetPropertyChangedSignal("CurrentCamera")`, scores closure candidates across `ActionArea.InputBegan` (Mobile), `UserInputService.InputBegan` (PC), `CharacterAdded`, and `getgc`, adds `.rehook` manual recovery, self-healing `__namecall` Raycast fallback (active only until `BulletHookFiredCount >= 1`), velocity lead compensation (`SilentAimLead`), and `ActionArea`-centered synthetic firing.
2. **Mobile & PC HUD Polish**:
   - **Drag-Guarded Viewport-Clamped Pills**: `.combo1` and `⌘ CMD` track `WasDraggedAt` so dragging never triggers accidental `.Activated` taps and never goes off-screen.
   - **Mobile Ergonomics**: Top-center mobile Command Bar & Autocomplete dropdown (with race-free tap handling), `TextChatService` + `Chatted` dual command listeners, and jump-adjacent circular Fly Up/Down buttons with stuck-touch protection.
3. **Complete Defense, Combat & ESP Upgrades**:
   - **`AntiCarBring` Protection**: Disables `CanTouch` on foreign passenger `Seat`s and immediately ejects forced kidnapping while preserving normal driving.
   - **Fixed `HoloShield` Pre-Rotation `SavedCF` & Styles**: Captures standing pose before `ShieldAutoFaceShooter`/`ShieldSpinBlock` so server packets desync without spinning your camera; adds `CyberHex`, `NeonRing`, and `Minimal` `ShieldVisualStyle`s (`CanQuery = false` always).
   - **Non-Yielding `AutoArmor` & Crowd `AutoArrest`**: Caches armor givers and spawns `InvokeServer` asynchronously; uses per-target `AutoArrest` cooldowns + auto-cuff equip, 1-arg `MeleeEvent`, optional `KillAuraAutoMelee`, and Ragebot auto-reload.
   - **Upgraded ESP**: 3px billboard health bars, Guard-aware threat colors for Inmates (crimson Hostile vs amber Trespassing vs cool gray Innocent), `.target` focus highlighting, and dropped `ItemESP` (weapons & keycards).
4. **Full KX Command Parity & Loadout Kits**:
   - Multi-target batch `.fc`/`.bring`/`.void`/`.fling`, `.target`/`.untarget`, `.loadout <light|sniper|riot|full>`, `.refill`, `.rehook`, `.anticarbring`, `.itemesp`, `.status`, `.shieldstyle`, plus working `.fencegod`/`.noclip`/`.esp` toggles synced directly with WindUI.

---

## 🛠️ Core Architecture
- **Single Centralized Scheduler & `WorldCache`**: Pooled `Heartbeat` scheduler sharing one `Players` snapshot + event-driven `Cars`, `Doors`, `Fences`, `ArmorParts`, `Dropped`, `Players`, and `Givers` caches (`0` per-frame `GetDescendants()` workspace scans).
- **Pre-Allocated Circular VFX Pools**: `32` bullet tracers, `14` floating damage numbers, and `10` shield sparks parked off-world at `(0, -9000, 0)`.
- **Distance-Sorted 30-Highlight LOD ESP & Grace-Hardened Anomalies**: Closest `30` players keep `Highlight` chams while distant targets collapse to `◆ 185m` LOD pips (`ESPDetailDistance`).
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
- **`;` (`Semicolon`)** — Open & Focus Command Bar
