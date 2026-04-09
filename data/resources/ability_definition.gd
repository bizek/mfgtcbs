class_name AbilityDefinition
extends Resource
## Defines an ability: targeting + conditions + effects.
## Abilities are data — the framework interprets them.

@export var ability_id: String = ""
@export var ability_name: String = ""
@export var tags: Array[String] = []                   ## ["Melee", "Attack", "AOE", "Fire"]
@export var targeting: TargetingRule                    ## How to select targets
@export var cooldown_base: float = 0.0                 ## Seconds (0 = no cooldown)
@export var mode: String = "Auto"                      ## "Auto", "Manual", "Conditional", "Toggle"
@export var conditions: Array[Resource] = []           ## Typed condition sub-resources
@export var effects: Array = []                        ## Typed effect sub-resources (DealDamageEffect, etc.)
@export var priority: int = 0                          ## AI priority ranking (higher = preferred)
@export var cast_range: float = 0.0                    ## Must be within this distance to cast (0 = no proximity requirement)
@export var hit_frames: Array[int] = []                ## Multi-hit: fire effects on each listed frame
@export var vfx_frame: int = 3                         ## Animation frame to spawn VFX (-1 = no VFX)
@export var anim_override: String = ""                 ## Custom attack animation ("" = use default "attack")
@export var hit_frame_override: int = -1               ## Custom hit frame for this ability (-1 = use entity default)
@export var vfx_layers: Array = []                      ## VfxLayerConfig entries for one-shot VFX on caster
@export var target_vfx_layers: Array = []               ## VfxLayerConfig entries for one-shot VFX on targets
@export var hit_targeting: TargetingRule                  ## Optional: wider targeting for hit-frame damage (null = use targeting)
@export var anim_on_complete: String = ""                 ## Follow-up animation after anim_override finishes
@export var grants_invulnerability: bool = false          ## Entity is invulnerable during entire animation
@export var resource_cost_status_id: String = ""               ## Status ID whose stacks are consumed to cast
@export var resource_cost_amount: int = 0                      ## Number of stacks consumed on cast
@export var choreography: ChoreographyDefinition             ## Multi-phase sequence config (null = standard ability)
