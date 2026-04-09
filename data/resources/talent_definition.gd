class_name TalentDefinition
extends Resource
## A single talent node. Same field pattern as StatusEffectDefinition —
## direct arrays of existing primitives, not a wrapper type.

@export var talent_id: String = ""
@export var talent_name: String = ""
@export var description: String = ""
@export var branch: String = ""              ## "intro", "a", "b"
@export var tier: int = 0                    ## 0 (intro), 1-3 (branch), 4 (capstone)

## What this talent does — same building blocks as items/statuses
@export var modifiers: Array[Resource] = []                  ## ModifierDefinitions
@export var trigger_listeners: Array[Resource] = []          ## TriggerListenerDefinitions
@export var ability_modifications: Array[Resource] = []      ## AbilityModifications
@export var apply_statuses: Array[Resource] = []             ## ApplyStatusEffectData (applied at entity setup)

## Capstone-specific
@export var unlocks_skill_id: String = ""    ## ability_id of the ultimate this capstone unlocks
