# 🚔 Prison Life — Ultimate 2026 Script (PC & Mobile) [v3.0 KX Feature Edition]

Complete, anti-ban-hardened script for **Roblox Prison Life** (`PlaceId: 155615604`), combining the clean, modular **WindUI** architecture (plus a built-in **Native PC/Mobile Touch GUI Fallback**) with **all signature features from KX Admin v2/v3**.

## ⚡ Quick Loadstring
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/reizure87-create/prison-life-script/main/PrisonLife.lua"))()
```

---

## 🔥 What's New in v3.0 (All KX Admin Features Integrated Cleanly + Anti-Ban Safe Mode)

1. **4-Mode 3D Holographic Bullet Shield (`Hotkey: G` / `;shield`)**:
   - **4 Modes**: `Hybrid` (auto-equips server `RiotShieldPart` when owned + micro CFrame anti-aim desync fallback), `RiotOnly`, `DesyncBox` (3D OBB anti-aim jitter that restores before `RenderStepped` so your camera never shakes), and `FEGhost`.
   - **Auto-Face Shooter & Spin-Block**: Automatically rotates your shield barrier toward the nearest armed threat (`;autofaceshield`) or spins 360° (`;spinblock`).
   - **OBB Incoming Bullet Interception**: Calculates exact 3D oriented-bounding-box ray intersections on `GunTracers`, emitting neon ricochet sparks, metallic deflection SFX, and updating a live **180 HP Durability Bar** with out-of-combat recharge.
2. **`.combo1` Multi-Gun Burst Engine (`Hotkey: X` / Top-Left `.combo1` Button / `;combo1`)**:
   - Rapidly cycles through all owned loaded firearms (`Remington 870` -> `M700` -> `FAL` -> `M4A1` -> `AK-47` -> `Revolver` -> `MP5` -> `M9`) to burst-eliminate targets in one tap, with **Auto-Grab Guns**, **Continuous `.combo1` Loop**, and **Post-Burst Shield Re-Equip**.
3. **360° Ragebot, Wallbang Origin Scanner & Auto Armor Penetration (`Hotkey: B` / `;rage`)**:
   - **Wallbang Origin Scanner**: Scans a 10-directional origin ring plus `Enum.NormalId` corner peeks around thin cover, syncing the spoofed origin on the Luau call stack (`debug.setstack`).
   - **Auto Armor Penetration**: Automatically forces headshots whenever an enemy is wearing a ballistic vest (`Light Vest` / `Armor`) to bypass vest damage reduction.
   - **360° Ragebot**: Omnidirectional auto-lock and auto-fire with automatic loaded-weapon switching and **Ragebot Shield-Peek**.
4. **Combat VFX & Audio Suite**:
   - **3D Neon Bullet Tracers** (Cyan for Silent Aim, Crimson for Ragebot / `.combo1`), **4-Tick Animated Crosshair Hitmarker** (flashes red on headshots and kills), **Floating 3D Damage Numbers**, and **Hit / Headshot / Kill-Streak Sound Effects**.
5. **Guard, Prisoner & Target Automation**:
   - **Auto-Taze Aura** (`;autotaze`), **Auto-Arrest Aura** (`;autoarrest`), **Anti-Arrest** (`;antiarrest` — hooks `ClientArrested` connections), **Anti-Tase** (`;antitase` — hooks `PlayerTased` connections & purges stun tracks/BodyMovers), **ArrestAll** (`;arrestall`), **TaseAll** (`;taseall`), **KillAll** (`;killall`), **Persistent LoopKill List** (`;loopkill <plr>`), **Whitelists** (`;kawl` / `;aawl`), **Spectate/View** (`;view <plr>`), and **FE Car-Seat Bring** (`;bring <plr>`).
6. **Heuristic Cheater & Car-TP Anomaly Detector + Streak Killfeed**:
   - Multi-strike telemetry alerts when other players speedhack or snap into vehicles across the map (`Car-TP Alert` / `Cheater Alert`), plus live killstreak tracking with `[.combo1]` and `[RAGEBOT]` tags.
7. **Built-In Top-Right KX Command Bar (`;cmd [OK]`) & 90+ Commands**:
   - Supports semicolon-chained execution (`;guns;shield on;rage on`), live autocomplete dropdown suggestions, Roblox chat commands (`;cmd`), configuration presets (`;preset safe|legit|rage`), rejoin (`;rj`), and serverhop (`;shop`).

---

## ⌨️ Default PC Hotkeys
- **`RightShift`** — Toggle WindUI Hub Window
- **`G`** — Toggle 4-Mode 3D Holographic Bullet Shield
- **`X`** — Execute `.combo1` Multi-Gun Burst
- **`B`** — Toggle 360° Ragebot
- **`F`** — Toggle Character Fly
- **`N`** — Toggle Noclip
- **`;` (`Semicolon`)** — Focus Top-Right KX Command Bar
