class_name SkillDefinition
extends Resource
## A skill slot entry — wraps an AbilityDefinition with unlock level info.

@export var skill_name: String = ""
@export var unlock_level: int = 1          ## Level at which this skill becomes available
@export var is_ultimate: bool = false      ## True for capstone skill
@export var ability: AbilityDefinition
