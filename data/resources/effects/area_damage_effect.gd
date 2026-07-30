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
