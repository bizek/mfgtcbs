class_name CodexEntry
extends Resource

@export var combo: ModCombo
@export var discovered: bool = false
@export var revealed: bool = false
@export var times_triggered: int = 0
@export var mastery_threshold: int = 50
@export var mastery_bonus_description: String


func is_mastered() -> bool:
	return times_triggered >= mastery_threshold


func mastery_progress() -> float:
	if mastery_threshold <= 0:
		return 0.0
	return min(float(times_triggered) / float(mastery_threshold), 1.0)
