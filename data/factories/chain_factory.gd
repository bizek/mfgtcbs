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
				"heavy": build_wizard_teleport(weapon_data),
				"channel": build_wizard_torrent(weapon_data),
			}
		"blood_mage":
			return {
				"light": build_blood_mage_light(weapon_data),
				"heavy": build_blood_mage_heavy(weapon_data),
				"channel": build_blood_mage_vampirize(weapon_data),
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
	blades.branches = [
		_branch_held("light_attack", HOLD_KEEP, -1, true), # released → end
	]

	# 4 — Holy Hammer (heavy finisher; terminal).
	var hammer := _hammer_phase(dtype, dmg)

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

	# 1 — Holy Hammer (shared finisher).
	var hammer := _hammer_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [bash, hammer]
	return _ability("paladin_heavy", "Warden Heavy", choreo)


# --- Paladin: Dome of Rightfulness channel (RMB hold) ---
## Plant the shield and dome up: retribution ticks around the Warden while held. Player slow is
## applied host-side (player.gd) like the other channels. Single looping node.
static func build_paladin_dome(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var dome := ChoreographyPhase.new()
	dome.animation = "dome"
	dome.hit_frame = 7                                      # the dictum flare
	dome.effects = [_aoe(dtype, dmg * 0.6, 60.0)]          # per-tick retribution (lower; repeats)
	dome.exit_type = "wait"
	dome.wait_duration = DICTUM_TICK
	dome.default_next = 0                                   # tick elapsed & still held → flare again
	dome.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [dome]
	return _ability("paladin_dome", "Dome of Rightfulness", choreo)


# --- Wizard: light combo (LMB) ---
## The Spark — pure ranged caster: cursor-aimed fire projectiles through the real
## ProjectileManager (SpawnProjectilesEffect "aimed_single" reads player.attack_target, which
## the host parks on the aim cursor). Phase indices:
## 0 Bolt · 1 Bolt II · 2 Fireball · 3 Summon Fire Familiar.
static func build_wizard_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Bolt (crisp opener: quick staff bolt at the cursor). No summon branch yet.
	var bolt := ChoreographyPhase.new()
	bolt.animation = "attack"
	bolt.hit_frame = 2
	bolt.effects = [_wizard_bolt(dtype, dmg * 0.75)]
	bolt.exit_type = "wait"
	bolt.wait_duration = CANCEL_WIN
	bolt.default_next = -1
	bolt.branches = [
		_branch_buffered("light_attack", 1),               # tap → Bolt II
	]

	# 1 — Bolt II (faster re-slice; gate now met → familiar available).
	var bolt2 := ChoreographyPhase.new()
	bolt2.animation = "attack_2"
	bolt2.hit_frame = 2
	bolt2.effects = [_wizard_bolt(dtype, dmg * 0.65)]
	bolt2.exit_type = "wait"
	bolt2.wait_duration = CANCEL_WIN
	bolt2.default_next = -1
	bolt2.branches = [
		_branch_buffered("light_attack", 2),               # tap → Fireball
		_branch_buffered("heavy_attack", 3),               # RMB → Summon Fire Familiar
	]

	# 2 — Fireball (big cast finisher: slow heavy projectile, explodes on impact; loops).
	var fireball := ChoreographyPhase.new()
	fireball.animation = "fireball"
	fireball.hit_frame = 6
	fireball.effects = [_wizard_fireball(dtype, dmg)]
	fireball.exit_type = "wait"
	fireball.wait_duration = CANCEL_WIN
	fireball.default_next = -1
	fireball.branches = [
		_branch_buffered("heavy_attack", 3),               # RMB → Summon Fire Familiar
		_branch_buffered("light_attack", 0),               # tap → loop to Bolt
	]

	# 3 — Summon Fire Familiar (gated finisher; terminal). The ignition burst fires here;
	# player.gd spawns/refreshes the FireFamiliar companion on the same hit_frame.
	var summon := ChoreographyPhase.new()
	summon.animation = "summon"
	summon.hit_frame = 8
	summon.effects = [_aoe(dtype, dmg * 0.4, 24.0)]
	summon.exit_type = "anim_finished"
	summon.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [bolt, bolt2, fireball, summon]
	return _ability("wizard_light", "Spark Combo", choreo)


# --- Wizard: Teleport (RMB tap) ---
## Two-phase blink: Start cast at the old spot (departure micro-burst, i-framed), player.gd
## moves the Spark to the cursor (clamped) late in the Start anim, then the End cast plays at
## the destination. Phase indices: 0 teleport_out · 1 teleport_in.
static func build_wizard_teleport(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var out := ChoreographyPhase.new()
	out.animation = "teleport_out"
	out.hit_frame = 9                                       # late — dissolve mostly done, then blink
	out.effects = [_aoe(dtype, dmg * 0.4, 22.0)]           # departure burst at the OLD position
	out.set_invulnerable = true
	out.exit_type = "anim_finished"
	out.default_next = 1

	var in_p := ChoreographyPhase.new()
	in_p.animation = "teleport_in"
	in_p.hit_frame = -1
	in_p.set_invulnerable = true
	in_p.exit_type = "anim_finished"
	in_p.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [out, in_p]
	return _ability("wizard_teleport", "Teleport", choreo)


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
	return c


## Paladin's shared heavy finisher — the hammerdin moment. The throw itself lands a close-range
## slam AoE; on the same hit_frame, player.gd launches the blessed-hammer spiral (HolyHammer
## nodes: Holy_Hammer package projectiles corkscrewing out, one hit per enemy per hammer, damage
## from the live damage stat). The spiral carries most of the payoff, so the direct AoE is modest.
static func _hammer_phase(dtype: String, dmg: float) -> ChoreographyPhase:
	var h := ChoreographyPhase.new()
	h.animation = "hammer"
	h.hit_frame = 7                                          # the release
	h.effects = [_aoe(dtype, dmg * 0.8, 30.0)]
	h.exit_type = "anim_finished"
	h.default_next = -1
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
