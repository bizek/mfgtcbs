class_name SkillFactory
extends RefCounted
## Builds neutral-input skill AbilityDefinitions (single-phase choreographies) run through the
## shared ChoreographyRunner. See docs/fighter_kit_spec.md §4. Numbers PROVISIONAL — tune after test.
##
## Damage effects: AreaDamageEffect self-centers on the player (host fires it on [self]).
## DisplacementEffect (Uppercut) is dispatched per-enemy by player.choreo_fire_effects.


## Dispatcher: neutral-special skills for a character's melee_kit, as { slot: AbilityDefinition }.
## Slots are input actions ("skill_q" = Q, "skill_e" = E) fired by the player through
## SkillComponent. Every kit has both.
static func build_kit_skills(kit_id: String, weapon_data: Dictionary) -> Dictionary:
	match kit_id:
		"fighter":
			return {
				"skill_q": build_fighter_second_wind(weapon_data),
				"skill_e": build_fighter_shield_rush(weapon_data),
			}
		"ranger":
			return {
				"skill_q": build_ranger_skirmish_step(weapon_data),
				"skill_e": build_ranger_conceal(weapon_data),
			}
		"paladin":
			return {
				"skill_q": build_paladin_aegis_vow(weapon_data),
				"skill_e": build_paladin_lay_on_hands(weapon_data),
			}
		"wizard":
			return {
				"skill_q": build_wizard_ice_burst(weapon_data),
				"skill_e": build_wizard_storm_call(weapon_data),
			}
		"necromancer":
			return {
				"skill_q": build_necro_rise_corpse(weapon_data),
				"skill_e": build_necro_bone_legion(weapon_data),
			}
		"blood_mage":
			return {
				"skill_q": build_blood_mage_blood_surge(weapon_data),
				"skill_e": build_blood_mage_blood_eruption(weapon_data),
			}
		"demonologist":
			return {
				"skill_q": build_demon_summon(weapon_data),
				"skill_e": build_demon_archdemon(weapon_data),
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


## Summon Angry Demon (Demonologist, Q): the ritual opens a pit and ONE bound demon climbs out — an
## elite companion, not a swarm (the Shade is the swarm summoner). The "pact_ritual" body triggers the
## host spawn (player._spawn_angry_demon); the small hellfire pulse both reads on cast and ensures
## choreo_fire_effects fires so the spawn hook runs. Mirrors Rise Corpse / Spirit Guardians.
static func build_demon_summon(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var pulse := AreaDamageEffect.new()
	pulse.damage_type = dtype
	pulse.base_damage = dmg * 0.3
	pulse.aoe_radius = 28.0

	var phase := ChoreographyPhase.new()
	phase.animation = "pact_ritual"
	phase.hit_frame = 13                                   # the circle catches and the pit opens
	phase.effects = [pulse]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("demon_summon", "Summon Angry Demon", phase, 16.0)


## Archdemon's Call (Demonologist, E): the long cast tears a pentagram open AT THE CURSOR and
## something far too large puts its head through it. The damage is a GroundZoneEffect timed to the
## 27-frame Archdemon_Call_Spell (the host drops the VFX over it in choreo_fire_effects), so the
## archdemon reads as CHEWING on whatever stood there rather than a single flat hit. Screen-shaking
## payoff, long cooldown.
static func build_demon_archdemon(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var maw := GroundZoneEffect.new()
	maw.zone_id = "archdemon_maw"
	maw.radius = 56.0
	maw.duration = ARCHDEMON_SPELL_TIME
	maw.tick_interval = 0.35
	maw.target_faction = "enemy"
	## The floor stays open and burning for as long as the thing is chewing on it.
	maw.vfx_element = "fire"
	var bite := DealDamageEffect.new()
	bite.damage_type = dtype
	bite.base_damage = dmg * 0.55
	maw.tick_effects = [bite]

	var phase := ChoreographyPhase.new()
	phase.animation = "archdemon_call"
	phase.hit_frame = 15                                   # the seal completes; the pit answers
	phase.effects = [maw]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("demon_archdemon", "Archdemon's Call", phase, 22.0)


## Must stay equal to player.ARCHDEMON_SPELL_LIFE — the archdemon has to sink back into the sigil on
## the same frame its ground zone stops biting.
const ARCHDEMON_SPELL_TIME: float = 2.45


## Second Wind (Fighter, Q): the soldier bangs his shield and catches his breath — heal 12%
## max HP + "steeled" (−15% damage taken for 4s). "rally" is a single shield smack off the
## Taunt sheet (Ben 2026-07-20: "smack his shield once instead of a swing"); the green heal
## ring/flash is host-side, landing on the smack frame.
static func build_fighter_second_wind(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "rally"
	phase.hit_frame = 5
	phase.effects = [ChainFactory._self_heal(0.12), _ward_buff("steeled", 0.15, 4.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("fighter_second_wind", "Second Wind", phase, 12.0)


## Shield Rush (Fighter, E — replaced Blade Flurry, Ben 2026-07-19: "just a big AoE swing
## again"): shield-first charge toward the cursor. The host hook on "rush" does the work —
## dash motion through the pack, corridor victims damaged and YANKED to the slam point, then
## the slam AoE lands. The small contact AoE here fires the hook and clips whoever he
## launches through.
static func build_fighter_shield_rush(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var phase := ChoreographyPhase.new()
	phase.animation = "rush"
	phase.hit_frame = 1
	phase.effects = [ChainFactory._aoe(dtype, dmg * 0.4, 24.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("fighter_shield_rush", "Shield Rush", phase, 8.0)


## Skirmisher's Step (Ranger, Q): the back-off kick, upgraded to a real escape (Ben
## 2026-07-19: shove alone felt weak for a cooldown) — shove the pack away, dart clear at
## +25% move speed for 4s, untouchable for the first second ("slippery": 100% dodge), and the
## kick refunds a dash charge (host hook on the ability id). Rides the Double Melee sheet.
static func build_ranger_skirmish_step(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "melee_2"
	phase.hit_frame = 2
	phase.effects = [
		_speed_buff("fleetfoot", 0.25, 4.0),
		_dodge_buff("slippery", 1.0, 1.0),
		ChainFactory._shove(),
	]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("ranger_skirmish_step", "Skirmisher's Step", phase, 10.0)


## Conceal (Ranger, E — swapped off RMB-hold, Ben 2026-07-20): duck under the cloak and vanish
## — "concealed" for 5s (player.is_invisible; enemies stop chasing, and any attack breaks it).
## The RMB-hold slot it vacated became the sustained Volley channel (ChainFactory).
static func build_ranger_conceal(_weapon_data: Dictionary) -> AbilityDefinition:
	var conceal := StatusEffectDefinition.new()
	conceal.status_id = "concealed"
	conceal.is_positive = true
	conceal.max_stacks = 1
	conceal.base_duration = 5.0
	conceal.duration_refresh_mode = "overwrite"
	var apply := ApplyStatusEffectData.new()
	apply.status = conceal
	apply.stacks = 1
	apply.apply_to_self = true

	var phase := ChoreographyPhase.new()
	phase.animation = "conceal"
	phase.hit_frame = 6
	phase.effects = [apply]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("ranger_conceal", "Conceal", phase, 10.0)


## Aegis Shield (Paladin, Q — was a heal, Ben 2026-07-20: "we want an absorb shield"): the oath
## raises a STANDING absorb pool (25% max HP) that eats hits until it's SPENT — no timer, it stays
## on the Warden until depleted — with the pack's DomeCycle bubble looping over him. The pool +
## bubble live host-side (player._grant_absorb_shield, keyed on this ability id); the status here
## is just the HUD marker, removed by player._end_absorb_shield when the pool runs out. "vow"
## re-slices the Dictum cast with the Dome effect as "vow_fx".
static func build_paladin_aegis_vow(_weapon_data: Dictionary) -> AbilityDefinition:
	var marker := StatusEffectDefinition.new()
	marker.status_id = "aegis_shield"
	marker.is_positive = true
	marker.max_stacks = 1
	marker.base_duration = 99999.0                         ## effectively permanent; ends when the pool is spent
	marker.duration_refresh_mode = "overwrite"
	var apply := ApplyStatusEffectData.new()
	apply.status = marker
	apply.stacks = 1
	apply.apply_to_self = true

	var phase := ChoreographyPhase.new()
	phase.animation = "vow"
	phase.hit_frame = 7
	phase.effects = [apply]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("paladin_aegis_vow", "Aegis Shield", phase, 14.0)


## Lay on Hands (Paladin, E — was Bulwark Slam, Ben 2026-07-20: "make it a heal"): a real mend,
## 20% max HP + "hallowed" (−15% damage taken for 4s). The "heal_word" body plays the Cleric's
## HealingWords overlay (heal_word_fx). Replaces the shield-bash rehash.
static func build_paladin_lay_on_hands(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "heal_word"
	phase.hit_frame = 11
	phase.effects = [ChainFactory._self_heal(0.20), _ward_buff("hallowed", 0.15, 4.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("paladin_lay_on_hands", "Lay on Hands", phase, 12.0)


## Frost Burst (Wizard, Q — was Mana Surge, Ben 2026-07-20): a point-blank ICE nova that damages
## + chills the pack, then leaves a ring of ice shards shimmering around the Spark for ~10s (the
## Aura_Ice visual — host-side, player._cast_ice_burst / _show_ice_aura). "attack_2" is the
## neutral cast gesture; the Burst_Ice + Aura_Ice sheets are the show.
static func build_wizard_ice_burst(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)

	var burst := AreaDamageEffect.new()
	burst.damage_type = "Ice"
	burst.base_damage = dmg * 1.2
	burst.aoe_radius = 58.0

	var phase := ChoreographyPhase.new()
	phase.animation = "ice_cast"
	phase.hit_frame = 3
	phase.effects = [burst, _chilled_debuff()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("wizard_ice_burst", "Frost Burst", phase, 12.0)


## Storm Call (Wizard, E — was Flame Nova, Ben 2026-07-20): call the sky down on the WHOLE arena
## — every enemy takes a two-bolt lightning strike (Aura_Electric row 0 dropped over each; the
## host damages them), and electric pulses crackle around the Spark. Screen-wide, so it carries
## a long cooldown. The small self-pulse here just guarantees choreo_fire_effects runs the host
## hook (player._cast_storm_call, keyed on this ability id).
static func build_wizard_storm_call(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)

	var pulse := AreaDamageEffect.new()
	pulse.damage_type = "Lightning"
	pulse.base_damage = dmg * 0.2
	pulse.aoe_radius = 40.0

	var phase := ChoreographyPhase.new()
	phase.animation = "storm_cast"
	phase.hit_frame = 3
	phase.effects = [pulse]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("wizard_storm_call", "Storm Call", phase, 16.0)


## Chill: enemies hit by Frost Burst crawl at −30% move speed for 3s.
static func _chilled_debuff() -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = "chilled"
	status.is_positive = false
	status.max_stacks = 1
	status.base_duration = 3.0
	status.duration_refresh_mode = "overwrite"
	var slow := ModifierDefinition.new()
	slow.target_tag = "move_speed"
	slow.operation = "bonus"
	slow.value = -0.30
	slow.source_name = "chilled"
	status.modifiers = [slow]
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	apply.apply_to_self = false
	return apply


## Rise Corpse (Necromancer, Q): summon the persistent Skeletal Champion companion. The "rise_corpse"
## body triggers the host spawn (player._spawn_skeletal_champion); the small void pulse both reads on
## cast and ensures choreo_fire_effects fires so the spawn hook runs. Mirrors Spirit Guardians.
static func build_necro_rise_corpse(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var pulse := AreaDamageEffect.new()
	pulse.damage_type = dtype
	pulse.base_damage = dmg * 0.3
	pulse.aoe_radius = 26.0

	var phase := ChoreographyPhase.new()
	phase.animation = "rise_corpse"
	phase.hit_frame = 9
	phase.effects = [pulse]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("necro_rise_corpse", "Rise Corpse", phase, 14.0)


## Bone Legion (Necromancer, E): raise a short-lived pack of lesser skeletons at once. Reuses the
## Rise_Corpse cast body under a distinct anim NAME ("bone_legion") so the host branches to the swarm
## spawn (player._spawn_bone_legion) instead of the single champion. Faster cooldown, weaker minions.
static func build_necro_bone_legion(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var pulse := AreaDamageEffect.new()
	pulse.damage_type = dtype
	pulse.base_damage = dmg * 0.3
	pulse.aoe_radius = 30.0

	var phase := ChoreographyPhase.new()
	phase.animation = "bone_legion"
	phase.hit_frame = 9
	phase.effects = [pulse]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("necro_bone_legion", "Bone Legion", phase, 10.0)


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


## Blood Eruption (Blood Mage, E — reworked, Ben 2026-07-19: was a re-skin of Blood Spikes):
## the ground opens AND stays open — the burst leaves a lingering blood pool underfoot that
## bleeds enemies standing in it, and every enemy that DIES in a pool feeds the Cursed
## (host heals 3% max HP per death — player._on_any_entity_death). Smaller up-front hit than
## the heavy Spikes; the pool is the identity.
static func build_blood_mage_blood_eruption(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var pool := GroundZoneEffect.new()
	pool.zone_id = "blood_pool"
	pool.radius = 48.0
	pool.duration = 5.0
	pool.tick_interval = 0.5
	pool.target_faction = "enemy"
	## The pool is the identity of this skill and was previously invisible — you could only find
	## it by watching your own HP tick up. Poison's creeping tileable, palette-shifted to arterial
	## red (docs/asset_inventory.md recolour strategy).
	pool.vfx_element = "poison"
	pool.vfx_tint = Color(1.0, 0.28, 0.30)
	var bleed := DealDamageEffect.new()
	bleed.damage_type = dtype
	bleed.base_damage = dmg * 0.15
	pool.tick_effects = [bleed]

	var phase := ChoreographyPhase.new()
	phase.animation = "spikes"
	phase.hit_frame = 5
	phase.effects = [ChainFactory._aoe(dtype, dmg * 1.0, 48.0), ChainFactory._shove(), pool]
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


## Self-applied dodge-chance buff (Skirmisher's Step "slippery" window). dodge_chance is an
## "add"-operation stat in DamageCalculator step 4, so amount 1.0 = guaranteed dodge.
static func _dodge_buff(id: String, amount: float, duration: float) -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = id
	status.is_positive = true
	status.max_stacks = 1
	status.base_duration = duration
	status.duration_refresh_mode = "overwrite"
	var dodge := ModifierDefinition.new()
	dodge.target_tag = "dodge_chance"
	dodge.operation = "add"
	dodge.value = amount
	dodge.source_name = id
	status.modifiers = [dodge]
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
