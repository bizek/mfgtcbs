extends Node
## Global event bus. Every combat event flows through here.
## Listeners (abilities, status effects, triggers, mods) register themselves and respond.

# --- Combat events ---
signal on_hit_dealt(source, target, hit_data)
signal on_hit_received(source, target, hit_data)
signal on_kill(killer, victim)
signal on_death(entity)
signal on_heal(source, target, amount: float)
signal on_crit(source, target, hit_data)
signal on_block(source, target, hit_data, mitigated: float)
signal on_dodge(source, target, hit_data)
signal on_overkill(killer, victim, overkill_amount: float)
signal on_consecutive_hit(source, target, count: int)
signal on_first_hit(source, target, hit_data)
signal on_interrupt(source, target)
signal on_reflect(source, target, hit_data)
signal on_absorb(entity, hit_data, absorbed: float)
signal on_friendly_fire(source, target, hit_data)

# --- Status events ---
signal on_status_applied(source, target, status_id: String, stacks: int)
signal on_status_expired(entity, status_id: String)
signal on_status_consumed(entity, status_id: String, stacks: int)
signal on_status_resisted(source, target, status_id: String)
signal on_cleanse(source, target, status_id: String)

# --- Movement events ---
signal on_displacement_resisted(resisted_by, attempted_by)

# --- Ability events ---
signal on_ability_used(source, ability)

# --- Entity events ---
signal on_ally_death(dead_entity, ally)
signal on_ally_hit_received(source, ally, hit_data)
signal on_summon(summoner, summon)
signal on_summon_death(summoner, summon)
signal on_revive(source, target)
signal on_transform(entity, from_state: String, to_state: String)

# --- System events ---
signal on_chain_threshold(chain_length: int, initiating_event: String)
signal on_chain_break(final_length: int, initiating_event: String)
signal on_threshold_cross(entity, stat: String, direction: String)
signal on_echo(source, ability_id: String)
signal on_conversion(source, original_type: String, converted_type: String)
signal on_idle(entity)
signal on_pickup(entity, pickup_type: String)
signal on_doom_trigger(entity)
signal on_proximity_enter(entity_a, entity_b)
signal on_proximity_exit(entity_a, entity_b)

# Chain gating (set by CombatManager at run start, null during hub phase)
var chain_tracker = null
