# Model Catalog

This directory contains .rbxm model files that can be spawned by the SkyIslandGenerator.

## Bridge Models

Currently supported:
- `bridge_pone_1.rbxm` - Basic wooden bridge plank

## Usage

The SkyIslandGenerator will automatically load models from this directory based on the configuration in ModelRegistry.luau.

## Adding New Models

1. Create your model in Roblox Studio
2. Export it as a .rbxm file
3. Place it in this directory
4. Update ModelRegistry.luau to include the model with its spawn weight

Note: All models should be anchored and ready for placement.
