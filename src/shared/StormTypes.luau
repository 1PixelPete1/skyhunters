--!strict
-- Shared type definitions for storm system (pure; no side effects)

export type GustEvent = {
    t: number,
    dur: number,
    mult: number,
}

export type StormProfile = "RAIN_HEAVY" | "RAIN_LIGHT" | "SNOW" | "DUST"

export type StormState = {
    vector: Vector3,
    profile: StormProfile,
    intensity: number,
    gusts: { GustEvent },
}

export type PerfTier = "HIGH" | "MED" | "LOW"

export type ForbiddenAzimuth = {
    minDeg: number,
    maxDeg: number,
}

export type ConePose = {
    origin: Vector3,
    dir: Vector3,
    halfAngleDeg: number,
    innerClear: number,
    innerSoft: number,
    outerSoft: number,
}

export type PerfConfig = {
    beamsRingCount: number,
    beamsPerRing: number,
    shells: number,
    shellSegs: number,
    overlays: boolean,
    splashes: boolean,
    dropsMax: number,
    dropsRatePerSec: number,
    dropSpawnRateMultiplier: number,
    splashRate: number,
    gustsMax: number,
    fogLayers: number,
    distantSheets: number,
}

return {}
