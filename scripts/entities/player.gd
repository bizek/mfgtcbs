extends CharacterBody2D

## Player — Movement, stats, health, leveling, and passive abilities.
## Uses engine component system for stats, damage pipeline, and status effects.
## Weapon firing through BehaviorComponent → EffectDispatcher pipeline.

signal health_changed(current: float, maximum: float)
signal xp_changed(current: float, needed: float)
signal leveled_up(new_level: int)
signal died

## Engine entity interface
var faction: int = 0  ## 0 = player/allies, 1 = enemies
var is_alive: bool = true
var is_attacking: bool = false
var is_channeling: bool = false
var is_invulnerable: bool = false
var is_untargetable: bool = false
var attack_target: Node2D = null
var last_hit_by: Node2D = null
var last_hit_time: float = -1e18
var _last_hit_time_by_tag: Dictionary = {}
var talent_picks: Array[String] = []
var combat_manager: Node2D = null
var spatial_grid: SpatialGrid = null
var combat_role: String = "MELEE"

## Base stats — initial values, modified by ModifierComponent
var _base_stats: Dictionary = {
	"max_hp":          100.0,
	"damage":          18.0,
	"attack_speed":    1.0,
	"crit_chance":     0.05,
	"crit_multiplier": 1.5,
	"move_speed":      54.0,   ## deliberate-pacing rebalance 2 2026-07-07 (was 66, orig 120); overridden per-character by CharacterData.base_move_speed in _load_character_stats
	"pickup_radius":   50.0,
	"melee_range":     1.0,    ## multiplier on melee-combo hit radius + swing-effect size (mod/upgrade hook)
	"projectile_count": 1,
	"pierce":          0,
	"projectile_size": 1.0,
	## Dash (modifier-driven so the passive tree / upgrades can scale them).
	## Read via get_stat() — a +1 charge or -20% cooldown upgrade is just a ModifierDefinition.
	"dash_speed":      520.0,  ## impulse speed at dash start (px/s)
	"dash_cooldown":   1.6,    ## per-charge refill time (s)
	"dash_charges":    1.0,    ## max charges (clamped to int >= 1 at read time)
}

## XP and leveling
var xp: float = 0.0
var level: int = 1
var xp_base: float = 10.0
var xp_growth: float = 0.3

## Weapon (engine AbilityDefinition)
var _weapon_id: String = ""
var _weapon_data: Dictionary = {}
## Status ids applied by class-gear uniques (task 34) — tracked so a re-apply can strip them.
var _gear_unique_status_ids: Array = []
var _weapon_ability: AbilityDefinition = null

## Mod system
var _active_mods: Array = []
var _has_instability_siphon: bool = false

## Cached base projectile stats (read from built ProjectileConfig, used for live stat sync)
var _base_proj_pierce: int = 0
var _base_proj_scale: Vector2 = Vector2.ONE
var _base_proj_hit_radius: float = 8.0

## Character passive
var _passive_id: String = "none"
var _bloodrage_on: bool = false   ## Ravager Bloodrage: tracked so the modifier only toggles on threshold crossings
var _calm_hands_on: bool = false  ## Deadeye Calm Hands: same threshold-toggle pattern, top of the health bar
var _time_since_hit: float = 999.0   ## Verdant Primal Vigor: seconds since last damage (regen-while-safe gate)
const VERDANT_REGEN_DELAY: float = 3.0   ## Primal Vigor: regen kicks in this long after being hit
const VERDANT_REGEN_FRAC: float = 0.04   ## …then restores this fraction of max HP per second
const DEVOUT_KILL_HEAL: float = 4.0      ## Devout Last Rites: flat HP restored per kill

## State
var god_mode: bool = false

## Hit iframes
var _iframes_timer: float = 0.0
const IFRAME_DURATION: float = 0.55
var _hit_flash_tween: Tween = null

## Animation state flags — prevent walk/idle logic from clobbering one-shot anims
var _attack_anim_active: bool = false
var _damage_anim_active: bool = false
var _is_dying: bool = false

## Pending fire — ability + targets stored at swing-start, executed at swing-end
var _pending_ability: AbilityDefinition = null
var _pending_targets: Array = []
## Manual-aim direction locked in at swing-start (Vector2.ZERO = auto-fire / not manual).
## When set, the shot aims/renders toward the cursor instead of the resolved enemy.
var _pending_aim_dir: Vector2 = Vector2.ZERO

## Controller right-stick aim. When the stick is deflected past its InputMap deadzone, aiming
## switches to the stick direction and holds it while the stick is idle (a combo/swing needs a
## stable facing, not a snap back to center). Mouse motion switches aiming back to the cursor.
var _controller_aim_dir: Vector2 = Vector2.ZERO
var _using_controller_aim: bool = false
const CONTROLLER_AIM_DISTANCE: float = 350.0  ## world units; ~matches on-screen mouse reach

## Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

## Manual fire is the DEFAULT: hold the "fire" action (left-click) to shoot toward the mouse
## cursor at the weapon's normal cadence (per-class aim in _resolve_manual_targets). The F1
## debug panel can flip this off to restore legacy auto-fire (aim at nearest enemy) for
## A/B testing. See docs/manual_fire.md.
var manual_fire_mode: bool = true
var _aim_marker: Node2D = null

## Dash — snappy, high-speed impulse with i-frames, charges + per-charge cooldown.
## Distance/cooldown/charge COUNT are modifier-driven (see _base_stats: dash_speed,
## dash_cooldown, dash_charges); the timing constants below are fixed feel values.
const DASH_DURATION: float = 0.16        ## active dash window in seconds (~80px at dash_speed 520)
const DASH_EASE_OUT: float = 0.25        ## tail deceleration amount (0 = constant speed, 1 = stops dead)
var _dash_timer: float = 0.0             ## counts down the active dash; >0 means dashing
var _dash_dir: Vector2 = Vector2.ZERO    ## locked-in dash direction
var _dash_speed_current: float = 0.0     ## dash_speed snapshotted at dash start
var _dash_charges: int = 1               ## currently available charges
var _dash_cooldown_timer: float = 0.0    ## counts down to the next charge refill
var _dash_anim_timer: float = 0.0        ## dash anim (Dodge roll / teleport_in) holds walk/idle off
var _last_move_dir: Vector2 = Vector2.RIGHT  ## fallback dash direction when no input is held

## Passive tree keystone flags (set in _apply_passive_tree, cleared on re-apply)
var _has_slipstream_keystone: bool = false
var _has_berserkers_cadence_keystone: bool = false
var _berserkers_cadence_last_trigger: float = -99.0  ## monotonic seconds; ICD for channel finishers

## Orbit orbs (Lightning Orb weapon)
var _orbit_orbs: Array = []
const OrbitOrbScript     := preload("res://scripts/entities/orbit_orb.gd")
const WeaponPickupScript := preload("res://scripts/pickups/weapon_pickup.gd")
const AimMarkerScript    := preload("res://scripts/entities/aim_marker.gd")

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var pickup_area: Area2D = $PickupCollector
@onready var pickup_shape: CollisionShape2D = $PickupCollector/CollisionShape

## Engine components (created at runtime)
var health: HealthComponent = null
var modifier_component: ModifierComponent = null
var ability_component: AbilityComponent = null
var behavior_component: BehaviorComponent = null
var status_effect_component: StatusEffectComponent = null
var trigger_component: TriggerComponent = null

## Melee combo system (docs/combat_chain_architecture.md). _combo_ability is null for ranged
## characters — all combo plumbing below is inert until a melee-combo weapon/character sets it.
var choreography_runner: ChoreographyRunner = null
var _combat_input: CombatInputBuffer = null
## Melee-kit entry abilities (null for non-melee characters). LMB → light, RMB tap → heavy
## (Uppercut→Cataclysm), RMB hold → channel (Taunt). _combo_ability == light gates the whole system.
var _combo_ability: AbilityDefinition = null
var _combo_heavy: AbilityDefinition = null
var _combo_channel: AbilityDefinition = null
## Combo cadence feedback (docs/combo_feedback_spec.md): pitch-ladder depth, channel-tick
## suppression, and the cancel-window pulse tween.
var _combo_step_depth: int = 0        ## light-chain hits fired this run (1-based ladder depth)
var _combo_last_hit_phase: int = -1   ## last phase index that fired — a repeat = channel self-loop tick
var _combo_pulse_tween: Tween = null
## Swing-effect overlay (the white slash), centered on the player and scaled per-node so the white's
## outer edge lands on that node's actual hit-zone radius — the visual IS the hitbox guide.
var _combo_fx: AnimatedSprite2D = null
## Ground layer for packs' "Base" sheets — same frames, drawn UNDER the character (z -1).
var _combo_base: AnimatedSprite2D = null
const FX_NATIVE_RADIUS: float = 14.0   ## radius (px) the white slash reaches inside the 32px frame
const COMBO_FX_SCALE: float = 2.4   ## fallback upscale for nodes with no AreaDamage radius
## Frame-matched full-body overlays that must play at NATIVE scale — never stretched to the
## hit radius (stretching a pack's frame-matched effect sheet reads as pixel mush; the
## shockwave ring marks the zone for these instead). The generic white swing slashes stay
## radius-scaled — for those the stretch IS the hitbox guide.
const NATIVE_FX_ANIMS: Array[String] = [
	"sunder", "bash", "dictum", "dome",
]
## Rogue Bomb visuals (Throw Bomb asset package): the spinning bomb projectile arcs a short hop in
## the facing direction during the wind-up, then "bomb_fx" (the package explosion) plays where it
## lands. The projectile sheets are 3×3 directional grids; we slice the right-facing cell + flip_h.
var _bomb_toss: AnimatedSprite2D = null
var _bomb_tween: Tween = null
var _bomb_start: Vector2 = Vector2.ZERO   ## world-space toss origin (bomb is NOT player-attached)
var _bomb_land: Vector2 = Vector2.ZERO    ## world-space landing/detonation point
var _bomb_atlases: Array = []             ## the spin frames' AtlasTextures (region re-aimed per toss)
## Four-way facing driven by the aim cursor. The True Heroes rows are DIAGONAL facings
## (down_left / down_right / up_left / up_right — Minifantasy oblique style);
## CharacterSpriteFactory slices them as "<anim>_<facing>" and _play_anim picks the variant.
var _facing: String = "down_left"
var _aim_dir: Vector2 = Vector2.DOWN   ## last aim/travel vector — picks the fallback facing side
var _has_dir_anims: bool = false
const BOMB_PROJ_SHEETS: Array[String] = [
	"res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/Special_Animations/Throw Bomb/Minifantasy_TrueHeroesRogueBombProjectileFrame1.png",
	"res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/Special_Animations/Throw Bomb/Minifantasy_TrueHeroesRogueBombProjectileFrame2.png",
]
const BOMB_EXPLOSION_SHEET: String = "res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/Special_Animations/Throw Bomb/Minifantasy_TrueHeroesRogueBombExplosion.png"
const BOMB_THROW_MAX: float = 60.0   ## bomb lands at the cursor, clamped to this throw range
const BOMB_TOSS_TIME: float = 0.33   ## ≈ time to hit_frame 6 @ 18fps
const BOMB_ARC_H: float = 14.0
## Wizard kit (The Spark): Teleport blink range, Fire Torrent forward offset, and the
## directional 64px torrent flame sheet (4 facing rows, drawn ahead of the caster).
const TELEPORT_RANGE: float = 100.0
const TORRENT_FORWARD: float = 36.0
## Barbarian Throw Things: the junk lands at the cursor, clamped to a hurl range. The thrown
## slab itself is cropped from the ThrowThings sheet's release frame (the pack draws it there —
## no separate projectile asset ships) and arced to the landing point as a world visual.
const THROW_RANGE: float = 120.0
## Barbarian Guard (RMB-hold channel): sword up — ALL damage from the frontal arc is blocked
## outright (take_damage), with the pack's BlockImpact flashing on each stopped hit.
const GUARD_BLOCK_ARC: float = 2.62   ## ~150° frontal arc (radians)
## Warden Reckoning (Dome redesign, Ben 2026-07-19): the channel drinks incoming hits into a
## pool; release (or the cap) detonates stored × REFLECT around the Warden.
const DOME_ABSORB_CAP: float = 0.30    ## fraction of max HP the dome can hold before bursting
const DOME_REFLECT_MULT: float = 1.5   ## stored damage → detonation damage
const DOME_BURST_RADIUS: float = 70.0  ## detonation hit zone (scales with melee_range)
var _dome_absorbed: float = 0.0
## Warden Aegis Shield (Q, Ben 2026-07-20): a STANDING absorb pool — soaks incoming hits whole
## until it's SPENT (no timer — it stays on the Warden until the absorb is used up, Ben's call),
## with the pack's DomeCycle bubble looping over him the whole time. Distinct from Reckoning
## (which stores hits to detonate); this one just protects.
const ABSORB_SHIELD_FRAC: float = 0.25   ## pool = 25% max HP
const DOME_CYCLE_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/Dome_Of_Rightfulness/DomeCycle.png"
var _absorb_shield: float = 0.0
var _shield_bubble: AnimatedSprite2D = null
var _active_choreo_id: String = ""     ## ability_id of the running choreography ("" = none)
## Gunslinger Desert Storm: the pack's directional barrage strips (8 files, 16f @ 96px cells)
## blaze ahead of the Deadeye toward the cursor while the channel pours, torrent-style.
const STORM_FX_DIR: String = "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Desert_Storm/Projectile_Impacts/"
const STORM_FX_FILES: Dictionary = {
	"e": "DS_Projectile_Impact_E.png", "se": "DS_Projectile_Impact_S-E.png",
	"s": "DS_Projectile_Impact_S.png", "sw": "DS_Projectile_Impact_S-W.png",
	"w": "DS_Projectile_Impact_W.png", "nw": "DS_Projectile_Impact_N-W.png",
	"n": "DS_Projectile_Impact_N.png", "ne": "DS_Projectile_Impact_N-E.png",
}
const STORM_FORWARD: float = 52.0
var _storm_fx: AnimatedSprite2D = null
const THROW_SHEET: String = "res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Throw_Things/Minifantasy_TrueHeroesBarbarianThrowThings.png"
const THROW_JUNK_REGION: Rect2 = Rect2(499, 13, 13, 8)   ## the airborne slab in row 0, frame 15
const TORRENT_FX_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fire_Torrent/Fire_Torrent_Effect.png"
var _fire_familiar: Node2D = null
var _torrent_fx: AnimatedSprite2D = null
## Spark Q/E overhaul (Ben 2026-07-20): Frost Burst leaves a looping ring of ice shards; Storm
## Call drops a two-bolt lightning strike over every enemy on the field. Sheets from the shared
## Spell Effects pack (32px cells; Aura sheets = row0 start / row1 loop / row2 end).
const SPELLFX_DIR: String = "res://assets/minifantasy/Minifantasy_Spell Effects_v1.0/Minifantasy_Spell_Effects_Assets/"
const AURA_ELECTRIC_SHEET: String = SPELLFX_DIR + "Electric/Aura/Aura_Electric.png"
const BURST_ELECTRIC_SHEET: String = SPELLFX_DIR + "Electric/Burst/Burst_Electric.png"
const BURST_ICE_SHEET: String = SPELLFX_DIR + "Ice/Burst/Burst_Ice.png"
const AURA_ICE_SHEET: String = SPELLFX_DIR + "Ice/Aura/Aura_Ice.png"
const STORM_CALL_DAMAGE_MULT: float = 1.6   ## per-enemy Lightning chunk (of weapon damage)
const STORM_CALL_RANGE: float = 1400.0       ## covers the whole arena (±800 × ±600)
const ICE_AURA_TIME: float = 10.0            ## shards loop this long, then deteriorate (row2)
var _ice_aura: AnimatedSprite2D = null
var _ice_aura_timer: float = 0.0
## Blood Mage kit (The Cursed): Extract Power HP cost, Vampirize heal-per-drink, and the
## Vampirize/Blood_Spikes loose effect sheets (drawn host-side, not body anims).
const BLOOD_COST_FRAC: float = 0.05      ## Extract Power costs 5% max HP (never lethal)
const VAMP_HEAL_FRAC: float = 0.02       ## Consume beat heals 2% max HP if the drain connected
const SPIKES_AOE_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Spikes/Blood_Spikes_AOE.png"
const FLOATING_BLOOD_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Vampirize/Floating_Blood.png"
const DRAIN_WISP_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Vampirize/Drain_Effect.png"
var _blood_elemental: Node2D = null
var _vamp_fx: AnimatedSprite2D = null
var _vamp_hit: bool = false              ## last extract beat found blood to drink
## Druid kit (The Verdant) + Cleric kit (The Devout): the Root/Word-of-Pain ground decals and the
## Cleric's summoned Spirit Guardian companion (pet standard, mirrors BloodElemental).
const ROOT_DECAL_SHEET: String = "res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Druid/Special_Animations/Root_Summoning/Minifantasy_TrueHeroesDruidRootAttack.png"
const PAIN_DECAL_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/Special_Animations/Prayers/Word_Of_Pain/WordOfPain.png"
var _spirit_guardian: Node2D = null
## Necromancer kit (The Shade): the persistent Skeletal Champion companion (pet standard) + Soul
## Harvest state — kills bank souls that heal and, every SOUL_HARVEST_THRESHOLD, empower the next summon.
## Rise Corpse (Q) raises a whole squad — the Shade is up against hordes, so one skeleton isn't
## enough. Resummon replaces the squad (the old one is banished). Empowered summons add one more.
const RISE_CORPSE_SQUAD: int = 4
var _skeletal_champions: Array[Node2D] = []
const SOUL_HARVEST_HEAL: float = 2.0        ## HP restored per soul reaped
const SOUL_HARVEST_THRESHOLD: int = 3       ## souls banked → next Rise Corpse / Bone Legion is empowered
var _soul_charges: int = 0
var _next_summon_empowered: bool = false
## Necromancer world-VFX sheets (Bone_Swirl orbit/rise, corpse-rise + ground layer, Plane Shift bursts).
## Spawned world-anchored via _spawn_pack_fx, NOT sliced into the character SpriteFrames.
const NECRO_SPECIAL_DIR: String = "res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Supreme_Necromancer/Special_Animations/"
const NECRO_SWIRL_SHEET: String = NECRO_SPECIAL_DIR + "Bone_Swirl/Bone_Swirl.png"            ## 64px, 3 rows (row 0 = full), orbit loop
const NECRO_SWIRL_RISE_SHEET: String = NECRO_SPECIAL_DIR + "Bone_Swirl/Bone_Swirl_Rise.png"  ## 64px, 1 row, bones erupt around caster
## Bone_Swirl_Rise is NOT one continuous eruption: frames 0-12 are the bones clawing up, and frames
## 13-28 are two verbatim copies of the 8-frame Bone_Swirl orbit loop (verified pixel-identical —
## rise f13 == orbit f0). So the rise's fps sets the ORBIT SPIN RATE, not just a gesture speed, and
## running it at the body cast's 26 fps span the bones at 3.25 rev/s ("helicopter blades", Ben
## 2026-07-25). One 8-frame loop = one full revolution (-45°/frame), so fps/8 IS revolutions/sec.
## We therefore play only the eruption and hand off to the loop at the SAME fps — the seam is
## invisible because the frames are the same art, and the spin rate never changes.
const NECRO_SWIRL_FPS: float = 12.0          ## 1.5 rev/s — pack-native is 10 fps (1.25 rev/s)
const NECRO_SWIRL_RISE_LAST: int = 12        ## last eruption frame; 13+ is the orbit loop inlined
## Must equal ChainFactory.SWIRL_ORBIT_TIME — the bones have to leave the screen on the same frame
## the status expires and fires them outward as projectiles.
const NECRO_SWIRL_ORBIT_LIFE: float = 1.35
const NECRO_SWIRL_ORBIT_FADE: float = 0.08   ## short — the bones don't dissolve, they launch
## Bone count → orbit rings. The sheet's three rows hold exactly 3, 2 and 1 bones, so any count
## decomposes into rows with no leftovers: 5 bones = one 3-row + one 2-row, spread around the circle.
const NECRO_SWIRL_BASE_BONES: int = 3
const NECRO_SWIRL_MAX_RINGS: int = 5         ## sanity cap (15 bones) so a stacked build can't spam sprites
var _swirl_rise_fx: AnimatedSprite2D = null
var _swirl_orbit_fx: Array[AnimatedSprite2D] = []
var _swirl_rings: Array[int] = []            ## sheet row per ring, resolved at cast time
var _swirl_chain_tween: Tween = null
const NECRO_RISE_GROUND_SHEET: String = NECRO_SPECIAL_DIR + "Rise_Corpse/Stand_Alone_Rise_Corpse_Ground.png"  ## 32px 2-row, ground scar below bodies (decoupled decal)
## Rise_Skeletal_Champion (the emerge body) now lives on the SkeletalChampion's own "spawn" state, so
## it's welded to the entity — see skeletal_champion.gd. Stand_Alone_Rise_Corpse (the generic fleshy
## corpse) is reserved for a future non-skeletal minion; our summons are skeletal → they use the
## matching champion emerge, per Ben's "the animation must match the skeleton" note (2026-07-23).
const NECRO_PLANESHIFT_OUT_SHEET: String = NECRO_SPECIAL_DIR + "Plane_Shift/Plane_Shift_Out.png"                ## 32px, 4 facing rows, dematerialize
const NECRO_PLANESHIFT_IN_SHEET: String = NECRO_SPECIAL_DIR + "Plane_Shift/Plane_Shift_In.png"                  ## 32px, 4 facing rows, rematerialize
## Demonologist kit (The Demon): the bound Angry Demon companion (pet standard) + the pack's
## world-anchored VFX. Spawned via _spawn_pack_fx, NOT sliced into the character SpriteFrames.
const DEMON_SPECIAL_DIR: String = "res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Demonologist/Special_Animations/"
## Standalone_Summon: the pact sigil WITHOUT a demon in it (32px, 1 row, 18f) — the circle draws
## itself, catches fire, and gutters out. Dropped under the Brimstone Circle finisher as a ground
## decal (z -1) scaled to the zone radius.
const BRIMSTONE_SIGIL_SHEET: String = DEMON_SPECIAL_DIR + "Summon_Demon/Standalone_Summon.png"
## Must equal ChainFactory.BRIMSTONE_ZONE_TIME — the sigil has to gutter out on the frame its ground
## zone stops burning. 18 frames spread across that life gives the playback fps.
const BRIMSTONE_SIGIL_LIFE: float = 4.0
const BRIMSTONE_SIGIL_FRAMES: int = 18
## Archdemon_Call_Spell: 32px, 1 row, 27f — the pentagram opens, the archdemon puts its head
## through, bites, and sinks back. World-anchored at the cursor over the Archdemon's Call zone.
const ARCHDEMON_SPELL_SHEET: String = DEMON_SPECIAL_DIR + "Archdemon_Call/Archdemon_Call_Spell.png"
## Must equal SkillFactory.ARCHDEMON_SPELL_TIME (27 frames @ ~11 fps ≈ 2.45s).
const ARCHDEMON_SPELL_LIFE: float = 2.45
const ARCHDEMON_SPELL_FRAMES: int = 27
## Hell_Breach_Spell: 64px, 17f, and its four rows are CARDINAL directions, not the pack's usual
## diagonal facings — measured off the sheet, each row's fissure grows a different way from the
## cell centre (row 0 east, 1 west, 2 south, 3 north). Spawned at the leap's landing point.
## Hell Breach is now the LIGHT CHAIN's second beat, not the dash (Ben 2026-07-26) — the chain
## phase carries the damage, so this host hook only owns the lunge and the fissure art.
const HELLBREACH_FISSURE_SHEET: String = DEMON_SPECIAL_DIR + "Hell_Breach/Hell_Breach_Spell.png"
const HELLBREACH_FISSURE_ROWS: Array[int] = [0, 1, 2, 3]   ## indexed by HELLBREACH_DIR order below
const HELLBREACH_FISSURE_FPS: float = 20.0
const HELLBREACH_RADIUS: float = 54.0       ## the fissure's bite; == ChainFactory.HELLBREACH_RADIUS
## Ashen Step (the Demon's dash, replacing Hell Breach): he hops clear on the pack's unused Jump
## sheet and the ground he left keeps burning, so disengaging also denies the ground. A ground
## zone rather than a flat AoE — it is a zoning tool, not a damage tool.
const ASHENSTEP_ZONE_RADIUS: float = 26.0
const ASHENSTEP_ZONE_TIME: float = 3.0
const ASHENSTEP_ZONE_TICK: float = 0.5
const ASHENSTEP_TICK_MULT: float = 0.18     ## × weapon damage per burn beat — chip, not a nuke
var _angry_demon: Node2D = null
## Control-scheme pass (2026-07-05): kit id + class dash + Wizard charge.
var _kit_id: String = ""
var _dash_style: String = ""             ## "" = standard dash; "teleport" = Spark blink
var _charge_start_ms: int = -1           ## Wizard Fireball charge start (real-time ms)
const WIZARD_CHARGE_SLOW: float = -0.4   ## move_speed penalty while charging (the greed tax)
const FIREBALL_MULT_MAX: float = 2.0     ## full overcharge doubles the Fireball
## Reach cap: base hit zones (ChainFactory) are ~half the "loved" size; full Reach mods scale them
## up to ~2× = the end-of-the-road size. Capped so it tops out there instead of growing forever.
const MELEE_RANGE_MAX: float = 2.0
var skill_component: SkillComponent = null   ## Q/E skill slots (SkillFactory per kit)
var _rmb_pending: bool = false      ## a neutral RMB press is waiting to resolve as tap vs hold
const TAUNT_HOLD_THRESHOLD: float = 0.20   ## hold RMB this long (from neutral) → Taunt channel, else heavy


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	_setup_components()
	_load_character_stats()
	_apply_character_sprite()
	_load_equipped_weapon()
	_apply_passive_mods()
	_apply_passive_tree()
	_load_weapon_mods()
	_load_combo()
	_update_pickup_radius()
	_reset_dash_state()
	health_changed.emit(health.current_hp, health.max_hp)
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.frame_changed.connect(_on_sprite_frame_changed)

	# Necromancer Soul Harvest: kills feed souls (heal + empowered summons). Gated on the passive
	# inside the handler; connecting unconditionally is safe (the char is loaded before enemies die).
	EventBus.on_kill.connect(_on_kill_soul_harvest)

	# Blood Eruption pools: deaths inside an active pool feed the Cursed.
	EventBus.on_death.connect(_on_any_entity_death)

	if _has_instability_siphon:
		EventBus.on_kill.connect(_on_kill_siphon)

	# Void instability debuff: auto-apply void_touched at high instability
	GameManager.instability_changed.connect(_on_instability_changed)
	GameManager.phase_started.connect(_on_phase_started)


func _setup_components() -> void:
	modifier_component = ModifierComponent.new()
	modifier_component.name = "ModifierComponent"
	add_child(modifier_component)

	health = HealthComponent.new()
	health.name = "HealthComponent"
	add_child(health)
	health.health_changed.connect(func(hp, max_hp): health_changed.emit(hp, max_hp))
	health.died.connect(_on_health_died)

	status_effect_component = StatusEffectComponent.new()
	status_effect_component.name = "StatusEffectComponent"
	add_child(status_effect_component)
	status_effect_component.setup(modifier_component)

	trigger_component = TriggerComponent.new()
	trigger_component.name = "TriggerComponent"
	add_child(trigger_component)

	ability_component = AbilityComponent.new()
	ability_component.name = "AbilityComponent"
	add_child(ability_component)

	behavior_component = BehaviorComponent.new()
	behavior_component.name = "BehaviorComponent"
	add_child(behavior_component)
	behavior_component.setup(modifier_component)

	choreography_runner = ChoreographyRunner.new()
	choreography_runner.name = "ChoreographyRunner"
	add_child(choreography_runner)
	choreography_runner.setup(self)

	_combat_input = CombatInputBuffer.new()
	_combat_input.setup(["light_attack", "heavy_attack"])

	skill_component = SkillComponent.new()
	skill_component.name = "SkillComponent"
	add_child(skill_component)
	skill_component.setup(self, choreography_runner)


# --- Character loading ---

func _load_character_stats() -> void:
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	_base_stats["max_hp"]     = char_data.get("base_hp", 100.0)
	_base_stats["move_speed"] = char_data.get("base_move_speed", 200.0)
	_passive_id               = char_data.get("passive_id", "none")
	for mod in CharacterFactory.build_base_modifiers(char_id, _base_stats):
		modifier_component.add_modifier(mod)
	health.setup(_base_stats["max_hp"])


# --- Character sprite ---

func _apply_character_sprite() -> void:
	## Swap the scene's placeholder SpriteFrames for the selected character's class
	## sprite, built data-driven from CharacterData.ALL[id]["sprite"] (see
	## docs/character_overhaul_design.md). Falls back to the scene's baked frames
	## if the character has no sprite metadata or its sheets fail to load.
	var char_id: String = ProgressionManager.selected_character
	var frames: SpriteFrames = CharacterSpriteFactory.build(char_id)
	if frames != null:
		sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	## Factory-built frames carry all four facing rows ("<anim>_<dir>"); baked scene frames don't.
	_has_dir_anims = sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation("idle_down_right")
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		_play_anim("idle")
	_setup_combo_fx(frames)


func _setup_combo_fx(frames: SpriteFrames) -> void:
	## Overlay sprite that plays the "<node>_fx" swing-effect anim on top of the body. Shares the
	## character SpriteFrames (which now carries the *_fx animations). Hidden until a combo fires.
	if frames == null or not _has_any_fx_anim(frames):
		return  ## character has no swing-effect sheets — skip
	if _combo_fx == null:
		_combo_fx = AnimatedSprite2D.new()
		_combo_fx.name = "ComboFx"
		_combo_fx.centered = true
		_combo_fx.visible = false
		_combo_fx.z_index = 1   ## draw above the body
		_combo_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_combo_fx)
		_combo_fx.animation_finished.connect(_on_combo_fx_finished)
	_combo_fx.sprite_frames = frames


func _input(event: InputEvent) -> void:
	## Mouse motion hands aiming back to the cursor; the right stick (polled in
	## _physics_process) hands it back to the controller. Whichever moved most recently wins.
	if event is InputEventMouseMotion:
		_using_controller_aim = false


## Poll the right stick once per physics frame (deadzone applied by the aim_* InputMap actions).
## Deflection updates and holds the aim direction; releasing the stick keeps the last direction
## instead of snapping back to the cursor, since a melee swing needs a stable facing.
func _update_controller_aim() -> void:
	## Radial deadzone, not per-axis: a per-axis gate zeroes the smaller component on any
	## shallow push, which snapped aim to the cardinals the same way movement was snapping.
	## Only the direction is used here, so magnitude past the deadzone doesn't matter.
	var stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.25)
	if stick.length_squared() > 0.0:
		_controller_aim_dir = stick.normalized()
		_using_controller_aim = true


## The world point every aim/facing calculation reads instead of the raw mouse position — the
## mouse cursor normally, or a fixed-distance point in the held controller-stick direction.
## Downstream call sites only use direction (normalized/limit_length) or clamp to their own
## range, so the fixed distance here is a stand-in reach, not a hard game-rule range.
func _get_aim_world_position() -> Vector2:
	if _using_controller_aim and _controller_aim_dir != Vector2.ZERO:
		return global_position + _controller_aim_dir * CONTROLLER_AIM_DISTANCE
	return get_global_mouse_position()


## Facing follows the aim cursor, not movement — combat reads from where you're pointing.
## The cursor's QUADRANT picks the row (the rows are diagonal facings): south of the player
## always shows a front row, north always a back row — never inverted.
func _update_facing() -> void:
	var to_mouse: Vector2 = _get_aim_world_position() - global_position
	if to_mouse.length_squared() < 4.0:
		return   ## cursor on top of the player — keep the last facing
	_aim_dir = to_mouse
	_facing = _facing_from_vector(to_mouse)


## 8-way facing: bucket a direction into one of 8 sectors (screen space: +x right, +y down).
## The four CARDINAL facings are only rendered by anims that ship an orthogonal companion sheet;
## every other anim falls back to the nearest DIAGONAL at play time, which resolves to exactly
## the same row the old 4-quadrant split picked — so 4-row sheets are visually unchanged.
func _facing_from_vector(v: Vector2) -> String:
	var a: float = rad_to_deg(atan2(v.y, v.x))   ## 0 = right, 90 = down
	if a < 0.0:
		a += 360.0
	var sector: int = int(round(a / 45.0)) % 8
	return FACING_SECTORS[sector]
const FACING_SECTORS: Array[String] = ["right", "down_right", "down", "down_left",
		"left", "up_left", "up", "up_right"]
## Resolve "<base>_<facing>" to an animation that actually exists: exact facing row → nearest
## neighbouring facing row (chosen by the true aim direction, so a diagonal-only sheet renders
## IDENTICALLY to the old 4-quadrant split and a cardinal-only sheet snaps to the nearer
## cardinal) → the base slice → "". One place so body, combo, and fx overlays fall back alike.
func _facing_variant(frames: SpriteFrames, base: String) -> String:
	if frames == null:
		return ""
	var exact: String = base + "_" + _facing
	if frames.has_animation(exact):
		return exact
	for near in _facing_fallback_order():
		var v: String = base + "_" + near
		if frames.has_animation(v):
			return v
	if frames.has_animation(base):
		return base
	return ""


## Neighbouring facings to try for the current facing, ordered by the live aim so the side
## matches where the cursor actually is (no left/right flip near the axes).
func _facing_fallback_order() -> Array:
	var ax: float = _aim_dir.x
	var ay: float = _aim_dir.y
	match _facing:
		"down":  return ["down_right", "down_left"] if ax >= 0.0 else ["down_left", "down_right"]
		"up":    return ["up_right", "up_left"] if ax >= 0.0 else ["up_left", "up_right"]
		"left":  return ["down_left", "up_left"] if ay >= 0.0 else ["up_left", "down_left"]
		"right": return ["down_right", "up_right"] if ay >= 0.0 else ["up_right", "down_right"]
		"down_right": return ["down", "right"] if absf(ay) >= absf(ax) else ["right", "down"]
		"down_left":  return ["down", "left"] if absf(ay) >= absf(ax) else ["left", "down"]
		"up_right":   return ["up", "right"] if absf(ay) >= absf(ax) else ["right", "up"]
		"up_left":    return ["up", "left"] if absf(ay) >= absf(ax) else ["left", "up"]
	return []


## Play `base` in the row matching the current facing when the frames carry it; fall back to the
## base slice (single-row sheets like death, or baked scene frames).
func _play_anim(base: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var variant: String = _facing_variant(sprite.sprite_frames, base)
	if variant != "" and variant != base:
		sprite.flip_h = false   ## real directional row — never mirror on top of it
		sprite.play(variant)
	else:
		sprite.play(base)


## Resolve a canonical anim name to its facing variant (ChoreographyRunner host hook — combo
## phases play the row matching the cursor; hit_frame indices are identical across rows).
func choreo_anim_name(base: String) -> String:
	var variant: String = _facing_variant(sprite.sprite_frames if sprite else null, base)
	return variant if variant != "" else base


## True if the character SpriteFrames carries any "<node>_fx" swing-effect animation. Not every
## kit has an fx sheet for its basic attack (e.g. Paladin only ships bash/dictum/dome effects),
## so the overlay must exist whenever ANY node can use it.
func _has_any_fx_anim(frames: SpriteFrames) -> bool:
	for anim_name in frames.get_animation_names():
		if String(anim_name).ends_with("_fx"):
			return true
	return false


# --- Weapon loading ---

func _load_equipped_weapon() -> void:
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	## Per-character loadout: every character runs its own chosen weapon (slot 1), which
	## defaults to its signature starting_weapon. See ProgressionManager.character_loadouts.
	var weapon_id: String = ProgressionManager.get_character_weapon(char_id, 1)
	if weapon_id.is_empty():
		weapon_id = char_data.get("starting_weapon", "Hurled Steel")

	_weapon_id   = weapon_id
	_weapon_data = WeaponData.ALL.get(weapon_id, WeaponData.ALL["Hurled Steel"])

	# Weapon stats override base damage/attack_speed/projectile_count
	_set_base_stat("damage", _weapon_data.get("damage", 18.0))
	_set_base_stat("attack_speed", _weapon_data.get("attack_speed", 1.0))
	_set_base_stat("projectile_count", _weapon_data.get("projectile_count", 1))

	# Orbit weapons spawn persistent orbs (deferred so scene tree is ready)
	if _weapon_data.get("behavior") == "orbit":
		call_deferred("_setup_orbit_orbs")

	# Class-gear (task 34): intrinsic stat lines, the weapon's purple unique, and
	# the character's equipped trinkets. Applied here so the passive-tree max_hp
	# re-sync (below) picks up any +max_hp from gear.
	_apply_gear_bonuses()


# --- Class gear: intrinsic modifiers, uniques, trinkets (task 34) ---

## Applies the equipped weapon's intrinsic `modifiers` + purple `unique`, and every
## equipped trinket's modifiers + unique. Mirrors the weapon-mod wiring in
## _load_weapon_mods: stat lines → ModifierComponent, uniques → StatusEffectComponent.
## Idempotent — strips prior gear modifiers/statuses first so a re-apply doesn't stack.
func _apply_gear_bonuses() -> void:
	modifier_component.remove_by_source_prefix("gear_")
	modifier_component.remove_by_source_prefix("gearunique_")
	for sid in _gear_unique_status_ids:
		if status_effect_component.has_status(sid):
			status_effect_component.force_remove_status(sid, self)
	_gear_unique_status_ids.clear()

	# Weapon intrinsic stat lines
	for m: Dictionary in WeaponData.get_weapon_modifiers(_weapon_id):
		_add_modifier(m["tag"], m["op"], float(m["value"]), "gear_" + _weapon_id)
	# Weapon purple unique
	var wuid: String = WeaponData.get_weapon_unique(_weapon_id)
	if wuid != "":
		_apply_gear_unique(wuid)

	# Equipped trinkets (universal, 2 slots + workshop 3rd)
	var char_id: String = ProgressionManager.selected_character
	for tid: String in ProgressionManager.get_character_trinkets(char_id):
		if tid == "":
			continue
		for m: Dictionary in TrinketData.get_modifiers(tid):
			_add_modifier(m["tag"], m["op"], float(m["value"]), "gear_trinket_" + tid)
		var tuid: String = TrinketData.get_unique(tid)
		if tuid != "":
			_apply_gear_unique(tuid)

	## Re-sync max HP so any +max_hp gear is reflected on the health bar.
	health.setup(get_stat("max_hp"))


func _apply_gear_unique(unique_id: String) -> void:
	var u: Dictionary = GearUniqueFactory.build(unique_id)
	for m: ModifierDefinition in u.get("modifiers", []):
		modifier_component.add_modifier(m)   ## source already "gearunique_…"
	for s: StatusEffectDefinition in u.get("statuses", []):
		status_effect_component.apply_status(s, self, 1)
		_gear_unique_status_ids.append(s.status_id)


# --- Passive application ---

func _apply_passive_mods() -> void:
	for mod in CharacterFactory.build_passive_modifiers(_passive_id):
		modifier_component.add_modifier(mod)
	if _passive_id == "cursed_passive":
		health.setup(get_stat("max_hp"))


## Apply passive skill tree allocations: stat nodes → ModifierDefinitions,
## behavior nodes → hidden permanent statuses via PassiveTreeFactory.
## Keystones (slipstream, berserkers_cadence) set flags instead of applying a status.
func _apply_passive_tree() -> void:
	_has_slipstream_keystone = false
	_has_berserkers_cadence_keystone = false
	PassiveTreeFactory.build_all()

	for node_id: String in ProgressionManager.passive_allocations:
		var ranks: int = int(ProgressionManager.passive_allocations[node_id])
		if ranks <= 0:
			continue
		var node: Dictionary = PassiveTreeData.NODES.get(node_id, {})
		if node.is_empty():
			continue

		var behavior: String = node.get("behavior", "")
		if behavior != "":
			if behavior == "slipstream":
				_has_slipstream_keystone = true
			elif behavior == "berserkers_cadence":
				_has_berserkers_cadence_keystone = true
			else:
				var passive_def: StatusEffectDefinition = PassiveTreeFactory.build(behavior)
				if passive_def != null:
					status_effect_component.apply_status(passive_def, self, 1)
			continue

		for eff: Dictionary in node.get("effects", []):
			var mod := ModifierDefinition.new()
			mod.target_tag = eff["stat"]
			mod.operation  = eff["op"]
			mod.value      = float(eff["value"]) * float(ranks)
			mod.source_name = "passive_tree"
			modifier_component.add_modifier(mod)

	## Re-sync max_hp so tree additions are reflected before the run starts.
	health.setup(get_stat("max_hp"))


## Ravager Bloodrage: the +damage modifier exists only while below half HP.
func _update_bloodrage() -> void:
	var raging: bool = health.current_hp < health.max_hp * 0.5
	if raging == _bloodrage_on:
		return
	_bloodrage_on = raging
	if raging:
		_add_modifier("damage", "bonus", 0.30, "passive_bloodrage")
	else:
		modifier_component.remove_by_source_prefix("passive_bloodrage")
	print("[RAVAGER] bloodrage %s (hp %.1f/%.1f, damage stat %.1f)" % [
			"ON" if raging else "off", health.current_hp, health.max_hp, get_stat("damage")])


## Deadeye Calm Hands: the +damage modifier exists only while above 80% HP.
func _update_calm_hands() -> void:
	var calm: bool = health.current_hp > health.max_hp * 0.8
	if calm == _calm_hands_on:
		return
	_calm_hands_on = calm
	if calm:
		_add_modifier("damage", "bonus", 0.25, "passive_calm_hands")
	else:
		modifier_component.remove_by_source_prefix("passive_calm_hands")
	print("[DEADEYE] calm hands %s (hp %.1f/%.1f, damage stat %.1f)" % [
			"ON" if calm else "off", health.current_hp, health.max_hp, get_stat("damage")])


# --- Mod loading ---

func _load_weapon_mods() -> void:
	_active_mods = ProgressionManager.get_weapon_mods(_weapon_id)
	_has_instability_siphon = "instability_siphon" in _active_mods

	# Stat mods (crit, lifesteal) as ModifierDefinitions
	var stat_mods: Array[ModifierDefinition] = WeaponFactory.build_mod_modifiers(_active_mods)
	for mod in stat_mods:
		modifier_component.add_modifier(mod)

	# Combo modifier bonuses (Size+Crit, Crit+Ricochet, etc.)
	var combo_mods: Array[ModifierDefinition] = WeaponFactory.build_combo_modifiers(_active_mods)
	for mod in combo_mods:
		modifier_component.add_modifier(mod)

	# Build weapon ability with mods baked into ProjectileConfig/effects
	_weapon_ability = WeaponFactory.build_weapon_ability(_weapon_id, _weapon_data, _active_mods)

	# Runtime combo passives (Static Strike, etc.) applied as permanent player statuses
	var combo_passives: Array[StatusEffectDefinition] = WeaponFactory.build_combo_passives(_active_mods)
	for passive_def in combo_passives:
		status_effect_component.apply_status(passive_def, self, 1)

	# Wire as auto-attack through engine components
	# Orbit weapons are passive — orbs handle their own hits, no auto-attack signal needed
	var attack_interval: float = _weapon_ability.cooldown_base
	behavior_component.setup(modifier_component, attack_interval)
	if _weapon_data.get("behavior", "") != "orbit":
		behavior_component.auto_attack_requested.connect(_on_auto_attack)
	ability_component.setup_abilities(_weapon_ability, [], 1)
	_cache_projectile_base_stats()


func reload_mods() -> void:
	# Remove old mod modifiers (sources starting with "mod_" or "combo_")
	modifier_component.remove_by_source_prefix("mod_")
	modifier_component.remove_by_source_prefix("combo_")
	# Remove old combo passive statuses
	for passive_id in ["combo_static_strike"]:
		if status_effect_component.has_status(passive_id):
			status_effect_component.force_remove_status(passive_id, self)
	_load_weapon_mods()
	_load_combo()   ## re-assert the combo (and re-drop weapon auto-fire) after a mod rebuild
	if _has_instability_siphon:
		if not EventBus.on_kill.is_connected(_on_kill_siphon):
			EventBus.on_kill.connect(_on_kill_siphon)


func get_active_weapon_id() -> String:
	return _weapon_id

## Spawn the currently-equipped weapon as a pickup at the player's position.
## Called before switch_weapon so the old weapon can be re-looted.
func drop_current_weapon() -> void:
	if _weapon_id.is_empty():
		return
	var pickup: Area2D = WeaponPickupScript.new()
	pickup.weapon_id       = _weapon_id
	pickup.global_position = global_position
	get_parent().add_child(pickup)


## Swap to a different weapon mid-run (called when a weapon upgrade is chosen at level-up).
## Carries over any stat upgrades already applied; mods are cleared (new weapon has none).
func switch_weapon(weapon_id: String) -> void:
	if weapon_id == _weapon_id:
		return
	## Clean up current weapon
	_cleanup_orbit_orbs()
	if behavior_component.auto_attack_requested.is_connected(_on_auto_attack):
		behavior_component.auto_attack_requested.disconnect(_on_auto_attack)

	## Remove old weapon base-stat modifiers so new ones don't stack
	_set_base_stat("damage",         0.0)
	_set_base_stat("attack_speed",   0.0)
	_set_base_stat("projectile_count", 0.0)

	## Remove mod modifiers from old weapon
	modifier_component.remove_by_source_prefix("mod_")
	modifier_component.remove_by_source_prefix("combo_")
	for passive_id in ["combo_static_strike"]:
		if status_effect_component.has_status(passive_id):
			status_effect_component.force_remove_status(passive_id, self)

	## Load new weapon data
	_weapon_id   = weapon_id
	_weapon_data = WeaponData.ALL.get(weapon_id, WeaponData.ALL["Hurled Steel"])
	_set_base_stat("damage",          _weapon_data.get("damage", 18.0))
	_set_base_stat("attack_speed",    _weapon_data.get("attack_speed", 1.0))
	_set_base_stat("projectile_count", _weapon_data.get("projectile_count", 1))

	## Build new weapon ability (no mods — the player didn't bring a loadout for this weapon)
	_active_mods   = []
	_weapon_ability = WeaponFactory.build_weapon_ability(_weapon_id, _weapon_data, _active_mods)

	## Re-wire behavior and ability components
	var attack_interval: float = _weapon_ability.cooldown_base
	behavior_component.setup(modifier_component, attack_interval)
	if _weapon_data.get("behavior", "") != "orbit":
		behavior_component.auto_attack_requested.connect(_on_auto_attack)
	ability_component.setup_abilities(_weapon_ability, [], 1)
	_cache_projectile_base_stats()
	## Rebuild the combo for the new weapon's damage (Fighter keeps its class combo).
	_load_combo()

	## Re-apply class-gear bonuses for the new weapon (strips the old weapon's intrinsic
	## modifiers/unique; trinkets persist since they key off "gear_trinket_"). (task 34)
	_apply_gear_bonuses()

	if _weapon_data.get("behavior") == "orbit":
		call_deferred("_setup_orbit_orbs")


func _cache_projectile_base_stats() -> void:
	## Snapshot base pierce/scale/radius from the built ProjectileConfig so
	## _on_auto_attack can apply player stat upgrades on top without compounding.
	if _weapon_ability == null:
		return
	for effect in _weapon_ability.effects:
		if effect is SpawnProjectilesEffect:
			_base_proj_pierce     = effect.projectile.pierce_count
			_base_proj_scale      = effect.projectile.visual_scale
			_base_proj_hit_radius = effect.projectile.hit_radius
			return
	_base_proj_pierce     = 0
	_base_proj_scale      = Vector2.ONE
	_base_proj_hit_radius = 8.0


func _on_auto_attack(ability: AbilityDefinition, targets: Array) -> void:
	## Engine callback: BehaviorComponent resolved targets.
	## Stats are synced and locked in NOW (swing-start); projectile fires at swing-end.
	if not is_alive:
		return
	## Manual aim may whiff (no enemies in the cursor line/arc) — still play the swing so
	## beams/arcs render toward the cursor; damage just resolves to an empty set.
	var manual_aim: bool = _pending_aim_dir != Vector2.ZERO
	if targets.is_empty() and not manual_aim:
		return
	attack_target = targets[0] if not targets.is_empty() else null

	# Sync live stats into weapon effects — locked in at swing-start
	var proj_count: int = int(get_stat("projectile_count"))
	var pierce_bonus: int = int(get_stat("pierce"))
	var size_mult: float = get_stat("projectile_size")
	for effect in ability.effects:
		if effect is SpawnProjectilesEffect:
			effect.count = proj_count
			## -1 = pierce-all (e.g. The Deep's Pull); never downgrade it with a finite bonus.
			effect.projectile.pierce_count = -1 if _base_proj_pierce == -1 else _base_proj_pierce + pierce_bonus
			effect.projectile.visual_scale = _base_proj_scale * size_mult
			effect.projectile.hit_radius   = _base_proj_hit_radius * size_mult
	## Beam: sync live projectile_count → targeting so next resolve picks up multi-beam
	if ability.tags.has("Beam") and ability.targeting != null:
		ability.targeting.max_targets = proj_count

	# Store pending shot — will be executed at the end of the attack animation
	_pending_ability = ability
	_pending_targets = targets  # Node2D refs; validity checked before firing

	# Play attack animation and schedule firing at the last frame
	if not _is_dying:
		_attack_anim_active = true
		_play_anim("attack")
	var frame_count: int = sprite.sprite_frames.get_frame_count("attack")
	var fps: float = sprite.sprite_frames.get_animation_speed("attack")
	var fire_delay: float = float(frame_count) / fps
	get_tree().create_timer(fire_delay).timeout.connect(_fire_pending_shot, CONNECT_ONE_SHOT)


func _fire_pending_shot() -> void:
	## Execute the stored projectile/beam/melee at the end of the swing animation.
	if not is_alive or _pending_ability == null:
		_clear_pending_shot()
		return
	var manual_aim: bool = _pending_aim_dir != Vector2.ZERO
	# Filter targets that are no longer valid (died during swing)
	var valid_targets: Array = _pending_targets.filter(func(t: Node) -> bool: return is_instance_valid(t))
	# Auto-fire only: if the original target died mid-swing, re-aim at the nearest live
	# enemy so the throw always releases. Manual aim keeps its cursor line — a whiff stays
	# a whiff, and the swing/beam still renders toward the cursor (no damage).
	if not manual_aim:
		if valid_targets.is_empty() and spatial_grid != null:
			var nearest: Node2D = spatial_grid.find_nearest(global_position, 1)
			if is_instance_valid(nearest):
				valid_targets.append(nearest)
		if valid_targets.is_empty():
			_clear_pending_shot()
			return

	EffectDispatcher.execute_effects(_pending_ability.effects, self, valid_targets, _pending_ability, combat_manager)
	EventBus.on_ability_used.emit(self, _pending_ability)

	# Weapon-specific visual feedback
	var scene_root: Node = get_tree().current_scene
	var tint: Color = _weapon_data.get("tint", Color.WHITE)
	if _pending_ability.tags.has("Beam"):
		if manual_aim:
			## One beam straight down the cursor line (corridor enemies already took the
			## hit); endpoint at max range so the beam reads even when it whiffs.
			var beam_range: float = _pending_ability.targeting.max_range if _pending_ability.targeting else 285.0
			var endpoint: Vector2 = global_position + _pending_aim_dir * beam_range
			PlayerVfxHelper.spawn_beam_flash(self, scene_root, global_position, endpoint, tint, _pending_ability.ability_id, 0)
			PlayerVfxHelper.cleanup_stale_beam_containers(self, 1)
			if "napalm" in _active_mods:
				_spawn_scorched_earth_patches(global_position, endpoint, scene_root)
		else:
			var active_beams: int = 0
			for i in valid_targets.size():
				if is_instance_valid(valid_targets[i]):
					PlayerVfxHelper.spawn_beam_flash(self, scene_root, global_position, valid_targets[i].global_position, tint, _pending_ability.ability_id, i)
					active_beams += 1
					if "napalm" in _active_mods:
						_spawn_scorched_earth_patches(global_position, valid_targets[i].global_position, scene_root)
			PlayerVfxHelper.cleanup_stale_beam_containers(self, active_beams)
	elif _pending_ability.tags.has("Melee"):
		var swing_dir: Vector2
		if manual_aim:
			swing_dir = _pending_aim_dir
		elif not valid_targets.is_empty() and is_instance_valid(valid_targets[0]):
			swing_dir = (valid_targets[0].global_position - global_position).normalized()
		else:
			swing_dir = Vector2.RIGHT
		## Range: read from the processed ability so size mod scaling is included.
		var range_px: float = _pending_ability.targeting.max_range
		## Arc: scale with size mod (same mult the factory applies to range).
		var arc_deg: float = _weapon_data.get("arc_degrees", 200.0)
		if "size" in _active_mods:
			arc_deg *= ModData.ALL["size"]["params"].get("size_mult", 1.5)
		PlayerVfxHelper.spawn_melee_arc(self, scene_root, global_position, swing_dir.angle(), range_px, deg_to_rad(arc_deg * 0.5), tint, _active_mods)
	elif _pending_ability.tags.has("Artillery") and not valid_targets.is_empty() and is_instance_valid(valid_targets[0]):
		var scatter    := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
		var target_pos: Vector2 = valid_targets[0].global_position + scatter
		PlayerVfxHelper.spawn_artillery_marker(self, scene_root, target_pos, _weapon_data.get("aoe_radius", 64.0), _weapon_data.get("fuse_time", 1.0), tint)

	_clear_pending_shot()


func _clear_pending_shot() -> void:
	_pending_ability = null
	_pending_targets.clear()
	_pending_aim_dir = Vector2.ZERO


# --- Main loop ---

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# Ravager Bloodrage: +30% damage below half HP (warden-style conditional passive;
	# polled here because heals bypass player.take_damage — one compare per frame).
	if _passive_id == "ravager_passive":
		_update_bloodrage()
	# Deadeye Calm Hands: +25% damage above 80% HP — the mirror image of Bloodrage.
	elif _passive_id == "deadeye_passive":
		_update_calm_hands()
	# Verdant Primal Vigor: regenerate once out of harm's way for a few seconds.
	elif _passive_id == "verdant_passive":
		_time_since_hit += delta
		if _time_since_hit >= VERDANT_REGEN_DELAY and health.current_hp < health.max_hp:
			health.apply_healing(health.max_hp * VERDANT_REGEN_FRAC * delta)

	# Iframe countdown
	if _iframes_timer > 0.0:
		_iframes_timer -= delta
		if _iframes_timer <= 0.0:
			if _hit_flash_tween and _hit_flash_tween.is_valid():
				_hit_flash_tween.kill()
				_hit_flash_tween = null
			sprite.modulate = Color.WHITE

	_update_controller_aim()

	# Movement (CC-aware)
	var move_blocked: bool = status_effect_component.is_disabled() or status_effect_component.is_movement_disabled()
	## Analog: length is the fraction of move_speed the stick is asking for, so this must
	## NOT be normalized — that is what pinned movement to 8 directions at full speed.
	var input_dir := Vector2.ZERO
	if not move_blocked:
		input_dir = MoveInput.get_move_vector()
	if input_dir.length_squared() > 0.0:
		_last_move_dir = input_dir.normalized()   ## direction only — dash/aim fallback

	# Dash: refill charges, then consume one on press (CC blocks both starting a dash
	# and is checked the same way the movement block is).
	_tick_dash_cooldown(delta)
	if not move_blocked and Input.is_action_just_pressed("dash"):
		_try_dash(input_dir)

	var move_speed_val: float = get_stat("move_speed")
	var target_velocity: Vector2 = input_dir * move_speed_val
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			# Dash ended — drop i-frames and snap to normal movement so there's no
			# floaty residual velocity to slide on.
			is_invulnerable = false
			_set_dash_phasing(false)  # restore enemy body collision
			velocity = target_velocity
		else:
			# Ease-out impulse: high speed at start, tapering toward the tail.
			var p: float = 1.0 - (_dash_timer / DASH_DURATION)  ## 0 -> 1 over the dash
			var ease_factor: float = 1.0 - DASH_EASE_OUT * p * p
			velocity = _dash_dir * (_dash_speed_current * ease_factor)
	else:
		velocity = velocity.move_toward(target_velocity, 1500.0 * delta)
	velocity += knockback_velocity
	move_and_slide()
	# Snap sprite to pixel grid without discarding fractional physics position.
	# Rounding position itself loses sub-pixel accumulation each frame, cutting
	# diagonal speed by ~15% vs ~10% cardinal (diagonal per-axis step is smaller).
	if sprite:
		sprite.position = position.round() - position
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1400.0 * delta)

	_dash_anim_timer = maxf(_dash_anim_timer - delta, 0.0)
	## Spark Frost Burst: the shard aura loops for ICE_AURA_TIME, then plays its deteriorate pass.
	if _ice_aura != null and _ice_aura.visible and _ice_aura_timer > 0.0:
		_ice_aura_timer -= delta
		if _ice_aura_timer <= 0.0 and _ice_aura.animation == &"loop":
			_ice_aura.play(&"end")
	if sprite:
		_update_facing()
		## Stealth legibility: ghost the body while invisible (Conceal / Smoke Bomb / Vanish)
		## so the player can TELL they're hidden. Alpha only — flashes use self_modulate.
		var stealth_a: float = 0.45 if is_invisible() else 1.0
		sprite.modulate.a = stealth_a if absf(sprite.modulate.a - stealth_a) < 0.02 \
				else lerpf(sprite.modulate.a, stealth_a, minf(12.0 * delta, 1.0))
		## Legacy mirror-flip only for baked frames without directional rows.
		if not _has_dir_anims and input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
		if not _attack_anim_active and not _damage_anim_active and not _is_dying \
				and _dash_anim_timer <= 0.0:
			if input_dir.length_squared() > 0:
				_play_anim("walk")
			else:
				_play_anim("idle")

	# Combo input bookkeeping + executor tick (cheap, runs every frame so held-tracking stays exact)
	if _combat_input:
		_combat_input.tick()
	if skill_component:
		skill_component.tick(delta)
	if choreography_runner and choreography_runner.is_running():
		# CC interrupts an active combo, same as it interrupts enemy choreography
		if status_effect_component.is_disabled():
			choreography_runner.interrupt()
		else:
			choreography_runner.tick(delta)

	# Attack: melee-combo characters run the combo graph; everyone else uses weapon fire.
	# BehaviorComponent.tick handles auto-attack timer and targeting.
	# Note: orchestrator also ticks behavior, but player needs per-frame firing
	# since orchestrator tick order is status→cooldown→behavior
	if not status_effect_component.is_disabled():
		if _combo_ability != null:
			_tick_combo()
		elif manual_fire_mode:
			_tick_manual_fire(delta)
		else:
			behavior_component.tick(delta, self)


# --- Manual fire (testing) ---

func toggle_manual_fire() -> bool:
	## Flip manual fire mode (driven by the F1 debug panel "Auto Fire" toggle). Manual is the
	## default; turning it off restores legacy auto-fire. Returns the new manual_fire_mode.
	manual_fire_mode = not manual_fire_mode
	## Reset the shared attack timer so the first shot after a mode switch is prompt.
	if behavior_component:
		behavior_component.auto_attack_timer = 0.0
	return manual_fire_mode


func _tick_manual_fire(delta: float) -> void:
	## Hold "fire" to shoot toward the mouse cursor at the weapon's normal cadence.
	## Reuses BehaviorComponent's timer + interval so attack-speed mods apply identically.
	if not Input.is_action_pressed("fire"):
		return
	behavior_component.auto_attack_timer -= delta
	if behavior_component.auto_attack_timer > 0.0:
		return
	var aa: AbilityDefinition = ability_component.get_auto_attack()
	if aa == null:
		return
	## Orbit weapons are passive (orbs self-manage their hits) — nothing to fire manually.
	if aa.tags.has("Orbit"):
		return
	var aim_pos: Vector2 = _get_aim_world_position()
	var aim_dir: Vector2 = aim_pos - global_position
	aim_dir = aim_dir.normalized() if aim_dir.length_squared() > 0.0 else _last_move_dir
	## Lock in the aim direction so _on_auto_attack / _fire_pending_shot render toward the
	## cursor and skip the auto re-aim. Resolve damage targets per weapon class (below).
	_pending_aim_dir = aim_dir
	_on_auto_attack(aa, _resolve_manual_targets(aa, aim_dir, aim_pos))
	behavior_component.auto_attack_timer = behavior_component.get_effective_attack_interval()


func _resolve_manual_targets(ability: AbilityDefinition, aim_dir: Vector2, aim_pos: Vector2) -> Array:
	## Pick the shot's targets from the cursor aim, per weapon class:
	##  • Beam  — real enemies along the aim ray (DealDamage hits them directly).
	##  • Melee — real enemies inside the swing arc toward the cursor.
	##  • Projectile/Spread — the phantom marker (direction stand-in; damage via collision).
	##  • Artillery — the phantom marker at the cursor (GroundZone detonates there).
	if ability.tags.has("Beam"):
		return _resolve_beam_targets(ability, aim_dir)
	if ability.tags.has("Melee"):
		return _resolve_melee_targets(ability, aim_dir)
	## Projectile / Spread / Artillery — marker provides the aim point.
	return [_get_aim_target(aim_pos)]


func _resolve_beam_targets(ability: AbilityDefinition, aim_dir: Vector2) -> Array:
	## Enemies within a thin corridor along the aim ray (in front, near the line),
	## nearest first, capped at the live projectile_count (multi-beam stat).
	if spatial_grid == null or ability.targeting == null:
		return []
	var max_range: float = ability.targeting.max_range
	var max_targets: int = maxi(1, int(get_stat("projectile_count")))
	const BEAM_HALF_WIDTH: float = 20.0
	var candidates: Array = spatial_grid.get_nearby_in_range(global_position, 1, max_range * max_range)
	var hits: Array = []
	for e in candidates:
		if not is_instance_valid(e) or not e.is_alive:
			continue
		var to_e: Vector2 = e.global_position - global_position
		var along: float = to_e.dot(aim_dir)
		if along <= 0.0:
			continue  ## behind the aim direction
		var perp: float = (to_e - aim_dir * along).length()
		if perp <= BEAM_HALF_WIDTH:
			hits.append(e)
	hits.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	if hits.size() > max_targets:
		hits = hits.slice(0, max_targets)
	return hits


func _resolve_melee_targets(ability: AbilityDefinition, aim_dir: Vector2) -> Array:
	## Enemies within max_range and inside the swing arc centred on the cursor direction.
	if spatial_grid == null or ability.targeting == null:
		return []
	var max_range: float = ability.targeting.max_range
	var arc_deg: float = _weapon_data.get("arc_degrees", 170.0)
	if "size" in _active_mods:
		arc_deg *= ModData.ALL["size"]["params"].get("size_mult", 1.5)
	var half_arc: float = deg_to_rad(arc_deg * 0.5)
	var candidates: Array = spatial_grid.get_nearby_in_range(global_position, 1, max_range * max_range)
	var hits: Array = []
	for e in candidates:
		if not is_instance_valid(e) or not e.is_alive:
			continue
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length_squared() <= 0.0:
			hits.append(e)
			continue
		if absf(aim_dir.angle_to(to_e)) <= half_arc:
			hits.append(e)
	return hits


func _get_aim_target(aim_pos: Vector2 = Vector2.INF) -> Node2D:
	## Persistent invisible world-space marker parked at the mouse cursor; reused each shot.
	## Uses AimMarkerScript so it carries `is_alive` — the projectile spawn guards and
	## EffectDispatcher read that off the target and would crash on a bare Node2D.
	if _aim_marker == null or not is_instance_valid(_aim_marker):
		_aim_marker = AimMarkerScript.new()
		_aim_marker.name = "ManualAimMarker"
		_aim_marker.top_level = true
		get_tree().current_scene.add_child(_aim_marker)
	_aim_marker.global_position = aim_pos if aim_pos != Vector2.INF else _get_aim_world_position()
	return _aim_marker


# --- Melee combo (ChoreographyRunner host) ---
## Active only when _combo_ability is set (melee-combo weapon/character). The runner drives the
## graph; branch conditions read _combat_input. See docs/combat_chain_architecture.md.

func set_combo_ability(ability: AbilityDefinition) -> void:
	## Install (or clear) the melee combo graph. Called by _load_combo on character/weapon load.
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.interrupt()
	_combo_ability = ability
	## A combo character doesn't auto-fire its weapon — the combo IS the attack. Drop the auto-attack
	## hookup so neither the player loop nor the orchestrator fires the weapon underneath the combo.
	if ability != null and behavior_component \
			and behavior_component.auto_attack_requested.is_connected(_on_auto_attack):
		behavior_component.auto_attack_requested.disconnect(_on_auto_attack)


func _load_combo() -> void:
	## Melee-combo characters drive a ChoreographyRunner combo graph + neutral skills instead of
	## weapon auto-fire. Data-driven off CharacterData "melee_kit" — a new combo character is a new
	## ChainFactory/SkillFactory case + a "melee_kit" field, no edits here. The weapon feeds damage.
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, {})
	var kit_id: String = char_data.get("melee_kit", "")
	_kit_id = kit_id
	_dash_style = char_data.get("dash_style", "")
	## Class mods (task 31): the ids equipped for THIS character that belong to THIS kit. Applied
	## to the freshly-built kit/skills at build time via the ClassModFactory seam. Rebuilt every
	## _load_combo, so kit mutations never accumulate; player modifiers carry "classmod_" so they
	## can be stripped on the next rebuild / weapon switch.
	var class_mods: Array = ProgressionManager.get_active_class_mods(char_id)
	modifier_component.remove_by_source_prefix("classmod_")
	## Run-scoped ability upgrades (task 33): kit-mutation entries are applied fresh each rebuild
	## (same "no accumulation" guarantee as class mods — build_kit returns a pristine kit).
	var ability_up_dicts: Array[Dictionary] = UpgradeManager.get_kit_mutation_upgrades_for_kit(kit_id)
	if kit_id != "":
		var kit: Dictionary = ChainFactory.build_kit(kit_id, _weapon_data)
		ClassModFactory.apply_to_kit(kit_id, kit, class_mods)
		ClassModFactory.apply_upgrade_dicts_to_kit(kit_id, kit, ability_up_dicts)
		_apply_hit_frame_overrides(char_id, kit.values())
		set_combo_ability(kit.get("light"))
		_combo_heavy = kit.get("heavy")
		_combo_channel = kit.get("channel")
		for m in ClassModFactory.build_modifiers(kit_id, class_mods):
			modifier_component.add_modifier(m)
	else:
		set_combo_ability(null)
		_combo_heavy = null
		_combo_channel = null
	## RMB specials are combo abilities; Q/E skills load from SkillFactory per kit.
	if skill_component:
		skill_component.clear()
		if kit_id != "":
			var skills: Dictionary = SkillFactory.build_kit_skills(kit_id, _weapon_data)
			ClassModFactory.apply_to_skills(kit_id, skills, class_mods)
			ClassModFactory.apply_upgrade_dicts_to_skills(kit_id, skills, ability_up_dicts)
			_apply_hit_frame_overrides(char_id, skills.values())
			for slot in skills:
				skill_component.set_skill(slot, skills[slot])


## Animation Lab hit-frame overrides: apply Ben's authored hit_frame (anim_overrides.json) to
## every choreography phase playing that anim. Runs at kit build so it survives rebuilds.
func _apply_hit_frame_overrides(char_id: String, abilities: Array) -> void:
	for ab in abilities:
		if ab == null or ab.choreography == null:
			continue
		for phase in ab.choreography.phases:
			if phase.animation == "":
				continue
			var ov: Dictionary = CharacterSpriteFactory.get_anim_override(char_id, phase.animation)
			if ov.has("hit_frame"):
				phase.hit_frame = int(ov["hit_frame"])


func _tick_combo() -> void:
	## From neutral: LMB starts the light combo; RMB tap starts the heavy combo (Uppercut→Cataclysm),
	## RMB hold starts the Taunt channel. Mid-combo RMB is handled by the runner's branches, not here,
	## since this returns early while the runner is active.
	if choreography_runner == null or choreography_runner.is_running():
		## Opener grace (Ben, playtest 2026-07-19): RMB pressed in the light graph before the
		## heavy-finisher gate opens shouldn't dead-end — cancel into the heavy opener instead
		## (Uppercut/Bash/...). Phases that DO listen for heavy_attack keep their branch.
		if choreography_runner != null and choreography_runner.is_running() \
				and _combo_heavy != null \
				and choreography_runner.get_ability() == _combo_ability \
				and Input.is_action_just_pressed("heavy_attack") \
				and not choreography_runner.current_phase_handles("heavy_attack"):
			if _combat_input:
				_combat_input.consume("heavy_attack")
			choreography_runner.interrupt()
			choreography_runner.start(_combo_heavy, [self])
		_rmb_pending = false   ## a combo started under us — drop any pending neutral RMB
		return

	## Q/E skills (control-scheme pass 2026-07-05): both are SkillComponent skills fired
	## through the shared runner.
	if InputMap.has_action("skill_q") and Input.is_action_just_pressed("skill_q"):
		_on_skill_q()
	if InputMap.has_action("skill_e") and Input.is_action_just_pressed("skill_e") \
			and skill_component and skill_component.has_skill("skill_e"):
		skill_component.trigger("skill_e")

	if Input.is_action_just_pressed("light_attack"):
		## Consume the opening tap so the first cancel window doesn't read it as an advance.
		if _combat_input:
			_combat_input.consume("light_attack")
		choreography_runner.start(_combo_ability, [self])
		return

	## Neutral RMB: distinguish tap (heavy combo) from hold (Taunt channel) via held duration.
	if _combat_input == null:
		return
	if Input.is_action_just_pressed("heavy_attack"):
		_rmb_pending = true
	if _rmb_pending:
		if _combat_input.held_for("heavy_attack") >= TAUNT_HOLD_THRESHOLD:
			_start_taunt_channel()
			_rmb_pending = false
		elif Input.is_action_just_released("heavy_attack"):
			## Consume so Uppercut's follow-up window doesn't read this same tap as the Cataclysm advance.
			_combat_input.consume("heavy_attack")
			if _combo_heavy != null:
				choreography_runner.start(_combo_heavy, [self])
			_rmb_pending = false


## HUD hook: the active melee kit id.
func get_kit_id() -> String:
	return _kit_id


func _on_skill_q() -> void:
	## Q is a normal skill slot fired through the shared runner, like E.
	if skill_component and skill_component.has_skill("skill_q"):
		skill_component.trigger("skill_q")


func _start_taunt_channel() -> void:
	if _combo_channel == null:
		return
	## Slow the player ~20% while channeling — trade-off for the ongoing shockwave.
	modifier_component.remove_by_source_prefix("combo_taunt")
	_add_modifier("move_speed", "bonus", -0.20, "combo_taunt")
	choreography_runner.start(_combo_channel, [self])


# --- ChoreographyRunner host interface ---

func choreo_sprite() -> AnimatedSprite2D:
	return sprite


func choreo_resolve_targets(_rule: TargetingRule) -> Array:
	## Combos self-center (AoE around the player); no external retargeting needed.
	return [self]


func choreo_fire_effects(effects: Array, _targets: Array, ability: AbilityDefinition) -> void:
	## Route each combo/skill effect to the right target set:
	##  • AreaDamageEffect — self-centers: fire on [self] so EffectDispatcher resolves the AoE around
	##    the player and excludes us. Radius scales with the melee_range stat (the "Reach" hook),
	##    applied to a duplicate so the base resource isn't compounded across swings.
	##  • DisplacementEffect (Uppercut fling) — dispatched per-enemy (the system displaces one target
	##    per call), targeting nearby enemies, knockback away from the player.
	##  • anything else — fire on the nearby-enemy set.
	var reach: float = _melee_range()
	## Aggression breaks stealth: any damaging effect fired drops "concealed" (Smoke Bomb
	## lasts until the attack; the Ranger's channel is unaffected — its beats deal no damage).
	if status_effect_component.has_status("concealed"):
		for eff in effects:
			if eff is AreaDamageEffect or eff is SpawnProjectilesEffect or eff is DealDamageEffect:
				status_effect_component.force_remove_status("concealed", self)
				break
	## Bomb detonation: this callback IS the hit_frame moment — swap the tossed bomb for the
	## package explosion at its world landing spot.
	var is_bomb: bool = sprite != null and String(sprite.animation).begins_with("bomb")
	if is_bomb:
		_detonate_bomb_fx(reach)
	## Holy Hammer (Paladin): the slam also launches the hammerdin spiral — blessed hammers
	## corkscrewing out from the Warden (HolyHammer nodes carry their own damage/visuals).
	if sprite != null and String(sprite.animation).begins_with("hammer"):
		_spawn_holy_hammers(reach)
	var cur_anim: String = String(sprite.animation) if sprite else ""
	## Barbarian Sunder: the broken ground stays broken — leave a fading crack decal.
	if cur_anim.begins_with("sunder"):
		_spawn_sunder_cracks()
	## Companion summons: the ignition burst also spawns/refreshes the kit's companion.
	## (Order matters — "summon_blood" must not fall into the generic "summon" case.)
	if cur_anim.begins_with("summon_blood"):
		_spawn_blood_elemental()
	elif cur_anim.begins_with("summon"):
		_spawn_fire_familiar()
	## Cleric Spirit Guardians: the prayer summons/refreshes the guardian companion.
	if cur_anim.begins_with("pray_guardian"):
		_spawn_spirit_guardian()
	## Necromancer summons: Rise Corpse raises the persistent champion; Bone Legion raises a swarm.
	## (Order matters — "bone_legion" must not fall into the generic "rise_corpse" case.)
	if cur_anim.begins_with("bone_legion"):
		_spawn_bone_legion()
	elif cur_anim.begins_with("rise_corpse"):
		_spawn_skeletal_champion()
	## Demonologist: the pact ritual binds the Angry Demon. (The finisher shares this cast body under
	## the name "brimstone", which must NOT reach this hook — hence the exact prefix.)
	if cur_anim.begins_with("pact_ritual"):
		_spawn_angry_demon()
	## Hell Breach (light chain node 1): crack the floor on the landing slam. The phase's own AoE +
	## Burning ride the normal effect routing below; this is just the fissure. No displacement.
	if cur_anim.begins_with("hell_breach"):
		_hellbreach_slam()
	## Second Wind: the salute lands — green mend ring + flash so the heal reads on cast.
	if cur_anim.begins_with("rally"):
		_spawn_shockwave_ring(26.0, Color(0.35, 1.0, 0.45, 0.9))
		if sprite:
			sprite.self_modulate = Color(0.7, 1.6, 0.8, 1.0)
			var heal_t := create_tween()
			heal_t.tween_property(sprite, "self_modulate", Color.WHITE, 0.35)
	## Shield Rush: the charge itself — dash motion, corridor drag, delayed slam.
	if cur_anim.begins_with("rush"):
		_start_shield_rush(reach)
	## Skirmisher's Step: the back-off kick also refunds a dash charge (escape tool, not
	## just a shove — Ben 2026-07-19).
	if ability != null and ability.ability_id == "ranger_skirmish_step":
		_dash_charges = mini(_dash_charges + 1, _max_dash_charges())
	## Warden Aegis Shield (Q): the cast raises a standing absorb pool + persistent DomeCycle bubble.
	if ability != null and ability.ability_id == "paladin_aegis_vow":
		_grant_absorb_shield()
	## Spark Storm Call (E): call the sky down on the whole arena — a lightning strike + a
	## Lightning chunk over every enemy, plus an electric pulse around the caster.
	if ability != null and ability.ability_id == "wizard_storm_call":
		_cast_storm_call(ability)
	## Spark Frost Burst (Q): the point-blank ice nova's damage/chill are in the skill's own
	## effects; the host just adds the Burst_Ice pop + the lingering shard aura.
	if ability != null and ability.ability_id == "wizard_ice_burst":
		_cast_ice_burst()
	var is_torrent: bool = cur_anim.begins_with("torrent")
	var is_throw: bool = cur_anim.begins_with("throw")
	var is_teleport: bool = cur_anim.begins_with("teleport_out")
	var is_extract: bool = cur_anim.begins_with("extract")
	var is_spikes: bool = cur_anim.begins_with("spikes")
	## Demonologist ground zones: the Brimstone Circle is slammed down UNDERFOOT (he's the epicentre);
	## Archdemon's Call tears open at the cursor. Both carry their own pack decal below.
	var is_brimstone: bool = cur_anim.begins_with("brimstone")
	var is_archdemon: bool = cur_anim.begins_with("archdemon_call")
	var is_vamp_rip: bool = cur_anim.begins_with("vampirize")
	var is_vamp_drink: bool = cur_anim.begins_with("consume")
	var self_effects: Array = []
	var enemy_effects: Array = []
	var proj_effects: Array = []
	var buff_effects: Array = []
	var zone_effects: Array = []
	var aoe_radius: float = 0.0
	for e in effects:
		if e is AreaDamageEffect:
			if is_equal_approx(reach, 1.0):
				self_effects.append(e)
			else:
				var scaled: AreaDamageEffect = e.duplicate()
				scaled.aoe_radius = e.aoe_radius * reach
				self_effects.append(scaled)
			if aoe_radius <= 0.0:
				aoe_radius = e.aoe_radius * reach
		elif e is SpawnProjectilesEffect:
			proj_effects.append(e)
		elif e is ApplyStatusEffectData and e.apply_to_self:
			buff_effects.append(e)   ## self-buffs (Extract Power) — applied to the player
		elif e is HealEffect:
			buff_effects.append(e)   ## self-heal (Healing Words / Regrowth / Sanctuary) → [self]
		elif e is GroundZoneEffect:
			zone_effects.append(e)   ## Root / Word of Pain — placed at the clamped cursor below
		else:
			enemy_effects.append(e)

	## Vampirize extract beat: sample BEFORE the drain AoE dispatches — a drain that kills
	## its victims still counts as blood found (the kill must feed the drink).
	if is_vamp_rip:
		_vamp_hit = not _nearby_enemies(50.0 * reach).is_empty()

	if not self_effects.is_empty():
		## The bomb's blast centers on its landing point, the torrent a short way toward the
		## cursor (aim-marker targets); every other combo AoE self-centers on the player.
		var center: Node2D = self
		if is_bomb:
			center = _get_aim_target(_bomb_land)
		elif is_torrent:
			var t_aim: Vector2 = _get_aim_world_position() - global_position
			if t_aim.length_squared() >= 1.0:
				center = _get_aim_target(global_position + t_aim.normalized() * TORRENT_FORWARD)
		elif is_throw:
			## Throw Things: the junk lands where you point, up to a hurl's reach.
			var j_aim: Vector2 = _get_aim_world_position() - global_position
			if j_aim.length() > THROW_RANGE:
				j_aim = j_aim.normalized() * THROW_RANGE
			center = _get_aim_target(global_position + j_aim)
			_spawn_thrown_junk(global_position + j_aim)
		EffectDispatcher.execute_effects(self_effects, self, [center], ability, combat_manager)

	## Charged Fireball release: swap the base projectile for one scaled by how long the
	## charge was held (damage up to ×2; blast radius and visual grow with the square root).
	if cur_anim.begins_with("fireball_2") and _charge_start_ms >= 0:
		var charge_t: float = float(Time.get_ticks_msec() - _charge_start_ms) / 1000.0
		_charge_start_ms = -1
		var mult: float = clampf(1.0 + charge_t / ChainFactory.WIZARD_CHARGE_MAX, 1.0, FIREBALL_MULT_MAX)
		var scaled_fb: SpawnProjectilesEffect = ChainFactory._wizard_fireball(
				ChainFactory._damage_type(_weapon_data), _weapon_data.get("damage", 42.0) * mult)
		scaled_fb.projectile.impact_aoe_radius *= sqrt(mult)
		scaled_fb.projectile.visual_scale = Vector2.ONE * sqrt(mult)
		proj_effects = [scaled_fb]

	if not proj_effects.is_empty():
		## Cursor-aimed casts (Wizard/Blood Mage projectiles): "aimed_single"/"spread" read
		## source.attack_target — park it on the aim cursor, then route through the normal
		## projectile pipeline.
		## Sync live projectile stats (projectile_count, pierce, projectile_size) into a
		## per-fire duplicate so passive tree and upgrade nodes apply to combo projectiles.
		var proj_count: int = int(get_stat("projectile_count"))
		var pierce_bonus: int = int(get_stat("pierce"))
		var size_mult: float = get_stat("projectile_size")
		var live_proj: Array = []
		for eff in proj_effects:
			if eff is SpawnProjectilesEffect:
				var e: SpawnProjectilesEffect = eff.duplicate(true)
				## projectile_count is ADDITIVE above the base 1 — authored volley counts
				## (Triple Shot 3, Arrow Storm 6, Fan the Hammer 5...) must survive.
				e.count = e.count + maxi(0, proj_count - 1)
				if e.projectile.pierce_count != -1:
					e.projectile.pierce_count = e.projectile.pierce_count + pierce_bonus
				e.projectile.visual_scale = e.projectile.visual_scale * size_mult
				e.projectile.hit_radius   = e.projectile.hit_radius * size_mult
				live_proj.append(e)
			else:
				live_proj.append(eff)
		attack_target = _get_aim_target()
		EffectDispatcher.execute_effects(live_proj, self, [self], ability, combat_manager)

	if not buff_effects.is_empty():
		EffectDispatcher.execute_effects(buff_effects, self, [self], ability, combat_manager)

	## Ground zones (Druid Root, Cleric Word of Pain): drop at the clamped cursor and mark the
	## spot with the pack's ground decal (a one-shot burst; the zone itself ticks host-side).
	if not zone_effects.is_empty():
		## Blood Eruption's pool and the Brimstone Circle erupt UNDERFOOT (the caster is the
		## epicenter); Root / Word of Pain / Archdemon's Call drop at the clamped cursor.
		var underfoot: bool = is_spikes or is_brimstone
		var z_pos: Vector2 = global_position
		if not underfoot:
			var z_aim: Vector2 = _get_aim_world_position() - global_position
			if z_aim.length() > THROW_RANGE:
				z_aim = z_aim.normalized() * THROW_RANGE
			z_pos = global_position + z_aim
		EffectDispatcher.execute_effects(zone_effects, self, [_get_aim_target(z_pos)], ability, combat_manager)
		## The zone's live radius (incl. Reach and any mod scaling) sizes the pack decal over it.
		var z_radius: float = 0.0
		for z in zone_effects:
			if z is GroundZoneEffect:
				z_radius = z.radius * reach
				break
		if is_spikes:
			for z in zone_effects:
				if z is GroundZoneEffect:
					_register_blood_pool(z_pos, z.radius * reach, z.duration)
					break
		elif is_brimstone:
			_spawn_brimstone_sigil(z_pos, z_radius)
		elif is_archdemon:
			_spawn_archdemon_spell(z_pos, z_radius)
		else:
			_spawn_oneshot_fx(ROOT_DECAL_SHEET if cur_anim.begins_with("root_cast") else PAIN_DECAL_SHEET, z_pos, 12.0)

	## Teleport blinks AFTER its departure burst has resolved at the old position.
	if is_teleport:
		_do_teleport()
	## Extract Power: the pact's price — paid as the buff lands.
	if is_extract:
		_pay_blood_cost()
	## Blood Spikes: ground-burst sheet at the hit-zone radius.
	if is_spikes:
		_spawn_spikes_ground(aoe_radius)
	## Vampirize consume beat: drink the blood the extract beat found (heal + drain wisp).
	if is_vamp_drink and _vamp_hit:
		health.apply_healing(health.max_hp * VAMP_HEAL_FRAC)
		var victims: Array = _nearby_enemies(50.0 * reach)
		if not victims.is_empty():
			_spawn_drain_wisp(victims[0].global_position)
	if not enemy_effects.is_empty():
		var enemies: Array = _nearby_enemies(90.0 * reach)
		if not enemies.is_empty():
			for e in enemy_effects:
				if e is DisplacementEffect:
					if combat_manager and combat_manager.get("displacement_system"):
						for en in enemies:
							combat_manager.displacement_system.execute(self, ability, e, [en])
				else:
					EffectDispatcher.execute_effects([e], self, enemies, ability, combat_manager)


func _nearby_enemies(radius: float) -> Array:
	## Live enemies within `radius` of the player (faction 1 = enemies in the spatial grid).
	if spatial_grid == null:
		return []
	var out: Array = []
	for en in spatial_grid.get_nearby_in_range(global_position, 1, radius * radius):
		if is_instance_valid(en) and en.is_alive:
			out.append(en)
	return out


func choreo_on_phase_anim(phase: ChoreographyPhase, stage: String = "") -> void:
	## Runner calls this when a combo node's body anim starts → play the matching swing effect, sized
	## to THIS node's hit-zone radius so the white edge marks exactly where the hitbox reaches.
	## `stage` is set for staged channel bodies ("intro"/"loop"/"outro") — a stage may declare
	## its OWN overlay, published by the factory as "<anim>_<stage>_fx".
	var anim: String = phase.animation
	if stage != "" and _combo_fx != null and _combo_fx.sprite_frames != null \
			and _combo_fx.sprite_frames.has_animation("%s_%s_fx" % [phase.animation, stage]):
		anim = "%s_%s" % [phase.animation, stage]
	## Ground layer: packs ship "Base" sheets meant to render BELOW the character (see the
	## Dictums _AnimationInfo.txt). Played on its own sprite under the body.
	_play_base_layer(anim)
	var reach: float = _melee_range()
	var radius: float = _node_hit_radius(phase) * reach   ## effective hit-zone radius (incl. capped Reach)

	## Wizard Fireball charge: the clock starts and the greed tax (slow) applies; the release
	## phase lifts the slow (the scaled shot itself resolves in choreo_fire_effects).
	if anim == "fireball":
		_charge_start_ms = Time.get_ticks_msec()
		modifier_component.remove_by_source_prefix("combo_charge")
		_add_modifier("move_speed", "bonus", WIZARD_CHARGE_SLOW, "combo_charge")
	elif anim == "fireball_2":
		modifier_component.remove_by_source_prefix("combo_charge")

	## Bone Swirl (Necromancer heavy): bones erupt and orbit the caster, starting with the cast.
	if anim.begins_with("bone_swirl"):
		_spawn_bone_swirl_fx(phase)

	## Big-impact nodes with no _fx sheet (Taunt) ring out a procedural shockwave at the
	## hit-zone radius instead. (Flame Nova retired 2026-07-20 → the Spark's E is Storm Call
	## now; Hammer dropped earlier — the spiraling hammers ARE its visual.)
	if anim == "taunt":
		if _combo_fx:
			_combo_fx.visible = false
		_spawn_shockwave_ring(radius)
		return
	if anim == "hammer" and _combo_fx:
		_combo_fx.visible = false
	## Rogue Bomb: toss the package's spinning bomb projectile during the wind-up; the explosion
	## ("bomb_fx") is played at detonation by choreo_fire_effects, not at anim start.
	if anim == "bomb":
		if _combo_fx:
			_combo_fx.visible = false
		_start_bomb_toss()
		return
	## Wizard Fire Torrent: dedicated directional flame overlay ahead of the caster.
	if anim == "torrent":
		if _combo_fx:
			_combo_fx.visible = false
		_show_torrent_fx()
		return
	if _torrent_fx:
		_torrent_fx.visible = false   ## any non-torrent node ends the flame
	## Gunslinger Desert Storm: directional barrage strip ahead of the shooter.
	if anim == "storm":
		if _combo_fx:
			_combo_fx.visible = false
		_show_storm_fx()
		return
	if _storm_fx:
		_storm_fx.visible = false     ## any non-storm node ends the barrage
	## Blood Mage Vampirize: Floating_Blood hovers over the Cursed through both channel beats.
	if anim == "vampirize" or anim == "consume":
		if _combo_fx:
			_combo_fx.visible = false
		_show_vamp_fx()
		return
	if _vamp_fx:
		_vamp_fx.visible = false      ## any non-vampirize node ends the float
	if _combo_fx == null or _combo_fx.sprite_frames == null:
		return
	## Facing variant of the swing effect when the fx sheet has directional rows (falls back
	## cardinal → nearest diagonal → base, same as the body).
	var fx_base: String = anim + "_fx"
	var fx: String = _facing_variant(_combo_fx.sprite_frames, fx_base)
	if fx == "":
		_combo_fx.visible = false
		return
	_combo_fx.flip_h = sprite.flip_h if fx == fx_base else false
	## Centered, scaled so the white's outer edge sits on the node's hit-zone radius. Nodes with
	## no AreaDamage radius (projectile casts — e.g. Wizard bolts) play frame-matched at native
	## size, only growing with Reach. Frame-matched FULL-BODY overlays (Apotheosis halo,
	## Mockery faces) stay native too — blowing them up to a big hit radius reads as pixel
	## mush (Ben 2026-07-19); the shockwave ring communicates the zone instead.
	## (No ring here — Ben 2026-07-20: rings on regular attacks read as stray Taunt circles.
	## Rings are reserved for the moves where the circle IS the move: Taunt, Nova, heals,
	## Reckoning's detonation, the Shield Rush slam.)
	var s: float = (radius / FX_NATIVE_RADIUS) if radius > 0.0 else reach
	if anim in NATIVE_FX_ANIMS:
		s = reach
	_combo_fx.position = Vector2.ZERO
	_combo_fx.scale = Vector2(s, s)
	_combo_fx.visible = true
	_combo_fx.play(fx)


func _node_hit_radius(phase: ChoreographyPhase) -> float:
	## The node's AreaDamage hit radius (0.0 if it has none, e.g. a pure-displacement node).
	for e in phase.effects:
		if e is AreaDamageEffect:
			return e.aoe_radius
	return 0.0


func _melee_range() -> float:
	## melee_range stat, capped at MELEE_RANGE_MAX so reach tops out at the end-of-the-road size.
	return minf(get_stat("melee_range"), MELEE_RANGE_MAX)


## Ground-layer overlay ("<anim>_base"): the packs' "Base" sheets belong UNDER the character.
## Shares the character SpriteFrames like ComboFx; hidden whenever the node has no base sheet.
func _play_base_layer(anim: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var want: String = anim + "_base"
	if not sprite.sprite_frames.has_animation(want):
		if _combo_base:
			_combo_base.visible = false
		return
	if _combo_base == null:
		_combo_base = AnimatedSprite2D.new()
		_combo_base.name = "ComboBase"
		_combo_base.centered = true
		_combo_base.z_index = -1          ## below the body, per the packs' instructions
		_combo_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_combo_base)
	_combo_base.sprite_frames = sprite.sprite_frames
	_combo_base.visible = true
	if _combo_base.animation != StringName(want) or not _combo_base.is_playing():
		_combo_base.play(want)


func _on_combo_fx_finished() -> void:
	if _combo_fx:
		_combo_fx.visible = false
		_combo_fx.position = Vector2.ZERO   ## undo any bomb-landing offset


func _start_bomb_toss() -> void:
	## Toss the Throw Bomb package's spinning projectile from the player toward the cursor
	## (clamped throw range), world-anchored so it doesn't ride along with the player. The
	## directional cell of the 3×3 projectile grid is picked from the throw octant.
	if _bomb_toss == null:
		_bomb_toss = AnimatedSprite2D.new()
		_bomb_toss.name = "BombToss"
		_bomb_toss.top_level = true   ## world space — the bomb is NOT attached to the player
		_bomb_toss.z_index = 1
		_bomb_toss.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sf := SpriteFrames.new()
		sf.clear_all()
		sf.add_animation(&"spin")
		sf.set_animation_loop(&"spin", true)
		sf.set_animation_speed(&"spin", 12.0)   ## frame 1/2 alternate = the fuse flicker
		_bomb_atlases.clear()
		for path in BOMB_PROJ_SHEETS:
			if not ResourceLoader.exists(path):
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = load(path)
			atlas.region = _bomb_cell(Vector2.DOWN)
			atlas.filter_clip = true
			sf.add_frame(&"spin", atlas)
			_bomb_atlases.append(atlas)
		## The package explosion, played at the landing point on detonation.
		sf.add_animation(&"explode")
		sf.set_animation_loop(&"explode", false)
		sf.set_animation_speed(&"explode", 20.0)
		if ResourceLoader.exists(BOMB_EXPLOSION_SHEET):
			var ex: Texture2D = load(BOMB_EXPLOSION_SHEET)
			for i in range(int(ex.get_width() / 32.0)):
				var cell := AtlasTexture.new()
				cell.atlas = ex
				cell.region = Rect2(i * 32, 0, 32, 32)
				cell.filter_clip = true
				sf.add_frame(&"explode", cell)
		_bomb_toss.sprite_frames = sf
		_bomb_toss.animation_finished.connect(_on_bomb_anim_finished)
		add_child(_bomb_toss)
	var aim: Vector2 = _get_aim_world_position() - global_position
	if aim.length_squared() < 1.0:
		aim = Vector2.DOWN
	_bomb_start = global_position
	_bomb_land = global_position + aim.limit_length(BOMB_THROW_MAX)
	for at in _bomb_atlases:
		at.region = _bomb_cell(aim)
	_bomb_toss.scale = Vector2.ONE
	_bomb_toss.global_position = _bomb_start
	_bomb_toss.visible = true
	_bomb_toss.play(&"spin")
	if _bomb_tween:
		_bomb_tween.kill()
	_bomb_tween = create_tween()
	_bomb_tween.tween_method(_bomb_arc_step, 0.0, 1.0, BOMB_TOSS_TIME)


func _bomb_arc_step(t: float) -> void:
	## Parabolic hop between the world-space start and landing points.
	if _bomb_toss:
		_bomb_toss.global_position = _bomb_start.lerp(_bomb_land, t) \
				+ Vector2(0.0, -BOMB_ARC_H * 4.0 * t * (1.0 - t))


## Octant → cell of the 3×3 directional projectile grid (screen y-down: row 0 = up, row 2 = down).
static func _bomb_cell(dir: Vector2) -> Rect2:
	var oct: int = wrapi(roundi(atan2(dir.y, dir.x) / (PI / 4.0)), 0, 8)   ## 0=E,1=SE,…,7=NE
	var cells: Array = [Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2),
			Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var c: Vector2i = cells[oct]
	return Rect2(c.x * 32, c.y * 32, 32, 32)


func _spawn_fire_familiar() -> void:
	## One familiar at a time — resummon replaces (the old one disperses).
	if is_instance_valid(_fire_familiar):
		_fire_familiar.disperse()
	var fam := FireFamiliar.new()
	fam.player_ref = self
	fam.damage_type = ChainFactory._damage_type(_weapon_data)
	get_tree().current_scene.add_child(fam)
	var side: float = -1.0 if _facing.ends_with("left") else 1.0
	fam.global_position = global_position + Vector2(18.0 * side, -14.0)
	_fire_familiar = fam


func _do_teleport() -> void:
	## Blink to the cursor (clamped). The departure burst already fired at the old spot; the
	## teleport_in phase plays at the destination. CharacterBody2D depenetrates on the next
	## move_and_slide if the landing point clips a wall edge.
	var aim: Vector2 = _get_aim_world_position() - global_position
	if aim.length_squared() < 1.0:
		return
	global_position += aim.limit_length(TELEPORT_RANGE)


func _show_torrent_fx() -> void:
	## Directional Fire_Torrent_Effect (64px frames, 4 facing rows) pours toward the cursor
	## while the channel loops; repositioned/re-rowed on every tick re-entry.
	if _torrent_fx == null:
		_torrent_fx = AnimatedSprite2D.new()
		_torrent_fx.name = "TorrentFx"
		_torrent_fx.z_index = 1
		_torrent_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sf := SpriteFrames.new()
		sf.clear_all()
		var tex: Texture2D = load(TORRENT_FX_SHEET)
		if tex:
			for facing in CharacterSpriteFactory.DIR_ROWS:
				var anim := StringName("t_" + facing)
				sf.add_animation(anim)
				sf.set_animation_loop(anim, true)
				sf.set_animation_speed(anim, 30.0)
				for i in range(int(tex.get_width() / 64.0)):
					var cell := AtlasTexture.new()
					cell.atlas = tex
					cell.region = Rect2(i * 64, int(CharacterSpriteFactory.DIR_ROWS[facing]) * 64, 64, 64)
					cell.filter_clip = true
					sf.add_frame(anim, cell)
		_torrent_fx.sprite_frames = sf
		add_child(_torrent_fx)
	var aim: Vector2 = _get_aim_world_position() - global_position
	if aim.length_squared() >= 1.0:
		_torrent_fx.position = aim.normalized() * TORRENT_FORWARD
	_torrent_fx.visible = true
	var anim_name := StringName("t_" + _facing)
	if _torrent_fx.animation != anim_name or not _torrent_fx.is_playing():
		_torrent_fx.play(anim_name)


func _spawn_blood_elemental() -> void:
	## One elemental at a time — resummon replaces (the old one banishes).
	if is_instance_valid(_blood_elemental):
		_blood_elemental.banish()
	var ele := BloodElemental.new()
	ele.player_ref = self
	ele.damage_type = ChainFactory._damage_type(_weapon_data)
	get_tree().current_scene.add_child(ele)
	var side: float = -1.0 if _facing.ends_with("left") else 1.0
	ele.global_position = global_position + Vector2(22.0 * side, 4.0)
	_blood_elemental = ele


func _spawn_spirit_guardian() -> void:
	## One guardian at a time — resummon replaces (the old one is unsummoned). Mirrors the
	## BloodElemental/FireFamiliar pet standard (autonomous locomotion + leash; CLAUDE.md).
	if is_instance_valid(_spirit_guardian):
		_spirit_guardian.banish()
	var g := SpiritGuardian.new()
	g.player_ref = self
	g.damage_type = ChainFactory._damage_type(_weapon_data)
	get_tree().current_scene.add_child(g)
	var side: float = -1.0 if _facing.ends_with("left") else 1.0
	g.global_position = global_position + Vector2(22.0 * side, 4.0)
	_spirit_guardian = g


func _spawn_skeletal_champion() -> void:
	## Rise Corpse (Q): raise a SQUAD of persistent champions (RISE_CORPSE_SQUAD), each clawing up
	## from its own spot with its own corpse-rise VFX — matched to the "several skeletons rise" read
	## the pack art gives. Resummon replaces the whole squad. Each is an autonomous pet
	## (SpiritGuardian/BloodElemental standard — own locomotion + leash; CLAUDE.md). Soul Harvest
	## adds one more skeleton to the raising.
	for old in _skeletal_champions:
		if is_instance_valid(old):
			old.banish()
	_skeletal_champions.clear()
	var dtype: String = ChainFactory._damage_type(_weapon_data)
	var count: int = RISE_CORPSE_SQUAD + (1 if _consume_summon_empower() else 0)
	## Spread them in a shallow fan ahead of the Shade so the emerges read as a rank of risen dead,
	## not a stack. Centered on the aim direction, fanned across ~120°, ~34px out.
	var base_ang: float = _aim_dir.angle() if _aim_dir.length_squared() > 0.01 else 0.0
	for i in range(count):
		var champ := SkeletalChampion.new()
		champ.player_ref = self
		champ.damage_type = dtype
		get_tree().current_scene.add_child(champ)
		var t: float = (float(i) / float(maxi(count - 1, 1))) - 0.5   # -0.5 .. 0.5
		var ang: float = base_ang + t * (TAU / 3.0)                    # fan across ~120°
		var dist: float = 30.0 + 8.0 * absf(t) * 2.0                   # outer skeletons a touch further
		champ.global_position = global_position + Vector2(cos(ang), sin(ang)) * dist
		_spawn_corpse_ground(champ.global_position)
		_skeletal_champions.append(champ)


func _spawn_bone_legion() -> void:
	## Bone Legion (E): raise a short-lived pack of weaker skeletons at once (they self-free on their
	## lifetime timer; not tracked as the persistent champion). Soul Harvest adds one more to the pack.
	var count: int = 3 if _consume_summon_empower() else 2
	var dtype: String = ChainFactory._damage_type(_weapon_data)
	for i in range(count):
		var sk := SkeletalChampion.new()
		sk.player_ref = self
		sk.damage_type = dtype
		sk.lifetime = 8.0
		sk.damage_mult = 0.35
		get_tree().current_scene.add_child(sk)
		var ang: float = TAU * float(i) / float(count)
		sk.global_position = global_position + Vector2(cos(ang), sin(ang)) * 26.0
		_spawn_corpse_ground(sk.global_position)


func _spawn_angry_demon() -> void:
	## Summon Angry Demon (Q): ONE bound elite, not a swarm — resummon banishes the old one. It rises
	## on its own Summon_Angry_Demon emerge (welded to the entity, so it can't be left behind as a
	## remnant) and then fights autonomously (AngryDemon owns its locomotion; CLAUDE.md pet standard).
	if is_instance_valid(_angry_demon):
		_angry_demon.banish()
	var d := AngryDemon.new()
	d.player_ref = self
	d.damage_type = ChainFactory._damage_type(_weapon_data)
	get_tree().current_scene.add_child(d)
	## Place it a short way along the aim direction so the pit opens where he's pointing.
	var ang: float = _aim_dir.angle() if _aim_dir.length_squared() > 0.01 else 0.0
	d.global_position = global_position + Vector2(cos(ang), sin(ang)) * 30.0
	_angry_demon = d


## Brimstone Circle (Demonologist finisher): the pack's Standalone_Summon sigil — the circle draws
## itself, ignites and gutters out — laid flat UNDER the bodies (z -1) at the ground zone's radius,
## its fps stretched so the fire dies exactly when the zone stops burning.
func _spawn_brimstone_sigil(at: Vector2, radius: float) -> void:
	var fps: float = float(BRIMSTONE_SIGIL_FRAMES) / maxf(BRIMSTONE_SIGIL_LIFE, 0.01)
	var fx: AnimatedSprite2D = _spawn_pack_fx(BRIMSTONE_SIGIL_SHEET, at, 32, 0, fps, false, -1)
	_scale_pack_fx(fx, radius)


## Archdemon's Call (Demonologist E): the pack's 27-frame Archdemon_Call_Spell over the ground zone
## at the cursor — pentagram, eruption, bite, and back into the floor. Above bodies (z 1): the thing
## coming through is bigger than anything standing on the field.
func _spawn_archdemon_spell(at: Vector2, radius: float) -> void:
	var fps: float = float(ARCHDEMON_SPELL_FRAMES) / maxf(ARCHDEMON_SPELL_LIFE, 0.01)
	var fx: AnimatedSprite2D = _spawn_pack_fx(ARCHDEMON_SPELL_SHEET, at, 32, 0, fps, false, 1)
	_scale_pack_fx(fx, radius)


## Hell Breach (Demonologist light chain, node 1): the slam, and the fissure that opens under it.
## The chain phase owns the damage (ChainFactory.build_demon_light) — this hook owns the art, so a
## Reach mod scales the phase's AoE and the fissure together without the two drifting apart.
##
## **He does not travel.** Ben 2026-07-26: the beat should read as swing → slam on the spot, like
## `Special_Animations/Hellfire/_GIFs/Hellfire.gif`. The pack art agrees — Hell_Breach's leap is a
## *vertical* hop (f2-4 airborne over a drop shadow) that lands on the tile it left, so the forward
## lunge this used to apply was fighting its own animation. Only the fissure is directional.
func _hellbreach_slam() -> void:
	var aim: Vector2 = _get_aim_world_position() - global_position
	var dir: Vector2 = aim.normalized() if aim.length_squared() >= 1.0 else _aim_dir
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	_spawn_hellbreach_fissure(dir)


## The landing fissure. Hell_Breach_Spell is 64px and its rows are CARDINAL — the crack grows
## east/west/south/north out of the cell centre — so the row is picked from the AIM vector (the
## crack races toward the cursor). Per the pack's AnimationInfo: "start Hell_Breach_Spell aligned
## with the Demonologist after the jump landing".
func _spawn_hellbreach_fissure(dir: Vector2) -> void:
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	## Cardinal quadrant of the leap: e / w / s / n → sheet rows 0 / 1 / 2 / 3.
	var row: int = HELLBREACH_FISSURE_ROWS[0]
	if absf(dir.x) >= absf(dir.y):
		row = HELLBREACH_FISSURE_ROWS[0] if dir.x >= 0.0 else HELLBREACH_FISSURE_ROWS[1]
	else:
		row = HELLBREACH_FISSURE_ROWS[2] if dir.y >= 0.0 else HELLBREACH_FISSURE_ROWS[3]
	_spawn_pack_fx(HELLBREACH_FISSURE_SHEET, global_position, 64, row,
			HELLBREACH_FISSURE_FPS, false, 1)


## Ashen Step (Demonologist dash): he hops out on the pack's Jump frames and the ground he was
## standing on keeps burning. Replaces the old Hell Breach dash, which became the light chain's
## second beat — the dash slot needed its own identity rather than a copy of a combo node.
## Dropped at the DEPARTURE point: the point of the tool is to make the space you just left
## expensive to follow you into.
func _spawn_ashenstep_trail(at: Vector2) -> void:
	var z := GroundZoneEffect.new()
	z.zone_id = "ashen_step"
	z.radius = ASHENSTEP_ZONE_RADIUS * _melee_range()
	z.duration = ASHENSTEP_ZONE_TIME
	z.tick_interval = ASHENSTEP_ZONE_TICK
	z.target_faction = "enemy"
	z.vfx_element = "fire"
	var burn := DealDamageEffect.new()
	burn.damage_type = ChainFactory._damage_type(_weapon_data)
	burn.base_damage = _weapon_data.get("damage", 42.0) * ASHENSTEP_TICK_MULT
	z.tick_effects = [burn]
	if combat_manager:
		combat_manager.spawn_ground_zone(z, self, at)


## Scale a world-anchored pack VFX so its native art radius lands on `radius`. No-op for a null
## sprite (missing sheet) or a zero radius (caller had no zone to size against).
func _scale_pack_fx(fx: AnimatedSprite2D, radius: float) -> void:
	if fx == null or radius <= 0.0:
		return
	var s: float = radius / FX_NATIVE_RADIUS
	fx.scale = Vector2(s, s)


## True (and clears the flag) when a banked Soul Harvest quota should empower this summon.
func _consume_summon_empower() -> bool:
	if not _next_summon_empowered:
		return false
	_next_summon_empowered = false
	return true


func _pay_blood_cost() -> void:
	## Extract Power's price: flat cut of max HP, never lethal, outside the damage pipeline
	## (no dodge/armor/i-frames — a pact, not an attack).
	var cost: float = maxf(1.0, health.max_hp * BLOOD_COST_FRAC)
	health.current_hp = maxf(1.0, health.current_hp - cost)
	health.health_changed.emit(health.current_hp, health.max_hp)


func _spawn_spikes_ground(radius: float) -> void:
	## One-shot Blood_Spikes_AOE ground burst under the player, scaled to the hit zone.
	if not ResourceLoader.exists(SPIKES_AOE_SHEET):
		return
	var tex: Texture2D = load(SPIKES_AOE_SHEET)
	var burst := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.clear_all()
	sf.add_animation(&"burst")
	sf.set_animation_loop(&"burst", false)
	sf.set_animation_speed(&"burst", 18.0)
	for i in range(int(tex.get_width() / 32.0)):
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(i * 32, 0, 32, 32)
		cell.filter_clip = true
		sf.add_frame(&"burst", cell)
	burst.sprite_frames = sf
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.z_index = 1
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position
	var s: float = (radius / FX_NATIVE_RADIUS) if radius > 0.0 else 2.0
	burst.scale = Vector2(s, s)
	burst.play(&"burst")
	burst.animation_finished.connect(burst.queue_free)


func _spawn_drain_wisp(at: Vector2) -> void:
	## One-shot Drain_Effect wisp at the drained victim.
	if not ResourceLoader.exists(DRAIN_WISP_SHEET):
		return
	var tex: Texture2D = load(DRAIN_WISP_SHEET)
	var wisp := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.clear_all()
	sf.add_animation(&"drain")
	sf.set_animation_loop(&"drain", false)
	sf.set_animation_speed(&"drain", 14.0)
	for i in range(int(tex.get_width() / 32.0)):
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(i * 32, 0, 32, 32)
		cell.filter_clip = true
		sf.add_frame(&"drain", cell)
	wisp.sprite_frames = sf
	wisp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wisp.z_index = 1
	get_tree().current_scene.add_child(wisp)
	wisp.global_position = at
	wisp.play(&"drain")
	wisp.animation_finished.connect(wisp.queue_free)


## Generic one-shot for loose single-row 32px effect sheets (ground decals, wisps, sparks).
## Sunder aftermath: the crack sheet's LAST frame lingers as a world-anchored ground decal
## (hold, then fade) so the slam reads as impact, not a blink (Ben feedback 2026-07-05).
## Drawn below bodies; matches the live ComboFx overlay scale so cracks == hit zone.
func _spawn_sunder_cracks() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var fx_anim: String = _facing_variant(sprite.sprite_frames, "sunder_fx")
	if fx_anim == "":
		return
	var last: int = sprite.sprite_frames.get_frame_count(fx_anim) - 1
	var decal := Sprite2D.new()
	decal.texture = sprite.sprite_frames.get_frame_texture(fx_anim, last)
	decal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decal.z_index = -1   ## ground layer — bodies walk over the cracks
	var s: float = _combo_fx.scale.x if (_combo_fx and _combo_fx.visible) else 1.0
	decal.scale = Vector2(s, s)
	get_tree().current_scene.add_child(decal)
	decal.global_position = global_position
	var tw := decal.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(decal, "modulate:a", 0.0, 0.9)
	tw.tween_callback(decal.queue_free)


## Throw Things visual: the slab cropped from the throw sheet tumbles from the Ravager's
## hands to the landing point, then vanishes as the landing burst hits.
func _spawn_thrown_junk(land: Vector2) -> void:
	var tex := AtlasTexture.new()
	tex.atlas = load(THROW_SHEET)
	tex.region = THROW_JUNK_REGION
	tex.filter_clip = true
	var junk := Sprite2D.new()
	junk.texture = tex
	junk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	junk.z_index = 2
	get_tree().current_scene.add_child(junk)
	var from: Vector2 = global_position + Vector2(0.0, -8.0)   ## leaves at chest height
	junk.global_position = from
	junk.rotation = (land - from).angle()
	var tw := junk.create_tween()
	tw.set_parallel(true)
	tw.tween_property(junk, "global_position", land, 0.16)
	tw.tween_property(junk, "rotation", junk.rotation + TAU, 0.16)   ## one full tumble
	tw.chain().tween_callback(junk.queue_free)


## Desert Storm overlay: 8-direction barrage strips, restarted every volley beat, aimed at
## the cursor's octant, parked a strip's reach ahead of the Deadeye.
func _show_storm_fx() -> void:
	if _storm_fx == null:
		var sf := SpriteFrames.new()
		sf.clear_all()
		for dir_name in STORM_FX_FILES:
			var anim := StringName(dir_name)
			sf.add_animation(anim)
			sf.set_animation_loop(anim, false)
			sf.set_animation_speed(anim, 24.0)
			var tex: Texture2D = load(STORM_FX_DIR + String(STORM_FX_FILES[dir_name]))
			if tex:
				for i in range(int(tex.get_width() / 96.0)):
					var cell := AtlasTexture.new()
					cell.atlas = tex
					cell.region = Rect2(i * 96, 0, 96, 96)
					cell.filter_clip = true
					sf.add_frame(anim, cell)
		_storm_fx = AnimatedSprite2D.new()
		_storm_fx.name = "StormFx"
		_storm_fx.z_index = 1
		_storm_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_storm_fx.sprite_frames = sf
		add_child(_storm_fx)
	var aim: Vector2 = _get_aim_world_position() - global_position
	if aim.length_squared() < 1.0:
		aim = Vector2.RIGHT
	var names: Array = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	var octant: int = wrapi(int(roundf(aim.angle() / (PI / 4.0))), 0, 8)
	_storm_fx.position = aim.normalized() * STORM_FORWARD
	_storm_fx.visible = true
	_storm_fx.stop()
	_storm_fx.play(StringName(names[octant]))


## Flexible world-VFX spawner for pack sheets: slices one ROW of `sheet_path` at `cell` px into a
## play-once or looping AnimatedSprite2D. `follow` parents it to the player (VFX that tracks the
## caster — e.g. the orbiting swirl); otherwise it's world-anchored at `at`. Looping fx with `life`>0
## fade out and free after `life` seconds; one-shots free on animation_finished. `z` places it above
## (1) or below (-1) bodies. `first`/`last` take a sub-range of the row's columns (`last` < 0 = to the
## end) for sheets that bake several beats into one strip. Returns the sprite so callers can nudge it.
##
## `cell_h` < 0 means square cells (`cell` × `cell`), which is every True Heroes / True Villains
## sheet. The Spell Effects packs ship plenty of NON-square strips — Fire_Wave_E is 80×40,
## Ice_Lance_N 24×64, the Electric shockwaves 8×80, Emperor_Effect 8×16 — and those were simply
## unloadable before this parameter existed.
func _spawn_pack_fx(sheet_path: String, at: Vector2, cell: int, row: int, fps: float, loops: bool,
		z: int = 1, follow: bool = false, life: float = 0.0,
		first: int = 0, last: int = -1, fade: float = 0.25,
		cell_h: int = -1) -> AnimatedSprite2D:
	if not ResourceLoader.exists(sheet_path):
		return null
	var tex: Texture2D = load(sheet_path)
	if tex == null:
		return null
	var cw: int = cell
	var ch: int = cell if cell_h < 0 else cell_h
	var fx := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.clear_all()
	sf.add_animation(&"play")
	sf.set_animation_loop(&"play", loops)
	sf.set_animation_speed(&"play", fps)
	var cols: int = int(tex.get_width() / float(cw))
	var from_col: int = clampi(first, 0, cols - 1)
	var to_col: int = cols - 1 if last < 0 else clampi(last, from_col, cols - 1)
	for i in range(from_col, to_col + 1):
		var atl := AtlasTexture.new()
		atl.atlas = tex
		atl.region = Rect2(i * cw, row * ch, cw, ch)
		atl.filter_clip = true
		sf.add_frame(&"play", atl)
	fx.sprite_frames = sf
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.z_index = z
	if follow:
		add_child(fx)
		fx.position = Vector2.ZERO
	else:
		get_tree().current_scene.add_child(fx)
		fx.global_position = at
	fx.play(&"play")
	if loops:
		if life > 0.0:
			var out: float = clampf(fade, 0.0, life)
			var tw := fx.create_tween()
			tw.tween_interval(maxf(0.0, life - out))
			tw.tween_property(fx, "modulate:a", 0.0, out)
			tw.tween_callback(fx.queue_free)
	else:
		fx.animation_finished.connect(fx.queue_free)
	return fx


## Bone Swirl (Necromancer heavy): a TWO-BEAT effect, not two simultaneous layers — the bones claw
## up (eruption), then settle into their orbit. Playing the rise and the loop together from t=0 drew
## a half-risen set over a full-density set and read as overlapping mush (Ben, 2026-07-25); running
## the rise at the cast body's fps then span its inlined loop into helicopter blades. Both beats now
## run at NECRO_SWIRL_FPS so the spin rate is constant and the handoff lands on identical art (see
## the const block). Both 64px and follow the Shade. Row 0 of the orbit = full bone density (rows
## 1-2 are the depleting-bones frames the pack ships for impact attrition — a future per-hit polish).
func _spawn_bone_swirl_fx(phase: ChoreographyPhase) -> void:
	## Re-cast inside a live swirl: drop the old set so orbits never stack on the player.
	_clear_bone_swirl_fx()
	_swirl_rings = _bone_swirl_rings(_bone_swirl_count(phase))
	## The eruption is the pack's 3-bone rise — extra bones from mods join once the ring has formed
	## (Bone_Swirl_Rise ships only the 3-bone version, so there's no 5-bone eruption to play).
	_swirl_rise_fx = _spawn_pack_fx(NECRO_SWIRL_RISE_SHEET, global_position, 64, 0,
			NECRO_SWIRL_FPS, false, 1, true, 0.0, 0, NECRO_SWIRL_RISE_LAST)
	if _swirl_rise_fx == null:
		return
	## Hand off the instant the last bone is up — the loop's frame 0 IS the eruption's next frame.
	var rise_time: float = float(NECRO_SWIRL_RISE_LAST + 1) / NECRO_SWIRL_FPS
	_swirl_chain_tween = create_tween()
	_swirl_chain_tween.tween_interval(rise_time)
	_swirl_chain_tween.tween_callback(_begin_bone_swirl_orbit)


## The swirl's live bone count = the burst's projectile count, so "add_projectiles" mods and
## level-ups grow the ring and the outgoing volley together. Falls back to the pack's 3.
func _bone_swirl_count(phase: ChoreographyPhase) -> int:
	if phase == null:
		return NECRO_SWIRL_BASE_BONES
	for e in phase.effects:
		if e is ApplyStatusEffectData and e.status != null:
			for x in e.status.on_expire_effects:
				if x is SpawnProjectilesEffect:
					return maxi(x.count, 1)
	return NECRO_SWIRL_BASE_BONES


## Split a bone count into sheet rows (row 0 = 3 bones, row 1 = 2, row 2 = 1). Greedy on the densest
## row, so every count lands exactly: 4 → [3,1], 5 → [3,2], 6 → [3,3].
func _bone_swirl_rings(count: int) -> Array[int]:
	var rows: Array[int] = []
	var left: int = maxi(count, 1)
	while left > 0 and rows.size() < NECRO_SWIRL_MAX_RINGS:
		var take: int = mini(left, 3)
		rows.append(3 - take)
		left -= take
	return rows


## Second beat: the risen bones settle into their orbit around the Shade. One sprite per ring, each
## started on a different frame so the rings sit at different angles instead of stacking — an orbit
## frame is a 45° step, so two rings land 180° apart and read as one evenly-spaced set of 6.
func _begin_bone_swirl_orbit() -> void:
	_swirl_rise_fx = null   ## the rise freed itself on animation_finished
	var ring_count: int = maxi(_swirl_rings.size(), 1)
	for i in _swirl_rings.size():
		var fx: AnimatedSprite2D = _spawn_pack_fx(NECRO_SWIRL_SHEET, global_position, 64,
				_swirl_rings[i], NECRO_SWIRL_FPS, true, 1, true, NECRO_SWIRL_ORBIT_LIFE,
				0, -1, NECRO_SWIRL_ORBIT_FADE)
		if fx == null:
			continue
		fx.frame = (i * 8) / ring_count
		_swirl_orbit_fx.append(fx)


## Tear down whatever beat of the swirl is currently on the Shade, plus any pending hand-off.
func _clear_bone_swirl_fx() -> void:
	if _swirl_chain_tween and _swirl_chain_tween.is_valid():
		_swirl_chain_tween.kill()
	_swirl_chain_tween = null
	if is_instance_valid(_swirl_rise_fx):
		_swirl_rise_fx.queue_free()
	_swirl_rise_fx = null
	for fx in _swirl_orbit_fx:
		if is_instance_valid(fx):
			fx.queue_free()
	_swirl_orbit_fx.clear()


## Corpse-rise (Necromancer summons): the ground cracks and the dead claw up at each spawn point.
## `champion` picks the Skeletal-Champion emerge (Rise Corpse Q) vs the generic corpse (Bone Legion E).
## Both 64px; the ground layer renders below bodies. Nudged up so the effect's feet sit near `at`.
func _spawn_corpse_ground(at: Vector2) -> void:
	## The floor scar under a rising skeleton — a decoupled ground decal (z=-1). It's MEANT to stay
	## put after the skeleton walks off. The rising skeleton itself is now the SkeletalChampion's own
	## "spawn" state (welded to the entity), so there's no body VFX to leave behind. 32px, row 0.
	_spawn_pack_fx(NECRO_RISE_GROUND_SHEET, at + Vector2(0, 2), 32, 0, 16.0, false, -1)


## Plane Shift (Necromancer dash): the directional dematerialize/rematerialize burst. 4 facing rows
## (32px) — plays the row matching the Shade's current facing at each end of the blink.
func _spawn_planeshift_burst(sheet: String, at: Vector2) -> void:
	var rows := {"down_right": 0, "down_left": 1, "up_right": 2, "up_left": 3}
	var row: int = int(rows.get(_facing, 0))
	_spawn_pack_fx(sheet, at, 32, row, 24.0, false, 1)


func _spawn_oneshot_fx(sheet_path: String, at: Vector2, fps: float) -> void:
	if not ResourceLoader.exists(sheet_path):
		return
	var tex: Texture2D = load(sheet_path)
	var fx := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.clear_all()
	sf.add_animation(&"play")
	sf.set_animation_loop(&"play", false)
	sf.set_animation_speed(&"play", fps)
	for i in range(int(tex.get_width() / 32.0)):
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(i * 32, 0, 32, 32)
		cell.filter_clip = true
		sf.add_frame(&"play", cell)
	fx.sprite_frames = sf
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.z_index = 1
	get_tree().current_scene.add_child(fx)
	fx.global_position = at
	fx.play(&"play")
	fx.animation_finished.connect(fx.queue_free)


## Storm Call (Spark E): every live enemy on the field takes a two-bolt lightning strike
## (Aura_Electric row 0 dropped over them) + a Lightning chunk; the caster crackles with an
## electric pulse. Screen-wide — the long cooldown is the balance.
func _cast_storm_call(ability) -> void:
	var chunk: float = _weapon_data.get("damage", 42.0) * STORM_CALL_DAMAGE_MULT
	for en in _nearby_enemies(STORM_CALL_RANGE):
		_spawn_oneshot_fx(AURA_ELECTRIC_SHEET, en.global_position + Vector2(0.0, -8.0), 14.0)
		var hit := DealDamageEffect.new()
		hit.damage_type = "Lightning"
		hit.base_damage = chunk
		EffectDispatcher.execute_effects([hit], self, [en], ability, combat_manager)
	_spawn_oneshot_fx(BURST_ELECTRIC_SHEET, global_position, 15.0)
	_spawn_shockwave_ring(64.0, Color(0.55, 0.8, 1.0, 0.95))


## Frost Burst (Spark Q): the Burst_Ice pop, then the lingering ice-shard aura. The nova's
## damage + chill ride the skill's own effects (choreo_fire_effects), not this hook.
func _cast_ice_burst() -> void:
	_spawn_oneshot_fx(BURST_ICE_SHEET, global_position, 15.0)
	_show_ice_aura()


## The ice-shard aura (Ben's frame plan): the Aura_Ice sheet counted as ONE flat row-major
## sequence over its 8×3 grid — the shards pop in and shimmer over frames 7-16 (looped for
## ICE_AURA_TIME), then frames 17-24 play once as the shards deteriorate. A child of the player,
## so it tracks the Spark.
func _show_ice_aura() -> void:
	if _ice_aura == null:
		if not ResourceLoader.exists(AURA_ICE_SHEET):
			return
		var tex: Texture2D = load(AURA_ICE_SHEET)
		if tex == null:
			return
		var cols: int = int(tex.get_width() / 32.0)   ## 8 across; the sheet wraps to the next row
		var frames := SpriteFrames.new()
		frames.clear_all()
		## Flat cell indices (0-based) = Ben's 1-based frames minus one:
		##   loop = frames 7-16  → cells 6..15   ·   deteriorate = frames 17-24 → cells 16..23
		_add_ice_aura_anim(frames, tex, &"loop", 6, 15, cols, true)
		_add_ice_aura_anim(frames, tex, &"end", 16, 23, cols, false)
		_ice_aura = AnimatedSprite2D.new()
		_ice_aura.name = "IceAura"
		_ice_aura.centered = true
		_ice_aura.z_index = 2
		_ice_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_ice_aura)
		_ice_aura.animation_finished.connect(_on_ice_aura_finished)
	_ice_aura.visible = true
	_ice_aura.play(&"loop")
	_ice_aura_timer = ICE_AURA_TIME


## Slice a FLAT (row-major) cell range [flat_first..flat_last] out of the Aura grid into one
## animation — so a range can span across the sheet's rows, matching how Ben counts the frames.
func _add_ice_aura_anim(frames: SpriteFrames, tex: Texture2D, anim: StringName,
		flat_first: int, flat_last: int, cols: int, loops: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loops)
	frames.set_animation_speed(anim, 12.0)
	for flat in range(flat_first, flat_last + 1):
		var col: int = flat % cols
		var row: int = int(flat / float(cols))
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(col * 32, row * 32, 32, 32)
		cell.filter_clip = true
		frames.add_frame(anim, cell)


func _on_ice_aura_finished() -> void:
	## The deteriorate ("end") pass finished → drop the aura.
	if _ice_aura and _ice_aura.animation == &"end":
		_ice_aura.visible = false


func _show_vamp_fx() -> void:
	## Floating_Blood loops above the Cursed while Vampirize channels.
	if _vamp_fx == null:
		_vamp_fx = AnimatedSprite2D.new()
		_vamp_fx.name = "VampFx"
		_vamp_fx.z_index = 1
		_vamp_fx.position = Vector2(0.0, -18.0)
		_vamp_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sf := SpriteFrames.new()
		sf.clear_all()
		var tex: Texture2D = load(FLOATING_BLOOD_SHEET)
		if tex:
			sf.add_animation(&"float")
			sf.set_animation_loop(&"float", true)
			sf.set_animation_speed(&"float", 10.0)
			for i in range(int(tex.get_width() / 32.0)):
				var cell := AtlasTexture.new()
				cell.atlas = tex
				cell.region = Rect2(i * 32, 0, 32, 32)
				cell.filter_clip = true
				sf.add_frame(&"float", cell)
		_vamp_fx.sprite_frames = sf
		add_child(_vamp_fx)
	_vamp_fx.visible = true
	if not _vamp_fx.is_playing():
		_vamp_fx.play(&"float")


var _hammer_angle_cycle: float = 0.0     ## fan angle for successive per-press hammers

func _spawn_holy_hammers(reach: float) -> void:
	## One blessed hammer per throw (Ben's redesign 2026-07-19): each RMB press in the Hammer
	## phase launches a single HolyHammer on its own outward spiral. The start angle cycles a
	## golden-angle step per press so mashed hammers fan around the Warden instead of stacking.
	## Max spiral radius scales with melee_range; damage reads the live damage stat per hammer.
	var dtype: String = ChainFactory._damage_type(_weapon_data)
	var hammer := HolyHammer.new()
	hammer.player_ref = self
	hammer.damage_type = dtype
	hammer.start_angle = _hammer_angle_cycle
	hammer.max_radius = 120.0 * reach
	get_tree().current_scene.add_child(hammer)
	_hammer_angle_cycle = fmod(_hammer_angle_cycle + TAU * 0.382, TAU)


# --- Blood Eruption pools (Blood Mage E) ---
## Active pools tracked host-side: any enemy dying inside one feeds the Cursed. Entries:
## { "pos": Vector2, "r_sq": float, "until": float (msec) }.
const BLOOD_POOL_HEAL_FRAC: float = 0.03
var _blood_pools: Array[Dictionary] = []


func _register_blood_pool(pos: Vector2, radius: float, duration: float) -> void:
	_blood_pools.append({
		"pos": pos, "r_sq": radius * radius,
		"until": float(Time.get_ticks_msec()) + duration * 1000.0,
	})


func _on_any_entity_death(entity) -> void:
	## Blood-pool feed: 3% max HP per enemy that dies inside an active pool.
	if _blood_pools.is_empty() or not is_alive:
		return
	if not (entity is Node2D) or entity == self or entity.get("faction") != 1:
		return
	var now: float = float(Time.get_ticks_msec())
	var fed: bool = false
	var live_pools: Array[Dictionary] = []
	for pool in _blood_pools:
		if now > pool.until:
			continue   ## expired — prune
		live_pools.append(pool)
		if not fed and entity.global_position.distance_squared_to(pool.pos) <= pool.r_sq:
			fed = true
			health.apply_healing(health.max_hp * BLOOD_POOL_HEAL_FRAC)
			EventBus.on_heal.emit(self, self, health.max_hp * BLOOD_POOL_HEAL_FRAC)
			_spawn_drain_wisp(entity.global_position)
	_blood_pools = live_pools


## Reckoning burst: everything the dome soaked goes back out as an AoE around the Warden.
func _detonate_reckoning() -> void:
	var stored: float = _dome_absorbed
	_dome_absorbed = 0.0
	var reach: float = _melee_range()
	var burst := AreaDamageEffect.new()
	burst.damage_type = ChainFactory._damage_type(_weapon_data)
	burst.base_damage = stored * DOME_REFLECT_MULT
	burst.aoe_radius = DOME_BURST_RADIUS * reach
	EffectDispatcher.execute_effects([burst], self, [self], _combo_channel, combat_manager)
	_spawn_shockwave_ring(DOME_BURST_RADIUS * reach, Color(1.0, 0.85, 0.25, 0.95))
	## Judgement pop on the Warden himself.
	if sprite:
		sprite.self_modulate = Color(1.6, 1.5, 1.0, 1.0)
		var t := create_tween()
		t.tween_property(sprite, "self_modulate", Color.WHITE, 0.25)


## Absorb feedback: quick gold blink each time the dome drinks a hit.
func _dome_flash() -> void:
	if sprite == null:
		return
	sprite.self_modulate = Color(1.5, 1.35, 0.8, 1.0)
	var t := create_tween()
	t.tween_property(sprite, "self_modulate", Color.WHITE, 0.12)


## Warden Aegis Shield (Q): raise a standing absorb pool = ABSORB_SHIELD_FRAC of max HP and
## turn on the persistent DomeCycle bubble. It stays until the pool is spent (no timer);
## re-casting re-tops the pool.
func _grant_absorb_shield() -> void:
	_absorb_shield = health.max_hp * ABSORB_SHIELD_FRAC
	_ensure_shield_bubble()
	if _shield_bubble:
		_shield_bubble.visible = true
		_shield_bubble.play(&"bubble")
	_spawn_shockwave_ring(30.0, Color(0.45, 0.75, 1.0, 0.9))


func _end_absorb_shield() -> void:
	_absorb_shield = 0.0
	if _shield_bubble:
		_shield_bubble.visible = false
	if status_effect_component and status_effect_component.has_status("aegis_shield"):
		status_effect_component.force_remove_status("aegis_shield", self)


## Lazily build the looping DomeCycle bubble sprite (a child, so it tracks the Warden). Kept at
## z_index 2 so it reads as a dome OVER the body.
func _ensure_shield_bubble() -> void:
	if _shield_bubble != null:
		return
	if not ResourceLoader.exists(DOME_CYCLE_SHEET):
		return
	var tex: Texture2D = load(DOME_CYCLE_SHEET)
	if tex == null:
		return
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"bubble")
	frames.set_animation_loop(&"bubble", true)
	frames.set_animation_speed(&"bubble", 12.0)
	var cols: int = int(tex.get_width() / 32.0)
	for i in range(cols):
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(i * 32, 0, 32, 32)
		cell.filter_clip = true
		frames.add_frame(&"bubble", cell)
	_shield_bubble = AnimatedSprite2D.new()
	_shield_bubble.name = "ShieldBubble"
	_shield_bubble.centered = true
	_shield_bubble.z_index = 2
	_shield_bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shield_bubble.visible = false
	add_child(_shield_bubble)


func _detonate_bomb_fx(reach: float) -> void:
	## Swap the tossed bomb for the package explosion at its world landing spot. Starts at the
	## sheet's native size and scales ONLY with the melee_range stat (Reach mods / level picks),
	## matching the blast's damage radius (ChainFactory keys it to the same native size).
	if _bomb_tween:
		_bomb_tween.kill()
	if _bomb_toss == null or _bomb_toss.sprite_frames == null \
			or not _bomb_toss.sprite_frames.has_animation(&"explode"):
		return
	_bomb_toss.global_position = _bomb_land
	_bomb_toss.scale = Vector2.ONE * reach
	_bomb_toss.visible = true
	_bomb_toss.play(&"explode")


func _on_bomb_anim_finished() -> void:
	if _bomb_toss and _bomb_toss.animation == &"explode":
		_bomb_toss.visible = false
		_bomb_toss.scale = Vector2.ONE


## Source art for the shockwave pop. Electric_Expansive_Shock is 56×56 over 26 frames — a ring
## that genuinely expands, unlike a scaled circle — and it tints cleanly to gold/green/blue for
## the non-electric callers (Reckoning, Second Wind, Aegis, Taunt).
const SHOCKWAVE_SHEET: String = SPELLFX_DIR + "Electric/Tileable_Effect/Premade_Spell_Effects/Electric_Expansive_Shock.png"
const SHOCKWAVE_CELL: int = 56
const SHOCKWAVE_FRAMES: int = 26
const SHOCKWAVE_TIME: float = 0.45   ## match the old tween's beat exactly — feel must not change


func _spawn_shockwave_ring(radius: float, color: Color = Color(1.0, 0.55, 0.10, 0.9)) -> void:
	## Expanding ring that rings out from the player to the hit-zone edge, then fades.
	## Orange by default (Taunt/impact zones); green = heals, gold = Reckoning.
	## Prefers the pack's real expanding-shock sheet; the Line2D below is the fallback when the
	## sheet is missing, and still runs UNDER the sprite as a bright leading edge.
	var fps: float = float(SHOCKWAVE_FRAMES) / SHOCKWAVE_TIME
	var burst: AnimatedSprite2D = _spawn_pack_fx(SHOCKWAVE_SHEET, global_position,
			SHOCKWAVE_CELL, 0, fps, false, 1)
	if burst:
		## The sheet's shock fills its 56px cell, so its native radius is half that.
		var s: float = radius / (float(SHOCKWAVE_CELL) * 0.5)
		burst.scale = Vector2(s, s)
		burst.modulate = Color(color.r, color.g, color.b, 1.0)

	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = color
	ring.closed = true
	var pts := PackedVector2Array()
	for i in 28:
		var a: float = TAU * float(i) / 28.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	ring.points = pts
	ring.top_level = true
	ring.z_index = 1
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position
	ring.scale = Vector2(0.15, 0.15)
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2.ONE, 0.45)
	t.tween_property(ring, "modulate:a", 0.0, 0.45)
	t.chain().tween_callback(ring.queue_free)


## Spam cap (Ben, playtest 2026-07-19: bolts fired at raw click speed, ~13/s). Chain tap-advances
## can't come faster than this base cadence; attack_speed picks/mods tighten it, so machine-gun
## casting is EARNED, not free. Held/release branches (channels, Whirlwind exit) are unaffected.
const MIN_TAP_CADENCE: float = 0.22


func choreo_min_advance_time(phase: ChoreographyPhase) -> float:
	## Two brakes, whichever is slower:
	##  • the flat spam cadence above (attack_speed tightens it), and
	##  • the node's own `cancel_open` frame, if its anim declares one.
	## The cadence alone was tuned against True Heroes bodies (4-7 frames, ~0.2s), which finish
	## BEFORE the 0.22s gate opens. The True Villains packs draw 10-15 frame bodies, so mashing cut
	## them at ~a third — the Demonologist's Hellfire reached frame 5 of 15 and its fire never drew
	## at all (Ben, 2026-07-26: "looks like the demonologist is twitching"). `cancel_open` is the
	## per-anim commitment point: presses still buffer, so a queued tap fires the instant it opens.
	##
	## NOT divided by attack_speed — the sprite plays at its authored fps regardless of the stat
	## (only telegraph_speed_scale touches speed_scale), so the anim is a real floor: you cannot
	## cancel out of frames that haven't been drawn yet.
	var base: float = MIN_TAP_CADENCE / maxf(get_stat("attack_speed"), 0.25)
	if phase == null or phase.animation == "":
		return base
	var open_frame: int = int(CharacterSpriteFactory.get_anim_meta(
			ProgressionManager.selected_character, phase.animation).get("cancel_open", -1))
	if open_frame < 0:
		return base
	var fps: float = _anim_fps(phase.animation)
	if fps <= 0.0:
		return base
	return maxf(base, float(open_frame) / fps)


## Playback fps of an anim as actually sliced (the facing variant carries the same speed as the
## base, and the Animation Lab's fps override is already baked into the SpriteFrames).
func _anim_fps(anim: String) -> float:
	if sprite == null or sprite.sprite_frames == null:
		return 0.0
	var variant := StringName("%s_%s" % [anim, _facing])
	if sprite.sprite_frames.has_animation(variant):
		return sprite.sprite_frames.get_animation_speed(variant)
	var base_sn := StringName(anim)
	if sprite.sprite_frames.has_animation(base_sn):
		return sprite.sprite_frames.get_animation_speed(base_sn)
	return 0.0


## Runner hook: the hit frame for the row that's about to play. Ben can pin a different impact
## frame per FACING in the Animation Lab (a swing's contact moment genuinely lands on a
## different frame in some packs' rows); -1 from the lookup means "keep what the kit authored".
func choreo_hit_frame(phase: ChoreographyPhase) -> int:
	if phase.animation == "":
		return phase.hit_frame
	var pinned: int = CharacterSpriteFactory.get_hit_frame(
			ProgressionManager.selected_character, phase.animation, _facing)
	return pinned if pinned >= 0 else phase.hit_frame


func choreo_execute_displacement(disp, targets: Array) -> void:
	if combat_manager and combat_manager.get("displacement_system"):
		combat_manager.displacement_system.execute(self, _combo_ability, disp, targets)


func choreo_evaluate_condition(condition: Resource, phase: ChoreographyPhase) -> bool:
	## Input-driven branch conditions (the combo's vocabulary). HP/count conditions could be added
	## here too, but the player's combos don't use them yet.
	if _combat_input == null:
		return false
	if condition is ConditionInputHeld:
		var held: bool = _combat_input.held_for(condition.action) >= condition.min_duration
		return held != condition.negate   ## negate → pass on release (channel exit)
	if condition is ConditionInputBuffered:
		var window: float = condition.within_window
		if window <= 0.0:
			window = phase.wait_duration   ## default to the phase's cancel window
		if _combat_input.was_buffered(condition.action, window):
			## Consume so a single tap can't satisfy a later node's window too.
			_combat_input.consume(condition.action)
			return true
		return false
	return false


func choreo_set_flags(untargetable: bool, invulnerable: bool) -> void:
	is_untargetable = untargetable
	if invulnerable:
		is_invulnerable = true


func choreo_on_start(ability: AbilityDefinition) -> void:
	## Keep walk/idle from clobbering combo anims; mark attacking for the engine.
	_attack_anim_active = true
	_damage_anim_active = false
	is_attacking = true
	_combo_step_depth = 0
	_combo_last_hit_phase = -1
	_active_choreo_id = ability.ability_id if ability else ""
	if _active_choreo_id == "paladin_dome":
		_dome_absorbed = 0.0   ## fresh Reckoning pool each channel


func choreo_on_finisher_hit() -> void:
	EventBus.on_finisher_hit.emit(self)
	if _has_berserkers_cadence_keystone:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _berserkers_cadence_last_trigger >= 3.0:
			_berserkers_cadence_last_trigger = now
			status_effect_component.apply_status(PassiveTreeFactory.frenzy_status, self, 1)


func choreo_on_phase_hit(phase: ChoreographyPhase, phase_index: int, ability: AbilityDefinition) -> void:
	## Combo cadence feedback (docs/combo_feedback_spec.md). Fires at the hit frame — the exact
	## moment the cancel window opens (tick() gates branch-advance on _hit_fired). A repeated
	## phase index is a channel self-loop tick (Whirlwind re-entering itself): a hold, not a tap,
	## so it stays off the ladder and pulse.
	if phase_index == _combo_last_hit_phase:
		return
	_combo_last_hit_phase = phase_index
	## Pitch ladder (mechanism A) — light chain only per Ben's redline; the finisher node is the
	## ladder's natural top note, no extra accent (its hitstop + shake are the accent).
	if ability == _combo_ability:
		_combo_step_depth += 1
		EventBus.on_combo_step.emit(self, _combo_step_depth, phase.is_finisher)
	## Heavy swing SFX rides the SWING, not the damage — same reasoning as the light chain's
	## ladder above. AudioManager used to play it from on_hit_dealt, which is correct only for a
	## melee heavy (swing and damage coincide); for a PROJECTILE heavy the damage lands at the
	## bolt's impact, so a melee whoosh fired there arrived a beat late and on top of the impact
	## sound — audible as a double hit (Ben, The Devout's RMB tap, 2026-07-26). Firing it here
	## also makes a whiffed heavy audible, which the on-hit path never did.
	elif ability == _combo_heavy:
		AudioManager.play("sfx_swing_heavy", global_position)
	## Cancel-window pulse (mechanism C) — only when a next press can actually chain.
	if not phase.branches.is_empty():
		_combo_window_pulse()


func choreo_on_chain_timeout(_phase: ChoreographyPhase) -> void:
	## Chain ended by letting the window lapse — not dash/hurt/stun (interrupt) and not a
	## finisher completing. The "exhale" (mechanism E); depth < 2 never established a cadence.
	if _combo_step_depth >= 2:
		EventBus.on_combo_dropped.emit(self, _combo_step_depth)


func _combo_window_pulse() -> void:
	## One subtle brightening tick on the body sprite: "press now and it chains." Rides
	## self_modulate so it composes with (never fights) the damage hit-flash on modulate.
	if _combo_pulse_tween and _combo_pulse_tween.is_valid():
		_combo_pulse_tween.kill()
	sprite.self_modulate = Color(1.35, 1.35, 1.35, 1.0)
	_combo_pulse_tween = create_tween()
	_combo_pulse_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.10)


func choreo_on_end() -> void:
	## Reckoning: the dome comes down — everything it soaked goes back out.
	if _active_choreo_id == "paladin_dome" and _dome_absorbed > 0.0:
		_detonate_reckoning()
	_active_choreo_id = ""
	_attack_anim_active = false
	is_attacking = false
	is_untargetable = false
	_combo_step_depth = 0
	_combo_last_hit_phase = -1
	if _combo_fx:
		_combo_fx.visible = false
	if _combo_base:
		_combo_base.visible = false
	## An un-detonated bomb toss (combo interrupted mid-wind-up) disappears; a detonated
	## explosion is world-anchored and finishes on its own.
	if _bomb_toss and _bomb_toss.animation != &"explode":
		if _bomb_tween:
			_bomb_tween.kill()
		_bomb_toss.visible = false
	if _torrent_fx:
		_torrent_fx.visible = false
	if _vamp_fx:
		_vamp_fx.visible = false
	_vamp_hit = false
	## Drop the channel slow / charge tax if active (no-ops otherwise).
	modifier_component.remove_by_source_prefix("combo_taunt")
	modifier_component.remove_by_source_prefix("combo_charge")
	_charge_start_ms = -1
	## Only drop invulnerability if a dash isn't currently granting it.
	if _dash_timer <= 0.0:
		is_invulnerable = false
	if sprite and is_alive and not _is_dying and sprite.sprite_frames \
			and sprite.sprite_frames.has_animation("idle"):
		_play_anim("idle")


# --- Dash ---

func _max_dash_charges() -> int:
	## dash_charges resolves through the modifier system; clamp to int >= 1.
	return maxi(1, int(round(get_stat("dash_charges"))))


func _dash_cooldown_seconds() -> float:
	## Per-charge refill time, resolved through the modifier system. Floored so stacked
	## "Quick Recovery" (-% dash_cooldown) picks can't drive it to <=0, which would
	## leave the refill clock permanently expired and stop charges regenerating.
	return maxf(0.1, get_stat("dash_cooldown"))


func _set_dash_phasing(phasing: bool) -> void:
	## Physically pass through enemy bodies during the dash. The dash i-frames only block
	## damage; without this the player's body still collides INTO enemies (mask bit 2) and
	## enemies collide INTO the player (player layer bit 1), so a dash bumps to a halt on
	## the first body. Toggling both bits lets the dash slip through the crowd.
	## Walls are NOT on these bits, so phasing never lets the player clip through walls.
	set_collision_mask_value(2, not phasing)   ## stop colliding into enemies (layer 2)
	set_collision_layer_value(1, not phasing)  ## stop enemies colliding into us (player layer 1)


func _reset_dash_state() -> void:
	## Full charges, no active dash, timers cleared. Called on spawn and run restart.
	_dash_timer = 0.0
	_dash_cooldown_timer = 0.0
	_dash_dir = Vector2.ZERO
	_dash_speed_current = 0.0
	_dash_charges = _max_dash_charges()
	is_invulnerable = false
	_set_dash_phasing(false)  # ensure enemy body collision is restored after any reset


func _tick_dash_cooldown(delta: float) -> void:
	## Refill one charge at a time on a per-charge cooldown (read live so upgrades apply).
	var max_charges: int = _max_dash_charges()
	if _dash_charges >= max_charges:
		_dash_cooldown_timer = 0.0
		return
	if _dash_cooldown_timer <= 0.0:
		## Safety: a charge is missing but no refill is queued — start one.
		_dash_cooldown_timer = _dash_cooldown_seconds()
		return
	_dash_cooldown_timer -= delta
	if _dash_cooldown_timer <= 0.0:
		_dash_charges += 1
		## Queue the next refill if still below max; otherwise stop.
		_dash_cooldown_timer = _dash_cooldown_seconds() if _dash_charges < max_charges else 0.0


func _try_dash(input_dir: Vector2) -> void:
	## Consume a charge and start a dash impulse. No-op while already dashing or at 0 charges.
	if _dash_timer > 0.0 or _dash_charges <= 0:
		return
	var dir: Vector2 = input_dir
	if dir.length_squared() <= 0.0:
		dir = _last_move_dir
	if dir.length_squared() <= 0.0:
		dir = Vector2.RIGHT
	## Dash-cancels an in-progress combo.
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.interrupt()
	## Class-flavored dash: the Spark blinks instead of sprinting (Teleport package on the
	## mobility input — instant, no tap/hold latency).
	if _dash_style == "teleport":
		_teleport_dash(dir.normalized())
		_on_dash_started()
		return
	_dash_dir = dir.normalized()
	_dash_speed_current = get_stat("dash_speed")
	_dash_timer = DASH_DURATION
	is_invulnerable = true
	_set_dash_phasing(true)  # slip through enemy bodies for the dash window
	_dash_charges -= 1
	## Class-flavored dash anim (e.g. the Shade's real Dodge roll) when the pack ships one.
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("dodge"):
		_dash_anim_timer = 0.27
		_play_anim("dodge")
	## Deadly Dash (the Whisper): the launch crouch ghosts at the departure point and every
	## enemy along the dash corridor takes a knife on the way through.
	if _dash_style == "deadly":
		_spawn_teleport_ghost("dash_out")
		_deadly_dash_strike(_dash_dir)
	## Plane Shift (the Shade): dematerialize to the invulnerable Soul form for the dash window (the
	## "dodge" anim above is mapped to Soul_Fly, so the soul body plays automatically). The pack's
	## Plane_Shift_Out burst sells the phase-out at departure; Plane_Shift_In fires at the arrival
	## point when the dash window closes. The dash's own i-frames + phasing ARE the pass-through.
	if _dash_style == "planeshift":
		_spawn_planeshift_burst(NECRO_PLANESHIFT_OUT_SHEET, global_position)
		get_tree().create_timer(DASH_DURATION).timeout.connect(
			func() -> void:
				if is_instance_valid(self) and is_alive:
					_spawn_planeshift_burst(NECRO_PLANESHIFT_IN_SHEET, global_position))
	## Ashen Step (the Demon): the "dodge" anim above is the pack's Jump, so the hop plays
	## automatically. The ground he pushed off from catches fire behind him.
	if _dash_style == "ashenstep":
		_spawn_ashenstep_trail(global_position)
	## Start the refill clock if it isn't already running (don't reset a charge mid-refill).
	if _dash_cooldown_timer <= 0.0:
		_dash_cooldown_timer = _dash_cooldown_seconds()
	if sprite and not _has_dir_anims and absf(_dash_dir.x) > 0.01:
		sprite.flip_h = _dash_dir.x < 0
	_spawn_dash_vfx()
	_on_dash_started()


func _on_dash_started() -> void:
	## Called whenever any dash variant completes its launch (standard or teleport).
	## Applies the Slipstream keystone buff when allocated.
	if _has_slipstream_keystone:
		status_effect_component.apply_status(PassiveTreeFactory.slipstream_status, self, 1)
	AudioManager.play(_dash_sound_id())


func _dash_sound_id() -> String:
	## Class-flavored dash SFX: blink, blade trail, dodge roll, or the generic whoosh.
	if _dash_style == "teleport":
		return "sfx_dash_teleport"
	if _dash_style == "planeshift":
		return "sfx_dash_teleport"   ## soul phase-out reuses the blink stinger
	if _dash_style == "deadly":
		return "sfx_dash_deadly"
	if _dash_style == "ashenstep":
		return "sfx_dash_dodge_roll"   ## a physical hop, not a blink — reuses the roll stinger
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("dodge"):
		return "sfx_dash_dodge_roll"
	return "sfx_dash_generic"


func _teleport_dash(dir: Vector2) -> void:
	## Instant blink: Start cast ghosts at the departure point, End cast plays on arrival.
	## Same charge/cooldown economy as a normal dash; brief i-frames cover the reappearance.
	## Blink anims face the TRAVEL direction, not the cursor — otherwise every teleport plays
	## the mouse-facing row (Ben 2026-07-19). Now 8-way: with the orthogonal teleport sheets
	## wired, a straight up/down/left/right blink plays its true cardinal row instead of the
	## nearest diagonal. _update_facing re-follows the cursor next frame.
	_aim_dir = dir
	_facing = _facing_from_vector(dir)
	_spawn_teleport_ghost()
	global_position += dir * TELEPORT_RANGE * 0.9
	is_invulnerable = true
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if is_alive and _dash_timer <= 0.0:
			is_invulnerable = false)
	_dash_charges -= 1
	if _dash_cooldown_timer <= 0.0:
		_dash_cooldown_timer = _dash_cooldown_seconds()
	_dash_anim_timer = 0.45
	_play_anim("teleport_in")
	_spawn_dash_vfx()


func _spawn_teleport_ghost(anim: String = "teleport_out") -> void:
	## One-shot copy of the player's frames playing a departure cast at the old spot
	## (Spark's Teleport Start, the Whisper's Deadly Dash launch crouch).
	if sprite == null or sprite.sprite_frames == null \
			or not sprite.sprite_frames.has_animation(anim):
		return
	var ghost := AnimatedSprite2D.new()
	ghost.sprite_frames = sprite.sprite_frames
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.z_index = sprite.z_index
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = global_position
	ghost.play(choreo_anim_name(anim))
	ghost.animation_finished.connect(ghost.queue_free)


## Deadly Dash: knife everything in the dash corridor (segment from launch to the expected
## dash end). One pass at dash start — cheap, no per-frame sweep.
func _deadly_dash_strike(dir: Vector2) -> void:
	## Knifing through the crowd is very much an attack — it breaks Smoke Bomb stealth too.
	if status_effect_component.has_status("concealed"):
		status_effect_component.force_remove_status("concealed", self)
	var corridor: float = _dash_speed_current * DASH_DURATION * 0.8   ## ease-out shortens the run
	var to: Vector2 = global_position + dir * corridor
	var dmg: float = get_stat("damage") * 0.8
	var dtype: String = ChainFactory._damage_type(_weapon_data)
	for en in _nearby_enemies(corridor + 30.0):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(en.global_position, global_position, to)
		if en.global_position.distance_squared_to(closest) <= 18.0 * 18.0:
			var hit: HitData = DamageCalculator.calculate_raw_hit(self, en, dmg, dtype)
			en.take_damage(hit)


## Shield Rush (Fighter E): shield-first charge toward the cursor. Rides the dash machinery
## (no charge cost): phase through the pack, clip corridor victims, then — once the Sellsword
## has arrived — yank them to him and slam. The yank is a "toward_source" displacement fired
## AFTER the rush, so the pull converges on the ARRIVAL point (the drag-and-slam feel).
const SHIELD_RUSH_SPEED: float = 560.0
const SHIELD_RUSH_SLAM_RADIUS: float = 40.0
var _rush_victims: Array = []


func _start_shield_rush(reach: float) -> void:
	var aim: Vector2 = _get_aim_world_position() - global_position
	var dir: Vector2 = aim.normalized() if aim.length_squared() >= 1.0 else _last_move_dir
	## Dash-style impulse: same feel constants, no dash charge consumed.
	_dash_dir = dir
	_dash_speed_current = SHIELD_RUSH_SPEED
	_dash_timer = DASH_DURATION
	is_invulnerable = true
	_set_dash_phasing(true)
	_dash_anim_timer = 0.3
	_spawn_dash_vfx()
	## Clip everything in the charge corridor now; remember them for the yank.
	_rush_victims.clear()
	var corridor: float = SHIELD_RUSH_SPEED * DASH_DURATION * 0.9
	var to: Vector2 = global_position + dir * corridor
	var dmg: float = get_stat("damage") * 0.9
	var dtype: String = ChainFactory._damage_type(_weapon_data)
	for en in _nearby_enemies(corridor + 30.0):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(en.global_position, global_position, to)
		if en.global_position.distance_squared_to(closest) <= 20.0 * 20.0:
			var hit: HitData = DamageCalculator.calculate_raw_hit(self, en, dmg, dtype)
			en.take_damage(hit)
			_rush_victims.append(en)
	get_tree().create_timer(DASH_DURATION + 0.02).timeout.connect(
			_shield_rush_slam.bind(reach), CONNECT_ONE_SHOT)


func _shield_rush_slam(reach: float) -> void:
	if not is_alive:
		return
	## Yank the corridor victims to the arrival point...
	var drag := DisplacementEffect.new()
	drag.displaced = "target"
	drag.destination = "toward_source"
	drag.motion = "linear"
	drag.duration = 0.14
	drag.distance = 120.0
	for en in _rush_victims:
		if is_instance_valid(en) and en.get("is_alive"):
			choreo_execute_displacement(drag, [en])
	_rush_victims.clear()
	## ...then the slam lands where he stops (a beat later so the yank reads).
	get_tree().create_timer(0.16).timeout.connect(_shield_rush_impact.bind(reach), CONNECT_ONE_SHOT)


func _shield_rush_impact(reach: float) -> void:
	if not is_alive:
		return
	var slam := AreaDamageEffect.new()
	slam.damage_type = ChainFactory._damage_type(_weapon_data)
	slam.base_damage = get_stat("damage") * 1.1
	slam.aoe_radius = SHIELD_RUSH_SLAM_RADIUS * reach
	var ab: AbilityDefinition = skill_component.get_skill("skill_e") if skill_component else null
	EffectDispatcher.execute_effects([slam], self, [self], ab, combat_manager)
	_spawn_shockwave_ring(SHIELD_RUSH_SLAM_RADIUS * reach)


func _spawn_dash_vfx() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		PlayerVfxHelper.spawn_dash_cue(self, scene_root, sprite, global_position, _dash_dir)
	## Small camera nudge in the dash direction for a punchy departure.
	var cam := get_viewport().get_camera_2d()
	if cam and is_instance_valid(cam):
		var ct := cam.create_tween()
		ct.tween_property(cam, "offset", _dash_dir * 4.0, 0.05)
		ct.tween_property(cam, "offset", Vector2.ZERO, 0.12)


# --- Stat helpers ---

func get_stat(stat_name: String) -> float:
	## Query a stat through the modifier system.
	## Base value lives as an "add" modifier with source "base".
	## Upgrades add more "add" or "bonus" modifiers.
	var base: float = modifier_component.sum_modifiers(stat_name, "add")
	var bonus: float = modifier_component.sum_modifiers(stat_name, "bonus")
	return base * (1.0 + bonus)


func get_armor() -> float:
	var base_armor: float = modifier_component.sum_modifiers("Physical", "resist")
	# Warden passive: double armor below 50% HP
	if _passive_id == "warden_passive" and health.current_hp < health.max_hp * 0.5:
		return base_armor * 2.0
	return base_armor


func is_dead() -> bool:
	return not is_alive


func is_invisible() -> bool:
	## The Ninja's Smoke Bomb / Ranger's Conceal "concealed" stealth (refreshed while held).
	if status_effect_component == null:
		return false
	return status_effect_component.has_status("concealed")


func apply_knockback(force: Vector2) -> void:
	if _iframes_timer > 0.0 or is_invulnerable:
		return
	var armor_val: float = get_armor()
	var reduction: float = armor_val / (armor_val + 15.0)
	knockback_velocity += force * (1.0 - reduction)


# --- Damage ---

func take_damage(hit_data) -> void:
	if not is_alive or god_mode:
		return
	if _iframes_timer > 0.0:
		return
	if is_invulnerable:
		return
	## Ravager Guard: while the sword is up (RMB-hold channel), frontal hits are stopped cold.
	if _is_guard_blocking(hit_data):
		_on_guard_block()
		return
	## Warden Reckoning: while the Dome channel is up, hits from ANY direction are drunk into
	## the pool instead of landing. At the cap the dome bursts on its own (interrupt() ends the
	## channel, and choreo_on_end detonates); otherwise release detonates whatever was stored.
	if choreography_runner != null and choreography_runner.is_running() \
			and _active_choreo_id == "paladin_dome":
		var soaked: float = hit_data.amount if hit_data is HitData else 0.0
		_dome_absorbed += soaked
		_dome_flash()
		if _dome_absorbed >= health.max_hp * DOME_ABSORB_CAP:
			choreography_runner.interrupt()
		return
	## Warden Aegis Shield: a standing absorb pool eats hits whole until it's spent (no i-frames,
	## so it soaks a rapid flurry like Reckoning does), then the remainder falls through next hit.
	if _absorb_shield > 0.0:
		_absorb_shield -= (hit_data.amount if hit_data is HitData else 0.0)
		_dome_flash()
		if _absorb_shield <= 0.0:
			_end_absorb_shield()
		return
	# NOTE: Dodge is handled by DamageCalculator Step 4 — all incoming hits
	# already went through the pipeline. If the hit wasn't dodged, it reaches here.
	# Shade invisibility on dodge is triggered by EventBus.on_dodge (see _ready).

	CombatUtils.process_incoming_damage(self, hit_data)

	# Player-specific reactions
	_iframes_timer = IFRAME_DURATION
	_time_since_hit = 0.0   ## Primal Vigor: reset the out-of-combat regen clock
	_start_hit_flash()
	var amount: float = hit_data.amount if hit_data is HitData else 0.0
	# Damage animation — interrupts attack, does not block movement.
	# Forgiving combo rule: small chip hits during a combo flash only (keep comboing); a real
	# hit (>10) interrupts the combo and plays the damage reaction.
	if not _is_dying:
		var combo_active: bool = choreography_runner != null and choreography_runner.is_running()
		## Q/E skill casts have flinch armor: their payoff often sits deep in the animation
		## (Throw frame 13, Sharpen 22, Reload 30) and a damage-interrupt silently eats the
		## whole cooldown. Hard CC (stun/root) still interrupts via the is_disabled check in
		## _physics_process.
		var skill_armor: bool = combo_active \
				and choreography_runner.get_ability() != null \
				and choreography_runner.get_ability().tags.has("Skill")
		if combo_active and (skill_armor or amount <= 10.0):
			pass  # flash already played; let the combo/cast continue
		else:
			if combo_active:
				choreography_runner.interrupt()
			_attack_anim_active = false
			_damage_anim_active = true
			_play_anim("damage")
	if ExtractionManager.is_channeling and amount > 10.0:
		ExtractionManager.interrupt_channel()


## True while the Guard channel is up AND the hit comes from the frontal arc (facing = the
## cursor, same as every aimed action). Sourceless hits (auras, DoTs) are not blockable.
func _is_guard_blocking(hit_data) -> bool:
	if sprite == null or not String(sprite.animation).begins_with("guard"):
		return false
	if choreography_runner == null or not choreography_runner.is_running():
		return false
	var src: Node2D = hit_data.source if hit_data is HitData else null
	if src == null or not is_instance_valid(src):
		return false
	var to_attacker: Vector2 = src.global_position - global_position
	var facing: Vector2 = _get_aim_world_position() - global_position
	if to_attacker.length_squared() < 1.0 or facing.length_squared() < 1.0:
		return true   ## point-blank overlap — the sword is up, call it blocked
	return absf(facing.angle_to(to_attacker)) <= GUARD_BLOCK_ARC * 0.5


## Blocked-hit feedback: the pack's BlockImpact sheet flashes on the ComboFx overlay.
func _on_guard_block() -> void:
	if _combo_fx == null or _combo_fx.sprite_frames == null:
		return
	var anim: String = _facing_variant(_combo_fx.sprite_frames, "guard_impact")
	if anim == "":
		return
	_combo_fx.position = Vector2.ZERO
	_combo_fx.scale = Vector2.ONE
	_combo_fx.flip_h = false
	_combo_fx.visible = true
	_combo_fx.play(anim)


func _on_sprite_animation_finished() -> void:
	## During a combo the runner owns animation flow — forward and keep combat flags set.
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.notify_animation_finished()
		return
	## Clear one-shot animation flags so walk/idle logic resumes.
	## Death is handled by its own await — don't clear _is_dying here.
	var anim: String = sprite.animation
	if anim == "attack":
		_attack_anim_active = false
	elif anim == "damage":
		_damage_anim_active = false


func _on_sprite_frame_changed() -> void:
	## Forward to the combo runner so it can fire effects on the active phase's hit_frame.
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.notify_frame_changed()


func _start_hit_flash() -> void:
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	var overbright: float = 1.0 + 4.0 * Settings.screen_flash_intensity
	sprite.modulate = Color(overbright, overbright, overbright, 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.07)
	var blinks: int = int((IFRAME_DURATION - 0.07) / 0.14)
	for _i in range(blinks):
		_hit_flash_tween.tween_property(sprite, "modulate:a", 0.12, 0.07)
		_hit_flash_tween.tween_property(sprite, "modulate:a", 1.0,  0.07)
	var cam := get_viewport().get_camera_2d()
	if cam and is_instance_valid(cam):
		var st := cam.create_tween()
		st.tween_property(cam, "offset",
			Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)), 0.05)
		st.tween_property(cam, "offset", Vector2.ZERO, 0.14)


func _on_kill_soul_harvest(killer: Node, victim: Node) -> void:
	## Necromancer Soul Harvest: each enemy the Shade fells yields a soul — a trickle of life now,
	## and every SOUL_HARVEST_THRESHOLD souls empowers the next Rise Corpse / Bone Legion. (Auto-
	## collected on the kill; the world-mote pickup form is a noted follow-up.)
	if _passive_id != "necro_soul_harvest":
		return
	if killer != self or not victim.is_in_group("enemies"):
		return
	if is_alive and health.current_hp < health.max_hp:
		health.apply_healing(SOUL_HARVEST_HEAL)
	_soul_charges += 1
	if _soul_charges >= SOUL_HARVEST_THRESHOLD:
		_soul_charges = 0
		_next_summon_empowered = true


func heal(amount: float) -> void:
	if not is_alive:
		return
	health.apply_healing(amount)
	EventBus.on_heal.emit(self, self, amount)


# --- XP / leveling ---

func add_xp(amount: float) -> void:
	if not is_alive:
		return
	var xp_mult: float = 1.0 + modifier_component.sum_modifiers("xp_gain", "bonus")
	xp += amount * xp_mult
	var xp_needed := _xp_to_next_level()
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		leveled_up.emit(level)
		xp_needed = _xp_to_next_level()
	xp_changed.emit(xp, _xp_to_next_level())


func _xp_to_next_level() -> float:
	return xp_base * (1.0 + (level - 1) * xp_growth)


# --- Upgrade application ---

func apply_stat_upgrade(upgrade: Dictionary) -> void:
	## Status-type upgrades apply a permanent passive status with trigger listeners
	if upgrade.get("type") == "status":
		var status_def := StatusFactory.get_by_id(upgrade["status_id"])
		if status_def and status_effect_component:
			status_effect_component.apply_status(status_def, self)
		return

	var stat_name: String = upgrade.stat
	var value: float      = upgrade.value
	var mod := ModifierDefinition.new()
	# "damage" percent upgrades → "All" bonus (engine convention for generic damage)
	if stat_name == "damage" and upgrade.type == "percent":
		mod.target_tag = "All"
	else:
		mod.target_tag = stat_name
	if upgrade.type == "flat":
		mod.operation = "add"
	elif upgrade.type == "percent":
		mod.operation = "bonus"
	mod.value = value
	mod.source_name = "upgrade"
	modifier_component.add_modifier(mod)

	if stat_name == "max_hp" and upgrade.type == "flat":
		health.max_hp = get_stat("max_hp")
		heal(value)
	if stat_name == "pickup_radius":
		_update_pickup_radius()
	if stat_name == "dash_charges":
		## Make the new charge(s) available immediately (clamped to the new cap) instead
		## of waiting a full cooldown for the raised cap to fill in.
		_dash_charges = mini(_max_dash_charges(), _dash_charges + int(round(value)))


func remove_stat_upgrade(upgrade: Dictionary) -> void:
	## For evolution recipes that remove prerequisite upgrades.
	if upgrade.get("type") == "status":
		if status_effect_component:
			status_effect_component.remove_status(upgrade["status_id"])
		return
	## Finds and removes the first matching modifier.
	var stat_name: String = upgrade.stat
	var value: float      = upgrade.value
	var op: String = "add" if upgrade.type == "flat" else "bonus"
	for mod in modifier_component.get_all_modifiers():
		if mod.target_tag == stat_name and mod.operation == op \
				and mod.source_name == "upgrade" and absf(mod.value - value) < 0.001:
			modifier_component.remove_modifier(mod)
			break
	if stat_name == "max_hp":
		health.max_hp = get_stat("max_hp")
		health.current_hp = minf(health.current_hp, health.max_hp)
	if stat_name == "pickup_radius":
		_update_pickup_radius()


func apply_ability_upgrade(upgrade: Dictionary) -> void:
	## Called by UpgradeManager when a run-scoped class ability upgrade is picked.
	## "modifier" ops add a ModifierDefinition with source "ability_upgrade" (distinct from
	## "upgrade" so evolution's remove_stat_upgrade cannot accidentally strip them).
	## All other ops (scale_aoe, add_status, add_projectiles, …) need a _load_combo rebuild
	## because ClassModFactory.apply_upgrade_dicts_to_kit applies them fresh to a pristine kit.
	var op: String = upgrade.get("op", "")
	if op == "modifier":
		var stat_name: String = upgrade.get("stat", "")
		var value: float = upgrade.get("value", 0.0)
		var mod := ModifierDefinition.new()
		if stat_name == "damage" and upgrade.get("type", "") == "percent":
			mod.target_tag = "All"
		else:
			mod.target_tag = stat_name
		mod.operation  = "add" if upgrade.get("type", "") == "flat" else "bonus"
		mod.value      = value
		mod.source_name = "ability_upgrade"
		modifier_component.add_modifier(mod)
		if stat_name == "max_hp" and upgrade.get("type", "") == "flat":
			health.max_hp = get_stat("max_hp")
			heal(value)
		if stat_name == "pickup_radius":
			_update_pickup_radius()
		if stat_name == "dash_charges":
			_dash_charges = mini(_max_dash_charges(), _dash_charges + int(round(value)))
	else:
		## Kit-mutation: upgrade dict is already in UpgradeManager.ability_upgrades; rebuild so it
		## takes effect. _load_combo re-applies class mods + all accumulated ability upgrades.
		_load_combo()


# --- Pickup collection ---

func _update_pickup_radius() -> void:
	if pickup_shape and pickup_shape.shape:
		pickup_shape.shape.radius = get_stat("pickup_radius")


func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("start_magnet"):
		area.start_magnet(self)


# --- Void instability debuff ---
## Apply void_touched when instability enters Volatile tier (≥70); remove with a
## hysteresis band at <60 to prevent flickering. Phase 1 is exempt (tutorial phase).

const VOID_APPLY_THRESHOLD: float = 70.0
const VOID_REMOVE_THRESHOLD: float = 60.0

func _on_instability_changed(new_value: float) -> void:
	_check_void_touched(new_value)


func _on_phase_started(phase_num: int) -> void:
	## Re-evaluate in case instability was already above threshold when phase begins.
	if phase_num >= 2:
		_check_void_touched(GameManager.instability)


func _check_void_touched(instability_value: float) -> void:
	if not is_alive or not status_effect_component:
		return
	if GameManager.phase_number < 2:
		## Phase 1 exempt — remove debuff if it somehow exists
		if status_effect_component.has_status("void_touched"):
			status_effect_component.remove_status("void_touched")
		return
	if instability_value >= VOID_APPLY_THRESHOLD \
			and not status_effect_component.has_status("void_touched"):
		StatusFactory.build_all()
		status_effect_component.apply_status(StatusFactory.void_touched, self)
	elif instability_value < VOID_REMOVE_THRESHOLD \
			and status_effect_component.has_status("void_touched"):
		status_effect_component.remove_status("void_touched")


# --- Instability Siphon ---

func _on_kill_siphon(killer: Node, victim: Node) -> void:
	if killer == self and victim.is_in_group("enemies"):
		GameManager.modify_instability(-1)
		## Devout Last Rites: each kill returns a little life (faith rewards the reaper).
		if _passive_id == "devout_passive" and is_alive and health.current_hp < health.max_hp:
			health.apply_healing(DEVOUT_KILL_HEAL)


# --- Orbit orbs ---

func _setup_orbit_orbs() -> void:
	_cleanup_orbit_orbs()
	var count: int = _weapon_data.get("orbit_count", 3)
	var radius: float = _weapon_data.get("orbit_radius", 64.0)
	var spd: float = _weapon_data.get("orbit_speed", 1.8)
	var tint: Color = _weapon_data.get("tint", Color.WHITE)

	## Read size multiplier from active mods
	var size_mult: float = 1.0
	for mod_id in _active_mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		if mod_data.get("effect_type", "") == "size":
			size_mult = mod_data.get("params", {}).get("size_mult", 1.5)
			break

	var orb_effects: Array = _weapon_ability.effects.duplicate() if _weapon_ability else []

	for i in range(count):
		var orb: Area2D = OrbitOrbScript.new()
		orb.player_ref = self
		orb.orbit_radius = radius
		orb.orbit_speed = spd
		orb.orbit_offset = TAU * float(i) / float(count)
		orb.tint = tint
		orb.hit_radius = 7.0
		orb.size_mult = size_mult
		orb.on_hit_effects = orb_effects
		orb.combat_manager_ref = combat_manager
		get_tree().current_scene.add_child(orb)
		_orbit_orbs.append(orb)


func _cleanup_orbit_orbs() -> void:
	for orb in _orbit_orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbit_orbs.clear()


# --- Death ---

func _on_health_died(_entity: Node2D) -> void:
	if not is_alive:
		return
	is_alive = false
	_is_dying = true
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.interrupt()
	if trigger_component:
		trigger_component.cleanup()
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	sprite.modulate = Color.WHITE
	knockback_velocity = Vector2.ZERO
	_cleanup_orbit_orbs()
	# Play death animation then trigger game-over flow
	_attack_anim_active = false
	_damage_anim_active = false
	_play_anim("death")   ## death sheets are single-row → falls back to the base slice
	await sprite.animation_finished
	EventBus.on_death.emit(self)
	died.emit()
	GameManager.on_player_died()


func reset_stats() -> void:
	## Called on run restart — clear all temporary modifiers.
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.interrupt()
	modifier_component.remove_modifiers_by_source("upgrade")
	modifier_component.remove_by_source_prefix("mod_")
	xp = 0.0
	level = 1
	_active_mods.clear()
	is_alive = true
	_is_dying = false
	_attack_anim_active = false
	_damage_anim_active = false
	_pending_ability = null
	_pending_targets.clear()
	_pending_aim_dir = Vector2.ZERO
	_iframes_timer = 0.0
	knockback_velocity = Vector2.ZERO
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	sprite.modulate = Color.WHITE
	_cleanup_orbit_orbs()
	if is_instance_valid(_aim_marker):
		_aim_marker.queue_free()
	_aim_marker = null
	_reset_dash_state()
	health.setup(_base_stats["max_hp"])
	_update_pickup_radius()


# --- Internal helpers ---

func _add_modifier(tag: String, op: String, value: float, source: String) -> void:
	var mod := ModifierDefinition.new()
	mod.target_tag = tag
	mod.operation = op
	mod.value = value
	mod.source_name = source
	modifier_component.add_modifier(mod)


## Debug: swap in a new mod list and rebuild the weapon ability in place.
## Removes old mod/combo modifiers, applies the new set, rebuilds _weapon_ability.
## Does NOT touch stat upgrades, health, or the behavior signal connection.
func debug_reload_mods(mod_ids: Array) -> void:
	modifier_component.remove_by_source_prefix("mod_")
	modifier_component.remove_by_source_prefix("combo_")
	_active_mods = mod_ids
	_has_instability_siphon = "instability_siphon" in _active_mods
	for m in WeaponFactory.build_mod_modifiers(_active_mods):
		modifier_component.add_modifier(m)
	for m in WeaponFactory.build_combo_modifiers(_active_mods):
		modifier_component.add_modifier(m)
	_weapon_ability = WeaponFactory.build_weapon_ability(_weapon_id, _weapon_data, _active_mods)
	var combo_passives: Array[StatusEffectDefinition] = WeaponFactory.build_combo_passives(_active_mods)
	for passive_def in combo_passives:
		status_effect_component.apply_status(passive_def, self, 1)
	behavior_component.setup(modifier_component, _weapon_ability.cooldown_base)


func _spawn_scorched_earth_patches(from: Vector2, to: Vector2, scene_root: Node) -> void:
	var mod_params: Dictionary = ModData.ALL.get("napalm", {}).get("params", {})
	var patch_count: int  = int(mod_params.get("patch_count",   5))
	var patch_dmg: float  = mod_params.get("patch_damage",   5.0)
	var patch_dur: float  = mod_params.get("patch_duration", 10.0)
	var patch_rad: float  = mod_params.get("patch_radius",   30.0)
	for p in patch_count:
		var t: float     = (float(p) + 0.5) / float(patch_count)
		var pos: Vector2 = from.lerp(to, t)
		_spawn_burn_patch(pos, patch_dmg, patch_rad, patch_dur, scene_root)


func _spawn_burn_patch(pos: Vector2, dmg_per_sec: float, radius: float, duration: float, scene_root: Node) -> void:
	var area := Area2D.new()
	area.top_level        = true
	area.global_position  = pos
	area.collision_layer  = 0
	area.collision_mask   = 2  # enemies
	area.monitoring       = true
	area.monitorable      = false
	scene_root.add_child(area)

	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape   = circle
	area.add_child(shape)

	# Ground glow: approximated circle via Polygon2D
	var poly   := Polygon2D.new()
	var pts    := PackedVector2Array()
	for i in 20:
		var a: float = (float(i) / 20.0) * TAU
		pts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color   = Color(1.0, 0.30, 0.0, 0.22)
	area.add_child(poly)

	# Fire particles
	var particles := CPUParticles2D.new()
	particles.amount               = 14
	particles.lifetime             = 1.0
	particles.one_shot             = false
	particles.explosiveness        = 0.0
	particles.direction            = Vector2(0.0, -1.0)
	particles.spread               = 40.0
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 50.0
	particles.gravity              = Vector2.ZERO
	particles.scale_amount_min     = 2.0
	particles.scale_amount_max     = 5.0
	particles.color                = Color(1.0, 0.45, 0.05)
	area.add_child(particles)
	particles.emitting = true

	# Track bodies entering / exiting the patch
	var bodies_in_area: Array = []
	area.body_entered.connect(func(b: Node2D): bodies_in_area.append(b))
	area.body_exited.connect(func(b: Node2D): bodies_in_area.erase(b))

	# Damage timer — auto-stops when area is freed
	var player_ref: Node2D = self
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.one_shot  = false
	area.add_child(timer)
	timer.timeout.connect(func() -> void:
		for body in bodies_in_area.duplicate():
			if is_instance_valid(body) and body.has_method("take_damage") and is_instance_valid(player_ref):
				body.take_damage(HitData.create(dmg_per_sec, "fire", player_ref, body, null))
	)
	timer.start()

	# Fade out then free
	area.get_tree().create_timer(duration - 0.5).timeout.connect(func() -> void:
		if is_instance_valid(area):
			particles.emitting = false
			var t := area.create_tween()
			t.tween_property(area, "modulate:a", 0.0, 0.5)
			t.tween_callback(area.queue_free)
	)


func _set_base_stat(stat_name: String, value: float) -> void:
	## Update a base stat by removing the old "base" modifier and adding a new one.
	for mod in modifier_component.get_all_modifiers():
		if mod.target_tag == stat_name and mod.source_name == "base" and mod.operation == "add":
			modifier_component.remove_modifier(mod)
			break
	_add_modifier(stat_name, "add", value, "base")
