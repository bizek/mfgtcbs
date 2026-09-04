class_name AreaDamageEffect
extends Resource
## Effect sub-resource: deal damage to all enemies within a radius of the target's position.
## Full damage pipeline (DamageCalculator) runs per target — not raw/flat damage.

@export var damage_type: String = "Physical"
@export var scaling_attribute: String = ""      ## Modifier tag to scale from ("" = no scaling)
@export var scaling_coefficient: float = 1.0
@export var base_damage: float = 1.0
@export var aoe_radius: float = 20.0
## Push the hit circle this far along the SOURCE's aim direction instead of centring it on the
## target (0 = centred, the old behaviour every other effect still uses).
## Why this exists: a melee node whose art is a wave LEAVING the character read wrong as a circle
## centred on them — Shield Bash hit as hard behind the Warden as in front, no matter how accurately
## the wave pointed at the cursor (Ben 2026-07-29). Offsetting is the cheap honest fix: it's the same
## SpatialGrid query from a point further out, so nothing about the shape math changes.
## Only sources that expose get_aim_direction() are offset — enemies have no aim, so they ignore it.
## Geometry: forward reach = offset + radius · rear reach = radius - offset · half-width at the
## caster = sqrt(radius^2 - offset^2). Keep offset < radius or the caster's own position falls
## outside its hit zone and enemies hugging them are missed entirely.
@export var aoe_forward_offset: float = 0.0
## Optional per-hit effects executed on each enemy this AoE damages (e.g. Galvanized Bleed spread).
@export var on_hit_effects: Array = []

## ── Making the hit visible (2026-08-26) ──────────────────────────────────────────────────────
## This effect had NO visual channel of its own for its entire existence: it is a SpatialGrid
## query plus a DealDamageEffect per target, so the only thing a player ever saw was damage
## numbers appearing on enemies. Anything whose whole identity IS the AoE was therefore invisible —
## the Fighter's Thunderclap and Spite shipped blind on 2026-08-24, and Volatile Remains had been
## detonating corpses unseen since 2026-08-03. StatusFactory's own cinder_skin comment had already
## named the failure mode ("an invisible damage ring would be a guessing game") and this is the
## same bug one layer down.
##
## Opt-in rather than on by default: plenty of AoEs are the tail of an ability that already draws
## its own art (Cataclysm, Brimstone Circle), and a second ring on top of those would be noise.
@export var vfx_shockwave: bool = false
## Ring colour. Default is the same orange every other shockwave in the game uses
## (player._spawn_shockwave_ring), so an AoE that opts in looks native rather than bolted on.
@export var vfx_color: Color = Color(1.0, 0.55, 0.10, 0.9)
