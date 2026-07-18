class_name MoveInput
extends RefCounted

## Single source of truth for analog movement input.
##
## Every movement site (arena player, hub player) reads the stick through here so the
## feel stays identical between them. Returns a vector whose LENGTH is the intended
## fraction of move_speed (0.0 -> 1.0), not a normalized direction — callers multiply
## it by their speed stat directly and must not re-normalize it.
##
## Keyboard is unaffected by design: digital keys report raw strength 1.0, so the
## curve and saturation below are no-ops and WASD still moves at exactly full speed.

## Radial deadzone, applied to the stick's MAGNITUDE rather than per-axis. The per-action
## deadzones in project.godot are deliberately bypassed (Input.get_vector reads raw
## strengths when handed an explicit deadzone) — a per-axis gate is what forced input into
## the 8 pure directions, since each axis had to clear its own threshold independently.
const DEADZONE: float = 0.18

## Response curve exponent on the post-deadzone magnitude. >1 trades a little top-end
## reach for finer control when weaving between projectiles at low deflection.
const RESPONSE_CURVE: float = 1.4

## Deflection at or above this reads as full speed. Sticks rarely reach a true 1.0 at the
## diagonals (square-ish gates, worn hardware), so without this you can never quite sprint.
const SATURATION: float = 0.95

## Floor on a non-zero magnitude. Just past the deadzone the curve would otherwise leave
## you crawling too slowly to be worth the input; this keeps the slowest walk useful.
const MIN_SPEED_FRAC: float = 0.22


## The frame's movement input as direction * speed-fraction (length 0.0 -> 1.0).
static func get_move_vector() -> Vector2:
	## get_vector applies the radial deadzone and rescales the surviving magnitude back
	## across the full 0..1 range, so there is no speed discontinuity at the edge.
	var raw: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down", DEADZONE)
	var magnitude: float = raw.length()
	if magnitude <= 0.0:
		return Vector2.ZERO
	return (raw / magnitude) * shape_magnitude(magnitude)


## Post-deadzone deflection (0..1) -> speed fraction (MIN_SPEED_FRAC..1). Split out from the
## Input plumbing above so the feel curve is testable on its own.
static func shape_magnitude(magnitude: float) -> float:
	var shaped: float = pow(minf(magnitude / SATURATION, 1.0), RESPONSE_CURVE)
	return lerpf(MIN_SPEED_FRAC, 1.0, shaped)
