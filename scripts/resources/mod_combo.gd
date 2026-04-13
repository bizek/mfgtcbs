class_name ModCombo
extends Resource

enum ComboType {
	BEHAVIOR_BEHAVIOR,
	BEHAVIOR_ELEMENTAL,
	ELEMENTAL_ELEMENTAL,
	STAT_INTERACTION,
	TRIPLE_LEGENDARY
}

@export var combo_id: StringName
@export var combo_name: String
@export var required_mods: Array[StringName]
@export var description: String
@export var combo_type: ComboType
@export var is_authored: bool = true
@export var vfx_hint: String
@export var mastery_bonus: MasteryBonus
