# LoomDesigner Command Bar Guide

This guide outlines how to access the plugin's `Main` module from the Roblox Studio command bar and use its authoring APIs.

## Accessing the `Main` Module

1. In Roblox Studio, open **View → Command Bar**.
2. Load the module:

```lua
-- Require the plugin's Main module
local LD = require(game:GetService("ServerScriptService"):WaitForChild("LoomDesigner"):WaitForChild("Main"))
```

The `LD` table now exposes the plugin's authoring functions.

## Examples

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

