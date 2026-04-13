## MasteryApplicator — query active mastery bonuses from mastered combos
class_name MasteryApplicator

## Get all active mastery bonuses from currently-active combos.
## Returns a dictionary: bonus_type (int) → accumulated_value (float)
static func get_active_mastery_bonuses(active_combos: Array[ModCombo]) -> Dictionary:
	var bonuses: Dictionary = {}

	if not CodexManager:
		return bonuses

	for combo in active_combos:
		# Check if this combo is mastered
		if combo.combo_id not in CodexManager.entries:
			continue

		var entry = CodexManager.entries[combo.combo_id]
		if not entry.is_mastered():
			continue

		# If combo has a mastery bonus, accumulate it
		if combo.mastery_bonus:
			var bonus_type = combo.mastery_bonus.bonus_type
			if bonus_type not in bonuses:
				bonuses[bonus_type] = 0.0
			bonuses[bonus_type] += combo.mastery_bonus.bonus_value

	return bonuses
