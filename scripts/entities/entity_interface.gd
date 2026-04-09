class_name EntityInterface
extends RefCounted
## Documents the interface that ALL entities (player, enemies, summons) must expose
## for the engine's component systems to function. This is not a base class —
## it's a contract. Both player.gd and enemy.gd must have these properties and methods.
##
## Required properties:
##   var faction: int              ## 0 = player/allies, 1 = enemies
##   var is_alive: bool            ## True while entity is active (false after death)
##   var is_attacking: bool        ## True during attack animations
##   var is_channeling: bool       ## True during channeled abilities
##   var is_invulnerable: bool     ## True during invulnerability windows
##   var is_untargetable: bool     ## True = excluded from spatial grid
##   var attack_target: Node2D     ## Current combat target (for aimed projectiles)
##   var last_hit_by: Node2D       ## Last entity that dealt damage
##   var last_hit_time: float      ## Run time of last damage taken
##   var _last_hit_time_by_tag: Dictionary  ## ability tag -> run_time
##   var talent_picks: Array[String]  ## Selected talent IDs (empty for enemies)
##   var combat_manager: Node2D    ## Back-reference set at spawn
##   var spatial_grid: SpatialGrid ## Back-reference set at spawn
##
## Required component references (child nodes or inline):
##   var health: HealthComponent
##   var modifier_component: ModifierComponent
##   var ability_component: AbilityComponent
##   var behavior_component: BehaviorComponent
##   var status_effect_component: StatusEffectComponent
##   var trigger_component: TriggerComponent
##
## Required node references:
##   var sprite: AnimatedSprite2D  ## For facing, VFX attachment, animations
##
## Required methods:
##   func take_damage(hit_data) -> void
##     Process incoming damage through HealthComponent, emit EventBus signals,
##     notify StatusEffectComponent for on_hit_received/on_hit_dealt effects.
##
## Optional properties (used by specific systems if present):
##   var summoner: Node2D          ## For summon entities — who summoned this
##   var _active_summons: Dictionary  ## For summoner entities — tracks living summons
##   var _overflow_damage_accumulator: float  ## For overflow chain tracking
##   var combat_role: String       ## "MELEE" or "RANGED" — for role-filtered targeting
