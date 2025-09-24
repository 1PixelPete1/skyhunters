-- DirectCleanupTest.server.luau
-- Simple script to directly test the cleanup system

local SkyIslandCleanupEnhanced = require(script.Parent.Worldgen.SkyIslandCleanupEnhanced)

print("===== DIRECT CLEANUP TEST =====")
print("Testing cleanup system directly...")

-- Test with no config (should use defaults)
local stats = SkyIslandCleanupEnhanced.cleanupAll()

print("Direct test complete!")
print("Stats returned:", stats)
print("Tagged models:", stats.taggedModels)
print("Terrain chunks:", stats.terrainChunks)