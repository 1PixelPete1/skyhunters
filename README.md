# Wailing Winds
Scaffolded Roblox project with services, remotes, and content registry per the Wailing Winds architecture.

## Getting Started
To build the place from scratch, use:

```bash
rojo build -o "WailingWinds.rbxlx"
```

Next, open `WailingWinds.rbxlx` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

For more help, check out [the Rojo documentation](https://rojo.space/docs).

What’s included (M0):
- ReplicatedStorage: `Shared` (types, util), `ContentRegistry` (parts, upgrades), `Net/Remotes` (RF_/RE_ stubs)
- ServerScriptService: `Systems` service modules (Save, Plot, Placement, Validation, Aether* stubs, Economy, etc.) and server bootstrap wiring remotes
- StarterPlayer: client modules (`UIRouter`, `BuildClient`, `ThreadRender`, `ExpeditionClient`)
- ServerStorage: `ContentDB` and `IslandTemplates` placeholders

First run behavior:
- On join, a default profile is loaded, a plot is claimed, and the client receives `RE_BaseAssigned` with `{ plotId, origin, bounds }` and `RE_Balances` with `{ aether, crumbs, purity? }`.
- Remotes are wired per contract: `RF_ClaimPlot`, `RF_PlaceObject(req)`, `RF_MoveObject(req)`, `RF_RemoveObject(req)`, `RF_SellAether(req)`, `RF_StartExpedition(req)`.
