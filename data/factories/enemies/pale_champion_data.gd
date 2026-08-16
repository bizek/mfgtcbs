class_name PaleChampionData
extends RefCounted
## Level 4 — The Threshold — FINAL BOSS: "The Pale Champion" (Minifantasy Dark_Orc_Army).
##
## What actually came through the door. The Orc Army pack files it under "Others" rather
## than under any rank tier, which is the pack telling you it does not belong to the army
## it leads — the right final note for a biome about a door held open by people who did not
## understand what was on the other side.
##
## Three tools, escalating in commitment:
##   Cleaving Arc   — the auto-attack; short tell, moderate radius, constant pressure
##   Breach         — a long line of the doorway's own energy, punishing the safe backpedal
##   Warcry         — a full-arena ring on a long cooldown; the "the army is here" beat
##
## Placed by LevelData.LEVELS[4].final_boss_id.

const COLOR_PALE: Color = Color(0.88, 0.86, 0.92, 0.55)
const COLOR_BREACH: Color = Color(0.94, 0.52, 0.34, 0.55)


static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id       = "pale_champion"
	def.enemy_name     = "The Pale Champion"
	def.tags           = ["Melee", "Heavy", "Boss", "Orc"]
	def.base_stats     = {"max_hp": 2100.0}
	def.combat_role    = "MELEE"
	def.move_speed     = 46.0
	def.contact_damage = 32.0
	def.base_armor     = 18.0
	def.xp_value       = 300.0
	def.health_drop_chance   = 0.85
	def.behavior_type        = "chase"
	def.knockback_multiplier = 0.05
	def.sprite_scale         = Vector2(2.6, 2.6)
	def.groups   = ["bosses"]
	def.is_boss  = true
	def.boss_bar_color = Color(0.90, 0.88, 0.94)    ## bone-white final-boss bar

	def.auto_attack = _cleaving_arc()

	var sk_breach := SkillDefinition.new()
	sk_breach.skill_name = "Breach"
	sk_breach.unlock_level = 1
	sk_breach.ability = _breach()

	var sk_warcry := SkillDefinition.new()
	sk_warcry.skill_name = "Warcry"
	sk_warcry.unlock_level = 1
	sk_warcry.ability = _warcry()

	def.skills = [sk_breach, sk_warcry]
	return def


## Short-tell arc at the player's position. Fast enough to punish greed, slow enough to
## read — the beat the whole fight is paced against.
static func _cleaving_arc() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "target_position"
	telegraph.radius = 68.0
	telegraph.duration = 0.6
	telegraph.color = COLOR_PALE
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "pale_cleave"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.55
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.6
	windup.default_next = 1

	var cleave := AreaDamageEffect.new()
	cleave.damage_type = "Physical"
	cleave.base_damage = 42.0
	cleave.aoe_radius = 68.0

	var hit := ChoreographyPhase.new()
	hit.effects = [cleave]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.3
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var aa := AbilityDefinition.new()
	aa.ability_id = "pale_cleaving_arc"
	aa.ability_name = "Cleaving Arc"
	aa.tags = ["Melee", "AOE", "Boss"]
	aa.cooldown_base = 3.6
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 240.0
	aa.targeting = targeting
	aa.choreography = choreo
	return aa


## A long reach at the player's position, Void-typed and wide. This is the answer to
## kiting: on open plane the player's instinct is to walk away and plink, and Breach makes
## distance itself unsafe rather than forcing them back into melee.
static func _breach() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "target_position"
	telegraph.radius = 92.0
	telegraph.duration = 1.0
	telegraph.color = COLOR_BREACH
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "pale_breach"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.4
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 1.0
	windup.default_next = 1

	var burst := AreaDamageEffect.new()
	burst.damage_type = "Void"
	burst.base_damage = 54.0
	burst.aoe_radius = 92.0

	var hit := ChoreographyPhase.new()
	hit.effects = [burst]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.45
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "pale_breach"
	ab.ability_name = "Breach"
	ab.tags = ["Ranged", "AOE", "Boss"]
	ab.cooldown_base = 7.5
	ab.mode = "Auto"
	ab.priority = 5
	ab.cast_range = 320.0            ## deliberately longer than the player's comfortable range
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 320.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab


## The widest ring in the game on the longest cooldown. Survivable by disengaging, and the
## long tell says so — it is a punctuation mark, not a damage check.
static func _warcry() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "ring"
	telegraph.anchor = "source_position"
	telegraph.radius = 200.0
	telegraph.duration = 1.5
	telegraph.color = Color(0.84, 0.80, 0.90, 0.5)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "pale_warcry"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.3
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 1.5
	windup.default_next = 1

	var burst := AreaDamageEffect.new()
	burst.damage_type = "Physical"
	burst.base_damage = 60.0
	burst.aoe_radius = 200.0

	var hit := ChoreographyPhase.new()
	hit.effects = [burst]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.6
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "pale_warcry"
	ab.ability_name = "Warcry"
	ab.tags = ["Melee", "AOE", "Boss"]
	ab.cooldown_base = 15.0
	ab.mode = "Auto"
	ab.priority = 8
	ab.cast_range = 215.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 215.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab
