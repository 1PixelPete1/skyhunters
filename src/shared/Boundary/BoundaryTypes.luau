--!strict
-- Type-only definitions for unified boundary data structures

export type BoundaryNode = {
    id: string,
    posXZ: Vector2,
    radius: number,
}

export type BoundaryEdge = {
    id: string,
    a: string, -- node id
    b: string, -- node id
    path: { Vector2 },
    width: number,
}

export type BoundaryGraph = {
    version: number,
    nodes: { [string]: BoundaryNode },
    edges: { [string]: BoundaryEdge },
}

export type Polyline = {
    id: string,
    pts: { Vector2 },
}

export type PolylineSoup = {
    version: number,
    polylines: { Polyline },
}

return {}

