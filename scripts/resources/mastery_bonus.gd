class_name MasteryBonus
extends Resource

enum BonusType {
	RADIUS_INCREASE,
	DAMAGE_INCREASE,
	DURATION_INCREASE,
	COOLDOWN_REDUCTION,
	EXTRA_PROC,
	COST_REDUCTION
}

@export var bonus_type: BonusType
@export var bonus_value: float
@export var description: String
