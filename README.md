# 🚔 Prison Life — Ultimate 2026 Script (PC & Mobile) [v7.1 Apex KX Pro Edition]

Complete, anti-ban-hardened script for **Roblox Prison Life** (`PlaceId: 155615604`), engineered for the **Late 2026 ("Sniper Update!")** client/server architecture (`M700`, `Revolver`, `Light Vest`). Built with a clean 7-tab **WindUI** menu (plus a built-in **Native PC/Mobile Touch GUI Fallback**) and a **clutter-free HUD**.

## ⚡ Quick Loadstring
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/reizure87-create/prison-life-script/main/PrisonLife.lua"))()
```

---

## 🛠️ What Was Fixed in v7.1 (From Delta Mobile Video Review + Bytecode Audit)

1. **Fixed Startup Crash Blocking Menu & HUD**:
   - Moved `Connections`, `CreatedInstances`, `HookedFunctions`, `AddConnection`, and `TrackInstance` *above* `MakeDraggable`, eliminating the `attempt to call global 'AddConnection' (a nil value)` crash at `⚡.combo1` that aborted startup before `⌘ CMD`, WindUI, and main loops loaded.
   - Hoisted `Core`, `Admin`, `UIRefs`, and `HoloShieldState` above all sections (preventing gunshot/Ragebot/`.loadout` crashes), added missing `local Stats = game:GetService("Stats")`, eliminated global `_` leaks, and verified **zero** accidental globals via `luajit -bl`.
2. **Guaranteed Menu Delivery & WindUI Mobile (`1600×720`) Fixes**:
   - Wrapped the entire WindUI initialization in `pcall` with automatic cleanup and guaranteed **Native Fallback UI** launch if WindUI ever fails to load or errors on mobile filesystems.
   - Held `UIRefs.IsSyncing = true` during WindUI widget creation so dropdowns don't overwrite `State` on startup, fixed `Core.SyncVisualUI()` to sync Dropdowns via `:Select()` and Toggles via `:Set(val, false)`, added `OnlyMobile = false` + `ToggleKey = RightShift`, raised WindUI `DisplayOrder = 100` above `OverlayGui`, selected Tab 1 by default (`Window:SelectTab(1)`), tuned mobile `MinSize`/`Size`/`SideBarWidth`, and added complete WindUI window teardown in `Env.PrisonLife2026Cleanup`.
3. **Stability & Capability Hardening**:
   - Added `SafeParentGui(gui)` (`gethui` -> `CoreGui` -> `PlayerGui` `pcall` probing), cut remote startup `WaitForChild` stall from `20s` down to `3s` with `ChildAdded` fallback, fixed multi-touch drag cancellation in `MakeDraggable`, fixed regular `Seat` (`~= nil`) Heartbeat crashes in `isDriving`/`EvaluateAnomalies`, replaced `getconnections()` proxy property mutation with weak `HookedClosureSet`, added per-run `RunToken` hook gating, guarded `Camera` & `CFrame.lookAt` NaN edge cases, and wrapped `GrabWeapons`/`RefillEmptyWeapons` locks in `pcall`.

---

## 🚀 Core v7.0 + v7.1 Features
- **Single Centralized Scheduler & `WorldCache`**: Event-driven `Cars`, `Doors`, `Fences`, `ArmorParts`, `Dropped`, `Players` (`App.CreateScope()`), and `Givers` caches (`0` per-frame `GetDescendants()` workspace scans).
- **4-Source `GunController` Hooks + 2026 Snipers**: Scans `ActionArea.InputBegan`, `UserInputService.InputBegan`, `CharacterAdded`, and `getgc` with `.rehook`, self-healing `BulletHookFiredCount` Raycast fallback, `SilentAimLead` ping compensation, `ActionArea`-centered synthetic firing, Weapon Kits (`Light`/`Sniper`/`Riot`/`Full`), `.refill`, `.target`/`.untarget`, and `.status`.
- **Anti-Hit Shield (`HoloShield`) & Defenses**: Pre-rotation `SavedCF`/`SavedVel` order (`CanQuery = false` across 3 `ShieldVisualStyle`s), `AntiCarBring` passenger-seat protection, `AntiFling`, `AntiTase`, `AntiArrest`, non-yielding `AutoArmor`, and per-target `AutoArrest`.
- **ESP, Mobile HUD & Commands**: 3px health bars, Guard-aware threat colors, dropped `ItemESP`, 30-Highlight LOD cap, drag-guarded `.combo1`/`⌘ CMD` pills, jump-adjacent Fly Pad, `TextChatService` + `Chatted` commands, and JSON config profiles (`PrisonLife2026Hub/profiles/<name>.json`).

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
