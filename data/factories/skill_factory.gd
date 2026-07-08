class_name SkillFactory
extends RefCounted
## Builds neutral-input skill AbilityDefinitions (single-phase choreographies) run through the
## shared ChoreographyRunner. See docs/fighter_kit_spec.md §4. Numbers PROVISIONAL — tune after test.
##
## Damage effects: AreaDamageEffect self-centers on the player (host fires it on [self]).
## DisplacementEffect (Uppercut) is dispatched per-enemy by player.choreo_fire_effects.


## Dispatcher: neutral-special skills for a character's melee_kit, as { slot: AbilityDefinition }.
## Modern slots are input actions ("skill_q" = Q, "skill_e" = E) fired by the player through
## SkillComponent; the legacy fighter slots predate the combo RMB scheme and are unused.
static func build_kit_skills(kit_id: String, weapon_data: Dictionary) -> Dictionary:
	match kit_id:
		"fighter":
			return {
				"uppercut": build_fighter_uppercut(weapon_data),
				"taunt": build_fighter_taunt(weapon_data),
			}
		"bard":
			return {
				"skill_e": build_bard_serenade(weapon_data),
			}
		"barbarian":
			return {
				"skill_q": build_barbarian_cry(weapon_data),
				"skill_e": build_barbarian_throw(weapon_data),
			}
		"ninja":
			return {
				"skill_q": build_ninja_sharpen(weapon_data),
				"skill_e": build_ninja_smoke(weapon_data),
			}
		"gunslinger":
			return {
				"skill_q": build_gunslinger_reload(weapon_data),
				"skill_e": build_gunslinger_whip(weapon_data),
			}
		"druid":
			return {
				"skill_q": build_druid_regrowth(weapon_data),
				"skill_e": build_druid_thornburst(weapon_data),
			}
		"cleric":
			return {
				"skill_q": build_cleric_sanctuary(weapon_data),
				"skill_e": build_cleric_guardians(weapon_data),
			}
	return {}


## Charming Serenade (Bard, E): sing — the nearest few enemies fall in love and turn on the
## horde for 5s (charm applied host-side to capped victims; see player.gd + enemy.gd).
static func build_bard_serenade(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "serenade"
	phase.hit_frame = 8
	phase.effects = [ChainFactory._charm_effect()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("bard_serenade", "Charming Serenade", phase, 12.0)


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


## Battle Cry (Barbarian, Q): roar — +25% damage for 6s, and nearby enemies stagger at
## -35% move speed (the "shaken" debuff rides the host's enemy dispatch). The frame-matched
## BattleCryEffect front layer plays automatically as the "cry_fx" overlay.
static func build_barbarian_cry(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "cry"
	phase.hit_frame = 5
	phase.effects = [ChainFactory._timed_damage_buff("battle_fury", 0.25, 6.0), ChainFactory._shaken_debuff()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("barbarian_cry", "Battle Cry", phase, 10.0)


## Throw Things (Barbarian, E): hurl a slab of junk at the cursor — one big landing burst
## (moved off RMB-hold, Ben feel test 2026-07-05; Guard took over the channel). The host
## centers the AoE on the clamped aim point and arcs the slab visual from the throw sheet.
static func build_barbarian_throw(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var burst := AreaDamageEffect.new()
	burst.damage_type = dtype
	burst.base_damage = dmg * 1.3
	burst.aoe_radius = 30.0

	var phase := ChoreographyPhase.new()
	phase.animation = "throw"
	phase.hit_frame = 13         ## the release frame — junk leaves his hand
	phase.effects = [burst]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("barbarian_throw", "Throw Things", phase, 5.0)


## Sharpen (Ninja, Q): the long whetstone ritual — 27 frames of commitment for +35% damage
## for 8s. The buff lands near the END of the ritual; getting the full stone in is the skill.
static func build_ninja_sharpen(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "sharpen"
	phase.hit_frame = 22
	phase.effects = [ChainFactory._timed_damage_buff("honed_edge", 0.35, 8.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("ninja_sharpen", "Sharpen", phase, 12.0)


## Smoke Bomb (Ninja, E): vanish in the puff — "concealed" for 3.5s (enemies stop chasing;
## same status the Ranger's cloak uses, one long vanish instead of channel ticks).
static func build_ninja_smoke(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "smoke"
	phase.hit_frame = 6
	phase.effects = [ChainFactory._smoke_conceal()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("ninja_smoke", "Smoke Bomb", phase, 10.0)


## Reload (Gunslinger, Q): the long 37-frame cylinder ritual — fresh chambers hit harder:
## +30% damage for 6s, landing near the END of the reload. Interrupt it and get nothing.
static func build_gunslinger_reload(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "reload"
	phase.hit_frame = 30
	phase.effects = [ChainFactory._timed_damage_buff("loaded_chambers", 0.30, 6.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("gunslinger_reload", "Reload", phase, 9.0)


## Whip Attack (Gunslinger, E): the tech-whip cracks — melee arc + shove to buy shooting
## room, with the pack's frame-matched Whip_Attack_Effect overlay.
static func build_gunslinger_whip(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var crack := AreaDamageEffect.new()
	crack.damage_type = dtype
	crack.base_damage = dmg * 1.0
	crack.aoe_radius = 36.0

	var phase := ChoreographyPhase.new()
	phase.animation = "whip"
	phase.hit_frame = 2
	phase.effects = [crack, ChainFactory._shove()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("gunslinger_whip", "Whip Attack", phase, 6.0)


## Regrowth (Druid, Q): a nature mend — the host routes the bare HealEffect onto the Verdant.
## Uses "attack_2" as a neutral gesture (root_cast/pray_* names carry host side-effects).
static func build_druid_regrowth(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "attack_2"
	phase.hit_frame = 3
	phase.effects = [ChainFactory._self_heal(0.15)]        ## 15% max HP burst
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("druid_regrowth", "Regrowth", phase, 12.0)


## Thornburst (Druid, E): a bramble nova — AoE Nature damage + shove around the Verdant.
static func build_druid_thornburst(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var nova := AreaDamageEffect.new()
	nova.damage_type = dtype
	nova.base_damage = dmg * 1.3
	nova.aoe_radius = 58.0

	var phase := ChoreographyPhase.new()
	phase.animation = "attack"
	phase.hit_frame = 1
	phase.effects = [nova, ChainFactory._shove()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("druid_thornburst", "Thornburst", phase, 6.0)


## Sanctuary (Cleric, Q): pray — a self-heal plus "blessed" (−20% damage taken for 5s). The
## "pray_heal" body plays the HealingWords overlay; the host routes the HealEffect onto the Devout.
static func build_cleric_sanctuary(_weapon_data: Dictionary) -> AbilityDefinition:
	var blessed := StatusEffectDefinition.new()
	blessed.status_id = "blessed"
	blessed.is_positive = true
	blessed.max_stacks = 1
	blessed.base_duration = 5.0
	blessed.duration_refresh_mode = "overwrite"
	var ward := ModifierDefinition.new()
	ward.target_tag = "damage_taken"
	ward.operation = "bonus"
	ward.value = -0.20
	ward.source_name = "blessed"
	blessed.modifiers = [ward]
	var apply := ApplyStatusEffectData.new()
	apply.status = blessed
	apply.stacks = 1
	apply.apply_to_self = true

	var phase := ChoreographyPhase.new()
	phase.animation = "pray_heal"
	phase.hit_frame = 11
	phase.effects = [ChainFactory._self_heal(0.12), apply]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("cleric_sanctuary", "Sanctuary", phase, 12.0)


## Spirit Guardians (Cleric, E): summon the guardian pet. The "pray_guardian" body triggers the
## host spawn (player._spawn_spirit_guardian); the small holy pulse both reads on cast and ensures
## choreo_fire_effects fires so the spawn hook runs.
static func build_cleric_guardians(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)

	var pulse := AreaDamageEffect.new()
	pulse.damage_type = "Fire"
	pulse.base_damage = dmg * 0.3
	pulse.aoe_radius = 26.0

	var phase := ChoreographyPhase.new()
	phase.animation = "pray_guardian"
	phase.hit_frame = 11
	phase.effects = [pulse]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("cleric_guardians", "Spirit Guardians", phase, 14.0)


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
