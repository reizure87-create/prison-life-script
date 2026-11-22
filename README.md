# 🚔 Prison Life — Ultimate 2026 Script (PC & Mobile) [v4.0 Clean KX Pro Edition]

Clean, anti-ban-hardened script for **Roblox Prison Life** (`PlaceId: 155615604`), engineered from the late-2026 game dump and verified against KX Admin's signature mechanics — featuring a clutter-free Mobile & PC HUD with zero screen bloat.

## ⚡ Quick Loadstring
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/reizure87-create/prison-life-script/main/PrisonLife.lua"))()
```

---

## 🛠️ What's Fixed & Upgraded in v4.0

### 1. Clean Clutter-Free HUD (Mobile & PC)
- **Removed the right-side button stack completely** so your aiming/thumbstick space stays wide open.
- **Collapsible Draggable `⌘ CMD` Pill**: Sits cleanly in the top-right (`⌘ CMD`) without overlapping the Menu or Ammo counter; expands into a quick command bar when tapped (or pressing `;` on PC).
- **Non-Overlapping Bottom Status Strip**: Shield Durability (`180/180`) and Arrest Cooldown bars now sit neatly above your hotbar instead of covering your character or Teams menu.
- **Transparent 3-Line Mini-Killfeed**: Replaced noisy WindUI killfeed toast popups with a sleek 3-line transparent feed below `.combo1`.
- **Contextual Fly Pad**: Circular `▲` / `▼` Fly buttons stay completely hidden until **Character Fly** or **Vehicle Fly** is active.

### 2. Critical Bugfixes from Gameplay Review
- **Fixed Guard Innocent-Kill Warnings**: Lethal combat (`Ragebot`, `AutoHvH`, `Silent Aim`, `.combo1`, `KillAura`) on the **Guards** team now strictly targets `Hostile == true` inmates (never `Trespassing`-only inmates), eliminating *"Do not kill innocent people!"* warnings/kicks while keeping `Auto-Arrest` and `Auto-Taze` active on both.
- **Fixed 3D Bullet Shield & Auto-Hide**: Hooked `ReplicatedStorage.GunRemotes.ReplicateEvent` so incoming enemy bullets trigger real shield deflection sparks, ricochet SFX, and `180 HP` durability decay. Shield visuals and HUD bars now hide automatically on the Intro/Teams menu and while dead.
- **Fixed FE Invisible Stuck Outline**: Removed the persistent cyan Highlight outline that stayed stuck on your avatar in v3.0.
- **Fixed Safe Multi-Zone Gun Grabber**: Reliably grabs `Remington 870`, `AK-47`, `MP5`, `M9`, `M4A1`, `FAL`, `Riot Shield`, `Hammer`, and `Crude Knife` in one clean pass without 60Hz jitter.

### 3. Signature KX Admin Features Integrated
- **`5-Mode` 3D Bullet Shield (`G` / `.shield`)**: `Hybrid`, `UndergroundPeek` (drops CFrame underground on `Heartbeat` and restores before `RenderStepped`), `DesyncBox`, `RiotOnly`, and `FEGhost`.
- **`.autohvh` (`Hotkey: H`)**: Armed-threat priority + `AutoArmorPen` headshots + `Wallbang` origin scanner + `UndergroundPeek` shooting + auto-switch.
- **`.savecar [n]` + KX Car Actions**: Save multi-seat vehicles in `CarContainer` and run `.forcecrim <plr|all>`, `.bring <plr>`, `.void <plr>` / `.forcekick`, and `.fling <plr>`.
- **`.combo1` (`Hotkey: X`) & `.wheelaura`**: One-tap multi-gun burst across loaded weapons + neon wheel particle auras.
- **Complete `.` & `;` Command Support**: Type `.savecar 2; .autohvh` or chat commands (`LocalPlayer.Chatted`).

---

## ⌨️ Default PC Hotkeys
- **`G`** — Toggle 3D Bullet Shield / FE Bullet Dodge
- **`X`** — Execute `.combo1` Multi-Gun Burst
- **`B`** — Toggle 360° Ragebot
- **`H`** — Toggle AutoHvH Mode
- **`F`** — Toggle Character Fly
- **`N`** — Toggle Noclip
- **`;` (`Semicolon`)** — Open Top-Right `⌘ CMD` Command Bar
