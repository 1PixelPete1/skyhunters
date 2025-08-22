# LoomDesigner Command Bar Guide

This guide outlines how to access the plugin's `Main` module from the Roblox Studio command bar and use its authoring APIs.

## Accessing the `Main` Module

1. In Roblox Studio, open **View → Command Bar**.
2. Reference the plugin folder and load the module:

```lua
-- Require the plugin folder (init.lua delegates to Main)

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

### Additional Controls

The UI exposes fields for base seed, segment count, and rotation rules. These can also be driven from the command bar:

```lua
-- Set deterministic seed used by the preview
LD.SetSeed(12345)

-- Override the number of segments rendered in the preview
local GSC = require(pluginFolder.GrowthStylesCore)
GSC.SetParam("segmentCount", 12)

-- Choose how segment rotations accumulate ("accumulate" or "absolute")
LD.SetRotationContinuity("absolute")
```

These snippets can be run directly from the command bar for quick iteration without opening the plugin UI.

## Plugin UI Branch Creation

The plugin's UI hides authoring controls until a branch is chosen. Use **Add Branch** to create a branch while staying in the current mode, or **New Branch + Author** to create a branch and immediately switch into authoring mode for it. When no branches exist, the first one you create is selected automatically.

