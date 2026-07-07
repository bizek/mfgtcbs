# 27 — Passive Tree Behavior Nodes (notables + keystones)

**Tier:** 3 → Opus-class (cross-system: triggers, statuses, combo runner, dash)
**Depends on:** 26 (backend + data file must exist)
**Blocks:** nothing hard; 28 benefits (keystone display)

```
You are working in a Godot 4.6.1 GDScript survivor/extraction game (Extraction Survivors,
E:\Projects\extraction-survivors). Read CLAUDE.md, then docs/passive_tree_spec.md §4 + §6
(authoritative design), then docs/passive_tree.md (backend API from the previous session), then
docs/engine_reference.md sections on the Trigger System and Status Effects.

GOAL: Make the passive tree's behavior nodes WORK. The data entries and allocation already
exist (previous session); they are currently inert. Wire each per spec §6.

THE PATTERN (use it, don't invent one): reactive effects in this engine are
TriggerListenerDefinitions on a StatusEffectDefinition's trigger_listeners, applied as a hidden
permanent status — TriggerComponent handles EventBus wiring automatically. Build a
PassiveTreeFactory (data/factories/passive_tree_factory.gd) that maps each "behavior" id to its
StatusEffectDefinition, mirroring how StatusFactory/ModFactory build theirs. In player.gd's
_apply_passive_tree(), apply these hidden statuses for allocated behavior nodes.

NODES TO WIRE (verify each trigger's fields against scripts/components/trigger_component.gd
before authoring — chance, conditions, internal cooldowns):
- m_bloodletter — on_kill, 10% chance, heal 2 HP (HealEffect via EffectDispatcher).
- m_second_wind — on_hit_received, condition: self below 30% HP, apply +25% move_speed status
  2s, internal cooldown 8s (use the trigger ICD field if one exists; otherwise the status's own
  non-stacking refresh rules).
- f_opportunist — on_dodge, apply +20% damage status 2s.
- a_ignition — on_crit, apply Burn to the target (REUSE StatusFactory's burn from the mod
  system — do not define a second burn).
- a_siphon — pure modifier: find the exact lifesteal modifier tag the mod system uses
  (player.gd ~line 310 / ModFactory) and emit the same tag from the node's effects. If it turns
  out to be a plain stat modifier, move this node to the stat path and note it.
- a_keystone Volatile Souls — on_kill, condition: victim has any status, 25% chance, small AoE
  explosion ~40% weapon damage. REUSE the explosive-mod AoE effect from ModComboFactory/the mod
  system; do not build a new explosion pipeline.
- KEYSTONE HOOKS (flag-gated direct code, spec §6.2 — no on_dash trigger exists):
  - f_keystone Slipstream: in player.gd's dash-start block, if the keystone flag is set (set
    the flag in _apply_passive_tree()), apply the Slipstream status (+30% attack_speed, +15%
    damage, 2.5s).
  - m_keystone Berserker's Cadence: fires on completing ANY kit's combo finisher — all 10
    classes have combo kits now, so DO NOT hardcode Fighter phase names (Tempest/Cataclysm/
    Taunt). Mark finisher phases in the kit data (an is_finisher flag on ChoreographyPhase, or
    a per-kit finisher list in ChainFactory) and hook the generic phase-completion path in
    scripts/components/choreography_runner.gd + player.gd's combo wiring. Channel-loop
    finishers (Taunt-style held phases) count once per 3s internal cooldown. Flag-gated apply
    of Frenzy (+25% attack_speed, +15% move_speed, 3s).
- a_catalyst (GO/NO-GO): statuses you apply last +20% longer. Implement ONLY if the
  EffectDispatcher apply-status path can read a "status_duration" bonus from the SOURCE's
  modifiers in ≤~5 clean lines. If not, REMOVE the node from PassiveTreeData and note it in
  docs/passive_tree.md as deferred — do not force it.

CONSTRAINTS:
- Typed GDScript; never := on untyped array access. New statuses must defensively handle
  missing keys on existing status entries (CLAUDE.md rule). Watch for cooldown_base=0.0
  effects firing on the player immediately (CLAUDE.md rule).
- Buff statuses here must NOT stack infinitely — refresh duration on reapply.
- Route all effects through EffectDispatcher; no bespoke damage/heal code.

DELIVERABLES: PassiveTreeFactory, the trigger/status wiring, the two keystone hooks,
validate-compiled. Update docs/passive_tree.md (behavior node section: what each does
mechanically + the Catalyst decision). Summarize and ask Ben to playtest each behavior node in
Godot with debug mode (F1-F5) — list a quick test recipe per node (e.g. "allocate f_opportunist,
stack c_evasion, get hit until a dodge procs, watch for the damage buff").
```
