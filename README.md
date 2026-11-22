# 🚔 Prison Life — Ultimate 2026 Script (PC & Mobile) [v4.0 Clean KX Pro Edition]

Complete, anti-ban-hardened script for **Roblox Prison Life** (`PlaceId: 155615604`), engineered specifically for the **Late 2026 ("Sniper Update!")** client/server architecture. Built with a clean 7-tab **WindUI** menu (plus a built-in **Native PC/Mobile Touch GUI Fallback**) and a **clutter-free HUD**.

## ⚡ Quick Loadstring
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/reizure87-create/prison-life-script/main/PrisonLife.lua"))()
```

---

## 🛠️ What Was Fixed & Added in v4.0 (From 10-Minute Gameplay Video Review + KX Research)

1. **Clutter-Free Mobile & PC HUD**:
   - **Removed the messy right-side button column** that overlapped in-game notifications and action controls.
   - **Collapsible Top-Right `⌘ CMD` Pill**: Sits cleanly below the top-right Menu button (never blocks the Menu or gun ammo counter) and expands into an autocomplete command bar when tapped (or on `;`).
   - **Non-Overlapping Bottom Status Strip**: Moved the **Shield Durability Bar** (`180/180`) and **Arrest Cooldown Bar** down just above your hotbar so nothing stacks over the center of your character.
   - **Transparent Top-Left Mini-Killfeed**: Replaced noisy WindUI killfeed toast popups with a clean 3-line fade-out killfeed & anomaly alert feed below the draggable `⚡ .combo1` pill.
   - **Contextual Fly Controls**: Circular `▲` / `▼` vertical flight buttons only appear when **Character Fly** or **Vehicle Fly** is active.
2. **Fixed Guard Innocent-Kill Warnings**:
   - Lethal combat (`Ragebot`, `AutoHvH`, `Silent Aim`, `.combo1`, `Kill Aura`) on the Guards team now strictly checks `Hostile == true` and **never shoots non-hostile or Trespassing-only Inmates**, eliminating `"Do not kill innocent people!"` warnings.
   - `Auto-Arrest` and `Auto-Taze` continue to target Criminals as well as `Hostile`, `Trespassing`, and `Tased` Inmates.
3. **5-Mode 3D Bullet Shield & Real Incoming Bullet Detection (`ReplicateEvent`)**:
   - **5 Protection Modes**: `Hybrid` (equips `RiotShieldPart` when owned + `UndergroundPeek` dodge when unequipped), `UndergroundPeek`, `DesyncBox` (anti-aim CFrame jitter restored before `RenderStepped` so your camera never shakes), `RiotOnly`, and `FEGhost`.
   - Hooked `ReplicatedStorage.GunRemotes.ReplicateEvent` so incoming enemy bullets genuinely trigger shield impact sparks, ricochet audio, and live 180 HP durability tracking.
   - Automatically hides Shield visuals and the HUD bar when dead or on the Intro/Teams menu.
4. **Fixed FE Invisible Outline & Safe Gun Grabber**:
   - Removed the stuck cyan `Highlight` outline from FE Invisible (`;invis`) and upgraded the zone-aware `#TouchGiver` / `GiverPressed` grabber so `Remington 870`, `AK-47`, `MP5`, `Hammer`, and `Crude Knife` can all be grabbed cleanly in one pass.
5. **Added Signature KX Admin Vehicle, HvH & Melee Commands**:
   - **`.savecar [1..5]`**: Saves unoccupied multi-seat cars into a reusable pool.
   - **`.forcecrim <plr|all>` / `.fc`**: Uses a saved vehicle seat to turn target Inmates Criminal cleanly.
   - **`.bring <plr>` / `.void <plr>` / `.forcekick <plr>` / `.fling <plr>`**: Improved FE vehicle-seat target manipulation with velocity lead prediction.
   - **`.autohvh` (`Hotkey: H`)**: Combines threat-prioritized 360° Ragebot, Auto-Switch, Bullet Shield, and Anti-Tase/Anti-Arrest.
   - **`.wheelaura`**: Adds neon particle trails to vehicle wheels while driving.
   - **`.hammer` / `.knife`**: Instant melee weapon grabbers.

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
