# Agent Configuration - Skyhunters

## Commands
- **Build**: `rojo build -o "skyhunters.rbxlx"`
- **Start dev server**: `rojo serve`
- **Run tests**: `lua spec/economy_spec.lua` (manual test runner)
- **Install tools**: `aftman install`

## Architecture
- **Roblox game** built with Rojo for syncing code to Roblox Studio
- **Client-Server architecture**: client/, server/, shared/ folders
- **Main modules**: Economy (currency/items), Config (game data)
- **Testing**: Basic Lua tests in spec/ folder using assert statements

## Code Style
- **Language**: Luau (Roblox Lua dialect)
- **File extension**: .luau
- **Imports**: Use require() with module names or script paths
- **Error handling**: pcall() for safe require(), return false/nil for failures
- **Naming**: camelCase for functions, snake_case for item IDs
- **Module pattern**: Return table with public functions
- **Rate limiting**: Built into economy functions with time-based checks
- **Data validation**: Whitelist-based validation for sensitive operations
