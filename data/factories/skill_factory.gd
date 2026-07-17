class_name SkillFactory
extends RefCounted
## Builds neutral-input skill AbilityDefinitions (single-phase choreographies) run through the
## shared ChoreographyRunner. See docs/fighter_kit_spec.md §4. Numbers PROVISIONAL — tune after test.
##
## Damage effects: AreaDamageEffect self-centers on the player (host fires it on [self]).
## DisplacementEffect (Uppercut) is dispatched per-enemy by player.choreo_fire_effects.


## Dispatcher: neutral-special skills for a character's melee_kit, as { slot: AbilityDefinition }.
## Slots are input actions ("skill_q" = Q, "skill_e" = E) fired by the player through
## SkillComponent. Every kit has both; the Bard's Q is the song-cycle stance toggle handled
## host-side in player._on_skill_q (no cooldown, no runner), so only E lives here.
static func build_kit_skills(kit_id: String, weapon_data: Dictionary) -> Dictionary:
	match kit_id:
		"fighter":
			return {
				"skill_q": build_fighter_second_wind(weapon_data),
				"skill_e": build_fighter_blade_flurry(weapon_data),
			}
		"ranger":
			return {
				"skill_q": build_ranger_skirmish_step(weapon_data),
				"skill_e": build_ranger_arrow_storm(weapon_data),
			}
		"paladin":
			return {
				"skill_q": build_paladin_aegis_vow(weapon_data),
				"skill_e": build_paladin_bulwark_slam(weapon_data),
			}
		"wizard":
			return {
				"skill_q": build_wizard_mana_surge(weapon_data),
				"skill_e": build_wizard_flame_nova(weapon_data),
			}
		"rogue":
			return {
				"skill_q": build_rogue_vanish(weapon_data),
				"skill_e": build_rogue_eviscerate(weapon_data),
			}
		"blood_mage":
			return {
				"skill_q": build_blood_mage_blood_surge(weapon_data),
				"skill_e": build_blood_mage_blood_eruption(weapon_data),
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


## Second Wind (Fighter, Q): the soldier plants his shield and catches his breath — heal 12%
## max HP + "steeled" (−15% damage taken for 4s). "rally" re-slices the Taunt sheet slower
## (a distinct NAME so it skips the taunt shockwave host hook).
static func build_fighter_second_wind(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "rally"
	phase.hit_frame = 5
	phase.effects = [ChainFactory._self_heal(0.12), _ward_buff("steeled", 0.15, 4.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("fighter_second_wind", "Second Wind", phase, 12.0)


## Blade Flurry (Fighter, E): a hard spin-cut — AoE + flat shove to clear a ring of room.
## "flurry" re-slices the Swirl sheet faster, with its frame-matched effect as "flurry_fx".
static func build_fighter_blade_flurry(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var phase := ChoreographyPhase.new()
	phase.animation = "flurry"
	phase.hit_frame = 1
	phase.effects = [ChainFactory._aoe(dtype, dmg * 1.2, 48.0), ChainFactory._shove()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("fighter_blade_flurry", "Blade Flurry", phase, 6.0)


## Skirmisher's Step (Ranger, Q): the back-off kick — shove the pack away and dart clear at
## +25% move speed for 4s. Rides the Double Melee sheet (its swipe pairs with the push).
static func build_ranger_skirmish_step(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "melee_2"
	phase.hit_frame = 2
	phase.effects = [_speed_buff("fleetfoot", 0.25, 4.0), ChainFactory._shove()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("ranger_skirmish_step", "Skirmisher's Step", phase, 10.0)


## Arrow Storm (Ranger, E): empty the quiver — a 6-arrow fan at the cursor, twice the Triple
## Shot's spread. Reuses the Triple Shot cast body (no host hooks on that name).
static func build_ranger_arrow_storm(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var phase := ChoreographyPhase.new()
	phase.animation = "triple_shot"
	phase.hit_frame = 6
	phase.effects = [ChainFactory._arrow_volley(dtype, dmg * 0.5, 6, 44.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("ranger_arrow_storm", "Arrow Storm", phase, 8.0)


## Aegis Vow (Paladin, Q): the oath renewed — heal 10% max HP + "aegis" (−20% damage taken
## for 5s). "vow" re-slices the Dictum cast with the protective Dome effect as "vow_fx".
static func build_paladin_aegis_vow(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "vow"
	phase.hit_frame = 7
	phase.effects = [ChainFactory._self_heal(0.10), _ward_buff("aegis", 0.20, 5.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("paladin_aegis_vow", "Aegis Vow", phase, 12.0)


## Bulwark Slam (Paladin, E): a bigger, cooldown-gated shield smash — AoE + shove. Reuses the
## Shield Bash body (and its frame-matched "bash_fx" overlay) at a wider hit zone.
static func build_paladin_bulwark_slam(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var phase := ChoreographyPhase.new()
	phase.animation = "bash"
	phase.hit_frame = 3
	phase.effects = [ChainFactory._aoe(dtype, dmg * 1.1, 48.0), ChainFactory._shove()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("paladin_bulwark_slam", "Bulwark Slam", phase, 6.0)


## Mana Surge (Wizard, Q): overcharge the next spells — +30% damage for 6s on the quick
## re-sliced cast gesture ("attack_2", same neutral-gesture pattern as the Druid's Regrowth).
static func build_wizard_mana_surge(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "attack_2"
	phase.hit_frame = 3
	phase.effects = [ChainFactory._timed_damage_buff("mana_surge", 0.30, 6.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("wizard_mana_surge", "Mana Surge", phase, 10.0)


## Flame Nova (Wizard, E): the glass cannon's panic button — a fire ring + shove around the
## caster. "nova" re-slices the Fireball cast fast (a distinct NAME so it skips the
## charge-slow host hooks on "fireball"/"fireball_2").
static func build_wizard_flame_nova(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var phase := ChoreographyPhase.new()
	phase.animation = "nova"
	phase.hit_frame = 6
	phase.effects = [ChainFactory._aoe(dtype, dmg * 1.4, 60.0), ChainFactory._shove()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("wizard_flame_nova", "Flame Nova", phase, 7.0)


## Vanish (Rogue, Q): the pack's real Dodge roll into 3s of "concealed" (player.is_invisible —
## enemies stop chasing; aggression breaks it, same rule as the Ninja's Smoke Bomb).
static func build_rogue_vanish(_weapon_data: Dictionary) -> AbilityDefinition:
	var conceal := StatusEffectDefinition.new()
	conceal.status_id = "concealed"
	conceal.is_positive = true
	conceal.max_stacks = 1
	conceal.base_duration = 3.0
	conceal.duration_refresh_mode = "overwrite"
	var apply := ApplyStatusEffectData.new()
	apply.status = conceal
	apply.stacks = 1
	apply.apply_to_self = true

	var phase := ChoreographyPhase.new()
	phase.animation = "dodge"
	phase.hit_frame = 4
	phase.effects = [apply]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("rogue_vanish", "Vanish", phase, 14.0)


## Eviscerate (Rogue, E): a tight, vicious burst — big damage in a small ring. Rides the
## fast "attack_2" re-slice; the assassin gets in your face or gets nothing.
static func build_rogue_eviscerate(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var phase := ChoreographyPhase.new()
	phase.animation = "attack_2"
	phase.hit_frame = 1
	phase.effects = [ChainFactory._aoe(dtype, dmg * 1.5, 36.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("rogue_eviscerate", "Eviscerate", phase, 6.0)


## Blood Surge (Blood Mage, Q): the pact, on demand — +30% damage for 6s. Reuses the
## Extract_Power cast, so the host's blood-price hook fires (player._pay_blood_cost, 5% max
## HP): power is never free for the Cursed.
static func build_blood_mage_blood_surge(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "extract"
	phase.hit_frame = 4
	phase.effects = [ChainFactory._timed_damage_buff("blood_surge", 0.30, 6.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("blood_mage_blood_surge", "Blood Surge", phase, 10.0)


## Blood Eruption (Blood Mage, E): the ground opens — AoE + shove on the Blood_Spikes body;
## the host's "spikes" hook spawns the pack's ground-burst sheet at the hit-zone radius.
static func build_blood_mage_blood_eruption(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var phase := ChoreographyPhase.new()
	phase.animation = "spikes"
	phase.hit_frame = 5
	phase.effects = [ChainFactory._aoe(dtype, dmg * 1.4, 52.0), ChainFactory._shove()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("blood_mage_blood_eruption", "Blood Eruption", phase, 8.0)


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
	var phase := ChoreographyPhase.new()
	phase.animation = "pray_heal"
	phase.hit_frame = 11
	phase.effects = [ChainFactory._self_heal(0.12), _ward_buff("blessed", 0.20, 5.0)]
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

## Self-applied damage-taken reduction ("blessed"/"steeled"/"aegis" wards).
static func _ward_buff(id: String, amount: float, duration: float) -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = id
	status.is_positive = true
	status.max_stacks = 1
	status.base_duration = duration
	status.duration_refresh_mode = "overwrite"
	var ward := ModifierDefinition.new()
	ward.target_tag = "damage_taken"
	ward.operation = "bonus"
	ward.value = -amount
	ward.source_name = id
	status.modifiers = [ward]
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	apply.apply_to_self = true
	return apply


## Self-applied move-speed buff (Skirmisher's Step).
static func _speed_buff(id: String, amount: float, duration: float) -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = id
	status.is_positive = true
	status.max_stacks = 1
	status.base_duration = duration
	status.duration_refresh_mode = "overwrite"
	var speed := ModifierDefinition.new()
	speed.target_tag = "move_speed"
	speed.operation = "bonus"
	speed.value = amount
	speed.source_name = id
	status.modifiers = [speed]
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	apply.apply_to_self = true
	return apply


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
