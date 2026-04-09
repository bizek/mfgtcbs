class_name StatusEffectDefinition
extends Resource
## Defines a status effect type. Applied via StatusEffectComponent at runtime.
## Modifiers are registered while active, scaled by current stacks.

@export var status_id: String = ""                      ## "Burn", "Frozen", etc.
@export var tags: Array[String] = []                    ## For immunity checks (Negate modifier)
@export var is_positive: bool = true                    ## Buff vs debuff (for cleanse targeting)
@export var max_stacks: int = 1                         ## Per-type cap
@export var base_duration: float = 5.0                  ## Seconds (-1 for permanent/until consumed)
@export var tick_interval: float = 0.0                  ## Periodic effect interval (0 = no ticking)
@export var tick_effects: Array[Resource] = []           ## Effects fired each tick
@export var on_apply_effects: Array[Resource] = []       ## Effects on first application
@export var on_expire_effects: Array[Resource] = []      ## Effects when duration ends naturally
@export var on_consume_effects: Array[Resource] = []     ## Effects when consumed by another ability
@export var on_hit_received_effects: Array[Resource] = [] ## Effects when entity is hit while this status is active
@export var on_hit_received_damage_filter: Array[String] = [] ## If non-empty, on_hit_received_effects only fire for these damage types
@export var on_hit_dealt_effects: Array[Resource] = []    ## Effects when status-bearing entity deals a hit
@export var modifiers: Array[Resource] = []              ## ModifierDefinitions applied while active
@export var disables_actions: bool = false               ## True = entity cannot act or move (Stun, Freeze, etc.)
@export var disables_movement: bool = false              ## True = entity cannot move but can still act (Root)
@export var movement_override: String = ""               ## Movement behavior override while active (e.g. "flee")
@export var curse_damage_type: String = ""                 ## Non-empty = healing inversion curse
@export var prevents_death: bool = false                   ## When true, prevents lethal damage (HP set to 1)
@export var on_death_prevented_effects: Array[Resource] = [] ## Effects fired when this status prevents death
@export var duration_refresh_mode: String = "overwrite"    ## "overwrite" or "max"
@export var shield_on_hit_absorbed_percent: float = 0.0    ## > 0 = gain Shield equal to this % of DR-mitigated damage
@export var shield_cap_percent_max_hp: float = 0.0         ## > 0 = Shield from this effect capped at this % of max HP
@export var aura_radius: float = 0.0                      ## > 0 = this status is an aura; proximity query range
@export var aura_target_faction: String = ""               ## "enemy" or "ally"
@export var aura_tick_effects: Array[Resource] = []        ## Effects dispatched to each entity in range per tick
@export var vfx_layers: Array = []                       ## VfxLayerConfig entries for looping status VFX
@export var on_stack_vfx_layers: Array = []              ## VfxLayerConfig entries for one-shot VFX on application
@export var grants_taunt: bool = false                    ## True = enemies prioritize targeting this entity
@export var taunt_radius: float = 0.0                     ## Range for taunt targeting override
@export var thorns_percent: float = 0.0                   ## > 0 = reflect this fraction of damage received
@export var targeting_count_threshold: int = 0            ## > 0 = apply targeting_count_status when N+ enemies target bearer
@export var targeting_count_status: Resource = null        ## StatusEffectDefinition applied when threshold met
@export var trigger_listeners: Array[Resource] = []      ## TriggerListenerDefinitions registered while active
