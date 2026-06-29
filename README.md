# FadeWare

A custom Roblox Bedwars client based on the original Vape client by 7GrandDad.

## Loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/n7xRqLm4Wk9/fadeware/main/NewMainScript.lua", true))()
```

Paste this into your executor (Delta, etc.) while in any Roblox game.

## How It Works

- `NewMainScript.lua` (root) is the entry point - it downloads compiled files from `_compiled/` in this same repo
- `_compiled/` contains pre-compiled standalone Lua files (all source files concatenated per game)
- `src/` contains the original source code with separate module files

## Developer Mode

Set `shared.FadeWareDeveloper = true` before loading to use local files instead of downloading from GitHub.

## Features

### Blatant
- Killaura, Reach, HitBoxes, Speed, Fly, NoFall, NoSlowdown, LongJump, FastBreak, AutoBlock, KeepSprint, ProjectileAimbot, ProjectileAura, AntiFall

### Combat
- AimAssist, AutoClicker, TriggerBot, Velocity, NoClickDelay, Sprint, **HitboxExpander** (NEW)

### Legit
- Crosshair, FOV, FPSBoost, DamageIndicator, KillEffect, Viewmodel, CleanKit, HitFix, SoundChanger, **TexturePack** (NEW), **NoHurtAnimation** (NEW)

### Utility
- AutoBuy, AutoConsume, AutoHotbar, AutoBank, AutoPearl, AutoShoot, AutoToxic, AutoVoidDrop, AutoKit, AutoPlay, AutoBalloon, PickupRange, Scaffold, MissileTP, RavenTP, ShopTierBypass, StaffDetector, **AutoQueue** (NEW), **LowHealthAlert** (NEW), **AutoGapple** (NEW)

### Render
- NameTags, KitESP, StorageESP, BedESP, Health

### World
- AutoTool, BedProtector, ChestSteal, Schematica, AutoSuffocate, Anti-AFK

### Universal
- ESP, Xray, SilentAim, AutoRejoin, ServerHop, and more

## Credits
- Original Vape client by 7GrandDad
- Modified and rebranded as FadeWare
