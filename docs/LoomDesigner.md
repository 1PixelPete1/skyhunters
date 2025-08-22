# LoomDesigner Command Bar Guide

This guide outlines how to access the plugin's `Main` module from the Roblox Studio command bar and use its authoring APIs.

## Accessing the `Main` Module

1. In Roblox Studio, open **View → Command Bar**.
2. Reference the plugin folder and load the module:

```lua
-- Require the plugin's Main module
local pluginFolder = plugin:WaitForChild("LoomDesigner")
local LD = require(pluginFolder)

-- Initialize authoring state (creates default branch1)
LD.Start(plugin)
```

The `LD` table now exposes the plugin's authoring functions. `Start` must be called once before creating or editing branches so the default profile exists.

## Examples

All snippets assume `LD.Start(plugin)` has already been executed.

### CreateBranch
Create a new branch profile:
```lua
LD.CreateBranch("branch1", { kind = "straight" })
```

### EditBranch
Patch an existing branch:
```lua
LD.EditBranch("branch1", { kind = "curved" })
```

### AddChild
Attach a child branch to a parent:
```lua
LD.AddChild("branch1", "child1", "tip", 1)
```

### RebuildPreview
Render the current authoring state in the workspace:
```lua
LD.RebuildPreview()
```

These snippets can be run directly from the command bar for quick iteration without opening the plugin UI.

