--!strict
-- LoomDesigner plugin scaffold. This minimal plugin exposes a DockWidget with a
-- seed field and growth slider. The real tooling will expand on this skeleton.
-- The code is written so it can be required as a ModuleScript during tests but
-- expects to run as a Plugin when used in Roblox Studio.

local LoomDesigner = {}

function LoomDesigner.Start(plugin)
    -- In Studio this would create a DockWidgetPluginGui. Here we simply note that
    -- the plugin started. The actual UI and preview behaviour is left as a TODO.
    print("LoomDesigner plugin started", plugin)
end

return LoomDesigner
