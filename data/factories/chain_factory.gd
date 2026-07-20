class_name ChainFactory
extends RefCounted
## Builds melee combo-graph AbilityDefinitions (choreography of attack nodes with input-conditioned
## branches) for the ChoreographyRunner. See docs/combat_chain_architecture.md §1 and
## docs/fighter_kit_spec.md. Numbers here are PROVISIONAL — tune after playtest.
##
## A character's "melee_kit" yields three entry abilities (build_kit), each started at its own
## phase 0 by a different input:
##   light   — LMB:        Attack → Swirl → Tempest (loops); held-LMB Whirlwind; RMB → Cataclysm.
##   heavy   — RMB tap:     Uppercut → Cataclysm (1-2 heavy combo).
##   channel — RMB hold:    Taunt (loops + ticks a shockwave while held; player slow applied by host).
## Cataclysm appears as a node in BOTH light and heavy graphs so it's reachable either way.
##
## Player combo hits are AreaDamageEffects centered on the player (host fires them on [self], so
## EffectDispatcher resolves the AoE around the player and excludes the player). DisplacementEffect
## (Uppercut fling) is dispatched per-enemy by player.choreo_fire_effects.
##
## Radii below are BASE (unmodded) hit zones. They scale with the player's melee_range stat, which
## the player caps at MELEE_RANGE_MAX (2.0) — so a fully Reach-modded Fighter reaches ~2× these,
## the intended "end of the road" size. The swing-effect visual tracks the live radius automatically.

## Shared tuning (provisional)
const CANCEL_WIN: float = 0.75      ## light-chain cancel/buffer window (forgiving; runs from phase
									## ENTRY, so post-anim grace ≈ this minus the swing length —
									## widened 0.55→0.75 after 2026-07-04 feel test)
const HEAVY_WIN: float = 0.55       ## Uppercut → Cataclysm follow-up window
const WHIRL_TICK: float = 0.22      ## one Swirl rotation ≈ Whirlwind tick
const TAUNT_TICK: float = 0.56      ## Taunt anim length (9f @ 16fps) ≈ shockwave tick
const FAN_TICK: float = 0.50        ## Rogue Fan of Blades tick (fan: 15f @ 30fps = 0.5s)
const DICTUM_TICK: float = 0.75     ## Paladin channel tick (dictum/dome: 15f @ 20fps = 0.75s)
const TORRENT_TICK: float = 0.67    ## Wizard Fire Torrent tick (torrent: 20f @ 30fps ≈ 0.67s)
const VAMP_TICK: float = 0.5        ## Blood Mage Vampirize half-cycle (7f @ 14fps = 0.5s)
const CONCEAL_TICK: float = 0.9     ## Ranger Conceal loop (14f @ 16fps ≈ 0.875s crouch cycle)
const SONG_TICK: float = 0.8        ## Bard song beat (16f @ 20fps = 0.8s)
const GUARD_TICK: float = 0.4       ## Barbarian Guard stance re-check beat (the block is host-side)
const BLADES_TICK: float = 0.4      ## Ninja Thousand Blades storm beat (blades body 4f @ 10fps)
const STORM_TICK: float = 0.7       ## Gunslinger Desert Storm volley beat (storm body 14f @ 20fps)
const HOUND_TICK: float = 0.3        ## Druid Hound Frenzy melee beat (hound_attack 4f @ 14fps ≈ 0.29s)
const PRAY_TICK: float = 0.9         ## Cleric Healing Words prayer beat (pray 22f @ 20fps = 1.1s cast)
const WIZARD_CHARGE_MAX: float = 1.6   ## Fireball overcharge cap — auto-releases at full power
const HOLD_ENTER: float = 0.18      ## hold LMB this long → enter Whirlwind
const HOLD_KEEP: float = 0.01       ## still-held check for a channel self-loop


## Dispatcher: { "light", "heavy", "channel" } abilities for a character's melee_kit.
static func build_kit(kit_id: String, weapon_data: Dictionary) -> Dictionary:
	match kit_id:
		"fighter":
			return {
				"light": build_fighter_light(weapon_data),
				"heavy": build_fighter_heavy(weapon_data),
				"channel": build_fighter_taunt(weapon_data),
			}
		"rogue":
			return {
				"light": build_rogue_light(weapon_data),
				"heavy": build_rogue_heavy(weapon_data),
				"channel": build_rogue_fan(weapon_data),
			}
		"paladin":
			return {
				"light": build_paladin_light(weapon_data),
				"heavy": build_paladin_heavy(weapon_data),
				"channel": build_paladin_dome(weapon_data),
			}
		"wizard":
			return {
				"light": build_wizard_light(weapon_data),
				"heavy": build_wizard_summon(weapon_data),
				"channel": build_wizard_torrent(weapon_data),
			}
		"blood_mage":
			return {
				"light": build_blood_mage_light(weapon_data),
				"heavy": build_blood_mage_heavy(weapon_data),
				"channel": build_blood_mage_vampirize(weapon_data),
			}
		"ranger":
			return {
				"light": build_ranger_light(weapon_data),
				"heavy": build_ranger_heavy(weapon_data),
				"channel": build_ranger_conceal(weapon_data),
			}
		"bard":
			return {
				"light": build_bard_light(weapon_data),
				"heavy": build_bard_heavy(weapon_data),
				"channel": build_bard_perform(weapon_data, "ballad"),
			}
		"barbarian":
			return {
				"light": build_barbarian_light(weapon_data),
				"heavy": build_barbarian_heavy(weapon_data),
				"channel": build_barbarian_guard(weapon_data),
			}
		"ninja":
			return {
				"light": build_ninja_light(weapon_data),
				"heavy": build_ninja_burst(weapon_data),
				"channel": build_ninja_storm(weapon_data),
			}
		"gunslinger":
			return {
				"light": build_gunslinger_light(weapon_data),
				"heavy": build_gunslinger_fan(weapon_data),
				"channel": build_gunslinger_desert_storm(weapon_data),
			}
		"druid":
			return {
				"light": build_druid_light(weapon_data),
				"heavy": build_druid_root(weapon_data),
				"channel": build_druid_hound(weapon_data),
			}
		"cleric":
			return {
				"light": build_cleric_light(weapon_data),
				"heavy": build_cleric_heavy(weapon_data),
				"channel": build_cleric_heal(weapon_data),
			}
	return {}


## Back-compat: the light combo alone (some callers/tests use this).
static func build_combo(kit_id: String, weapon_data: Dictionary) -> AbilityDefinition:
	return build_kit(kit_id, weapon_data).get("light")


# --- Fighter: light combo (LMB) ---
## Phase indices: 0 Attack · 1 Swirl · 2 Tempest · 3 Whirlwind · 4 Cataclysm.
static func build_fighter_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Attack (crisp opener). No heavy branch here (Cataclysm gate = depth ≥ Swirl).
	var attack := ChoreographyPhase.new()
	attack.animation = "attack"
	attack.hit_frame = 1
	attack.effects = [_aoe(dtype, dmg * 0.9, 28.0)]
	attack.exit_type = "wait"
	attack.wait_duration = CANCEL_WIN
	attack.default_next = -1
	attack.branches = [
		_branch_held("light_attack", HOLD_ENTER, 3),       # hold → Whirlwind
		_branch_buffered("light_attack", 1),               # tap  → Swirl
	]

	# 1 — Swirl (gate now met → heavy branch available).
	var swirl := ChoreographyPhase.new()
	swirl.animation = "swirl"
	swirl.hit_frame = 1
	swirl.effects = [_aoe(dtype, dmg * 0.7, 30.0)]
	swirl.exit_type = "wait"
	swirl.wait_duration = CANCEL_WIN
	swirl.default_next = -1
	swirl.branches = [
		_branch_held("light_attack", HOLD_ENTER, 3),       # hold → Whirlwind
		_branch_buffered("light_attack", 2),               # tap  → Tempest
		_branch_buffered("heavy_attack", 4),               # RMB  → Cataclysm
	]

	# 2 — Tempest (light finisher; loops back to Attack on a fresh tap).
	var tempest := ChoreographyPhase.new()
	tempest.animation = "tempest"
	tempest.hit_frame = 3
	tempest.effects = [_aoe(dtype, dmg * 1.05, 40.0)]
	tempest.exit_type = "wait"
	tempest.wait_duration = CANCEL_WIN
	tempest.default_next = -1
	tempest.is_finisher = true
	tempest.branches = [
		_branch_buffered("heavy_attack", 4),               # RMB → Cataclysm
		_branch_buffered("light_attack", 0),               # tap → loop to Attack
	]

	# 3 — Whirlwind (held channel; loops via default_next while held, exits on release).
	var whirl := ChoreographyPhase.new()
	whirl.animation = "swirl"
	whirl.hit_frame = 1
	whirl.effects = [_aoe(dtype, dmg * 0.30, 30.0)]
	whirl.exit_type = "wait"
	whirl.wait_duration = WHIRL_TICK
	whirl.default_next = 3
	whirl.branches = [
		_branch_held("light_attack", HOLD_KEEP, -1, true), # released → end
	]

	# 4 — Cataclysm (heavy finisher; terminal).
	var cataclysm := _cataclysm_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [attack, swirl, tempest, whirl, cataclysm]
	return _ability("fighter_light", "Fighter Combo", choreo)


# --- Fighter: heavy combo (RMB tap) ---
## Uppercut → Cataclysm. Phase indices: 0 Uppercut · 1 Cataclysm.
static func build_fighter_heavy(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Uppercut: AoE + arc knockback that flings nearby enemies. RMB again → Cataclysm.
	var up := ChoreographyPhase.new()
	up.animation = "uppercut"
	up.hit_frame = 1
	up.effects = [_aoe(dtype, dmg * 0.6, 35.0), _fling()]
	up.exit_type = "wait"
	up.wait_duration = HEAVY_WIN
	up.default_next = -1
	up.branches = [
		_branch_buffered("heavy_attack", 1),               # RMB → Cataclysm
	]

	# 1 — Cataclysm (shared finisher).
	var cataclysm := _cataclysm_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [up, cataclysm]
	return _ability("fighter_heavy", "Fighter Heavy", choreo)


# --- Fighter: Taunt channel (RMB hold) ---
## Loops the shield-hammer, ticking a shockwave AoE while held. Player slow + ring VFX are applied
## host-side (player.gd) while this ability runs. Single looping node.
static func build_fighter_taunt(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var taunt := ChoreographyPhase.new()
	taunt.animation = "taunt"
	taunt.hit_frame = 5                                     # the shield smack
	taunt.effects = [_aoe(dtype, dmg * 0.5, 46.0)]         # per-tick shockwave (lower; repeats)
	taunt.exit_type = "wait"
	taunt.wait_duration = TAUNT_TICK
	taunt.default_next = 0                                  # tick elapsed & still held → hammer again
	taunt.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [taunt]
	return _ability("fighter_taunt", "Taunt", choreo)


# --- Rogue: light combo (LMB) ---
## The Shade — fast blades ending in a shuriken fan. Tighter radii than the Fighter (a knife, not a
## greatsword) but a longer-reach ranged finisher. No held-LMB channel (Flurry cut after playtest
## 2026-07-04 — felt bad; RMB-hold Fan of Blades remains the kit's channel). Phase indices:
## 0 Slash · 1 Slash II · 2 Shuriken Fan · 3 Bomb.
static func build_rogue_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Slash (crisp opener). No bomb branch here (gate = depth ≥ Slash II).
	var slash := ChoreographyPhase.new()
	slash.animation = "attack"
	slash.hit_frame = 1
	slash.effects = [_aoe(dtype, dmg * 0.9, 26.0)]
	slash.exit_type = "wait"
	slash.wait_duration = CANCEL_WIN
	slash.default_next = -1
	slash.branches = [
		_branch_buffered("light_attack", 1),               # tap → Slash II
	]

	# 1 — Slash II (faster re-slice of the same sheet; gate now met → bomb branch available).
	var slash2 := ChoreographyPhase.new()
	slash2.animation = "attack_2"
	slash2.hit_frame = 1
	slash2.effects = [_aoe(dtype, dmg * 0.7, 26.0)]
	slash2.exit_type = "wait"
	slash2.wait_duration = CANCEL_WIN
	slash2.default_next = -1
	slash2.branches = [
		_branch_buffered("light_attack", 2),               # tap → Shuriken Fan
		_branch_buffered("heavy_attack", 3),               # RMB → Bomb
	]

	# 2 — Shuriken Fan (ranged finisher; loops back to Slash on a fresh tap).
	var fan := ChoreographyPhase.new()
	fan.animation = "fan"
	fan.hit_frame = 7
	fan.effects = [_aoe(dtype, dmg * 1.05, 60.0)]
	fan.exit_type = "wait"
	fan.wait_duration = CANCEL_WIN
	fan.default_next = -1
	fan.is_finisher = true
	fan.branches = [
		_branch_buffered("heavy_attack", 3),               # RMB → Bomb
		_branch_buffered("light_attack", 0),               # tap → loop to Slash
	]

	# 3 — Bomb (heavy finisher; terminal).
	var bomb := _bomb_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [slash, slash2, fan, bomb]
	return _ability("rogue_light", "Shade Combo", choreo)


# --- Rogue: heavy combo (RMB tap) ---
## Shuriken Fan → Bomb. Ranged poke into an area nuke. Phase indices: 0 Fan · 1 Bomb.
static func build_rogue_heavy(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Fan: throw a spread of shurikens; RMB again → Bomb.
	var fan := ChoreographyPhase.new()
	fan.animation = "fan"
	fan.hit_frame = 7
	fan.effects = [_aoe(dtype, dmg * 0.6, 60.0)]
	fan.exit_type = "wait"
	fan.wait_duration = HEAVY_WIN
	fan.default_next = -1
	fan.branches = [
		_branch_buffered("heavy_attack", 1),               # RMB → Bomb
	]

	# 1 — Bomb (shared finisher).
	var bomb := _bomb_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [fan, bomb]
	return _ability("rogue_heavy", "Shade Heavy", choreo)


# --- Rogue: Fan of Blades channel (RMB hold) ---
## Loops the shuriken throw, ticking a wide AoE while held. Player slow is applied host-side
## (player.gd) like the Fighter Taunt. Single looping node.
static func build_rogue_fan(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var fan := ChoreographyPhase.new()
	fan.animation = "fan"
	fan.hit_frame = 7                                       # the release of the spread
	fan.effects = [_aoe(dtype, dmg * 0.5, 60.0)]           # per-tick (lower; repeats)
	fan.exit_type = "wait"
	fan.wait_duration = FAN_TICK
	fan.default_next = 0                                    # tick elapsed & still held → throw again
	fan.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [fan]
	return _ability("rogue_fan", "Fan of Blades", choreo)


# --- Paladin: light combo (LMB) ---
## The Warden — slow, heavy, righteous. Bigger single hits than the Fighter, shield shove control,
## and dictum channels instead of a spin. Phase indices:
## 0 Strike · 1 Strike II · 2 Shield Bash · 3 Blades of Justice · 4 Holy Hammer.
static func build_paladin_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Strike (weighty opener). No hammer branch here (gate = depth ≥ Strike II).
	var strike := ChoreographyPhase.new()
	strike.animation = "attack"
	strike.hit_frame = 2
	strike.effects = [_aoe(dtype, dmg * 1.0, 30.0)]
	strike.exit_type = "wait"
	strike.wait_duration = CANCEL_WIN
	strike.default_next = -1
	strike.branches = [
		_branch_held("light_attack", HOLD_ENTER, 3),       # hold → Blades of Justice
		_branch_buffered("light_attack", 1),               # tap  → Strike II
	]

	# 1 — Strike II (slower re-slice, heavier follow-through; gate now met → hammer available).
	var strike2 := ChoreographyPhase.new()
	strike2.animation = "attack_2"
	strike2.hit_frame = 2
	strike2.effects = [_aoe(dtype, dmg * 0.8, 30.0)]
	strike2.exit_type = "wait"
	strike2.wait_duration = CANCEL_WIN
	strike2.default_next = -1
	strike2.branches = [
		_branch_held("light_attack", HOLD_ENTER, 3),       # hold → Blades of Justice
		_branch_buffered("light_attack", 2),               # tap  → Shield Bash
		_branch_buffered("heavy_attack", 4),               # RMB  → Holy Hammer
	]

	# 2 — Shield Bash (control finisher: damage + flat shove; loops back to Strike on a fresh tap).
	var bash := ChoreographyPhase.new()
	bash.animation = "bash"
	bash.hit_frame = 3
	bash.effects = [_aoe(dtype, dmg * 0.9, 34.0), _shove()]
	bash.exit_type = "wait"
	bash.wait_duration = CANCEL_WIN
	bash.default_next = -1
	bash.is_finisher = true
	bash.branches = [
		_branch_buffered("heavy_attack", 4),               # RMB → Holy Hammer
		_branch_buffered("light_attack", 0),               # tap → loop to Strike
	]

	# 3 — Blades of Justice (held channel; dictum cast loops, orbiting blades tick while held).
	var blades := ChoreographyPhase.new()
	blades.animation = "dictum"
	blades.hit_frame = 7
	blades.effects = [_aoe(dtype, dmg * 0.7, 50.0)]
	blades.exit_type = "wait"
	blades.wait_duration = DICTUM_TICK
	blades.default_next = 3
	blades.hold_anim_on_reentry = true   ## cast once, then the blades fx loops under the frozen body
	blades.branches = [
		_branch_held("light_attack", HOLD_KEEP, -1, true), # released → end
	]

	# 4 — Holy Hammer (heavy finisher; loops on RMB for more hammers).
	var hammer := _hammer_phase(dtype, dmg, 4)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [strike, strike2, bash, blades, hammer]
	return _ability("paladin_light", "Warden Combo", choreo)


# --- Paladin: heavy combo (RMB tap) ---
## Shield Bash → Holy Hammer. Shove them back, then bring the hammer down. 0 Bash · 1 Hammer.
static func build_paladin_heavy(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Shield Bash: shove opener; RMB again → Holy Hammer.
	var bash := ChoreographyPhase.new()
	bash.animation = "bash"
	bash.hit_frame = 3
	bash.effects = [_aoe(dtype, dmg * 0.6, 34.0), _shove()]
	bash.exit_type = "wait"
	bash.wait_duration = HEAVY_WIN
	bash.default_next = -1
	bash.branches = [
		_branch_buffered("heavy_attack", 1),               # RMB → Holy Hammer
	]

	# 1 — Holy Hammer (shared finisher; loops on RMB for more hammers).
	var hammer := _hammer_phase(dtype, dmg, 1)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [bash, hammer]
	return _ability("paladin_heavy", "Warden Heavy", choreo)


# --- Paladin: Reckoning channel (RMB hold) ---
## Plant the shield and dome up: PURE absorb — the dome deals nothing while held (tick damage
## removed 2026-07-20: it killed everything before it could hit the bubble, so nothing ever
## charged the pool). Every hit taken is drunk into the pool (player.take_damage); release —
## or the 30% max-HP cap — detonates stored ×1.5 around the Warden (player._detonate_reckoning).
## Player slow applied host-side like all channels. Single looping node.
static func build_paladin_dome(weapon_data: Dictionary) -> AbilityDefinition:
	var _dmg: float = weapon_data.get("damage", 42.0)   ## unused — the dome absorbs, not deals

	var dome := ChoreographyPhase.new()
	dome.animation = "dome"
	dome.hit_frame = -1                                     # no effects; absorb is host-side
	dome.exit_type = "wait"
	dome.wait_duration = DICTUM_TICK
	dome.default_next = 0                                   # still held → keep the dome up
	dome.hold_anim_on_reentry = true                        # plant once; the dome fx loops on top
	dome.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [dome]
	return _ability("paladin_dome", "Reckoning", choreo)


# --- Wizard: light combo (LMB) — tap bolts, HOLD TO CHARGE the Fireball ---
## The Spark — tap alternates two quick bolt casts (distinct anim names so each re-fires its
## hit frame); holding LMB from either flows into the Charge: the cast anim crawls at
## telegraph speed while the player is slowed (greed is punishable), and releasing — or
## overcharging past the cap — looses a Fireball scaled by charge time (player.gd builds the
## scaled projectile on release). Phase indices: 0 Bolt A · 1 Bolt B · 2 Charge · 3 Release.
static func build_wizard_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Bolt A (crisp cursor bolt).
	var bolt_a := ChoreographyPhase.new()
	bolt_a.animation = "attack"
	bolt_a.hit_frame = 2
	bolt_a.effects = [_wizard_bolt(dtype, dmg * 0.75)]
	bolt_a.exit_type = "wait"
	bolt_a.wait_duration = CANCEL_WIN
	bolt_a.default_next = -1
	bolt_a.branches = [
		_branch_held("light_attack", HOLD_ENTER, 2),       # hold → Charge
		_branch_buffered("light_attack", 1),               # tap  → Bolt B
	]

	# 1 — Bolt B (alternate cast).
	var bolt_b := ChoreographyPhase.new()
	bolt_b.animation = "attack_2"
	bolt_b.hit_frame = 2
	bolt_b.effects = [_wizard_bolt(dtype, dmg * 0.75)]
	bolt_b.exit_type = "wait"
	bolt_b.wait_duration = CANCEL_WIN
	bolt_b.default_next = -1
	bolt_b.branches = [
		_branch_held("light_attack", HOLD_ENTER, 2),       # hold → Charge
		_branch_buffered("light_attack", 0),               # tap  → Bolt A
	]

	# 2 — Charge (held): the fireball cast at telegraph crawl. Release → loose it; holding
	# past the window overcharges and auto-releases at full power.
	var charge := ChoreographyPhase.new()
	charge.animation = "fireball"
	charge.telegraph_speed_scale = 0.3
	charge.hit_frame = -1
	charge.exit_type = "wait"
	charge.wait_duration = WIZARD_CHARGE_MAX
	charge.default_next = 3                                 # overcharge cap → auto-release
	charge.branches = [
		_branch_held("light_attack", HOLD_KEEP, 3, true),  # released → Release
	]

	# 3 — Release: the cast snaps to full speed and the Fireball flies. The base effect here
	# is the floor; player.gd swaps in a charge-scaled copy at the hit frame.
	var release := ChoreographyPhase.new()
	release.animation = "fireball_2"
	release.hit_frame = 6
	release.effects = [_wizard_fireball(dtype, dmg)]
	release.exit_type = "anim_finished"
	release.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [bolt_a, bolt_b, charge, release]
	return _ability("wizard_light", "Spark Combo", choreo)


# --- Wizard: Summon Fire Familiar (RMB tap) ---
## Teleport moved to the DASH input (class-flavored mobility, player.gd), freeing the neutral
## RMB tap for the familiar. Single cast; player.gd spawns/refreshes it on the hit frame.
static func build_wizard_summon(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var summon := ChoreographyPhase.new()
	summon.animation = "summon"
	summon.hit_frame = 8
	summon.effects = [_aoe(dtype, dmg * 0.4, 24.0)]
	summon.exit_type = "anim_finished"
	summon.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [summon]
	return _ability("wizard_summon", "Summon Fire Familiar", choreo)


# --- Wizard: Fire Torrent channel (RMB hold) ---
## Pours flame toward the cursor while held: each cast loop ticks an AoE centered a short way
## ahead of the Spark along the aim direction (player.gd centers it and drives the directional
## Fire_Torrent_Effect overlay). Player slow applied host-side like all channels.
static func build_wizard_torrent(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var torrent := ChoreographyPhase.new()
	torrent.animation = "torrent"
	torrent.hit_frame = 7                                   # the flame pours out
	torrent.effects = [_aoe(dtype, dmg * 0.55, 30.0)]      # per-tick (lower; repeats)
	torrent.exit_type = "wait"
	torrent.wait_duration = TORRENT_TICK
	torrent.default_next = 0                                # still held → keep pouring
	torrent.hold_anim_on_reentry = true                     # hold the pour pose; the flame fx loops
	torrent.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [torrent]
	return _ability("wizard_torrent", "Fire Torrent", choreo)


# --- Blood Mage: light combo (LMB) ---
## The Cursed — blood pays for power. Cursor-aimed shard projectiles into a 3-shard volley;
## held LMB mid-chain sacrifices HP for Extract Power (+damage buff); gated mid-combo RMB
## summons the Blood Elemental. Phase indices:
## 0 Shard · 1 Shard II · 2 Blood Shards volley · 3 Extract Power · 4 Summon Blood Elemental.
static func build_blood_mage_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Shard (crisp opener: single blood shard at the cursor).
	var shard := ChoreographyPhase.new()
	shard.animation = "attack"
	shard.hit_frame = 2
	shard.effects = [_blood_shard(dtype, dmg * 0.7)]
	shard.exit_type = "wait"
	shard.wait_duration = CANCEL_WIN
	shard.default_next = -1
	shard.branches = [
		_branch_held("light_attack", HOLD_ENTER, 3),       # hold → Extract Power
		_branch_buffered("light_attack", 1),               # tap  → Shard II
	]

	# 1 — Shard II (gate now met → elemental available).
	var shard2 := ChoreographyPhase.new()
	shard2.animation = "attack_2"
	shard2.hit_frame = 2
	shard2.effects = [_blood_shard(dtype, dmg * 0.6)]
	shard2.exit_type = "wait"
	shard2.wait_duration = CANCEL_WIN
	shard2.default_next = -1
	shard2.branches = [
		_branch_held("light_attack", HOLD_ENTER, 3),       # hold → Extract Power
		_branch_buffered("light_attack", 2),               # tap  → Blood Shards volley
		_branch_buffered("heavy_attack", 4),               # RMB  → Summon Blood Elemental
	]

	# 2 — Blood Shards volley (finisher: 3-shard spread; loops back to Shard on a fresh tap).
	var volley := ChoreographyPhase.new()
	volley.animation = "shards"
	volley.hit_frame = 5
	volley.effects = [_blood_shard_volley(dtype, dmg * 0.55)]
	volley.exit_type = "wait"
	volley.wait_duration = CANCEL_WIN
	volley.default_next = -1
	volley.is_finisher = true
	volley.branches = [
		_branch_buffered("heavy_attack", 4),               # RMB → Summon Blood Elemental
		_branch_buffered("light_attack", 0),               # tap → loop to Shard
	]

	# 3 — Extract Power (held-LMB pact: player.gd pays 5% max HP on this hit_frame; the
	# self-applied status buffs damage for its duration). Terminal.
	var extract := ChoreographyPhase.new()
	extract.animation = "extract"
	extract.hit_frame = 4
	extract.effects = [_blood_power_buff()]
	extract.exit_type = "anim_finished"
	extract.default_next = -1

	# 4 — Summon Blood Elemental (gated finisher; terminal). Ignition burst fires here;
	# player.gd spawns/refreshes the BloodElemental on the same hit_frame.
	var summon := ChoreographyPhase.new()
	summon.animation = "summon_blood"
	summon.hit_frame = 10
	summon.effects = [_aoe(dtype, dmg * 0.4, 24.0)]
	summon.exit_type = "anim_finished"
	summon.default_next = -1
	summon.is_finisher = true

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [shard, shard2, volley, extract, summon]
	return _ability("blood_mage_light", "Cursed Combo", choreo)


# --- Blood Mage: heavy combo (RMB tap) ---
## Blood Slam → Blood Spikes. Close-range eruption into a bigger one (player.gd spawns the
## Blood_Spikes_AOE ground burst at the spikes' hit-zone radius). 0 Slam · 1 Spikes.
static func build_blood_mage_heavy(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var slam := ChoreographyPhase.new()
	slam.animation = "slam"
	slam.hit_frame = 3
	slam.effects = [_aoe(dtype, dmg * 1.2, 42.0)]
	slam.exit_type = "wait"
	slam.wait_duration = HEAVY_WIN
	slam.default_next = -1
	slam.branches = [
		_branch_buffered("heavy_attack", 1),               # RMB → Blood Spikes
	]

	var spikes := ChoreographyPhase.new()
	spikes.animation = "spikes"
	spikes.hit_frame = 5
	spikes.effects = [_aoe(dtype, dmg * 1.7, 55.0)]
	spikes.exit_type = "anim_finished"
	spikes.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [slam, spikes]
	return _ability("blood_mage_heavy", "Cursed Heavy", choreo)


# --- Blood Mage: Vampirize channel (RMB hold) ---
## Two-beat drain loop using both Vampirize casts: Extract_Blood rips blood out (damage tick),
## Consume_Blood drinks it (player.gd heals if the extract connected, with drain-wisp VFX).
## Player slow applied host-side like all channels. 0 extract-beat · 1 consume-beat.
static func build_blood_mage_vampirize(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var rip := ChoreographyPhase.new()
	rip.animation = "vampirize"
	rip.hit_frame = 3
	rip.effects = [_aoe(dtype, dmg * 0.45, 50.0)]
	rip.exit_type = "wait"
	rip.wait_duration = VAMP_TICK
	rip.default_next = 1                                    # into the consume beat
	rip.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var drink := ChoreographyPhase.new()
	drink.animation = "consume"
	drink.hit_frame = 3
	drink.effects = [_aoe(dtype, dmg * 0.15, 40.0)]        # the consumed blood bursts
	drink.exit_type = "wait"
	drink.wait_duration = VAMP_TICK
	drink.default_next = 0                                  # back to the extract beat
	drink.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [rip, drink]
	return _ability("blood_mage_vampirize", "Vampirize", choreo)


# --- Ranger: light combo (LMB) ---
## The Scavenger — the bow escalates: one arrow, two, three. Cursor-aimed volleys through the
## real arrow projectile grids. Phase indices: 0 Shot · 1 Double Shot · 2 Triple Shot · 3 Knife.
static func build_ranger_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Shot (single arrow opener).
	var shot := ChoreographyPhase.new()
	shot.animation = "attack"
	shot.hit_frame = 6
	shot.effects = [_arrow_volley(dtype, dmg * 0.8, 1, 0.0)]
	shot.exit_type = "wait"
	shot.wait_duration = CANCEL_WIN
	shot.default_next = -1
	shot.branches = [
		_branch_buffered("light_attack", 1),               # tap → Double Shot
	]

	# 1 — Double Shot (two arrows, tight pair; gate now met → knife available).
	var double_shot := ChoreographyPhase.new()
	double_shot.animation = "double_shot"
	double_shot.hit_frame = 6
	double_shot.effects = [_arrow_volley(dtype, dmg * 0.55, 2, 10.0)]
	double_shot.exit_type = "wait"
	double_shot.wait_duration = CANCEL_WIN
	double_shot.default_next = -1
	double_shot.branches = [
		_branch_buffered("light_attack", 2),               # tap → Triple Shot
		_branch_buffered("heavy_attack", 3),               # RMB → Throwing Knife
	]

	# 2 — Triple Shot (fan finisher; loops back to Shot on a fresh tap).
	var triple_shot := ChoreographyPhase.new()
	triple_shot.animation = "triple_shot"
	triple_shot.hit_frame = 6
	triple_shot.effects = [_arrow_volley(dtype, dmg * 0.5, 3, 22.0)]
	triple_shot.exit_type = "wait"
	triple_shot.wait_duration = CANCEL_WIN
	triple_shot.default_next = -1
	triple_shot.is_finisher = true
	triple_shot.branches = [
		_branch_buffered("heavy_attack", 3),               # RMB → Throwing Knife
		_branch_buffered("light_attack", 0),               # tap → loop to Shot
	]

	# 3 — Throwing Knife (gated finisher; terminal): heavy spinning knife that skewers
	# through one victim and lands with the knife-on-the-ground sheet.
	var knife := ChoreographyPhase.new()
	knife.animation = "knife"
	knife.hit_frame = 6
	knife.effects = [_throwing_knife(dtype, dmg * 1.2)]
	knife.exit_type = "anim_finished"
	knife.default_next = -1
	knife.is_finisher = true

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [shot, double_shot, triple_shot, knife]
	return _ability("ranger_light", "Scavenger Combo", choreo)


# --- Ranger: melee string (RMB tap) ---
## The "back off" knives: Single Melee → Double Melee, both with frame-matched effect
## overlays. 0 Melee · 1 Double Melee.
static func build_ranger_heavy(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var melee := ChoreographyPhase.new()
	melee.animation = "melee"
	melee.hit_frame = 2
	melee.effects = [_aoe(dtype, dmg * 0.9, 26.0)]
	melee.exit_type = "wait"
	melee.wait_duration = HEAVY_WIN
	melee.default_next = -1
	melee.branches = [
		_branch_buffered("heavy_attack", 1),               # RMB → Double Melee
	]

	var melee2 := ChoreographyPhase.new()
	melee2.animation = "melee_2"
	melee2.hit_frame = 2
	melee2.effects = [_aoe(dtype, dmg * 1.3, 30.0)]
	melee2.exit_type = "anim_finished"
	melee2.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [melee, melee2]
	return _ability("ranger_heavy", "Scavenger Melee", choreo)


# --- Ranger: Conceal channel (RMB hold) ---
## Crouch under the cloak: each loop refreshes the "concealed" status (player.is_invisible —
## enemies stop chasing) while held. No damage; the payoff is disappearing from the horde.
## Player slow applied host-side like all channels (moving while concealed is slow, fittingly).
static func build_ranger_conceal(weapon_data: Dictionary) -> AbilityDefinition:
	var _dmg: float = weapon_data.get("damage", 42.0)   ## unused — conceal deals no damage

	var conceal := ChoreographyPhase.new()
	conceal.animation = "conceal"
	conceal.hit_frame = -1                                  # refresh on every loop entry
	conceal.effects = [_concealed_status()]
	conceal.exit_type = "wait"
	conceal.wait_duration = CONCEAL_TICK
	conceal.default_next = 0                                # still held → stay hidden
	conceal.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [conceal]
	return _ability("ranger_conceal", "Conceal", choreo)


# --- Bard: light combo (LMB) ---
## The Herald — the sound leads, the blade punctuates (flow flipped per Ben 2026-07-19: the
## ranged character plays ranged by DEFAULT, no melee gate in front of the chord). Tap = a
## chord bolt immediately; two chords into the melee Strike payoff up close. Phase indices:
## 0 Chord · 1 Chord II · 2 Strike (finisher) · 3 Apotheosis.
static func build_bard_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Chord (sound-bolt opener at the cursor).
	var chord := ChoreographyPhase.new()
	chord.animation = "chord"
	chord.hit_frame = 6
	chord.effects = [_chord_bolt(dtype, dmg * 0.85)]
	chord.exit_type = "wait"
	chord.wait_duration = CANCEL_WIN
	chord.default_next = -1
	chord.branches = [
		_branch_buffered("light_attack", 1),               # tap → Chord II
	]

	# 1 — Chord II (re-slice under a distinct name so the cast re-fires; gate now met).
	var chord2 := ChoreographyPhase.new()
	chord2.animation = "chord_2"
	chord2.hit_frame = 6
	chord2.effects = [_chord_bolt(dtype, dmg * 0.85)]
	chord2.exit_type = "wait"
	chord2.wait_duration = CANCEL_WIN
	chord2.default_next = -1
	chord2.branches = [
		_branch_buffered("light_attack", 2),               # tap → Strike
		_branch_buffered("heavy_attack", 3),               # RMB → Apotheosis
	]

	# 2 — Strike (melee finisher: the instrument comes down; loops back to Chord on a tap).
	var strike := ChoreographyPhase.new()
	strike.animation = "attack"
	strike.hit_frame = 1
	strike.effects = [_aoe(dtype, dmg * 1.2, 30.0)]
	strike.exit_type = "wait"
	strike.wait_duration = CANCEL_WIN
	strike.default_next = -1
	strike.is_finisher = true
	strike.branches = [
		_branch_buffered("heavy_attack", 3),               # RMB → Apotheosis
		_branch_buffered("light_attack", 0),               # tap → loop to Chord
	]

	# 3 — Apotheosis (gated finisher; terminal): divine burst + a self damage buff, with the
	# frame-matched ApotheosisEffect overlay.
	var apo := _apotheosis_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [chord, chord2, strike, apo]
	return _ability("bard_light", "Herald Combo", choreo)


# --- Bard: heavy combo (RMB tap) ---
## Vicious Mockery → Apotheosis: insult the crowd (AoE + damage-down debuff on everyone hit),
## then ascend. 0 Mockery · 1 Apotheosis.
static func build_bard_heavy(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var mockery := ChoreographyPhase.new()
	mockery.animation = "mockery"
	mockery.hit_frame = 8
	mockery.effects = [_aoe(dtype, dmg * 0.6, 70.0), _mocked_debuff()]
	mockery.exit_type = "wait"
	mockery.wait_duration = HEAVY_WIN
	mockery.default_next = -1
	mockery.branches = [
		_branch_buffered("heavy_attack", 1),               # RMB → Apotheosis
	]

	var apo := _apotheosis_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [mockery, apo]
	return _ability("bard_heavy", "Herald Heavy", choreo)


# --- Bard: Perform (RMB hold) — plays the ACTIVE song, chosen with Q ---
## Song stances (2026-07-05 control-scheme pass): Q cycles the song in the Herald's heart
## (player.gd rebuilds this channel), RMB-hold performs it loudly. Ballad heals per beat
## (host-side, floating notes); Enhancement refreshes the +damage buff — either way the song
## only works while he plays it.
static func build_bard_perform(weapon_data: Dictionary, song: String) -> AbilityDefinition:
	var _dmg: float = weapon_data.get("damage", 42.0)   ## unused — songs don't damage

	var beat := ChoreographyPhase.new()
	beat.animation = "song_ballad" if song == "ballad" else "song_enhance"
	beat.hit_frame = -1                                     # fire on every beat entry
	beat.effects = [_song_marker() if song == "ballad" else _enhancement_buff()]
	beat.exit_type = "wait"
	beat.wait_duration = SONG_TICK
	beat.default_next = 0                                   # still held → keep playing
	beat.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [beat]
	return _ability("bard_perform_" + song, "Perform: " + song.capitalize(), choreo)


## Ballad's per-beat marker status (no modifiers — the heal itself is host-side; this keeps
## the beat's effects non-empty and leaves a visible "song active" status on the player).
static func _song_marker() -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = "ballad_song"
	status.is_positive = true
	status.max_stacks = 1
	status.base_duration = 1.2
	status.duration_refresh_mode = "overwrite"
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	apply.apply_to_self = true
	return apply


## Charming Serenade (E skill): charmed enemies fight for the Herald — enemy.gd routes their
## chase/strikes at other enemies while this status runs. Applied host-side to the nearest
## few victims (with heart wisps), not broadcast to everything in range.
static func _charm_effect() -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = "charmed"
	status.is_positive = false
	status.max_stacks = 1
	status.base_duration = 5.0
	status.duration_refresh_mode = "overwrite"
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	apply.apply_to_self = false
	return apply


# --- Barbarian: light combo (LMB) ---
## The Ravager — raw weight of steel. Two cleaves into the ground-breaking Sunder; gated
## mid-combo RMB flows into the Thunder Blade. Phase indices:
## 0 Cleave · 1 Cleave II · 2 Sunder · 3 Thunder Blade.
static func build_barbarian_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Cleave (weighty opener). No thunder branch here (gate = depth ≥ Cleave II).
	var cleave := ChoreographyPhase.new()
	cleave.animation = "attack"
	cleave.hit_frame = 2
	cleave.effects = [_aoe(dtype, dmg * 1.0, 32.0)]
	cleave.exit_type = "wait"
	cleave.wait_duration = CANCEL_WIN
	cleave.default_next = -1
	cleave.branches = [
		_branch_buffered("light_attack", 1),               # tap → Cleave II
	]

	# 1 — Cleave II (faster re-slice of the same sheet; gate now met → thunder available).
	var cleave2 := ChoreographyPhase.new()
	cleave2.animation = "attack_2"
	cleave2.hit_frame = 2
	cleave2.effects = [_aoe(dtype, dmg * 0.8, 32.0)]
	cleave2.exit_type = "wait"
	cleave2.wait_duration = CANCEL_WIN
	cleave2.default_next = -1
	cleave2.branches = [
		_branch_buffered("light_attack", 2),               # tap → Sunder
		_branch_buffered("heavy_attack", 3),               # RMB → Thunder Blade
	]

	# 2 — Sunder (ground-breaker finisher: AoE + shove; loops back to Cleave on a fresh tap).
	var sunder := ChoreographyPhase.new()
	sunder.animation = "sunder"
	sunder.hit_frame = 3
	sunder.effects = [_aoe(dtype, dmg * 1.4, 48.0), _shove()]
	sunder.exit_type = "wait"
	sunder.wait_duration = CANCEL_WIN
	sunder.default_next = -1
	sunder.is_finisher = true
	sunder.branches = [
		_branch_buffered("heavy_attack", 3),               # RMB → Thunder Blade
		_branch_buffered("light_attack", 0),               # tap → loop to Cleave
	]

	# 3 — Thunder Blade (heavy finisher; terminal).
	var thunder := _thunder_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [cleave, cleave2, sunder, thunder]
	return _ability("barbarian_light", "Ravager Combo", choreo)


# --- Barbarian: heavy combo (RMB tap) ---
## Sunder → Thunder Blade: crack the ground, then the sky answers. 0 Sunder · 1 Thunder.
static func build_barbarian_heavy(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var sunder := ChoreographyPhase.new()
	sunder.animation = "sunder"
	sunder.hit_frame = 3
	sunder.effects = [_aoe(dtype, dmg * 0.7, 44.0), _shove()]
	sunder.exit_type = "wait"
	sunder.wait_duration = HEAVY_WIN
	sunder.default_next = -1
	sunder.branches = [
		_branch_buffered("heavy_attack", 1),               # RMB → Thunder Blade
	]

	var thunder := _thunder_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [sunder, thunder]
	return _ability("barbarian_heavy", "Ravager Heavy", choreo)


# --- Barbarian: Guard channel (RMB hold) ---
## Sword up, feet planted: while held, ALL damage from the frontal arc is blocked outright —
## player.take_damage checks the arc host-side and flashes the pack's BlockImpact sheet on
## every stopped hit. (Throw Things moved to the E skill, Ben feel test 2026-07-05.) The
## raise anim freezes on its last frame across self-loops (same-name play() is a no-op), so
## the sword just stays up. Player slow applied host-side like all channels.
static func build_barbarian_guard(weapon_data: Dictionary) -> AbilityDefinition:
	var _dmg: float = weapon_data.get("damage", 42.0)   ## unused — the block deals no damage

	var guard := ChoreographyPhase.new()
	guard.animation = "guard"
	guard.hit_frame = -1                                    # no effects; the block is host-side
	guard.exit_type = "wait"
	guard.wait_duration = GUARD_TICK
	guard.default_next = 0                                  # still held → keep the sword up
	guard.hold_anim_on_reentry = true                       # raise once, stay frozen at the top
	guard.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [guard]
	return _ability("barbarian_guard", "Guard", choreo)


## Shared Thunder Blade finisher: the lightning-wreathed swing lands a melee AoE AND looses
## the package's own 4-frame directional lightning projectile at the cursor. The bolt is
## Lightning by definition (the thunder is the point), independent of the weapon's element.
static func _thunder_phase(dtype: String, dmg: float) -> ChoreographyPhase:
	var t := ChoreographyPhase.new()
	t.animation = "thunder"
	t.hit_frame = 11                                        # the swing releases
	t.effects = [_aoe(dtype, dmg * 1.2, 40.0), _thunder_bolt(dmg * 0.9)]
	t.exit_type = "anim_finished"
	t.default_next = -1
	t.is_finisher = true
	return t


## Thunder Blade bolt: 4-frame directional lightning (the pack's own projectile grids).
static func _thunder_bolt(hit_damage: float) -> SpawnProjectilesEffect:
	var cfg := ProjectileConfig.new()
	cfg.motion_type = "directional"
	cfg.speed = 300.0
	cfg.max_range = 230.0
	cfg.hit_radius = 8.0
	cfg.sprite_frames = _get_thunder_proj_frames()
	cfg.use_directional_anims = true
	var hit := DealDamageEffect.new()
	hit.damage_type = "Lightning"
	hit.base_damage = hit_damage
	cfg.on_hit_effects = [hit]
	var e := SpawnProjectilesEffect.new()
	e.projectile = cfg
	e.spawn_pattern = "aimed_single"
	e.count = 1
	return e


## Battle Cry's fear-of-the-loud: enemies nearby stagger at -35% move speed for 3s.
static func _shaken_debuff() -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = "shaken"
	status.is_positive = false
	status.max_stacks = 1
	status.base_duration = 3.0
	status.duration_refresh_mode = "overwrite"
	var slow := ModifierDefinition.new()
	slow.target_tag = "move_speed"
	slow.operation = "bonus"
	slow.value = -0.35
	slow.source_name = "shaken"
	status.modifiers = [slow]
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	apply.apply_to_self = false
	return apply


# --- Ninja: light combo (LMB) ---
## The Whisper — two knife-quick slashes (both with the pack's frame-matched Attack_Effect
## gleam), looping; gated mid-combo RMB erupts into the Thousand Blades burst. Phase indices:
## 0 Slash · 1 Slash II · 2 Storm Start · 3 Storm · 4 Storm End.
static func build_ninja_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Slash (knife-quick opener). No storm branch here (gate = depth ≥ Slash II).
	var slash := ChoreographyPhase.new()
	slash.animation = "attack"
	slash.hit_frame = 2
	slash.effects = [_aoe(dtype, dmg * 0.9, 26.0)]
	slash.exit_type = "wait"
	slash.wait_duration = CANCEL_WIN
	slash.default_next = -1
	slash.branches = [
		_branch_buffered("light_attack", 1),               # tap → Slash II
	]

	# 1 — Slash II (faster re-slice; gate now met → storm available; loops back on a tap).
	var slash2 := ChoreographyPhase.new()
	slash2.animation = "attack_2"
	slash2.hit_frame = 2
	slash2.effects = [_aoe(dtype, dmg * 0.7, 26.0)]
	slash2.exit_type = "wait"
	slash2.wait_duration = CANCEL_WIN
	slash2.default_next = -1
	slash2.branches = [
		_branch_buffered("heavy_attack", 2),               # RMB → Thousand Blades burst
		_branch_buffered("light_attack", 0),               # tap → loop to Slash
	]

	var phases: Array[ChoreographyPhase] = [slash, slash2]
	phases.append_array(_blade_burst_phases(dtype, dmg, 2))

	var choreo := ChoreographyDefinition.new()
	choreo.phases = phases
	return _ability("ninja_light", "Whisper Combo", choreo)


# --- Ninja: Thousand Blades burst (RMB tap) ---
## Crouch → one blade storm → flourish out. 0 Start · 1 Storm · 2 End.
static func build_ninja_burst(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)
	var choreo := ChoreographyDefinition.new()
	choreo.phases = _blade_burst_phases(dtype, dmg, 0)
	return _ability("ninja_burst", "Thousand Blades", choreo)


## Shared burst trio starting at `base` index: Start (wind-up crouch, no hit) → Storm (the
## blade nova, Thousand_Blades_Effect riding the ComboFx overlay) → End (flourish, smaller hit).
static func _blade_burst_phases(dtype: String, dmg: float, base: int) -> Array[ChoreographyPhase]:
	var start := ChoreographyPhase.new()
	start.animation = "blades_start"
	start.hit_frame = -1
	start.exit_type = "anim_finished"
	start.default_next = base + 1

	var storm := ChoreographyPhase.new()
	storm.animation = "blades"
	storm.hit_frame = 2
	storm.effects = [_aoe(dtype, dmg * 1.4, 50.0)]
	storm.exit_type = "anim_finished"
	storm.default_next = base + 2
	storm.is_finisher = true

	var end := ChoreographyPhase.new()
	end.animation = "blades_end"
	end.hit_frame = 1
	end.effects = [_aoe(dtype, dmg * 0.6, 40.0)]
	end.exit_type = "anim_finished"
	end.default_next = -1

	return [start, storm, end]


# --- Ninja: Thousand Blades storm channel (RMB hold) ---
## The sustained version: crouch in, then the storm ticks while held, flourishing out on
## release — the first channel with a real intro and outro. Player slow applied host-side.
## 0 Start · 1 Storm loop · 2 End.
static func build_ninja_storm(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var start := ChoreographyPhase.new()
	start.animation = "blades_start"
	start.hit_frame = -1
	start.exit_type = "anim_finished"
	start.default_next = 1

	var storm := ChoreographyPhase.new()
	storm.animation = "blades"
	storm.hit_frame = 2
	storm.effects = [_aoe(dtype, dmg * 0.5, 50.0)]          # per-tick (lower; repeats)
	storm.exit_type = "wait"
	storm.wait_duration = BLADES_TICK
	storm.default_next = 1                                  # still held → keep storming
	storm.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, 2, true),  # released → flourish out
	]

	var end := ChoreographyPhase.new()
	end.animation = "blades_end"
	end.hit_frame = 1
	end.effects = [_aoe(dtype, dmg * 0.6, 45.0)]
	end.exit_type = "anim_finished"
	end.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [start, storm, end]
	return _ability("ninja_storm", "Thousand Blades Storm", choreo)


## Smoke Bomb conceal: same "concealed" status the Ranger's cloak uses (player.is_invisible —
## enemies stop chasing) but one long vanish that lasts until the Whisper ATTACKS (host drops
## the status on any damaging combo/skill/dash-strike; the duration is just the safety cap).
static func _smoke_conceal() -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = "concealed"
	status.is_positive = true
	status.max_stacks = 1
	status.base_duration = 8.0
	status.duration_refresh_mode = "overwrite"
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	apply.apply_to_self = true
	return apply


# --- Gunslinger: light combo (LMB) ---
## The Deadeye — every tap is a trigger pull: two alternating shot casts (distinct names so
## each re-fires), each loosing one fast bullet with the pack's impact burst; gated mid-combo
## RMB fans the hammer. Phase indices: 0 Shot · 1 Shot II · 2 Fan the Hammer.
static func build_gunslinger_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Shot (single crisp bullet at the cursor).
	var shot := ChoreographyPhase.new()
	shot.animation = "attack"
	shot.hit_frame = 3
	shot.effects = [_gun_bullet(dtype, dmg * 0.85)]
	shot.exit_type = "wait"
	shot.wait_duration = CANCEL_WIN
	shot.default_next = -1
	shot.branches = [
		_branch_buffered("light_attack", 1),               # tap → Shot II
	]

	# 1 — Shot II (alternate pull; gate now met → fan available; loops back on a tap).
	var shot2 := ChoreographyPhase.new()
	shot2.animation = "attack_2"
	shot2.hit_frame = 3
	shot2.effects = [_gun_bullet(dtype, dmg * 0.85)]
	shot2.exit_type = "wait"
	shot2.wait_duration = CANCEL_WIN
	shot2.default_next = -1
	shot2.branches = [
		_branch_buffered("heavy_attack", 2),               # RMB → Fan the Hammer
		_branch_buffered("light_attack", 0),               # tap → loop to Shot
	]

	# 2 — Fan the Hammer (gated finisher; terminal).
	var fan := _fan_hammer_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [shot, shot2, fan]
	return _ability("gunslinger_light", "Deadeye Combo", choreo)


# --- Gunslinger: Fan the Hammer (RMB tap) ---
## The whole cylinder at once: 5 bullets in a wide fan, each landing with the FTH impact.
static func build_gunslinger_fan(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)
	var choreo := ChoreographyDefinition.new()
	choreo.phases = [_fan_hammer_phase(dtype, dmg)]
	return _ability("gunslinger_fan", "Fan the Hammer", choreo)


static func _fan_hammer_phase(dtype: String, dmg: float) -> ChoreographyPhase:
	var fan := ChoreographyPhase.new()
	fan.animation = "fan"
	fan.hit_frame = 6                                       # the hammer blurs
	fan.effects = [_fan_bullets(dtype, dmg * 0.45)]
	fan.exit_type = "anim_finished"
	fan.default_next = -1
	fan.is_finisher = true
	return fan


# --- Gunslinger: Desert Storm channel (RMB hold) ---
## Lead pours toward the cursor while held: each loop volleys a tight bullet cone, with the
## pack's directional Desert Storm barrage strip blazing ahead of the Deadeye (host overlay,
## torrent-style). Player slow applied host-side like all channels.
static func build_gunslinger_desert_storm(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var storm := ChoreographyPhase.new()
	storm.animation = "storm"
	storm.hit_frame = 5                                     # the barrels open up
	storm.effects = [_storm_bullets(dtype, dmg * 0.35)]    # per-tick cone (lower; repeats)
	storm.exit_type = "wait"
	storm.wait_duration = STORM_TICK
	storm.default_next = 0                                  # still held → keep firing
	storm.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [storm]
	return _ability("gunslinger_storm", "Desert Storm", choreo)


# --- Druid: light combo (LMB) ---
## The Verdant — nature strikes that finish by flickering into a form: the Beast maul (morph →
## claw) or, gated mid-combo, the Owl swoop. Forms-as-stances (design §2.8): the morph sheets are
## the finisher wind-ups; the form's own Attack sheet is the strike. Phase indices:
## 0 Claw · 1 Claw II · 2 Beast morph · 3 Beast Maul · 4 Owl morph · 5 Owl Swoop.
static func build_druid_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Claw (crisp opener). No form branch here (gate = depth ≥ Claw II).
	var claw := ChoreographyPhase.new()
	claw.animation = "attack"
	claw.hit_frame = 1
	claw.effects = [_aoe(dtype, dmg * 0.9, 28.0)]
	claw.exit_type = "wait"
	claw.wait_duration = CANCEL_WIN
	claw.default_next = -1
	claw.branches = [
		_branch_buffered("light_attack", 2),               # tap → Beast morph (into the maul)
	]

	# 1 — (unused index kept for readability) — collapsed; see phases array below.

	# 2 — Beast morph (wind-up, no hit): the Verdant flickers into the Forest Beast.
	var morph_beast := ChoreographyPhase.new()
	morph_beast.animation = "morph_beast"
	morph_beast.hit_frame = -1
	morph_beast.exit_type = "anim_finished"
	morph_beast.default_next = 3

	# 3 — Beast Maul (finisher: heavy claw AoE + shove; loops back to Claw on a fresh tap).
	var maul := ChoreographyPhase.new()
	maul.animation = "beast_attack"
	maul.hit_frame = 2
	maul.effects = [_aoe(dtype, dmg * 1.3, 46.0), _shove()]
	maul.exit_type = "wait"
	maul.wait_duration = CANCEL_WIN
	maul.default_next = -1
	maul.is_finisher = true
	maul.branches = [
		_branch_buffered("heavy_attack", 4),               # RMB → Owl Swoop
		_branch_buffered("light_attack", 0),               # tap → loop to Claw
	]

	# 4 — Owl morph (wind-up, no hit).
	var morph_owl := ChoreographyPhase.new()
	morph_owl.animation = "morph_owl"
	morph_owl.hit_frame = -1
	morph_owl.exit_type = "anim_finished"
	morph_owl.default_next = 5

	# 5 — Owl Swoop (gated finisher; terminal): a wide diving rake (no owl projectile in-pack, so
	# the swoop is a broad melee arc rather than a bolt).
	var swoop := ChoreographyPhase.new()
	swoop.animation = "owl_attack"
	swoop.hit_frame = 2
	swoop.effects = [_aoe(dtype, dmg * 1.2, 52.0)]
	swoop.exit_type = "anim_finished"
	swoop.default_next = -1
	swoop.is_finisher = true

	# 1 — Claw II (faster re-slice; gate now met → Owl branch available). Declared here so the
	# phases array reads 0..5 in index order.
	var claw2 := ChoreographyPhase.new()
	claw2.animation = "attack_2"
	claw2.hit_frame = 1
	claw2.effects = [_aoe(dtype, dmg * 0.7, 28.0)]
	claw2.exit_type = "wait"
	claw2.wait_duration = CANCEL_WIN
	claw2.default_next = -1
	claw2.branches = [
		_branch_buffered("light_attack", 2),               # tap → Beast morph
		_branch_buffered("heavy_attack", 4),               # RMB → Owl morph
	]
	# Claw's tap should reach Claw II first — repoint it now that claw2 exists at index 1.
	claw.branches = [_branch_buffered("light_attack", 1)]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [claw, claw2, morph_beast, maul, morph_owl, swoop]
	return _ability("druid_light", "Verdant Combo", choreo)


# --- Druid: Root Summoning (RMB tap) ---
## Call the roots up at the cursor: a snaring + Nature-DoT GroundZone. The host places the zone at
## the clamped aim point and drops the RootAttack decal there.
static func build_druid_root(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var cast := ChoreographyPhase.new()
	cast.animation = "root_cast"
	cast.hit_frame = 4
	cast.effects = [_root_zone(dtype, dmg)]
	cast.exit_type = "anim_finished"
	cast.default_next = -1
	cast.is_finisher = true

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [cast]
	return _ability("druid_root", "Root Summoning", choreo)


# --- Druid: Hound Frenzy channel (RMB hold) ---
## Fight as the forest hound: fast close melee ticks while held. Player slow host-side like all
## channels. Single looping node.
static func build_druid_hound(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var hound := ChoreographyPhase.new()
	hound.animation = "hound_attack"
	hound.hit_frame = 2
	hound.effects = [_aoe(dtype, dmg * 0.4, 30.0)]         # per-tick (lower; repeats)
	hound.exit_type = "wait"
	hound.wait_duration = HOUND_TICK
	hound.default_next = 0                                  # still held → keep worrying the horde
	hound.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [hound]
	return _ability("druid_hound", "Hound Frenzy", choreo)


## Root Summoning zone: snare (−60% move_speed, refreshed each tick) + Nature DoT for 4 s.
static func _root_zone(dtype: String, dmg: float) -> GroundZoneEffect:
	var z := GroundZoneEffect.new()
	z.zone_id = "roots"
	z.radius = 40.0
	z.duration = 4.0
	z.tick_interval = 0.5
	z.target_faction = "enemy"
	var hit := DealDamageEffect.new()
	hit.damage_type = dtype
	hit.base_damage = dmg * 0.25
	z.tick_effects = [hit, _rooted_status()]
	return z


## "Rooted": brief hard slow re-applied every zone tick (enemies crawl while in the roots).
static func _rooted_status() -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = "rooted"
	status.is_positive = false
	status.max_stacks = 1
	status.base_duration = 1.0
	status.duration_refresh_mode = "overwrite"
	var slow := ModifierDefinition.new()
	slow.target_tag = "move_speed"
	slow.operation = "bonus"
	slow.value = -0.6
	slow.source_name = "rooted"
	status.modifiers = [slow]
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	apply.apply_to_self = false
	return apply


# --- Cleric: light combo (LMB) ---
## The Devout — censer smites into holy fire, gated into a Word of Pain curse zone. Phase indices:
## 0 Smite · 1 Smite II · 2 Divine Fire · 3 Word of Pain.
static func build_cleric_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Smite (crisp opener). No pain branch here (gate = depth ≥ Smite II).
	var smite := ChoreographyPhase.new()
	smite.animation = "attack"
	smite.hit_frame = 2
	smite.effects = [_aoe(dtype, dmg * 0.9, 30.0)]
	smite.exit_type = "wait"
	smite.wait_duration = CANCEL_WIN
	smite.default_next = -1
	smite.branches = [
		_branch_buffered("light_attack", 1),               # tap → Smite II
	]

	# 1 — Smite II (gate now met → Word of Pain available).
	var smite2 := ChoreographyPhase.new()
	smite2.animation = "attack_2"
	smite2.hit_frame = 2
	smite2.effects = [_aoe(dtype, dmg * 0.7, 30.0)]
	smite2.exit_type = "wait"
	smite2.wait_duration = CANCEL_WIN
	smite2.default_next = -1
	smite2.branches = [
		_branch_buffered("light_attack", 2),               # tap → Divine Fire
		_branch_buffered("heavy_attack", 3),               # RMB → Word of Pain
	]

	# 2 — Divine Fire (finisher: loose the holy bolt at the cursor; loops back on a fresh tap).
	var divine := ChoreographyPhase.new()
	divine.animation = "divine_fire"
	divine.hit_frame = 6
	divine.effects = [_divine_fire_bolt(dmg)]
	divine.exit_type = "wait"
	divine.wait_duration = CANCEL_WIN
	divine.default_next = -1
	divine.is_finisher = true
	divine.branches = [
		_branch_buffered("heavy_attack", 3),               # RMB → Word of Pain
		_branch_buffered("light_attack", 0),               # tap → loop to Smite
	]

	# 3 — Word of Pain (gated finisher; terminal).
	var pain := _word_of_pain_phase(dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [smite, smite2, divine, pain]
	return _ability("cleric_light", "Devout Combo", choreo)


# --- Cleric: heavy combo (RMB tap) ---
## Divine Fire → Word of Pain: holy poke into the curse zone. 0 Fire · 1 Pain.
static func build_cleric_heavy(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)

	var fire := ChoreographyPhase.new()
	fire.animation = "divine_fire"
	fire.hit_frame = 6
	fire.effects = [_divine_fire_bolt(dmg * 0.7)]
	fire.exit_type = "wait"
	fire.wait_duration = HEAVY_WIN
	fire.default_next = -1
	fire.branches = [
		_branch_buffered("heavy_attack", 1),               # RMB → Word of Pain
	]

	var pain := _word_of_pain_phase(dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [fire, pain]
	return _ability("cleric_heavy", "Devout Heavy", choreo)


# --- Cleric: Healing Words channel (RMB hold) ---
## Pray while held: each beat mends the Devout (host routes the self-heal + plays the HealingWords
## overlay and Back/Front sparkle). Player slow host-side. Single looping node.
static func build_cleric_heal(weapon_data: Dictionary) -> AbilityDefinition:
	var _dmg: float = weapon_data.get("damage", 42.0)   ## unused — the prayer heals, not harms

	var pray := ChoreographyPhase.new()
	pray.animation = "pray_heal"
	pray.hit_frame = 11                                     # the words land mid-prayer
	pray.effects = [_self_heal(0.04)]                      # 4% max HP per beat
	pray.exit_type = "wait"
	pray.wait_duration = PRAY_TICK
	pray.default_next = 0                                   # still held → keep praying
	pray.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [pray]
	return _ability("cleric_heal", "Healing Words", choreo)


## Shared Word of Pain finisher: the pray body + WordOfPainPrayEffect overlay; the host drops a
## damaging holy GroundZone (Fire) at the clamped cursor, with the WordOfPain decal.
static func _word_of_pain_phase(dmg: float) -> ChoreographyPhase:
	var p := ChoreographyPhase.new()
	p.animation = "pray_pain"
	p.hit_frame = 11
	p.effects = [_pain_zone(dmg)]
	p.exit_type = "anim_finished"
	p.default_next = -1
	p.is_finisher = true
	return p


## Word of Pain zone: holy Fire DoT (fixed base per tick, like the other combo effects).
static func _pain_zone(dmg: float) -> GroundZoneEffect:
	var z := GroundZoneEffect.new()
	z.zone_id = "word_of_pain"
	z.radius = 44.0
	z.duration = 4.0
	z.tick_interval = 0.5
	z.target_faction = "enemy"
	var hit := DealDamageEffect.new()
	hit.damage_type = "Fire"                                # holy fire, independent of the weapon
	hit.base_damage = dmg * 0.3
	z.tick_effects = [hit]
	return z


## Self-heal for the Healing-Words channel / Regrowth / Sanctuary. The host routes bare HealEffects
## onto the player (see player.choreo_fire_effects), so this mends the Devout, not the horde.
static func _self_heal(percent: float) -> HealEffect:
	var h := HealEffect.new()
	h.percent_max_hp = percent
	return h


# --- Cleric Divine Fire projectile (Divine Fire package) ---

const CLERIC_DF_DIR: String = "res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/Special_Animations/Divine Fire/"
static var _divine_fire_impact_frames: SpriteFrames = null


## The holy bolt: DivineFireProjectile (3×3 directional grid) + DivineFireImpact one-shot burst.
static func _divine_fire_bolt(hit_damage: float) -> SpawnProjectilesEffect:
	var cfg := ProjectileConfig.new()
	cfg.motion_type = "directional"
	cfg.speed = 250.0
	cfg.max_range = 220.0
	cfg.hit_radius = 8.0
	cfg.sprite_frames = _grid8_frames(CLERIC_DF_DIR + "DivineFireProjectile.png", "_divine_fire_frames")
	cfg.use_directional_anims = true
	var hit := DealDamageEffect.new()
	hit.damage_type = "Fire"
	hit.base_damage = hit_damage
	cfg.on_hit_effects = [hit]
	cfg.impact_sprite_frames = _get_divine_fire_impact()
	cfg.impact_animation = "impact"
	var e := SpawnProjectilesEffect.new()
	e.projectile = cfg
	e.spawn_pattern = "aimed_single"
	e.count = 1
	return e


static func _get_divine_fire_impact() -> SpriteFrames:
	if _divine_fire_impact_frames:
		return _divine_fire_impact_frames
	_divine_fire_impact_frames = _oneshot_row_frames(CLERIC_DF_DIR + "DivineFireImpact.png", 18.0)
	return _divine_fire_impact_frames


# --- Gunslinger projectile builders (Shot / Fan_The_Hammer packages) ---

const GUNSLINGER_ASSET_DIR: String = "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/"
static var _bullet_frames: SpriteFrames = null
static var _bullet_impact_frames: SpriteFrames = null
static var _fth_impact_frames: SpriteFrames = null


## One fast bullet at the cursor. Bullets have no in-flight sheet in the pack (they're meant
## to read as near-hitscan) — the tracer is the impact burst's first spark frame, and the
## landing plays the full Projectile_Impact sheet.
static func _gun_bullet(dtype: String, hit_damage: float) -> SpawnProjectilesEffect:
	var e := SpawnProjectilesEffect.new()
	e.projectile = _bullet_config(dtype, hit_damage, _get_bullet_impact_frames())
	e.spawn_pattern = "aimed_single"
	e.count = 1
	return e


## Fan the Hammer: 5 bullets in a wide fan, FTH's own impact sheet on each landing.
static func _fan_bullets(dtype: String, per_bullet: float) -> SpawnProjectilesEffect:
	var e := SpawnProjectilesEffect.new()
	e.projectile = _bullet_config(dtype, per_bullet, _get_fth_impact_frames())
	e.spawn_pattern = "spread"
	e.count = 5
	e.spread_angle = 44.0
	return e


## Desert Storm tick: a tight 3-bullet cone toward the cursor.
static func _storm_bullets(dtype: String, per_bullet: float) -> SpawnProjectilesEffect:
	var e := SpawnProjectilesEffect.new()
	e.projectile = _bullet_config(dtype, per_bullet, _get_bullet_impact_frames())
	e.spawn_pattern = "spread"
	e.count = 3
	e.spread_angle = 22.0
	return e


static func _bullet_config(dtype: String, hit_damage: float, impact: SpriteFrames) -> ProjectileConfig:
	var cfg := ProjectileConfig.new()
	cfg.motion_type = "directional"
	cfg.speed = 460.0
	cfg.max_range = 250.0
	cfg.hit_radius = 6.0
	cfg.sprite_frames = _get_bullet_frames()
	var hit := DealDamageEffect.new()
	hit.damage_type = dtype
	hit.base_damage = hit_damage
	cfg.on_hit_effects = [hit]
	cfg.impact_sprite_frames = impact
	cfg.impact_animation = "impact"
	return cfg


## Tracer: the first spark frame of Projectile_Impact on the SpriteFrames' stock "default"
## animation (non-directional projectiles play "default"; the manager rotates the sprite).
static func _get_bullet_frames() -> SpriteFrames:
	if _bullet_frames:
		return _bullet_frames
	var tex: Texture2D = load(GUNSLINGER_ASSET_DIR + "General_Animations/Projectile_Impact.png")
	var frames := SpriteFrames.new()
	var cell := AtlasTexture.new()
	cell.atlas = tex
	cell.region = Rect2(0, 0, 32, 32)
	cell.filter_clip = true
	frames.add_frame(&"default", cell)
	_bullet_frames = frames
	return frames


static func _get_bullet_impact_frames() -> SpriteFrames:
	if _bullet_impact_frames:
		return _bullet_impact_frames
	_bullet_impact_frames = _oneshot_row_frames(GUNSLINGER_ASSET_DIR + "General_Animations/Projectile_Impact.png", 20.0)
	return _bullet_impact_frames


static func _get_fth_impact_frames() -> SpriteFrames:
	if _fth_impact_frames:
		return _fth_impact_frames
	_fth_impact_frames = _oneshot_row_frames(GUNSLINGER_ASSET_DIR + "Special_Animations/Fan_The_Hammer/FTH_Projectile_Impact.png", 24.0)
	return _fth_impact_frames


# --- Barbarian projectile builder (Thunder_Blade_Attack package) ---

const BARBARIAN_ASSET_DIR: String = "res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/"
static var _thunder_proj_frames: SpriteFrames = null


## The four ThunderBladeProjectilesFrameN.png files are each a 3×3 directional grid — one
## animation FRAME per file, so each direction gets a looping 4-frame crackling bolt.
static func _get_thunder_proj_frames() -> SpriteFrames:
	if _thunder_proj_frames:
		return _thunder_proj_frames
	var frames := SpriteFrames.new()
	frames.clear_all()
	var sheets: Array = []
	for n in range(1, 5):
		sheets.append(load(BARBARIAN_ASSET_DIR
				+ "Special_Animations/Thunder_Blade_Attack/Minifantasy_TrueHeroesBarbarianThunderBladeProjectilesFrame%d.png" % n))
	for dir_name in GRID8_CELLS:
		var anim := StringName(dir_name)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, 12.0)
		var c: Vector2i = GRID8_CELLS[dir_name]
		for tex in sheets:
			if tex == null:
				continue
			var cell := AtlasTexture.new()
			cell.atlas = tex
			cell.region = Rect2(c.x * 32, c.y * 32, 32, 32)
			cell.filter_clip = true
			frames.add_frame(anim, cell)
	_thunder_proj_frames = frames
	return frames


# --- Ranger/Bard builders ---

const RANGER_ASSET_DIR: String = "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/"
const BARD_ASSET_DIR: String = "res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Bard/"
static var _arrow_frames: SpriteFrames = null
static var _knife_frames: SpriteFrames = null
static var _knife_impact_frames: SpriteFrames = null
static var _chord_frames: SpriteFrames = null
static var _chord_impact_frames: SpriteFrames = null

## 3×3 directional grid cells shared by all single-frame projectile sheets.
const GRID8_CELLS: Dictionary = {
	"e": Vector2i(2, 1), "se": Vector2i(2, 2), "s": Vector2i(1, 2), "sw": Vector2i(0, 2),
	"w": Vector2i(0, 1), "nw": Vector2i(0, 0), "n": Vector2i(1, 0), "ne": Vector2i(2, 0),
}


static func _arrow_volley(dtype: String, per_arrow: float, count: int, spread: float) -> SpawnProjectilesEffect:
	var cfg := ProjectileConfig.new()
	cfg.motion_type = "directional"
	cfg.speed = 300.0
	cfg.max_range = 240.0
	cfg.hit_radius = 6.0
	cfg.sprite_frames = _grid8_frames(RANGER_ASSET_DIR + "General_Animations/Single_Arrow_Projectile.png", "_arrow_frames")
	cfg.use_directional_anims = true
	var hit := DealDamageEffect.new()
	hit.damage_type = dtype
	hit.base_damage = per_arrow
	cfg.on_hit_effects = [hit]
	var e := SpawnProjectilesEffect.new()
	e.projectile = cfg
	e.spawn_pattern = "aimed_single" if count == 1 else "spread"
	e.count = count
	e.spread_angle = spread
	return e


## Heavy spinning knife: 8-way tumble (ortho+diagonal 4-row sheets), pierces one victim,
## lands with the Knife_On_The_Ground sheet as its impact.
static func _throwing_knife(dtype: String, hit_damage: float) -> SpawnProjectilesEffect:
	var cfg := ProjectileConfig.new()
	cfg.motion_type = "directional"
	cfg.speed = 260.0
	cfg.max_range = 210.0
	cfg.hit_radius = 8.0
	cfg.pierce_count = 1
	cfg.sprite_frames = _get_knife_frames()
	cfg.use_directional_anims = true
	var hit := DealDamageEffect.new()
	hit.damage_type = dtype
	hit.base_damage = hit_damage
	cfg.on_hit_effects = [hit]
	cfg.impact_sprite_frames = _get_knife_impact_frames()
	cfg.impact_animation = "impact"
	var e := SpawnProjectilesEffect.new()
	e.projectile = cfg
	e.spawn_pattern = "aimed_single"
	e.count = 1
	return e


static func _chord_bolt(dtype: String, hit_damage: float) -> SpawnProjectilesEffect:
	var cfg := ProjectileConfig.new()
	cfg.motion_type = "directional"
	cfg.speed = 250.0
	cfg.max_range = 210.0
	cfg.hit_radius = 8.0
	cfg.sprite_frames = _grid8_frames(BARD_ASSET_DIR + "Special_Animations/Dissonant_Chord/DissonantChordProjectile.png", "_chord_frames")
	cfg.use_directional_anims = true
	var hit := DealDamageEffect.new()
	hit.damage_type = dtype
	hit.base_damage = hit_damage
	cfg.on_hit_effects = [hit]
	cfg.impact_sprite_frames = _get_chord_impact_frames()
	cfg.impact_animation = "impact"
	var e := SpawnProjectilesEffect.new()
	e.projectile = cfg
	e.spawn_pattern = "aimed_single"
	e.count = 1
	return e


static func _apotheosis_phase(dtype: String, dmg: float) -> ChoreographyPhase:
	var apo := ChoreographyPhase.new()
	apo.animation = "apotheosis"
	apo.hit_frame = 8
	apo.effects = [_aoe(dtype, dmg * 1.6, 60.0), _timed_damage_buff("apotheosis", 0.20, 6.0)]
	apo.exit_type = "anim_finished"
	apo.default_next = -1
	apo.is_finisher = true
	return apo


## "Concealed": while refreshed, player.is_invisible() — enemies stop chasing. Duration
## outlasts the conceal loop tick so the stealth never blinks between refreshes.
static func _concealed_status() -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = "concealed"
	status.is_positive = true
	status.max_stacks = 1
	status.base_duration = 1.2
	status.duration_refresh_mode = "overwrite"
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	apply.apply_to_self = true
	return apply


## Vicious Mockery: enemies hit sing along at -20% damage for 4s (applied to targets, not self).
static func _mocked_debuff() -> ApplyStatusEffectData:
	var status := StatusEffectDefinition.new()
	status.status_id = "mocked"
	status.is_positive = false
	status.max_stacks = 1
	status.base_duration = 4.0
	status.duration_refresh_mode = "overwrite"
	var dmg_mod := ModifierDefinition.new()
	dmg_mod.target_tag = "damage"
	dmg_mod.operation = "bonus"
	dmg_mod.value = -0.20
	dmg_mod.source_name = "mocked"
	status.modifiers = [dmg_mod]
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	apply.apply_to_self = false
	return apply


## Enhancement Song: short damage buff refreshed every beat — fades quickly once you stop playing.
static func _enhancement_buff() -> ApplyStatusEffectData:
	return _timed_damage_buff("enhancement_song", 0.15, 1.2)


## Shared shape for self-applied +damage statuses (blood_power / apotheosis / enhancement_song).
static func _timed_damage_buff(id: String, amount: float, duration: float) -> ApplyStatusEffectData:
	var buff := StatusEffectDefinition.new()
	buff.status_id = id
	buff.is_positive = true
	buff.max_stacks = 1
	buff.base_duration = duration
	buff.duration_refresh_mode = "overwrite"
	var dmg_mod := ModifierDefinition.new()
	dmg_mod.target_tag = "damage"
	dmg_mod.operation = "bonus"
	dmg_mod.value = amount
	dmg_mod.source_name = id
	buff.modifiers = [dmg_mod]
	var apply := ApplyStatusEffectData.new()
	apply.status = buff
	apply.stacks = 1
	apply.apply_to_self = true
	return apply


## Shared 3×3-grid slicer for single-frame directional projectile sheets, cached per sheet.
static var _grid8_cache: Dictionary = {}
static func _grid8_frames(path: String, cache_key: String) -> SpriteFrames:
	if _grid8_cache.has(cache_key):
		return _grid8_cache[cache_key]
	var tex: Texture2D = load(path)
	var frames := SpriteFrames.new()
	frames.clear_all()
	for dir_name in GRID8_CELLS:
		var anim := StringName(dir_name)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		var cell := AtlasTexture.new()
		cell.atlas = tex
		var c: Vector2i = GRID8_CELLS[dir_name]
		cell.region = Rect2(c.x * 32, c.y * 32, 32, 32)
		cell.filter_clip = true
		frames.add_frame(anim, cell)
	_grid8_cache[cache_key] = frames
	return frames


## Knife tumble: ortho sheet rows = cardinal travel, diagonal sheet rows = diagonals
## (HolyHammer row-mapping convention — swap rows here if a scrub shows a mismatch).
static func _get_knife_frames() -> SpriteFrames:
	if _knife_frames:
		return _knife_frames
	var frames := SpriteFrames.new()
	frames.clear_all()
	var ortho_rows: Dictionary = {"n": 0, "e": 1, "s": 2, "w": 3}
	var diag_rows: Dictionary = {"ne": 0, "se": 1, "sw": 2, "nw": 3}
	_slice_dir_rows(frames, RANGER_ASSET_DIR + "Special_Animations/Throwing_Knife/Knife_Projectile_Orthogonal.png", ortho_rows, 4, 12.0)
	_slice_dir_rows(frames, RANGER_ASSET_DIR + "Special_Animations/Throwing_Knife/Knife_Projectile_Diagonal.png", diag_rows, 4, 12.0)
	_knife_frames = frames
	return frames


static func _slice_dir_rows(frames: SpriteFrames, path: String, rows: Dictionary,
		count: int, fps: float) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		return
	for dir_name in rows:
		var anim := StringName(dir_name)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, fps)
		for i in range(count):
			var cell := AtlasTexture.new()
			cell.atlas = tex
			cell.region = Rect2(i * 32, int(rows[dir_name]) * 32, 32, 32)
			cell.filter_clip = true
			frames.add_frame(anim, cell)


static func _get_knife_impact_frames() -> SpriteFrames:
	if _knife_impact_frames:
		return _knife_impact_frames
	_knife_impact_frames = _oneshot_row_frames(RANGER_ASSET_DIR + "Special_Animations/Throwing_Knife/Knife_On_The_Ground.png", 12.0)
	return _knife_impact_frames


static func _get_chord_impact_frames() -> SpriteFrames:
	if _chord_impact_frames:
		return _chord_impact_frames
	_chord_impact_frames = _oneshot_row_frames(BARD_ASSET_DIR + "Special_Animations/Dissonant_Chord/DissonantChordImpact.png", 16.0)
	return _chord_impact_frames


## Single-row 32px sheet → one-shot "impact" animation.
static func _oneshot_row_frames(path: String, fps: float) -> SpriteFrames:
	var tex: Texture2D = load(path)
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"impact")
	frames.set_animation_loop(&"impact", false)
	frames.set_animation_speed(&"impact", fps)
	if tex:
		for i in range(int(tex.get_width() / 32.0)):
			var cell := AtlasTexture.new()
			cell.atlas = tex
			cell.region = Rect2(i * 32, 0, 32, 32)
			cell.filter_clip = true
			frames.add_frame(&"impact", cell)
	return frames


# --- Blood Mage builders (Blood_Shard package + the pact buff) ---

const BLOOD_SHARD_DIR: String = "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Shard/"
static var _shard_proj_frames: SpriteFrames = null
static var _shard_impact_frames: SpriteFrames = null


static func _blood_shard(dtype: String, hit_damage: float) -> SpawnProjectilesEffect:
	var e := SpawnProjectilesEffect.new()
	e.projectile = _shard_config(dtype, hit_damage)
	e.spawn_pattern = "aimed_single"
	e.count = 1
	return e


## Volley: 3 shards in a narrow cone ("spread" aims at attack_target = the cursor marker).
static func _blood_shard_volley(dtype: String, per_shard_damage: float) -> SpawnProjectilesEffect:
	var e := SpawnProjectilesEffect.new()
	e.projectile = _shard_config(dtype, per_shard_damage)
	e.spawn_pattern = "spread"
	e.count = 3
	e.spread_angle = 24.0
	return e


static func _shard_config(dtype: String, hit_damage: float) -> ProjectileConfig:
	var cfg := ProjectileConfig.new()
	cfg.motion_type = "directional"
	cfg.speed = 230.0
	cfg.max_range = 200.0
	cfg.hit_radius = 7.0
	cfg.sprite_frames = _get_shard_proj_frames()
	cfg.use_directional_anims = true
	var hit := DealDamageEffect.new()
	hit.damage_type = dtype
	hit.base_damage = hit_damage
	cfg.on_hit_effects = [hit]
	cfg.impact_sprite_frames = _get_shard_impact_frames()
	cfg.impact_animation = "impact"
	return cfg


## Extract Power: the self-applied pact buff (+25% damage for 6s; adrenaline_rush pattern).
## The HP cost is paid host-side by player.gd on the cast's hit_frame.
static func _blood_power_buff() -> ApplyStatusEffectData:
	var buff := StatusEffectDefinition.new()
	buff.status_id = "blood_power"
	buff.is_positive = true
	buff.max_stacks = 1
	buff.base_duration = 6.0
	buff.duration_refresh_mode = "overwrite"
	var dmg_mod := ModifierDefinition.new()
	dmg_mod.target_tag = "damage"
	dmg_mod.operation = "bonus"
	dmg_mod.value = 0.25
	dmg_mod.source_name = "blood_power"
	buff.modifiers = [dmg_mod]
	var apply := ApplyStatusEffectData.new()
	apply.status = buff
	apply.stacks = 1
	apply.apply_to_self = true
	return apply


## Shard_Projectiles.png is a 3×3 directional grid → 8 one-frame anims (DIR_NAMES).
static func _get_shard_proj_frames() -> SpriteFrames:
	if _shard_proj_frames:
		return _shard_proj_frames
	var tex: Texture2D = load(BLOOD_SHARD_DIR + "Shard_Projectiles.png")
	var frames := SpriteFrames.new()
	frames.clear_all()
	var cells: Dictionary = {
		"e": Vector2i(2, 1), "se": Vector2i(2, 2), "s": Vector2i(1, 2), "sw": Vector2i(0, 2),
		"w": Vector2i(0, 1), "nw": Vector2i(0, 0), "n": Vector2i(1, 0), "ne": Vector2i(2, 0),
	}
	for dir_name in cells:
		var anim := StringName(dir_name)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		var cell := AtlasTexture.new()
		cell.atlas = tex
		var c: Vector2i = cells[dir_name]
		cell.region = Rect2(c.x * 32, c.y * 32, 32, 32)
		cell.filter_clip = true
		frames.add_frame(anim, cell)
	_shard_proj_frames = frames
	return frames


## Shard_Impact.png: 9 × 32px one-shot burst (sheet is 317px wide — pack quirk; the ninth
## frame's last 3px column is padding).
static func _get_shard_impact_frames() -> SpriteFrames:
	if _shard_impact_frames:
		return _shard_impact_frames
	var tex: Texture2D = load(BLOOD_SHARD_DIR + "Shard_Impact.png")
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"impact")
	frames.set_animation_loop(&"impact", false)
	frames.set_animation_speed(&"impact", 18.0)
	for i in range(int(tex.get_width() / 32.0)):
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(i * 32, 0, 32, 32)
		cell.filter_clip = true
		frames.add_frame(&"impact", cell)
	_shard_impact_frames = frames
	return frames


# --- Wizard projectile builders (Fireball asset package) ---

const FIREBALL_ASSET_DIR: String = "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fireball/"
static var _fireball_proj_frames: SpriteFrames = null
static var _fireball_impact_frames: SpriteFrames = null


## Quick staff bolt: small, fast, single-hit. Reuses the fireball projectile grid scaled down.
static func _wizard_bolt(dtype: String, hit_damage: float) -> SpawnProjectilesEffect:
	var cfg := ProjectileConfig.new()
	cfg.motion_type = "directional"
	cfg.speed = 240.0
	cfg.max_range = 190.0
	cfg.hit_radius = 7.0
	cfg.sprite_frames = _get_fireball_proj_frames()
	cfg.use_directional_anims = true
	cfg.visual_scale = Vector2(0.7, 0.7)
	var hit := DealDamageEffect.new()
	hit.damage_type = dtype
	hit.base_damage = hit_damage
	cfg.on_hit_effects = [hit]
	var e := SpawnProjectilesEffect.new()
	e.projectile = cfg
	e.spawn_pattern = "aimed_single"
	e.count = 1
	return e


## The Fireball: slower, bigger, explodes on impact (package explosion + splash damage).
static func _wizard_fireball(dtype: String, dmg: float) -> SpawnProjectilesEffect:
	var cfg := ProjectileConfig.new()
	cfg.motion_type = "directional"
	cfg.speed = 170.0
	cfg.max_range = 240.0
	cfg.hit_radius = 10.0
	cfg.sprite_frames = _get_fireball_proj_frames()
	cfg.use_directional_anims = true
	var hit := DealDamageEffect.new()
	hit.damage_type = dtype
	hit.base_damage = dmg * 1.1
	cfg.on_hit_effects = [hit]
	cfg.impact_sprite_frames = _get_fireball_impact_frames()
	cfg.impact_animation = "impact"
	cfg.impact_aoe_radius = 34.0
	var splash := DealDamageEffect.new()
	splash.damage_type = dtype
	splash.base_damage = dmg * 0.9
	cfg.impact_aoe_effects = [splash]
	var e := SpawnProjectilesEffect.new()
	e.projectile = cfg
	e.spawn_pattern = "aimed_single"
	e.count = 1
	return e


## Fireball_Projectile.png is a 3×3 directional grid → 8 one-frame anims named after
## ProjectileManager.DIR_NAMES ("e","se",...) for use_directional_anims.
static func _get_fireball_proj_frames() -> SpriteFrames:
	if _fireball_proj_frames:
		return _fireball_proj_frames
	var tex: Texture2D = load(FIREBALL_ASSET_DIR + "Fireball_Projectile.png")
	var frames := SpriteFrames.new()
	frames.clear_all()
	var cells: Dictionary = {
		"e": Vector2i(2, 1), "se": Vector2i(2, 2), "s": Vector2i(1, 2), "sw": Vector2i(0, 2),
		"w": Vector2i(0, 1), "nw": Vector2i(0, 0), "n": Vector2i(1, 0), "ne": Vector2i(2, 0),
	}
	for dir_name in cells:
		var anim := StringName(dir_name)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		var cell := AtlasTexture.new()
		cell.atlas = tex
		var c: Vector2i = cells[dir_name]
		cell.region = Rect2(c.x * 32, c.y * 32, 32, 32)
		cell.filter_clip = true
		frames.add_frame(anim, cell)
	_fireball_proj_frames = frames
	return frames


## Explossion_Only_Effect.png (pack's spelling): 5 frames of 64×64 → one-shot "impact".
static func _get_fireball_impact_frames() -> SpriteFrames:
	if _fireball_impact_frames:
		return _fireball_impact_frames
	var tex: Texture2D = load(FIREBALL_ASSET_DIR + "Explossion_Only_Effect.png")
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"impact")
	frames.set_animation_loop(&"impact", false)
	frames.set_animation_speed(&"impact", 15.0)
	for i in range(int(tex.get_width() / 64.0)):
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(i * 64, 0, 64, 64)
		cell.filter_clip = true
		frames.add_frame(&"impact", cell)
	_fireball_impact_frames = frames
	return frames


# --- helpers ---

static func _cataclysm_phase(dtype: String, dmg: float) -> ChoreographyPhase:
	var c := ChoreographyPhase.new()
	c.animation = "cataclysm"
	c.hit_frame = 7
	c.effects = [_aoe(dtype, dmg * 1.8, 55.0)]
	c.exit_type = "anim_finished"
	c.default_next = -1
	c.is_finisher = true
	return c


## Paladin's shared heavy finisher — the hammerdin moment (redesigned per Ben 2026-07-19):
## each RMB press throws ONE blessed hammer on its own outward spiral (player.gd launches a
## HolyHammer node on the hit_frame, cycling the start angle so successive hammers fan out).
## The phase loops on buffered RMB, so mashing = more hammers in flight, each with its own
## corkscrew. The direct slam AoE stays modest — the spirals carry the payoff.
## `self_index` = this phase's own index in its graph (light 4 / heavy 1), for the loop branch.
static func _hammer_phase(dtype: String, dmg: float, self_index: int) -> ChoreographyPhase:
	var h := ChoreographyPhase.new()
	h.animation = "hammer"
	h.hit_frame = 7                                          # the release
	h.effects = [_aoe(dtype, dmg * 0.8, 30.0)]
	h.exit_type = "wait"
	h.wait_duration = HEAVY_WIN
	h.default_next = -1
	h.is_finisher = true
	h.branches = [
		_branch_buffered("heavy_attack", self_index),      # RMB again → another hammer
	]
	return h


## Shield Bash shove: flat, short push — crowd control, not a launch. Same i-frame-gated
## DisplacementEffect system as the Fighter fling (CLAUDE.md).
static func _shove() -> DisplacementEffect:
	var d := DisplacementEffect.new()
	d.displaced = "target"
	d.destination = "away_from_source"
	d.motion = "arc"
	d.duration = 0.22
	d.arc_height = 8.0
	d.distance = 48.0
	return d


## Rogue's shared heavy finisher: lob a bomb at the cursor (clamped range) — blast + knockback
## centered on the landing point. Visuals come from the Throw Bomb asset package (player.gd arcs
## the spinning projectile, then plays the BombExplosion sheet where it lands). The blast radius
## matches the explosion sheet's NATIVE size (≈16px half-extent) so the visual IS the hit zone at
## 1× — both scale together with the melee_range stat (Reach mods / level picks).
static func _bomb_phase(dtype: String, dmg: float) -> ChoreographyPhase:
	var b := ChoreographyPhase.new()
	b.animation = "bomb"
	b.hit_frame = 6                                          # the detonation
	b.effects = [_aoe(dtype, dmg * 1.8, 16.0), _blast_wave()]
	b.exit_type = "anim_finished"
	b.default_next = -1
	b.is_finisher = true
	return b


## Bomb knockback: flatter and shorter than the Uppercut fling — a blast shove, not a launch.
## Same DisplacementEffect system, so it stays i-frame-gated (CLAUDE.md).
static func _blast_wave() -> DisplacementEffect:
	var d := DisplacementEffect.new()
	d.displaced = "target"
	d.destination = "away_from_source"
	d.motion = "arc"
	d.duration = 0.26
	d.arc_height = 16.0
	d.distance = 64.0
	return d


static func _fling() -> DisplacementEffect:
	var d := DisplacementEffect.new()
	d.displaced = "target"
	d.destination = "away_from_source"   ## knockback away from the player
	d.motion = "arc"                     ## parabolic launch reads as an uppercut
	d.duration = 0.32
	d.arc_height = 34.0
	d.distance = 88.0
	return d


static func _aoe(damage_type: String, base_damage: float, radius: float) -> AreaDamageEffect:
	var e := AreaDamageEffect.new()
	e.damage_type = damage_type
	e.base_damage = base_damage
	e.aoe_radius = radius
	return e


static func _ability(id: String, name: String, choreo: ChoreographyDefinition) -> AbilityDefinition:
	var a := AbilityDefinition.new()
	a.ability_id = id
	a.ability_name = name
	a.tags = ["Weapon", "Melee", "Combo"]
	a.mode = "Manual"
	a.choreography = choreo
	return a


static func _branch_buffered(action: String, next_phase: int) -> ChoreographyBranch:
	var c := ConditionInputBuffered.new()
	c.action = action
	c.within_window = 0.0                                   # 0 = use the phase's cancel window
	var b := ChoreographyBranch.new()
	b.condition = c
	b.next_phase = next_phase
	return b


static func _branch_held(action: String, min_duration: float, next_phase: int,
		negate: bool = false) -> ChoreographyBranch:
	var c := ConditionInputHeld.new()
	c.action = action
	c.min_duration = min_duration
	c.negate = negate
	var b := ChoreographyBranch.new()
	b.condition = c
	b.next_phase = next_phase
	return b


static func _damage_type(data: Dictionary) -> String:
	match data.get("damage_type", "physical"):
		"physical": return "Physical"
		"fire": return "Fire"
		"cryo": return "Ice"
		"shock": return "Lightning"
		"void": return "Void"
	return "Physical"
