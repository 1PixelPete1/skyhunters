# Game Mechanics

---

### World & Atmosphere
**Definition**  
Procedural sky islands generated each round when the Sky Hub lands. Each round rolls for atmosphere (lighting preset) and a curse chance. Islands may include treasure and rare Points of Interest (POIs).

**Player verbs**
- Explore island for treasure/POIs.
- Traverse between POIs, gather loot.
- Respond to atmosphere (cursed or neutral).

**System behavior**
- Islands are constructed from low-poly meshes with capped part budgets.  
- Atmosphere = lighting/fog presets (Neutral, Overcast, Dusk, Cursed Gloom).  
- Weather (optional): light rain, mist, wind sway. Minimal particle budget.  
- Curse roll determines whether Shades spawn during the round.  

**Rewards / outputs**
- Treasure from POIs, consumables, cosmetics, currency.  
- Cursed rounds → access to Shades.  

**Constraints**
- No dynamic terrain; only prefabs + meshes.  
- Lighting presets applied once at round start; no per-frame changes.  
- Weather is always optional and scales off on low FPS clients.  

---

### Growth System (Looms)
**Definition**  
Core progression system. Player-placed looms are living structures that grow in styled segments. Growth directly fuels aether production and value.

**Player verbs**
- Place looms in their base.  
- Assign or mix growth profiles (straight, curved, zigzag, sigmoid, chaotic).  
- Apply buffs (Shades, shrine tokens, POI rewards).  
- Harvest output: aether, growth currency, cosmetics, rare seeds.  

**System behavior**
- Each loom has a base growth rate.  
- Growth profiles define segment count ranges, amplitude, frequency, curvature, zigzag cadence, etc.  
- RNG effects (segment count, size) are **always positive** → larger growth yields higher aether production/value.  
- Buffs stack additively within caps:  
  - Shades = temporary timed buffs (+X% growth).  
  - POIs/Shrines = permanent or timed minor boosts.  
- Visual growth is deterministic from seeds (stable on rebuild).  
- Decorations may spawn at rare intervals (MeshPart inserts).  

**Rewards / outputs**
- **Aether throughput** (core currency).  
- **Growth currency** (to unlock new profiles/depths).  
- **Seeds/cuttings** (rare → unlock new loom variants).  
- **Cosmetics** (visual drops tied to Shades).  

**Constraints**
- No negative RNG; growth always benefits the player.  
- Growth updates simulated client-side for visuals, server tracks timers.  
- Segments built from MeshParts or capped primitives (low perf impact).  
- Shadows disabled by default.  

---

### Shades
**Definition**  
Bouncing “soul” entities that spawn in cursed rounds. Cute ambient companions that offer buffs or treasure.

**Player verbs**
- Tend → Shade follows player for ~X seconds, then can be attached to a Loom.  
- Release → Shade disperses at Hub, triggering a treasure/cosmetic roll.  

**System behavior**
- Spawn cadence = curse intensity scaled.  
- Caps: per-player cap (M), global cap (N).  
- Idle lifetime ~100s if untended.  
- Animation is client-only (bobbing sin/cos seeded per ID).  
- Far distance (>120 studs) = impostor or hidden.  

**Rewards / outputs**
- Attached → Loom buff (+% growth speed/value, ~60–120s).  
- Released → % chance cosmetic, % chance treasure (loot table).  

**Constraints**
- Always positive: no debuff states.  
- Only spawn in cursed rounds.  
- No server-side AI; server owns spawn/state, client animates.  

---

### Crowds (Minions)
**Definition**  
Buyer NPCs that swarm under a player’s base to purchase aether. Flow like a “corner-shop” crowd: entering at one side of a triangular underside and exiting the other.

**Player verbs**
- Trigger crowd response by selling aether.  
- Observe cheering/celebration when sales occur.  

**System behavior**
- Spawn from portals at plot edges.  
- Move along **fan-shaped lane bundles** (3–5 lanes per side).  
- Lanes converge into a **corner plaza** under the base, then exit.  
- Spacing enforced by min distance `d_min` (2.5–3.5 studs).  
- Animation = seeded wobble/bob (sin/cos), slow yaw drift.  
- Confetti emitter at plaza; burst size scales with % of aether sold (nonlinear diminishing function).  

**Rewards / outputs**
- Visual feedback (crowd cheers + confetti).  
- Reinforces sell action as a milestone moment.  

**Constraints**
- Kinematic only (no Humanoid/Pathfinding).  
- Freeze or impostorize when player is topside or far.  
- Confetti capped per event; shared emitter only.  

---

### Economy (Aether)
**Definition**  
Core resource loop. Looms and producers generate aether over time. Selling at the hub triggers economy feedback.

**Player verbs**
- Collect aether.  
- Sell at hub.  
- Use proceeds for upgrades, growth unlocks, cosmetics.  

**System behavior**
- Producers tick at low Hz server-side.  
- Selling triggers crowd response + confetti burst.  
- Offline production exists: capped catch-up proportional to time away. Cap is tunable via config, not hard-coded.  

**Rewards / outputs**
- Currency for upgrades.  
- Growth progression (through loom size effects).  

**Constraints**
- RNG always positive; larger looms = higher aether.  
- No penalties for not selling promptly (storage cap may apply later).  
- Offline grant limited to cap to prevent runaway inflation.  

---

### Treasure & POIs
**Definition**  
Optional exploration layer. POIs and treasure caches spawn on islands, tied to rarity rolls.

**Player verbs**
- Discover POIs.  
- Solve small puzzles/mini-interactions (vaults, shrines).  
- Collect treasure rewards.  

**System behavior**
- Rarity tiers: common, uncommon, rare, mythic.  
- Dynamic POIs possible, but controlled so layout is structured.  
- POIs may grant shrine tokens, unique treasures, cosmetics, or new loom seeds.  

**Rewards / outputs**
- Aether bundles.  
- Rare growth currency.  
- Cosmetics (hats, loom skins, Shade trinkets).  
- Shrine tokens for permanent loom nudges.  

**Constraints**
- Always structured, not freeform procedural dungeons.  
- Limited part/mesh budget per island.  
- No heavy particle/post-processing tied to treasure.  
