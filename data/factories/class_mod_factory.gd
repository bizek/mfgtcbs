class_name ClassModFactory
extends RefCounted

## ClassModFactory — the ONE seam that applies CLASS mods (ClassModData) to a character's combo
## kit at build time. Mirrors the ModComboFactory / WeaponFactory.build_combo_modifiers pattern:
## data in, kit mutations out, no bespoke per-mod code paths in the combat scripts.
##
## player._load_combo builds the kit (ChainFactory.build_kit) and skills (SkillFactory.build_kit_skills),
## then calls:
##   ClassModFactory.apply_to_kit(kit_id, kit, active_ids)         # mutates light/heavy/channel
##   ClassModFactory.apply_to_skills(kit_id, skills, active_ids)   # mutates skill_q/skill_e/…
##   for m in ClassModFactory.build_modifiers(kit_id, active_ids): modifier_component.add_modifier(m)
##
## `active_ids` are the class-mod ids the player has EQUIPPED for the current character AND that
## belong to this kit (ProgressionManager.get_active_class_mods filters both). All modifiers this
## factory produces carry the source prefix "classmod_" so the player can strip them on rebuild.


## Mutate the { "light","heavy","channel" } kit abilities in place.
static func apply_to_kit(kit_id: String, kit: Dictionary, active_ids: Array) -> void:
	_apply_to_abilities(kit_id, kit, active_ids)


## Mutate the { slot: AbilityDefinition } skills dict in place.
static func apply_to_skills(kit_id: String, skills: Dictionary, active_ids: Array) -> void:
	_apply_to_abilities(kit_id, skills, active_ids)


## Apply run-scoped ability upgrade dicts (from UpgradeManager) to the kit/skills.
## Takes raw dicts directly rather than class mod IDs, using the same _apply_op_to_phase internals.
## Called by player._load_combo after class mods so run upgrades stack on top each rebuild.
static func apply_upgrade_dicts_to_kit(kit_id: String, kit: Dictionary, dicts: Array) -> void:
	_apply_dicts_to_abilities(kit_id, kit, dicts)


static func apply_upgrade_dicts_to_skills(kit_id: String, skills: Dictionary, dicts: Array) -> void:
	_apply_dicts_to_abilities(kit_id, skills, dicts)


## Player-level ModifierDefinitions for "modifier" class mods (kit-agnostic stat buffs while
## equipped). source_name prefixed "classmod_" so player.reload/switch can remove them cleanly.
static func build_modifiers(kit_id: String, active_ids: Array) -> Array[ModifierDefinition]:
	var result: Array[ModifierDefinition] = []
	for mod_id: String in active_ids:
		var mod: Dictionary = ClassModData.ALL.get(mod_id, {})
		if mod.get("kit", "") != kit_id or mod.get("op", "") != "modifier":
			continue
		var params: Dictionary = mod.get("params", {})
		var m := ModifierDefinition.new()
		m.target_tag  = params.get("stat", "damage")
		m.operation   = params.get("op", "bonus")
		m.value       = params.get("value", 0.0)
		m.source_name = "classmod_" + mod_id
		result.append(m)
	return result


# ── Internals ────────────────────────────────────────────────────────────────────

## Same as _apply_to_abilities but takes raw dicts (ability upgrade entries) instead of IDs.
static func _apply_dicts_to_abilities(kit_id: String, abilities: Dictionary, dicts: Array) -> void:
	for mod: Dictionary in dicts:
		if mod.get("kit", "") != kit_id:
			continue
		var op: String = mod.get("op", "")
		if op == "modifier" or op == "kit_flag" or op == "":
			continue   ## modifier → ModifierComponent; kit_flag → read by the entity. Not phases.
		var target: Dictionary = mod.get("target", {})
		var want_graph: String = target.get("graph", "")
		var want_anim: String  = target.get("anim", "")
		var params: Dictionary = mod.get("params", {})
		for key: String in abilities.keys():
			if want_graph != "" and key != want_graph:
				continue
			var ability: AbilityDefinition = abilities[key]
			if ability == null or ability.choreography == null:
				continue
			for phase: ChoreographyPhase in ability.choreography.phases:
				if want_anim != "" and phase.animation != want_anim:
					continue
				_apply_op_to_phase(op, phase, params)


## Apply every phase-targeting class mod in `active_ids` to the abilities in `abilities`
## ({ graph_key: AbilityDefinition }). A mod applies to an ability when its target.graph matches
## the key (or graph is omitted → any key), scanning phases for target.anim.
static func _apply_to_abilities(kit_id: String, abilities: Dictionary, active_ids: Array) -> void:
	for mod_id: String in active_ids:
		var mod: Dictionary = ClassModData.ALL.get(mod_id, {})
		if mod.get("kit", "") != kit_id:
			continue
		var op: String = mod.get("op", "")
		if op == "modifier":
			continue   ## handled by build_modifiers, not a phase mutation
		if op == "kit_flag":
			continue   ## routing-level; the entity reads the equipped id itself (player._load_combo)
		var target: Dictionary = mod.get("target", {})
		var want_graph: String = target.get("graph", "")
		var want_anim: String  = target.get("anim", "")
		var params: Dictionary = mod.get("params", {})
		for key: String in abilities.keys():
			if want_graph != "" and key != want_graph:
				continue
			var ability: AbilityDefinition = abilities[key]
			if ability == null or ability.choreography == null:
				continue
			for phase: ChoreographyPhase in ability.choreography.phases:
				if want_anim != "" and phase.animation != want_anim:
					continue
				_apply_op_to_phase(op, phase, params)


static func _apply_op_to_phase(op: String, phase: ChoreographyPhase, params: Dictionary) -> void:
	match op:
		"scale_aoe":
			var rmult: float = params.get("radius_mult", 1.0)
			var dmult: float = params.get("damage_mult", 1.0)
			_scale_effects(phase.effects, rmult, dmult)
		"add_pull":
			phase.effects.append(_pull_effect(params))
		"add_status":
			var apply := _status_effect(params)
			if apply != null:
				phase.effects.append(apply)
		"add_projectile_status":
			## Injects a status into projectile on_hit_effects rather than the phase AoE pool.
			## Use for ranged phases (SpawnProjectilesEffect) so bleed/burn lands on each enemy hit.
			var apply := _status_effect(params)
			if apply != null:
				for eff in phase.effects:
					if eff is SpawnProjectilesEffect and eff.projectile != null:
						eff.projectile.on_hit_effects.append(apply)
		"add_projectiles":
			## Adds extra projectiles to a SpawnProjectilesEffect (Fan the Hammer +2, etc.).
			var add_n: int = params.get("count", 1)
			for eff in _projectile_effects(phase):
				eff.count += add_n


## Scale a pool of effects in place. Recurses one level into a status the phase applies, so ops still
## reach abilities that keep their payload on a status rather than directly on the phase — the
## Necromancer's Bone Swirl holds its grind damage on an aura and its bone burst on that aura's
## expiry, and without this its two "scale_aoe" mods would silently do nothing.
##
## The status is DUPLICATED before mutation: `add_status` hands out shared StatusFactory singletons,
## and scaling one in place would leak the buff into every other user of that status for the session.
static func _scale_effects(effects: Array, rmult: float, dmult: float, depth: int = 0) -> void:
	if depth > 2:
		return                                   ## guard: a status that re-applies itself
	for i in effects.size():
		var eff: Resource = effects[i]
		if eff is AreaDamageEffect:
			eff.aoe_radius  *= rmult
			eff.base_damage *= dmult
		elif eff is DealDamageEffect:
			eff.base_damage *= dmult
		elif eff is GroundZoneEffect:
			eff.radius *= rmult
			## …and the burn itself. Without this a "damage_mult" op widened a zone but left every
			## tick at base — the Demonologist's Brimstone Circle and the Cleric's Word of Pain both
			## keep their real damage on tick_effects, not on the phase.
			_scale_effects(eff.tick_effects, rmult, dmult, depth + 1)
		elif eff is SpawnProjectilesEffect:
			if eff.projectile != null:
				for hit in eff.projectile.on_hit_effects:
					if hit is DealDamageEffect:
						hit.base_damage *= dmult
				for hit in eff.projectile.impact_aoe_effects:
					if hit is DealDamageEffect:
						hit.base_damage *= dmult
		elif eff is ApplyStatusEffectData and eff.status != null:
			var st: StatusEffectDefinition = eff.status.duplicate(true)
			eff.status = st
			if st.aura_radius > 0.0:
				st.aura_radius *= rmult
			_scale_effects(st.aura_tick_effects, rmult, dmult, depth + 1)
			_scale_effects(st.tick_effects, rmult, dmult, depth + 1)
			_scale_effects(st.on_expire_effects, rmult, dmult, depth + 1)


## Every SpawnProjectilesEffect a phase can loose — directly, or via the expiry of a status it
## applies (the Bone Swirl's outgoing bones). `count` on these is the dial "add_projectiles" turns.
static func _projectile_effects(phase: ChoreographyPhase) -> Array:
	var out: Array = []
	for eff in phase.effects:
		if eff is SpawnProjectilesEffect:
			out.append(eff)
		elif eff is ApplyStatusEffectData and eff.status != null:
			for x in eff.status.on_expire_effects:
				if x is SpawnProjectilesEffect:
					out.append(x)
	return out


## A toward-player displacement — sucks the phase's hit targets inward. Same i-frame-gated
## DisplacementEffect system as the Fighter Uppercut fling / Shield Bash shove (CLAUDE.md).
static func _pull_effect(params: Dictionary) -> DisplacementEffect:
	var d := DisplacementEffect.new()
	d.displaced   = "target"
	d.destination = "toward_source"          ## pull enemies toward the player
	d.motion      = "arc"
	d.duration    = params.get("duration", 0.2)
	d.arc_height  = params.get("arc_height", 6.0)
	d.distance    = params.get("distance", 60.0)
	return d


## Append a status the phase applies on hit. params.status is a StatusFactory id; apply_to_self
## defaults false (debuff on the enemies hit). Returns null if the status id is unknown.
static func _status_effect(params: Dictionary) -> ApplyStatusEffectData:
	StatusFactory.build_all()
	var status_def: StatusEffectDefinition = StatusFactory.get_by_id(params.get("status", ""))
	if status_def == null:
		return null
	var apply := ApplyStatusEffectData.new()
	apply.status = status_def
	apply.stacks = params.get("stacks", 1)
	apply.apply_to_self = params.get("apply_to_self", false)
	return apply
