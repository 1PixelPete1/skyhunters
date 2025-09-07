--!strict

-- Stable type aliases used by both client and server.
local Types = {}

-- Contract-level types
export type Balances = { aether: number, crumbs: number, purity: number? }

export type PlacementRequest = {
    partId: string,
    pos: Vector3,
    rot: Vector3?,
    variant: string?,
    attachments: { [string]: string }?,
}

export type MoveRequest = { objectId: string, pos: Vector3, rot: Vector3? }
export type RemoveRequest = { objectId: string }
export type SellRequest = { mode: string, amount: number? }

export type ThreadSnapshot = {
    nodes: { any },
    edges: { any },
    guides: { any },
}

export type AABB = { min: Vector3, max: Vector3 }
export type PlotAssignment = { plotId: string, origin: CFrame, bounds: AABB }

-- Save-profile level types (internal)
export type Inventory = { [string]: number }
export type Upgrades = { [string]: boolean }

export type PlacementRecord = {
    id: string,
    partId: string,
    cframe: CFrame,
    metadata: any,
}

export type CollectorRecord = {
    id: string,
    kind: string,
    cframe: CFrame,
    params: any,
}

export type BaseState = {
    plotLocalOrigin: CFrame?,
    placements: { PlacementRecord },
    collectors: { CollectorRecord },
    threadsCache: any?,
    baselineIncome: number,
}

export type PlayerProfile = {
    __schemaVersion: number?,
    userId: number,
    balances: Balances,
    inventory: Inventory,
    upgrades: Upgrades,
    baseState: BaseState,
    lantern: any?,
    lastSeen: number,
    baselineAtLogout: number,
    version: number,
}

return Types
