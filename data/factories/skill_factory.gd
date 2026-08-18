class_name SkillFactory
extends RefCounted
## Builds neutral-input skill AbilityDefinitions (single-phase choreographies) run through the
## shared ChoreographyRunner. See docs/fighter_kit_spec.md §4. Numbers PROVISIONAL — tune after test.
##
## Damage effects: AreaDamageEffect self-centers on the player (host fires it on [self]).
## Skills do NOT displace enemies — knockback was cut from every kit (Ben, 2026-07-31).


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
				"skill_q": build_ranger_mirror_archer(weapon_data),
				"skill_e": build_ranger_quiver_swap(weapon_data),
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
				"skill_q": build_blood_mage_blood_elemental(weapon_data),
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
				"skill_e": build_barbarian_pile_driver(weapon_data),
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
				"skill_q": build_druid_summon_bear(weapon_data),
				"skill_e": build_druid_summon_hounds(weapon_data),
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
	return _ability("demon_summon", "Summon Angry Demon", phase, 16.0, "Summon")


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
## the same frame its ground zone stops biting. That value is now derived from the sheet's playback
## rate (27 frames / ARCHDEMON_SPELL_FPS), so this zone duration FOLLOWS the art: if the cast needs
## to be longer or shorter, change the fps there, not the number here.
const ARCHDEMON_SPELL_TIME: float = 27.0 / 11.0   ## 2.4545s — was a hand-rounded 2.45


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
	return _ability("fighter_second_wind", "Second Wind", phase, 12.0, "Buff")


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


## Mirror Archer (Ranger, Q — replaced Skirmisher's Step, Ben 2026-07-29): the Scavenger splits off
## a spectral duplicate of herself that plants its feet and looses her own arrows at anything in
## range for 10s. The "conceal" body triggers the host spawn (player._spawn_mirror_archer) — the
## vanishing-into-the-cloak flourish is the pack's most natural "a second one of me steps out"
## gesture, and it is the same sheet the E skill uses, playing the kit's own art twice over rather
## than borrowing another class's.
##
## The kick this replaced was the kit's escape. Conceal (E) was the other one, and it is gone too
## as of 2026-07-31 (build_ranger_quiver_swap) — so the Scavenger's only disengage is now her dash
## plus the melee knives she gives up when she arms a head. That is the intended shape: her
## survivability is range and positioning, not a panic button.
##
## The archer INHERITS the loaded quiver — its arrows are built through the same ChainFactory
## helper the player injects into (mirror_archer.gd), so a Frost stance puts a second chill-stacker
## on the field. It is the stance's strongest single payoff and it cost nothing to wire.
static func build_ranger_mirror_archer(_weapon_data: Dictionary) -> AbilityDefinition:
	## "mirrored" is a pure HUD marker, the same job the Warden's Aegis status does: it carries no
	## modifiers, it just runs a buff-bar timer for exactly as long as the reflection stands. It is
	## also load-bearing — ChoreographyRunner._fire() skips choreo_fire_effects entirely on a phase
	## with no effects, so a truly empty node would never reach the spawn hook at all.
	var mirrored := StatusEffectDefinition.new()
	mirrored.status_id = "mirrored"
	mirrored.is_positive = true
	mirrored.max_stacks = 1
	mirrored.base_duration = 10.0                  ## == MirrorArcher.lifetime
	mirrored.duration_refresh_mode = "overwrite"
	var apply := ApplyStatusEffectData.new()
	apply.status = mirrored
	apply.stacks = 1
	apply.apply_to_self = true

	var phase := ChoreographyPhase.new()
	phase.animation = "conceal"
	phase.hit_frame = 6
	phase.effects = [apply]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("ranger_mirror_archer", "Mirror Archer", phase, 14.0, "Summon")


## Quiver Swap (Ranger, E — replaced Conceal, Ben 2026-07-31). A STANCE, not a cast: each press
## cycles the loaded arrowhead Unarmed → Fire → Frost → Unarmed, and that head rides every arrow
## the Scavenger looses on RMB (the elemental shot string), the held Volley, and her Mirror Archer.
##
## Why Conceal died. `concealed` is the NINJA's Smoke Bomb status — same id, same code path — so
## the Scavenger's E was renting another class's identity, and in a game where you are always
## attacking a 5s vanish that breaks on your first arrow is a "stop playing" button. Stealth stays
## owned by the Ninja. (Ben: "stealth isnt required in this game for.. literally anything".)
##
## Why a toggle and not a timed buff. A cooldown'd "your next N arrows are fire" makes the player
## count arrows and watch a timer; a free-ish toggle makes them decide what kind of ranger they
## are right now. The 0.6s cooldown exists only so the stance can't be strobed mid-chain.
##
## Unarmed is IN the cycle because it is how you get the melee knives back — arming a head costs
## you the kit's point-blank panic swing (player._tick_combo picks the RMB graph off the stance),
## so the toggle is a trade rather than a free upgrade.
##
## The swap itself happens in player.choreo_on_start the instant the ability fires, NOT on a hit
## frame: a stance must never be eaten by an interrupted body. The phase carries no effects — the
## cloak duck is pure flourish.
##
## Timing. The duck is 14f @ 16fps = 0.875s, far too long to stand in for a stance change, so it
## plays at 3x for a ~0.29s commitment. That is deliberately a real cost (you cannot swap heads
## for free mid-chain) and deliberately NOT a "wait" phase: a wait with no branches is a dead
## idle, which ComboTimingAudit correctly flags as a STALL. anim_finished at speed keeps the whole
## pack animation on screen and ends the moment it's drawn.
static func build_ranger_quiver_swap(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "conceal"
	phase.hit_frame = -1
	phase.effects = []
	phase.exit_type = "anim_finished"
	phase.telegraph_speed_scale = 3.0    ## 0.875s duck → ~0.29s
	phase.default_next = -1
	return _ability("ranger_quiver_swap", "Quiver Swap", phase, 0.6, "Movement")


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
	return _ability("paladin_aegis_vow", "Aegis Shield", phase, 14.0, "Buff")


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
	return _ability("paladin_lay_on_hands", "Lay on Hands", phase, 12.0, "Buff")


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
	return _ability("necro_rise_corpse", "Rise Corpse", phase, 14.0, "Summon")


## Bone Legion (Necromancer, E): raise a ring of VOLATILE skeletons that sprint at whatever is
## nearest and detonate — thrown ordnance, spent in one go. Reuses the Rise_Corpse cast body under a
## distinct anim NAME ("bone_legion") so the host branches to the swarm spawn
## (player._spawn_bone_legion) instead of the persistent champions.
##
## Reworked 2026-08-01 (Ben: "what makes the E skeletons better than the Q skeletons other than
## theres more on Q than on E") — it was 2 champions that were strictly worse than Q's 4 in every
## stat. See skeletal_champion.gd's `volatile` mode. The cooldown stays shorter than Rise Corpse's
## 14s: this is the button you press INTO a pack, and it leaves nothing behind.
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
	return _ability("necro_bone_legion", "Bone Legion", phase, 10.0, "Summon")


## Summon Blood Elemental (Blood Mage, Q — Ben 2026-08-01: "blood golem move to Q"). The golem used
## to be a gated RMB finisher buried mid-way through the light chain, which meant the Cursed's one
## companion was the hardest thing in his kit to actually get out. On Q it is a button.
##
## It replaces Blood Surge, which was the weakest slot in the kit for a reason that only shows up
## once they sit side by side: Blood Surge was +30% damage for 6s, and the light chain's held-LMB
## Extract Power is already +25% damage — the same button-press for the same effect, one of them
## costing a skill slot. The Cursed keeps his damage pact on hold-LMB and spends Q on the golem.
##
## "summon_blood" is the anim NAME the host keys the spawn off (player._spawn_blood_elemental fires
## in choreo_fire_effects), so moving the cast here needs no host change. The ignition burst both
## reads on cast and guarantees choreo_fire_effects runs. Mirrors Rise Corpse / Summon Angry Demon.
static func build_blood_mage_blood_elemental(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var pulse := AreaDamageEffect.new()
	pulse.damage_type = dtype
	pulse.base_damage = dmg * 0.4
	pulse.aoe_radius = 24.0

	var phase := ChoreographyPhase.new()
	phase.animation = "summon_blood"
	phase.hit_frame = 10                                   # the blood gathers and stands up
	phase.effects = [pulse]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("blood_mage_blood_elemental", "Summon Blood Elemental", phase, 16.0, "Summon")


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
	phase.effects = [ChainFactory._aoe(dtype, dmg * 1.0, 48.0), pool]
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
	return _ability("barbarian_cry", "Battle Cry", phase, 10.0, "Buff")


## Pile Driver (Barbarian, E): TWO presses. The first one has him bend down and grab an enemy —
## and everything packed close enough to it, and everything packed close to THOSE, chaining
## outward through the crowd until the pile is full. He straightens up carrying the lot overhead.
## The second press hurls the whole pile at the cursor: the thrown bodies take the impact, so does
## whatever they land on, and all of it is stunned.
##
## Replaces the old Throw Things (a slab of scenery at the cursor) — Ben + Clerveu, 2026-08-16.
## The pack drew this: the Throw_Things sheet is a crouch-grab, an overhead carry and a release,
## which is exactly the two-beat shape. See CharacterData's "hoist"/"hurl" slices.
##
## The grab and the throw are HOST hooks (player._grab_pile / _hurl_pile), not effect resources.
## "chain outward through a crowd, pick those bodies up, carry them, then throw them at a point"
## is not something the effect vocabulary can say, and inventing a 17th effect type to say it once
## would be worse than the hook — the phase still owns every number the mod/upgrade ops can reach.
const PILE_HOLD_TIME: float = 6.0    ## seconds he can carry before his grip goes (Ben, 2026-08-16)
const PILE_STUN_TIME: float = 1.4    ## stun on everything involved, thrown and landed-on alike

static func build_barbarian_pile_driver(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	## Phase 0 — HOIST. The grab-and-lift plays once; hit_frame 4 fires the chain-grab. It does
	## NOT set hold_anim_on_reentry — that flag marks a phase as a channel beat (suppresses the
	## runner's recovery release, so the pose freezes for the whole wait), which was originally
	## copied from Guard/Sharpen/Whirlwind-style stationary channels. Pile Driver's hold isn't
	## stationary: PILE_CARRY_SLOW is a move-speed *penalty*, not a lock, so the player is meant
	## to walk around during the up-to-6s hold. Without the flag, the runner's own recovery
	## release (choreo_on_phase_recovery) fires the instant the hoist animation finishes playing,
	## clearing _attack_anim_active early and handing the body back to the locomotion block for
	## the rest of the hold — which is exactly what lets Clerveu's carry_idle/carry_walk sheets
	## (CharacterData "sprite") actually react to movement instead of freezing on the overhead
	## grab. Re-adding hold_anim_on_reentry would silently break that swap by pinning
	## _attack_anim_active true again — see Ben + Clerveu, 2026-08-17: keeping it pinned for the
	## full hold was confirmed a bug, not intended behavior.
	## default_next = -1 means the window lapsing ENDS the graph → choreo_on_chain_timeout, where
	## the host drops the pile (stunned, no damage — the throw is the payoff, holding is not).
	var hoist := ChoreographyPhase.new()
	hoist.animation = "hoist"
	hoist.hit_frame = 4                  ## he closes his hands — the grab chain runs here
	hoist.exit_type = "wait"
	hoist.wait_duration = PILE_HOLD_TIME
	hoist.default_next = -1
	hoist.branches = [ChainFactory._branch_buffered("skill_e", 1)]

	## Phase 1 — HURL. This burst is the CROWD hit at the landing point (the host re-centers it on
	## the clamped aim point, same seam the bomb and torrent use). The damage the thrown bodies
	## themselves take, and the stun on both groups, are applied by the host on arrival — they
	## scale with how many he actually caught, which no static effect resource can know.
	var burst := AreaDamageEffect.new()
	burst.damage_type = dtype
	burst.base_damage = dmg * 1.1
	burst.aoe_radius = 34.0

	var hurl := ChoreographyPhase.new()
	hurl.animation = "hurl"
	hurl.hit_frame = 1                   ## the pack's release flash (sheet frame 9)
	hurl.effects = [burst]
	hurl.exit_type = "anim_finished"
	hurl.default_next = -1
	hurl.is_finisher = true

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [hoist, hurl]
	var a := AbilityDefinition.new()
	a.ability_id = "barbarian_pile_driver"
	a.ability_name = "Pile Driver"
	a.tags = ["Skill", "Offensive"]
	a.mode = "Manual"
	## Longer than the old 5s throw: this is a hard-CC crowd answer now, not a ranged poke.
	a.cooldown_base = 9.0
	a.choreography = choreo
	return a


## Sharpen (Ninja, Q): the long whetstone ritual — 27 frames of commitment for +35% damage
## for 8s. The buff lands near the END of the ritual; getting the full stone in is the skill.
static func build_ninja_sharpen(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "sharpen"
	phase.hit_frame = 22
	phase.effects = [ChainFactory._timed_damage_buff("honed_edge", 0.35, 8.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("ninja_sharpen", "Sharpen", phase, 12.0, "Buff")


## Smoke Bomb (Ninja, E): vanish in the puff — "concealed" for 3.5s (enemies stop chasing;
## same status the Ranger's cloak uses, one long vanish instead of channel ticks).
static func build_ninja_smoke(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "smoke"
	phase.hit_frame = 6
	phase.effects = [ChainFactory._smoke_conceal()]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("ninja_smoke", "Smoke Bomb", phase, 10.0, "Buff")


## Reload (Gunslinger, Q): the long 37-frame cylinder ritual — fresh chambers hit harder:
## +30% damage for 6s, landing near the END of the reload. Interrupt it and get nothing.
static func build_gunslinger_reload(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "reload"
	phase.hit_frame = 30
	phase.effects = [ChainFactory._timed_damage_buff("loaded_chambers", 0.30, 6.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("gunslinger_reload", "Reload", phase, 9.0, "Buff")


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
	phase.effects = [crack]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("gunslinger_whip", "Whip Attack", phase, 6.0)


## Summon Bear (Druid, Q) — Ben 2026-08-01: "what if Q summoned a bear and E summoned 2 hounds".
##
## The Verdant CALLS the forest instead of becoming it. Shapeshifting is gone: he stays the ranged
## caster and the Forest Beast / Forest Hound sheets drive autonomous companions instead of his own
## body. That removes the whole class of problem the transformations had — nothing swaps his
## animation set mid-swing, because nothing swaps his animation set at all.
##
## ONE bear; resummoning replaces it (player._spawn_forest_bear), the single-elite rule the Angry
## Demon follows. The "summon_bear" anim NAME is what the host keys the spawn off, and the small
## nature pulse both reads on cast and guarantees choreo_fire_effects runs so the hook fires.
## Mirrors Rise Corpse / Summon Angry Demon / Spirit Guardians.
static func build_druid_summon_bear(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var pulse := AreaDamageEffect.new()
	pulse.damage_type = dtype
	pulse.base_damage = dmg * 0.3
	pulse.aoe_radius = 26.0

	var phase := ChoreographyPhase.new()
	phase.animation = "summon_bear"
	phase.hit_frame = 4                                    ## the roots open and it climbs out
	phase.effects = [pulse]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("druid_summon_bear", "Summon Bear", phase, 16.0, "Summon")


## Summon Hounds (Druid, E): a PAIR of Forest Hounds, fanned either side of the aim. Faster cooldown
## and far less damage each than the bear — they are pressure and chase, where the bear is an anchor
## that holds ground. Reuses the same cast body under a distinct anim NAME so the host branches to
## the pack spawn instead of the single bear, exactly like the Shade's rise_corpse/bone_legion pair.
static func build_druid_summon_hounds(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var pulse := AreaDamageEffect.new()
	pulse.damage_type = dtype
	pulse.base_damage = dmg * 0.25
	pulse.aoe_radius = 30.0

	var phase := ChoreographyPhase.new()
	phase.animation = "summon_hounds"
	phase.hit_frame = 4
	phase.effects = [pulse]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("druid_summon_hounds", "Summon Hounds", phase, 11.0, "Summon")


## Sanctuary (Cleric, Q): pray — a self-heal plus "blessed" (−20% damage taken for 5s). The
## "pray_heal" body plays the HealingWords overlay; the host routes the HealEffect onto the Devout.
static func build_cleric_sanctuary(_weapon_data: Dictionary) -> AbilityDefinition:
	var phase := ChoreographyPhase.new()
	phase.animation = "pray_heal"
	phase.hit_frame = 11
	phase.effects = [ChainFactory._self_heal(0.12), _ward_buff("blessed", 0.20, 5.0)]
	phase.exit_type = "anim_finished"
	phase.default_next = -1
	return _ability("cleric_sanctuary", "Sanctuary", phase, 12.0, "Buff")


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
	return _ability("cleric_guardians", "Spirit Guardians", phase, 14.0, "Summon")


# --- helpers ---

## Self-applied damage-taken reduction ("blessed"/"steeled"/"hallowed" wards).
##
## The pair is ("All", "damage_taken") and NOT ("damage_taken", "bonus") — that is the whole bug this
## helper shipped with until 2026-08-01. ModifierComponent.sum_modifiers is a plain `tag + ":" + op`
## dictionary lookup with no aliasing, and the only readers of damage reduction are
## DamageCalculator's `sum_modifiers(damage_type, "damage_taken")` and `sum_modifiers("All",
## "damage_taken")`. Nothing anywhere calls `get_stat("damage_taken")`, so a modifier filed under
## ("damage_taken", "bonus") was never read by anything and every ward in the game — Second Wind's
## "steeled", Lay on Hands' "hallowed", Sanctuary's "blessed" — granted exactly zero mitigation.
##
## The failure was silent: no error, no warning, the status applied and displayed normally. The
## magnitude convention is unchanged (DamageCalculator does `raw *= 1.0 + damage_taken`), so -0.20
## still means "take 20% less damage" — it just actually happens now.
static func _ward_buff(id: String, amount: float, duration: float) -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = id
	status.is_positive = true
	status.max_stacks = 1
	status.base_duration = duration
	status.duration_refresh_mode = "overwrite"
	var ward := ModifierDefinition.new()
	ward.target_tag = "All"
	ward.operation = "damage_taken"
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


## `category` is the audio-relevant classification a skill sound plays off of
## (AudioManager._on_ability_used reads tags[1]): "Buff" (self status/heal), "Offensive"
## (damage-dealing cast), "Summon" (spawns a companion), or "Movement" (stance/utility with no
## damage or status payload). It rides the ability's own `tags` field rather than a lookup table
## elsewhere, so it stays next to the rest of the skill's data. Defaults to "Offensive" — the
## commonest shape — so a call site that forgets the arg still gets a sane sound rather than none.
static func _ability(id: String, name: String, phase: ChoreographyPhase, cooldown: float, category: String = "Offensive") -> AbilityDefinition:
	var choreo := ChoreographyDefinition.new()
	choreo.phases = [phase]
	var a := AbilityDefinition.new()
	a.ability_id = id
	a.ability_name = name
	a.tags = ["Skill", category]
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
