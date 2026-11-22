# 🚔 Prison Life — Ultimate 2026 Script (PC & Mobile) [v4.0 Clean KX Pro Edition]

Complete, anti-ban-hardened script for **Roblox Prison Life** (`PlaceId: 155615604`), rebuilt cleanly for both **PC and Mobile** using a mobile-responsive **7-Tab WindUI Hub** (plus built-in Touch/PC Native Fallback UI) and verified **KX Admin** vehicle, combat, and protection mechanics.

## ⚡ Quick Loadstring
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/reizure87-create/prison-life-script/main/PrisonLife.lua"))()
```

---

## ✨ What's New & Fixed in v4.0 ("Clean KX Pro Edition")

1. **Clutter-Free Mobile & PC HUD**:
   - **Removed the messy right-side button dock** — only sleek, draggable top-left pills (`⚡ .combo1` and collapsible `⌘ CMD`) appear when in-game, plus contextual `▲` / `▼` Fly thumbs only while flying on mobile.
   - **Zero UI Overlaps**: The collapsible `⌘ CMD` pill never covers Prison Life's `Menu` button, Team shield icon, or `15/15` ammo counter.
   - **Clean Bottom Status Strip & Auto-Hide**: Shield HP and Arrest Cooldown bars sit neatly above the hotbar (never over your character) and automatically hide when dead or on the Teams intro screen.
   - **3-Line Transparent Mini-Killfeed**: Killfeed, Arrests, Cheater Alerts, and Car-TP Alerts render as a subtle top-left overlay instead of blocking your crosshair with toast popups.
2. **Fixed Guard Innocent-Kill Kicks**:
   - Lethal features (`Ragebot`, `AutoHvH`, `Silent Aim`, `.combo1`, `KillAura`) now strictly verify `Hostile == true` on Inmates when playing as a Guard — eliminating `"Do not kill innocent people!"` warnings.
   - Non-lethal `Auto-Arrest` and `Auto-Taze` skip seated players and only start the 7s arrest cooldown after a confirmed server arrest.
3. **Real 5-Mode 3D Holographic Bullet Shield & `ReplicateEvent` Interception (`B` / `;shield`)**:
   - Intercepts the late-2026 `GunRemotes.ReplicateEvent` payload for genuine incoming bullet sparks, ricochet SFX, and live 180 HP durability tracking.
   - **5 Dodge Modes**: `Hybrid`, `UndergroundPeek`, `DesyncBox`, `RiotOnly`, and `FEGhost` (restoring `SavedCF` before `RenderStepped` so your camera stays smooth).
4. **Signature KX Vehicle & Combat Mechanics**:
   - **Saved Cars Pool (`.savecar [1-5]` / `.sc`)**, **Force Criminal (`.fc <plr|all>`)**, **Bring (`.bring <plr>`)**, **Vehicle Void (`.void <plr>` / `.forcekick`)**, **Car Fling (`.fling <plr>`)**, and **Neon Wheel Aura (`.wheelaura`)**.
   - **`.autohvh` (`H`)**: Threat-prioritizing Hack-vs-Hack combat (returns fire on active attackers first with 360° Ragebot, Auto-Switch, Wallbang Scanner, and Peek Shield).
   - **Instant Weapon & Yard Grabber**: Grabs `Remington 870`, `AK-47`, `MP5`, `M9`, `M4A1`, `FAL`, `Riot Shield`, **`Hammer`** (`.hammer`), and **`Crude Knife`** (`.knife`).
5. **Clean FE Invisible (`V` / `;invis`) & 20-Region `RegionSafe` WalkSpeed**:
   - Uses clean `0.55` translucent character visibility without the distracting cyan Highlight glow, plus `IndoorSubRegions` + `PrisonOuterBox` safe WalkSpeed scaling and `Anti-Ban SafeMode` caps.

---

## ⌨️ Default PC Hotkeys & Top Commands
- **`RightShift`** — Toggle WindUI Hub
- **`G`** — Execute `.combo1` Multi-Gun Burst
- **`X`** — Toggle Silent Aim
- **`B`** — Toggle 5-Mode Holo-Shield (`Hybrid`)
- **`H`** — Toggle `AutoHvH` + 360° Ragebot
- **`F`** — Toggle Fly (or Vehicle Fly when seated)
- **`N`** — Toggle Noclip
- **`V`** — Toggle FE Invisible
- **`;` (`Semicolon`)** — Open & Focus `⌘ CMD` Command Bar (supports chaining like `;guns;shield on;autohvh`)

**Popular Commands (via `⌘ CMD` pill or chat `.` / `;`):**
- Combat & Gear: `.guns`, `.hammer`, `.knife`, `.combo1 [plr]`, `.autohvh`, `.rage`, `.silentaim`, `.wallbang`, `.shieldmode <mode>`, `.killaura`, `.hitbox [size]`, `.loopkill <plr>`
- Vehicles & KX Targets: `.savecar 2`, `.fc <plr>`, `.bring <plr>`, `.void <plr>`, `.fling <plr>`, `.wheelaura`, `.car`, `.carfly`
- Teams & Guard: `.guard`, `.inmate`, `.crim`, `.neutral`, `.re`, `.autoarrest`, `.autotaze`, `.arrestall`, `.taseall`, `.antitase`, `.antiarrest`, `.opendoors`, `.fencegod`
- Utility & Movement: `.fly`, `.speed [num]`, `.safespeed`, `.noclip`, `.invis`, `.goto <plr|loc>`, `.view <plr>`, `.esp`, `.preset <safe|legit|rage|hvh>`, `.rj`, `.shop`
