extends Node2D

## InstabilityAura — Concentric ring VFX drawn around the player that grows
## in intensity with instability tier. Attached as a child of the player node
## by main_arena.gd. Uses _draw() to match the project's zero-sprite pattern.

var _instability: float = 0.0
var _tier_idx: int = 0         ## 0=Stable, 1=Unsettled, 2=Volatile, 3=Critical
var _tier_color: Color = Color.WHITE
var _pulse_time: float = 0.0

## Pulse speeds per tier (radians/sec)
const PULSE_SPEEDS: Array = [0.0, 1.8, 2.8, 4.5]

func _ready() -> void:
	z_index = -1  ## Draw behind player sprite
	GameManager.instability_changed.connect(_on_instability_changed)

func _process(delta: float) -> void:
	if _tier_idx == 0:
		return  ## Nothing to animate at Stable tier
	_pulse_time += delta * PULSE_SPEEDS[_tier_idx]
	queue_redraw()

func _on_instability_changed(new_value: float) -> void:
	_instability = new_value
	var tier: Dictionary = LootTables.get_instability_tier(new_value)
	var new_idx: int = LootTables.INSTABILITY_TIERS.find(tier)
	if new_idx < 0:
		new_idx = 0
	_tier_idx = new_idx
	_tier_color = tier.color
	queue_redraw()

func _draw() -> void:
	if _tier_idx == 0:
		return

	## Number of rings and brightness scale by tier
	var ring_count: int = _tier_idx           ## 1, 2, or 3 rings
	var base_alpha: float = 0.10 + _tier_idx * 0.06
	var pulse: float = 0.5 + 0.5 * sin(_pulse_time)  ## 0→1 sine wave

	for i in range(ring_count):
		## Each ring has a different radius and phase offset
		var phase_offset: float = float(i) * (TAU / 3.0)
		var ring_pulse: float = 0.5 + 0.5 * sin(_pulse_time + phase_offset)
		var radius: float = 12.0 + float(i) * 5.0 + ring_pulse * 2.0
		var alpha: float = base_alpha * (1.0 - float(i) * 0.25) * (0.6 + 0.4 * ring_pulse)
		var col := Color(_tier_color.r, _tier_color.g, _tier_color.b, alpha)

		## Draw ring as a series of short arc segments (approximated as thin rect outline)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, col, 1.0)

	## At Critical: add an inner glow fill
	if _tier_idx >= 3:
		var glow_alpha: float = 0.06 + 0.04 * pulse
		draw_circle(Vector2.ZERO, 10.0, Color(_tier_color.r, _tier_color.g, _tier_color.b, glow_alpha))
