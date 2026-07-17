class_name GearUniqueFactory
extends RefCounted
## Builds the ONE unique effect carried by a purple gear item (task 34).
##
## HARD RULE (design_audit §3.1): uniques are assembled ONLY from existing machinery —
## ModifierDefinition stat bundles, StatusEffectDefinition + TriggerListenerDefinition procs,
## and the established effect types (HealEffect / AreaDamageEffect / ApplyStatusEffectData).
## No bespoke runtime code. If a unique needs new dispatch, it gets redesigned, not coded.
##
## build(unique_id) → { "modifiers": Array[ModifierDefinition], "statuses": Array[StatusEffectDefinition] }
## The player applies modifiers to its ModifierComponent (source "gearunique_…") and the
## statuses to its StatusEffectComponent on weapon equip — exactly like weapon-mod modifiers
## and combo passives are wired today (player._load_weapon_mods).


static func build(unique_id: String) -> Dictionary:
	var result: Dictionary = { "modifiers": [], "statuses": [] }
	match unique_id:
		# Fighter — Bloodsworn Greatblade: kills stoke the swing.
		"u_rampage":
			result.statuses = [_self_buff_on_kill("rampage", "attack_speed", 0.25, 3.0)]
		# Ranger — Widowmaker: crits open wounds.
		"u_hemorrhage":
			result.statuses = [_on_crit_apply(StatusFactory.get_by_id("bleed"), "hemorrhage")]
		# Paladin — Aegis of the Fallen: the dead ward you; the kill mends you.
		"u_retribution":
			result.modifiers = [_mod("Physical", "resist", 5.0, "u_retribution")]
			result.statuses = [_on_kill_heal("retribution", 0.06)]
		# Wizard — Cinderbrand: everything it strikes catches.
		"u_wildfire":
			result.statuses = [_on_hit_apply(StatusFactory.get_by_id("burning"), "wildfire")]
		# Rogue — Whispering Death: sustained serrated bleed (reuse the shipped passive).
		"u_serrated":
			result.statuses = [StatusFactory.get_by_id("serrated_strikes")]
		# Bard — Chorus of the Void: the chord staggers the crowd.
		"u_discord":
			result.statuses = [_on_hit_apply(_slow_status("discord_slow", -0.25, 2.0), "discord")]
		# Barbarian — Skullcleaver: fury builds with every blow.
		"u_bloodrage":
			result.statuses = [_on_hit_self_stack("skull_fury", "damage", 0.04, 5, 4.0)]
		# Ninja — Death's Whisper: crits detonate a killing flourish.
		"u_killing_edge":
			result.statuses = [_on_crit_aoe("Physical", 18.0, 60.0, "killing_edge")]
		# Blood Mage — Heart-Eater: what it takes, it gives back.
		"u_sanguine":
			result.modifiers = [_mod("leech", "bonus", 0.04, "u_sanguine")]
			result.statuses = [_on_kill_heal("sanguine", 0.06)]
		# Gunslinger — Deadman's Hand: a kill snaps the next volley faster.
		"u_fanfire":
			result.statuses = [_self_buff_on_kill("fanfire", "attack_speed", 0.25, 2.5)]
		# Druid — World-Root: poison creep plus a trickle of life on the kill.
		"u_blightbloom":
			result.statuses = [
				_on_hit_apply(StatusFactory.get_by_id("bleed"), "blightbloom_dot"),
				_on_kill_heal("blightbloom_heal", 0.04),
			]
		# Cleric — Pyre of Judgment: the faithful are mended; kills sanctify.
		"u_benediction":
			result.modifiers = [_mod("max_hp", "add", 15.0, "u_benediction")]
			result.statuses = [_on_kill_heal("benediction", 0.08)]
		# ── Universal trinket uniques ──
		# Bloodring: it drinks a little, gives a little back.
		"t_bloodring":
			result.modifiers = [_mod("leech", "bonus", 0.05, "t_bloodring")]
			result.statuses = [_on_kill_heal("bloodring", 0.05)]
		# Stormcore: hums with static; hits pass it on.
		"t_stormcore":
			result.statuses = [_on_hit_apply(StatusFactory.get_by_id("shocked"), "stormcore")]
		# Ember Heart: a kill stokes the pulse.
		"t_emberheart":
			result.modifiers = [_mod("max_hp", "add", 25.0, "t_emberheart")]
			result.statuses = [_self_buff_on_kill("emberheart", "attack_speed", 0.20, 3.0)]
	return result


## Human-readable one-liner for the item card's unique line (Pass 2 UI).
static func describe(unique_id: String) -> String:
	match unique_id:
		"u_rampage":      return "On kill: +25% Attack Speed for 3s."
		"u_hemorrhage":   return "Crits apply Bleed."
		"u_retribution":  return "+5 Armor. On kill: heal 6% max HP."
		"u_wildfire":     return "Hits apply Burning."
		"u_serrated":     return "Hits apply Bleed."
		"u_discord":      return "Hits slow enemies by 25% for 2s."
		"u_bloodrage":    return "Each hit: +4% Damage (stacks 5×, 4s)."
		"u_killing_edge": return "On crit: 18 damage burst around the target."
		"u_sanguine":     return "+4% Lifesteal. On kill: heal 6% max HP."
		"u_fanfire":      return "On kill: +25% Attack Speed for 2.5s."
		"u_blightbloom":  return "Hits apply Bleed. On kill: heal 4% max HP."
		"u_benediction":  return "+15 Max HP. On kill: heal 8% max HP."
		"t_bloodring":    return "+5% Lifesteal. On kill: heal 5% max HP."
		"t_stormcore":    return "Hits apply Shocked."
		"t_emberheart":   return "+25 Max HP. On kill: +20% Attack Speed for 3s."
	return ""


# ── Builders (all mirror shipped StatusFactory patterns) ──────────────────────

static func _mod(tag: String, op: String, value: float, source: String) -> ModifierDefinition:
	var m := ModifierDefinition.new()
	m.target_tag = tag
	m.operation = op
	m.value = value
	m.source_name = "gearunique_" + source
	return m


## Permanent passive: on kill, heal a % of max HP (mirrors StatusFactory bloodthirst).
static func _on_kill_heal(id: String, pct: float) -> StatusEffectDefinition:
	var def := StatusEffectDefinition.new()
	def.status_id = "gu_" + id
	def.tags = ["Passive", "Heal"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0
	var heal := HealEffect.new()
	heal.percent_max_hp = pct
	var l := TriggerListenerDefinition.new()
	l.event = "on_kill"
	l.target_self = true
	l.conditions = [TriggerConditionSourceIsSelf.new()]
	l.effects = [heal]
	def.trigger_listeners = [l]
	return def


## Permanent passive: on a hit we deal, apply `status` to the victim (mirrors serrated_strikes).
static func _on_hit_apply(status: StatusEffectDefinition, id: String) -> StatusEffectDefinition:
	var def := StatusEffectDefinition.new()
	def.status_id = "gu_" + id
	def.tags = ["Passive"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	var l := TriggerListenerDefinition.new()
	l.event = "on_hit_dealt"
	l.target_self = false
	l.conditions = [TriggerConditionSourceIsSelf.new()]
	l.effects = [apply]
	def.trigger_listeners = [l]
	return def


## Permanent passive: on a crit we deal, apply `status` to the victim.
static func _on_crit_apply(status: StatusEffectDefinition, id: String) -> StatusEffectDefinition:
	var def := StatusEffectDefinition.new()
	def.status_id = "gu_" + id
	def.tags = ["Passive"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = 1
	var l := TriggerListenerDefinition.new()
	l.event = "on_crit"
	l.target_self = false
	l.conditions = [TriggerConditionSourceIsSelf.new()]
	l.effects = [apply]
	def.trigger_listeners = [l]
	return def


## Permanent passive: on a crit we deal, detonate an AoE on the victim (mirrors static_discharge).
static func _on_crit_aoe(dtype: String, dmg: float, radius: float, id: String) -> StatusEffectDefinition:
	var def := StatusEffectDefinition.new()
	def.status_id = "gu_" + id
	def.tags = ["Passive"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0
	var aoe := AreaDamageEffect.new()
	aoe.damage_type = dtype
	aoe.base_damage = dmg
	aoe.aoe_radius = radius
	var l := TriggerListenerDefinition.new()
	l.event = "on_crit"
	l.target_self = false
	l.conditions = [TriggerConditionSourceIsSelf.new()]
	l.effects = [aoe]
	def.trigger_listeners = [l]
	return def


## Permanent passive: on kill, apply a timed self-buff on one stat (mirrors adrenaline_rush).
static func _self_buff_on_kill(id: String, stat: String, value: float, duration: float) -> StatusEffectDefinition:
	var def := StatusEffectDefinition.new()
	def.status_id = "gu_" + id
	def.tags = ["Passive"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0
	var buff := StatusEffectDefinition.new()
	buff.status_id = "gu_" + id + "_burst"
	buff.is_positive = true
	buff.max_stacks = 1
	buff.base_duration = duration
	buff.duration_refresh_mode = "overwrite"
	buff.modifiers = [_stat_mod(stat, "bonus", value, "gu_" + id + "_burst")]
	var apply := ApplyStatusEffectData.new()
	apply.status = buff
	apply.stacks = 1
	apply.apply_to_self = true
	var l := TriggerListenerDefinition.new()
	l.event = "on_kill"
	l.target_self = true
	l.conditions = [TriggerConditionSourceIsSelf.new()]
	l.effects = [apply]
	def.trigger_listeners = [l]
	return def


## Permanent passive: on a hit we deal, add a stacking self-buff on one stat.
static func _on_hit_self_stack(id: String, stat: String, per_stack: float, max_stacks: int, duration: float) -> StatusEffectDefinition:
	var def := StatusEffectDefinition.new()
	def.status_id = "gu_" + id
	def.tags = ["Passive"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0
	var buff := StatusEffectDefinition.new()
	buff.status_id = "gu_" + id + "_stack"
	buff.is_positive = true
	buff.max_stacks = max_stacks
	buff.base_duration = duration
	buff.duration_refresh_mode = "overwrite"
	buff.modifiers = [_stat_mod(stat, "bonus", per_stack, "gu_" + id + "_stack")]
	var apply := ApplyStatusEffectData.new()
	apply.status = buff
	apply.stacks = 1
	apply.apply_to_self = true
	var l := TriggerListenerDefinition.new()
	l.event = "on_hit_dealt"
	l.target_self = true
	l.conditions = [TriggerConditionSourceIsSelf.new()]
	l.effects = [apply]
	def.trigger_listeners = [l]
	return def


## A stackable/timed move-speed slow applied to enemies (mirrors abyssal_slow shape).
static func _slow_status(id: String, pct: float, duration: float) -> StatusEffectDefinition:
	var def := StatusEffectDefinition.new()
	def.status_id = id
	def.tags = ["CC"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = duration
	def.duration_refresh_mode = "overwrite"
	def.modifiers = [_stat_mod("move_speed", "bonus", pct, id)]
	return def


static func _stat_mod(tag: String, op: String, value: float, source: String) -> ModifierDefinition:
	var m := ModifierDefinition.new()
	m.target_tag = tag
	m.operation = op
	m.value = value
	m.source_name = source
	return m
