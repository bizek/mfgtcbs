class_name CharacterDefinition
extends Resource
## Defines a playable character. Pure data — the framework interprets it.
## Equivalent to ClassDefinition in the source engine, adapted for single-character play.

@export var character_id: String = ""                  ## "The Drifter", "Scavenger", etc.
@export var tags: Array[String] = []                   ## ["Human", "Armed"]

@export var auto_attack: AbilityDefinition             ## Implicit weapon attack
@export var skills: Array[SkillDefinition] = []        ## Active abilities
@export var talent_tree: TalentTreeDefinition          ## Talent tree structure
@export var passive_status: StatusEffectDefinition     ## Character passive as a permanent status

## Sprite/animation references
@export var sprite_sheet: SpriteFrames
@export var hit_frame: int = 3                         ## Attack frame where damage fires

## Combat defaults
@export var base_stats: Dictionary = {}                ## {"max_hp": 100.0, "damage": 18.0, "armor": 0.0, ...}
@export var move_speed: float = 200.0
