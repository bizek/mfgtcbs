class_name ProjectileConfig
extends Resource
## Configures how a single projectile behaves. Pure data.

# --- Motion ---
@export var motion_type: String = "directional"  ## "directional", "aimed", "homing"
@export var speed: float = 80.0                  ## Pixels/sec
@export var max_range: float = 0.0               ## Max travel distance (0 = screen bounds)
@export var arc_height: float = 0.0              ## Parabolic arc peak height (0 = straight line)

# --- Steering (seek + turn cap) ---
## Cap on how fast the heading may rotate, in DEGREES PER SECOND. 0 = uncapped, which is the
## legacy shape: a "homing" projectile re-points straight at its target every frame and is
## effectively unmissable. A FINITE rate turns a tracker into a *curving* projectile — it can be
## out-turned and outrun, so tracking becomes a feel nudge instead of an aimbot.
@export var homing_turn_rate: float = 0.0
## If > 0, a projectile carrying no target acquires one within this radius. Paired with a turn
## rate this is the "slight homing" shape: it flies where it was aimed and bends into whatever is
## roughly ahead. Deliberately works for "directional" motion too — such a projectile travels dead
## straight until it acquires, so an unaimed shot is still an unaimed shot.
@export var seek_radius: float = 0.0
## Half-angle (DEGREES) of the forward cone a seeking projectile may acquire within, measured off
## its current heading. Keeps a shot from whipping around onto something behind the shooter.
@export var seek_cone: float = 40.0

# --- Visual ---
@export var sprite_frames: SpriteFrames
@export var use_directional_anims: bool = true   ## true = pick anim from direction ("n","ne","e"...)
@export var animation: String = ""               ## Single anim name if not directional
@export var visual_scale: Vector2 = Vector2.ONE
@export var rotation_offset: float = 0.0   ## Sprite baseline correction in radians (e.g. -PI/2 if sprite points up)
@export var fallback_color: Color = Color(1.0, 0.5, 0.1, 0.9) ## Procedural circle color when no sprite_frames
## Multiplied over sprite_frames when drawn. WHITE = the sheet as authored (the default, so every
## existing projectile renders exactly as before). Used to re-colour ONE sheet per variant instead
## of shipping a sheet per variant — the Ranger's fire/frost arrowheads recolour her own arrow art.
## Channels may exceed 1.0 to read as heat rather than a wash.
@export var tint: Color = Color.WHITE

# --- Hit Detection ---
@export var hit_radius: float = 8.0              ## Distance at which a target is "hit"

# --- On-Hit Behavior ---
@export var pierce_count: int = 0                ## 0 = destroy on first hit, -1 = infinite
@export var on_hit_effects: Array = [] ## DealDamageEffect, ApplyStatusEffectData, etc.

# --- Ricochet (wall bounce) ---
@export var bounce_count: int = 0                ## Number of wall bounces (0 = none)

# --- On-Expire Behavior (split, etc.) ---
@export var on_expire_effects: Array = []        ## SpawnProjectilesEffect etc. fired when projectile expires or runs out of pierces

# --- Impact VFX (optional) ---
@export var impact_sprite_frames: SpriteFrames   ## One-shot VfxEffect on hit (null = none)
@export var impact_animation: String = ""

# --- Impact AOE (splash damage) ---
@export var impact_aoe_radius: float = 0.0       ## Splash radius around impact (0 = no splash)
@export var impact_aoe_effects: Array = []        ## Effects on splash targets

# --- Mod Combo Flags ---
## Phase Bolt (Pierce + Ricochet): pierce counter resets to full on each wall bounce
@export var pierce_resets_on_bounce: bool = false
## Base pierce count used for reset; set equal to pierce_count at build time
@export var pierce_count_base: int = 0

## Bouncing Grenade / Storm Breaker: fire impact_aoe at each wall bounce position
@export var explodes_on_bounce: bool = false

## Generic on-bounce AoE (Wildfire, Thunderball, Ricochet Razor, etc.): apply effects
## to enemies within on_bounce_aoe_radius of each bounce point
@export var on_bounce_aoe_radius: float = 0.0
@export var on_bounce_aoe_effects: Array = []

## Spiral Orbit (Gravity + Ricochet): re-acquire nearest enemy as homing target after each bounce
@export var re_home_after_bounce: bool = false

## Bloodhound (Gravity + DOT Applicator): prefer Bleeding targets when homing
@export var homing_prefers_bleeding: bool = false

## Ice Ball (Ricochet + Cryo): apply extra status stacks on any bounced hit
## Set bounced_hit_extra_apply to an ApplyStatusEffectData at build time
@export var bounced_hit_extra_apply: Resource = null  ## ApplyStatusEffectData
