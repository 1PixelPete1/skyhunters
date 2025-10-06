# Socket Frame Positioning Fix

## Problems Fixed

### 1. Dual Spawn Handler Conflict
**Issue:** Two spawn handlers were running simultaneously:
- `DesignerSpawnHandler.server.luau` (old, legacy)
- `SpawnDesignerLantern.server.luau` (new, correct)

The old handler was spawning at incorrect locations first, causing positioning conflicts.

**Fix:** Disabled the old `DesignerSpawnHandler.server.luau` file.

### 2. Socket Attachments in Local Space
**Issue:** Socket attachments (S1, S2, Tip) were being created in local space instead of world space:
```
Branch 1: Start origin: 0, 7.104... (LOCAL SPACE - wrong!)
Branch 2: Start origin: 31.255..., 2.163..., -33.984... (WORLD SPACE - correct!)
```

**Root Cause:** The socket attachments were being created and parented to the pole model BEFORE the lantern was pivoted to its final position. This caused the world-space CFrames to be converted to local space.

**Fix in LanternFactory.luau:**

1. **Modified `buildPole` function** to return socket frames instead of creating attachments:
   - Changed return type from `Model` to `(Model, {[string]: FrameTransport.Frame})`
   - Removed socket attachment creation from buildPole

2. **Moved lantern pivoting BEFORE socket creation:**
   ```lua
   -- Build pole (no sockets yet)
   local pole, poleSockets = buildPole(samples, frames, 0.15, orientationMode)
   pole.Parent = lanternModel
   
   -- Pivot lantern to final position FIRST
   lanternModel:PivotTo(CFrame.new(position))
   
   -- NOW create sockets using WorldCFrame to maintain world positions
   for name, frame in pairs(poleSockets) do
       local attachment = Instance.new("Attachment")
       attachment.Name = name
       attachment.WorldCFrame = FrameTransport.cframeFrom(frame)
       attachment.Parent = pole
   end
   ```

3. **Result:** All socket attachments are now created at their correct world-space positions, allowing branches to connect properly to the pole at the intended locations.

## Why This Works

- **Before:** Sockets created → parented → lantern pivoted = sockets in local space
- **After:** Lantern pivoted → sockets created using WorldCFrame = sockets in world space

The key is using `attachment.WorldCFrame` instead of `attachment.CFrame` AFTER the parent model is already positioned. This maintains the world-space coordinates regardless of the parent's pivot.
