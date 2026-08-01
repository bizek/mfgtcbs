class_name ComboTimingAudit
extends RefCounted
## Debug-only audit of the combo layer's TIMING data against the sprite sheets it actually plays.
## Every finding here is a class of bug that is invisible in code review because it only exists in
## the gap between a hand-authored number (hit_frame, wait_duration) and a sheet Ben trimmed or
## retimed in the Animation Lab.
##
## Run it from the Training Room panel (AUDIT TIMING) or call ComboTimingAudit.log_report(player).
##
## Why it audits the LIVE player rather than parsing the factories: the number that matters is the
## one the runner uses at play time, which depends on (a) the Lab's per-anim AND per-facing
## overrides, already baked into the built SpriteFrames, and (b) _facing_variant's fallback chain —
## an anim with no orthogonal sheet emits no cardinal rows at all, so a "cardinal" facing plays a
## DIAGONAL row with a different frame count. Parsing chain_factory.gd cannot see either, and gets
## the wrong answer (it reported The Drifter's Taunt as dead on the cardinals; in engine the base
## slice it was reading is never played).
##
## Findings:
##   MISSING  the phase names an anim that resolves to nothing — the body plays whatever was on
##            screen before, and an "anim_finished" phase leans on its no-animation escape hatch.
##   DEADHIT  hit_frame >= the resolved row's frame count → frame_changed never matches → the
##            phase's effects NEVER FIRE for that facing. Silent zero damage.
##   LOCK     exit_type "anim_finished" on a LOOPING row → animation_finished never fires → the
##            runner sits in that phase forever, holding its flags (invulnerable frozen host).
##   CUT      a channel beat shorter than its own body anim → each beat restarts the cast before it
##            finishes drawing → reads as a stutter instead of a rhythm.
##   FREEZE   a tap-chain node whose cancel window outruns its swing. Handled at runtime by the
##            runner's recovery release (choreo_on_phase_recovery), so this is INFO, not an error —
##            it's here to show how much of each window is post-swing grace.

const FREEZE_TOLERANCE: float = 0.12   ## ignore sub-2-frame slack; that's just rounding
const FACINGS: Array[String] = ["right", "down_right", "down", "down_left",
		"left", "up_left", "up", "up_right"]


## Audit every graph the given player can run. Returns report lines (first line is the summary).
static func run(player) -> Array[String]:
	var lines: Array[String] = []
	if player == null or player.sprite == null or player.sprite.sprite_frames == null:
		return ["ComboTimingAudit: no player sprite to audit."]

	var char_id: String = ProgressionManager.selected_character
	var graphs: Array = [
		["light", player._combo_ability],
		["heavy", player._combo_heavy],
		["channel", player._combo_channel],
	]
	## Stance-swapped graphs (the Scavenger's armed RMB) are still graphs the player can run —
	## audit them, or their nodes would be the only unchecked timings in the kit.
	if player._combo_heavy_elemental != null:
		graphs.append(["heavy_elemental", player._combo_heavy_elemental])
	if player.skill_component:
		for slot in player.skill_component.get_slots():
			graphs.append([slot, player.skill_component.get_skill(slot)])

	## _facing_variant reads live facing state; drive it across all 8 sectors and restore after.
	var saved_facing: String = player._facing
	var saved_aim: Vector2 = player._aim_dir

	var errors: int = 0
	var infos: int = 0
	for entry in graphs:
		var label: String = entry[0]
		var ability: AbilityDefinition = entry[1]
		if ability == null or ability.choreography == null:
			continue
		var phases: Array = ability.choreography.phases
		for i in phases.size():
			var phase: ChoreographyPhase = phases[i]
			var found: Array[String] = _audit_phase(player, char_id, ability, phase, i, phases)
			for f in found:
				if f.begins_with("FREEZE"):
					infos += 1
				else:
					errors += 1
				lines.append("  [%s %s #%d %s] %s" % [char_id, label, i,
						phase.animation if phase.animation != "" else "(no anim)", f])

	player._facing = saved_facing
	player._aim_dir = saved_aim

	var head: String = "ComboTimingAudit [%s]: %d problem(s), %d info." % [char_id, errors, infos]
	if lines.is_empty():
		head += " Clean."
	lines.insert(0, head)
	return lines


## One phase across all 8 facings. Findings are deduplicated per kind, listing the facings hit.
static func _audit_phase(player, char_id: String, _ability: AbilityDefinition,
		phase: ChoreographyPhase, index: int, phases: Array) -> Array[String]:
	var out: Array[String] = []
	if phase.animation == "":
		return out   ## "hold whatever is on screen" is legal and carries no timing contract

	var frames: SpriteFrames = player.sprite.sprite_frames
	var speed_scale: float = phase.telegraph_speed_scale if phase.telegraph_speed_scale > 0.0 else 1.0
	var is_beat: bool = _is_channel_beat(phase, index)

	var missing: Array[String] = []
	var deadhit: Array[String] = []
	var looping: Array[String] = []
	var lengths: Dictionary = {}   ## resolved anim name -> length in seconds

	for facing in FACINGS:
		player._facing = facing
		player._aim_dir = Vector2.RIGHT.rotated(deg_to_rad(FACINGS.find(facing) * 45.0))
		var resolved: String = player._facing_variant(frames, phase.animation)
		if resolved == "":
			missing.append(facing)
			continue
		var sn := StringName(resolved)
		var count: int = frames.get_frame_count(sn)
		var fps: float = frames.get_animation_speed(sn)
		if fps > 0.0:
			lengths[resolved] = float(count) / fps / speed_scale
		## The hit frame the runner will actually use for this facing (Lab pin wins over the kit).
		var pinned: int = CharacterSpriteFactory.get_hit_frame(char_id, phase.animation, facing)
		var hit: int = pinned if pinned >= 0 else phase.hit_frame
		if hit >= count:
			deadhit.append("%s(%s: frame %d of %d)" % [facing, resolved, hit, count])
		if phase.exit_type == "anim_finished" and frames.get_animation_loop(sn):
			looping.append(resolved)

	if not missing.is_empty():
		out.append("MISSING '%s' resolves to nothing on: %s" % [phase.animation, ", ".join(missing)])
	if not deadhit.is_empty():
		out.append("DEADHIT effects never fire — %s" % ", ".join(deadhit))
	if not looping.is_empty():
		out.append("LOCK exit_type='anim_finished' on looping row(s) %s — animation_finished never fires"
				% ", ".join(looping))

	if phase.exit_type == "wait" and not lengths.is_empty():
		var longest: float = 0.0
		var shortest: float = 1e9
		for k in lengths:
			var seg: float = lengths[k]
			longest = maxf(longest, seg)
			shortest = minf(shortest, seg)
		if is_beat and phase.wait_duration < longest - 0.01 and not phase.hold_anim_on_reentry:
			out.append("CUT channel beat %.2fs < body %.2fs — the cast restarts before it finishes"
					% [phase.wait_duration, longest])
		elif not is_beat and phase.wait_duration > shortest + FREEZE_TOLERANCE:
			out.append("FREEZE window %.2fs vs swing %.2fs → %.2fs of post-swing grace (recovery release covers it)"
					% [phase.wait_duration, shortest, phase.wait_duration - shortest])
	## A "wait" phase that can neither branch nor fall through just burns its window doing nothing.
	if phase.exit_type == "wait" and phase.branches.is_empty() and phase.default_next < 0 \
			and phase.wait_duration > 0.25:
		out.append("STALL no branches and default_next=-1 — the phase idles %.2fs before ending"
				% phase.wait_duration)
	## A branch pointing outside the graph silently ends the chain instead of advancing.
	for branch in phase.branches:
		if branch.next_phase >= phases.size():
			out.append("BADLINK branch → phase %d but the graph has %d" % [branch.next_phase, phases.size()])
	return out


## Mirrors ChoreographyRunner._is_channel_beat — keep the two in step. A self-pointing BUFFERED
## branch is a re-tappable node, not a held channel beat.
static func _is_channel_beat(phase: ChoreographyPhase, index: int) -> bool:
	if phase.hold_anim_on_reentry or phase.default_next == index:
		return true
	for branch in phase.branches:
		if branch.next_phase == index and branch.condition is ConditionInputHeld:
			return true
	return false


## Print the report to the output log (Training Room button / manual call).
## NOTE: plain print(), not the Logger autoload — `Logger` is also a Godot NATIVE class name in 4.6,
## and inside a class_name script the native one wins at parse time ("Static function log_info() not
## found in base GDScriptNativeClass"). Nothing else in the codebase uses that autoload either.
static func log_report(player) -> void:
	for line in run(player):
		print(line)
