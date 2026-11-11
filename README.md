# 🚔 Prison Life — Ultimate 2026 Script (PC & Mobile)

Complete, up-to-date script for **Roblox Prison Life** (`PlaceId: 155615604`), engineered specifically for the **Late 2026 ("Sniper Update!")** client/server architecture. Built with **WindUI** for full **PC and Mobile** compatibility.

## ⚡ Quick Loadstring
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/reizure87-create/prison-life-script/main/PrisonLife.lua"))()
```

## 🔥 2026 Architecture & Features

### 1. Combat & Aiming (`ActionArea` / `GunController` Hooks)
- **Silent Aim (`pl.Bullet` Hook)**: Hooks the 2026 `GunController` bullet function via `PlayerGui.Home.hud.ActionArea.InputBegan` upvalues to redirect bullets directly to the target (`Head`, `HumanoidRootPart`, or `Torso`) with zero spread, configurable Hit Chance, FOV Circle, Wallcheck, and **Guard Safe Mode** (automatically ignores innocent Inmates unless they have `Hostile` or `Trespassing` attributes).
- **Smooth Camera Aim Assist**: Works with both PC Mouse and Mobile Touch controls, including velocity prediction.
- **Triggerbot / Auto-Shoot**: Automatically fires via `pl.Shoot` upvalue when a valid target enters your FOV and auto-reloads via `pl.Reload`.
- **Anti-Riot Shield**: Sets `CanQuery = false` on enemy `RiotShieldPart` instances so your bullets pierce straight through Riot Shields.
- **Melee Kill Aura & Hitbox Expander**: Uses `ReplicatedStorage.meleeEvent:FireServer(target, 1, 1)` with Guard Safe checks and customizable enemy hitbox expansion.

### 2. Weapons & 2026 Gun Mods
- **Instant Gun Grabber (`GiverPressed` + `#TouchGiver`)**: Seamlessly grabs `Remington 870`, `AK-47`, and `MP5` using the 2026 `ReplicatedStorage.Remotes.GiverPressed` remote and `RenderStepped` CFrame restoration (no screen flicker).
- **Auto Grab Guns on Respawn** & **Auto Pickup Dropped Keycards/Weapons**.
- **2026 Gun Attribute Mods**: Modifies live tool attributes (`FireRate`, `SpreadRadius = 0`, `AutoFire = true`, `Range = 9999`) on all firearms (`M9`, `Remington 870`, `AK-47`, `MP5`, `M4A1`, `FAL`, `M700` Sniper, `Revolver`).
- **Auto Heal & Auto Armor**: Uses `ReplicatedStorage.Remotes.EatFood` with cafeteria food (`Breakfast`, `Lunch`, `Dinner`) and `InteractWithItem` on armor stands.
- **Floating Mobile Action Bar**: Quick on-screen tap buttons for **⚡ Fast Switch**, **🔫 Grab Guns**, and **👻 FE Invisible**.

### 3. Prison, Guards & Teams
- **Instant Team Switcher**: Uses `ReplicatedStorage.Remotes.RequestTeamChange:InvokeServer(Team, 1)` for `Inmates`, `Guards`, and `Neutral`, plus instant Criminal conversion.
- **Auto Arrest Aura**: Invokes `ReplicatedStorage.Remotes.ArrestPlayer:InvokeServer(player, 1)` on nearby Criminals and `Hostile`/`Trespassing`/`Tased` Inmates with a live 7-second cooldown bar.
- **Anti-Tase & Always Enable Backpack**: Hooks `ReplicatedStorage.GunRemotes.PlayerTased` to cancel tase animations (`279227693` / `279229192`), restore `WalkSpeed`/`JumpHeight`, and lock `BackpackEnabled = true`.
- **Auto Criminal on Arrest**: Listens to `ReplicatedStorage.Remotes.ClientArrested` and teleports you back to Criminal Base as soon as the 4-second arrest teleport completes.
- **Fast Respawn (`<1s`)**: Uses the `Neutral` -> `Team` swap trick and returns you to your exact death CFrame.
- **Electric Fence Godmode & Open All Doors**: Disables `CanTouch` on `Prison_Fences` touch transmitters and strips collisions on `workspace.Doors`.

### 4. Vehicles, Movement & Visuals
- **Remote Car Spawner**: Invokes `ReplicatedStorage.Remotes.InteractWithItem` on the nearest `Car Spawner` button and seats you in the spawned vehicle.
- **PC & Mobile Vehicle Fly**: Full 3D car flight controlled by your **Mobile Touch Thumbstick + ▲/▼ Fly Buttons** or **PC WASD + Space/Ctrl**, plus **Vehicle Speed Multiplier**.
- **Serverside FE Invisible & Anti-Invisible**: Uses the R6 (`215384594`) / R15 (`18665825805`) underground animation freeze with a client ghost highlight, plus an Anti-Invisible stripper to reveal invisible exploiters.
- **Anti-Fling**: Neutralizes `workspace.CarContainer` collisions so car-fling exploiters cannot fling you.
- **Region-Safe MaxSpeed & Anti-Cheat Noclip**: Adapts velocity to indoor (`34`), yard (`48`), and city (`85`) anti-cheat bounds, destroys `ReplicatedStorage.Scripts.CharacterCollision`, and disables `AntiJump`.
- **Role-Colored ESP & 15+ Teleports**: Team-colored highlights, nametags, live `[HOSTILE]` / `[TRESPASS]` / `[TASED]` status flags, health, distance, equipped weapon, and 15 preset teleports + Teleport Behind Player.
