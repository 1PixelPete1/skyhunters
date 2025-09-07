--!strict
-- Shared types for Pond Network v1 (placed under Shared to avoid colliding with existing Types module)

export type PondId = string
export type LakeId = string

export type Pond = {
    id: PondId,
    pos: Vector2,   -- world XZ
    radius: number,
}

export type Lake = {
    id: LakeId,
    a: PondId,
    b: PondId,
    path: { Vector2 }, -- sampled centerline in XZ
    width: number,     -- half-width
}

export type Snapshot = {
    version: number,
    ponds: { [PondId]: Pond },
    lakes: { [LakeId]: Lake },
}

return {}

