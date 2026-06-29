# Contributing to FadeWare

## Development Setup

1. Clone the repository
2. Use `shared.FadeWareDeveloper = true` when loading to use local files
3. The client will read from the `fadeware/` folder instead of downloading from GitHub

## Structure

- `src/main.lua` - Main entry point
- `src/loader.lua` - File loader and cache manager
- `src/games/` - Game-specific modules
  - `universal - base/` - Universal modules (work in all games)
  - `bedwars/` - Bedwars-specific modules
- `src/guis/` - GUI themes
- `src/libraries/` - Shared libraries (entity, prediction, hash, etc.)

## Adding New Modules

1. Create a new `.lua` file in the appropriate category folder
2. Use the `vape.Categories.X:CreateModule()` pattern
3. Test with `shared.FadeWareDeveloper = true`
