class_name SkillFactory
extends RefCounted
## Builds neutral-input skill AbilityDefinitions (single-phase choreographies) run through the
## shared ChoreographyRunner. See docs/fighter_kit_spec.md §4. Numbers PROVISIONAL — tune after test.
##
## Damage effects: AreaDamageEffect self-centers on the player (host fires it on [self]).
## DisplacementEffect (Uppercut) is dispatched per-enemy by player.choreo_fire_effects.


## Dispatcher: neutral-special skills for a character's melee_kit, as { slot: AbilityDefinition }.
## Slots map to player input handling: "uppercut" = RMB tap, "taunt" = RMB hold.
static func build_kit_skills(kit_id: String, weapon_data: Dictionary) -> Dictionary:
	match kit_id:
		"fighter":
			return {
				"uppercut": build_fighter_uppercut(weapon_data),
				"taunt": build_fighter_taunt(weapon_data),
			}
	return {}


## Uppercut (Fighter, neutral RMB tap): quick launcher — modest damage + arc knockback that flings
## nearby enemies away. Knockback uses the engine displacement system (CLAUDE.md: i-frame-gated push).
static func build_fighter_uppercut(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var hit := AreaDamageEffect.new()
	hit.damage_type = dtype
	hit.base_damage = dmg * 0.6
	hit.aoe_radius = 70.0

	var fling := DisplacementEffect.new()
	fling.displaced = "target"
	fling.destination = "away_from_source"   ## knockback away from the player
	fling.motion = "arc"                     ## parabolic launch reads as an uppercut
	fling.duration = 0.32
	fling.arc_height = 34.0
	fling.distance = 88.0

	var phase := ChoreographyPhase.new()
	phase.animation = "uppercut"
	phase.hit_frame = 1
	phase.effects = [hit, fling]
	phase.exit_type = "anim_finished"
	phase.default_next = -1

	return _ability("fighter_uppercut", "Uppercut", phase, 2.5)


## Taunt (Fighter, neutral RMB hold): shield smack → shockwave AoE around the player.
static func build_fighter_taunt(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var shock := AreaDamageEffect.new()
	shock.damage_type = dtype
	shock.base_damage = dmg * 1.0
	shock.aoe_radius = 92.0

	var phase := ChoreographyPhase.new()
	phase.animation = "taunt"
	phase.hit_frame = 5          ## the shield smack
	phase.effects = [shock]
	phase.exit_type = "anim_finished"
	phase.default_next = -1

	return _ability("fighter_taunt", "Taunt", phase, 5.0)


# --- helpers ---

static func _ability(id: String, name: String, phase: ChoreographyPhase, cooldown: float) -> AbilityDefinition:
	var choreo := ChoreographyDefinition.new()
	choreo.phases = [phase]
	var a := AbilityDefinition.new()
	a.ability_id = id
	a.ability_name = name
	a.tags = ["Skill", "Melee"]
	a.mode = "Manual"
	a.cooldown_base = cooldown
	a.choreography = choreo
	return a


static func _damage_type(data: Dictionary) -> String:
	match data.get("damage_type", "physical"):
		"physical": return "Physical"
		"fire": return "Fire"
		"cryo": return "Ice"
		"shock": return "Lightning"
		"void": return "Void"
	return "Physical"
