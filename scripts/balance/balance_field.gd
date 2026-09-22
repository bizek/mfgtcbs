class_name BalanceField
extends RefCounted

## BalanceField — the schema for ONE tunable number.
##
## The Unit Editor builds its whole inspector from these: a field knows its address, its
## shipped value, what kind of widget edits it, what range is sane, and what has to happen
## before a change is visible. Nothing in the editor hardcodes a stat name, so a field
## added to the registry appears in the UI with no UI work.
##
## `base` is the value compiled into source — what "revert" restores and what the editor
## shows as the anchor next to your edit. It is NOT read from the override layer; the whole
## point is to always be able to see how far you have moved from shipped.

enum Kind {
	FLOAT,
	INT,
	BOOL,
	VEC2,
}

## How a change reaches the running game. Drives what the editor does after a write, and
## what it tells you when it can't do it silently.
enum Apply {
	LIVE,      ## re-read every frame or on next use — nothing to do
	REBUILD,   ## needs the player's kit/stats rebuilt (editor calls the rebuild hook)
	RESTART,   ## needs a scene reload or a fresh run (editor says so; never does it behind your back)
}

var path: String = ""
var label: String = ""
var kind: Kind = Kind.FLOAT
var base: Variant = 0.0
var minimum: float = 0.0
var maximum: float = 100.0
var step: float = 0.1
var suffix: String = ""
var doc: String = ""
var section: String = ""          ## group heading inside a subject ("CORE", "COMBAT", ...)
var apply: Apply = Apply.LIVE

## When non-empty, this value is DERIVED — something downstream overwrites it every rebuild,
## so an override here could never be observed. The editor renders these read-only with this
## string as the pointer to the real control.
##
## The alternative was to leave them out of the registry entirely, which is what an earlier
## pass did for the pickup-collector radius. That is right when the field has no obvious home
## to look for, but wrong for a stat as expected as "Damage": Ben would open a character, not
## find it, and reasonably conclude the tool was incomplete. Showing the row and naming its
## owner is the honest version of absent.
var derived_from: String = ""


static func make(p_path: String, p_label: String, p_base: Variant, p_section: String,
		p_kind: Kind = Kind.FLOAT) -> BalanceField:
	var f := BalanceField.new()
	f.path = p_path
	f.label = p_label
	f.base = p_base
	f.section = p_section
	f.kind = p_kind
	f._auto_range()
	return f


## A default range derived from the shipped value, used when no hint is registered.
##
## Deliberately generous — 0 to 4x the base, or a fixed span when the base is 0 (a 0-based
## stat with a 0-based range would be an uneditable spinbox, which is how a "tunable" ends
## up inert). Every stat the editor knows well overrides this from the hint table.
func _auto_range() -> void:
	match kind:
		Kind.BOOL:
			minimum = 0.0
			maximum = 1.0
			step = 1.0
		Kind.INT:
			var bi: float = float(base) if (base is int or base is float) else 0.0
			minimum = 0.0
			maximum = maxf(bi * 4.0, 10.0)
			step = 1.0
		Kind.VEC2:
			minimum = 0.0
			maximum = 512.0
			step = 1.0
		_:
			var bf: float = float(base) if (base is int or base is float) else 0.0
			minimum = minf(0.0, bf * 2.0)
			maximum = maxf(absf(bf) * 4.0, 1.0)
			step = _nice_step(maxf(absf(bf), 1.0))


## Step sized to the magnitude, so a 0.05 crit chance nudges by 0.001 and a 520 dash speed
## nudges by 5 — one spinbox rule instead of a per-stat step in every hint.
static func _nice_step(magnitude: float) -> float:
	if magnitude >= 200.0:
		return 5.0
	if magnitude >= 20.0:
		return 1.0
	if magnitude >= 2.0:
		return 0.1
	if magnitude >= 0.2:
		return 0.01
	return 0.001


## Fluent range setter, so the hint table reads as one line per stat.
func ranged(p_min: float, p_max: float, p_step: float = -1.0) -> BalanceField:
	minimum = p_min
	maximum = p_max
	if p_step > 0.0:
		step = p_step
	return self


func described(p_doc: String, p_suffix: String = "") -> BalanceField:
	doc = p_doc
	suffix = p_suffix
	return self


func applied(p_apply: Apply) -> BalanceField:
	apply = p_apply
	return self


func derived(p_owner: String) -> BalanceField:
	derived_from = p_owner
	return self


func is_derived() -> bool:
	return derived_from != ""


## The live value: the override if one is authored, else the shipped base.
func current() -> Variant:
	match kind:
		Kind.BOOL:
			return BalanceOverrides.get_bool(path, bool(base))
		Kind.INT:
			return BalanceOverrides.get_int(path, int(base))
		Kind.VEC2:
			return BalanceOverrides.get_vector2(path, base if base is Vector2 else Vector2.ZERO)
		_:
			return BalanceOverrides.get_float(path, float(base))


func is_overridden() -> bool:
	return BalanceOverrides.has_override(path)


## True when an override exists but resolves to the shipped value anyway — the editor
## offers to clear these so the change list stays honest about what actually differs.
func is_noop_override() -> bool:
	if not is_overridden():
		return false
	return _equal(current(), base)


func write(value: Variant) -> void:
	## Writing the base value back CLEARS the override rather than storing a duplicate of
	## source. Without this, nudging a spinbox up and back down would leave a permanent
	## entry in the change list that differs from shipped by nothing.
	if _equal(value, base):
		BalanceOverrides.clear_value(path)
		return
	match kind:
		Kind.VEC2:
			var v: Vector2 = value if value is Vector2 else Vector2.ZERO
			BalanceOverrides.set_value(path, [v.x, v.y])
		Kind.INT:
			BalanceOverrides.set_value(path, int(value))
		Kind.BOOL:
			BalanceOverrides.set_value(path, bool(value))
		_:
			BalanceOverrides.set_value(path, float(value))


func revert() -> void:
	BalanceOverrides.clear_value(path)


static func _equal(a: Variant, b: Variant) -> bool:
	if a is Vector2 and b is Vector2:
		return (a as Vector2).is_equal_approx(b)
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b


## "100 → 120" for the change list and the diff view.
func delta_text() -> String:
	if not is_overridden():
		return ""
	return "%s → %s" % [format_value(base), format_value(current())]


func format_value(v: Variant) -> String:
	match kind:
		Kind.BOOL:
			return "on" if bool(v) else "off"
		Kind.INT:
			return str(int(v))
		Kind.VEC2:
			var vec: Vector2 = v if v is Vector2 else Vector2.ZERO
			return "%.0f x %.0f" % [vec.x, vec.y]
		_:
			var f: float = float(v)
			## Match the printed precision to the step, so a crit chance reads 0.055 and a
			## dash speed reads 520 rather than 520.000.
			if step >= 1.0:
				return "%.0f" % f
			if step >= 0.1:
				return "%.1f" % f
			if step >= 0.01:
				return "%.2f" % f
			return "%.3f" % f
