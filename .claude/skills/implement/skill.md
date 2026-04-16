---
name: implement
description: Start any implementation task. Front-loads the context-read discipline that this engine's interdependent systems require. Use at the start of every coding session before writing any code.
disable-model-invocation: true
argument-hint: [brief description of what to implement]
---

# Implement: $ARGUMENTS

## Before anything: understand what you're extending.

This is a component-based combat engine where all content = data. Effects route through EffectDispatcher, stats through ModifierComponent, events through EventBus, statuses through StatusEffectComponent, targeting through BehaviorComponent. Every system touches every other system. A "simple" status effect interacts with the modifier system, the damage pipeline, ability conditions, trigger listeners, VFX, and potentially projectiles, displacement, and auras.

**Ben does not read code.** He uses Claude Code exclusively. The docs are his only verification layer. If you skip them and build something wrong, it compounds silently.

---

## Step 1: Read the engine reference.

**Always read `docs/engine_reference.md` first.** This is the authoritative reference for all systems, data patterns, unused capabilities, and wiring examples. It tells you what exists, how to extend it, and what's available but unused.

Then read docs based on your task:

| Task | Also read |
|------|-----------|
| Combat / damage / abilities | `docs/core_framework_decisions.md`, `docs/mechanical_vocabulary.md` |
| Enemies / spawning / AI | `docs/systems_design_part2.md`, `docs/mechanical_vocabulary.md` |
| Loot / extraction / instability | `docs/systems_design_part2.md`, `docs/core_framework_decisions.md` |
| Meta-progression / hub | `docs/systems_design_part3.md` |
| Game design questions | `docs/architecture_blueprint.md` (design principles section) |

---

## Step 2: Infrastructure gate — content vs. infrastructure.

**The question: "Am I building a machine, or feeding data into one?"**

### Content (proceed directly to implementation, do NOT present approach):
- New Resource entries following established patterns (new enemy data factory, new status definition, new ability definition)
- New fields on existing Resources + handling in existing components using established patterns (bool flags with counters, lifecycle hook arrays, string filters, numeric thresholds)
- New match arms in existing dispatch tables (EffectDispatcher, BehaviorComponent targeting, trigger conditions)
- Anything where you can point to an existing factory/component that does the same *kind* of thing with different values

The data factory pattern (`static func create() -> Resource`) is established. The effect dispatch pattern (type-switch in EffectDispatcher) is established. The status lifecycle pattern (fields on StatusEffectDefinition + handling in StatusEffectComponent) is established with 20+ fields. The targeting pattern (match arms in BehaviorComponent._resolve_targets_internal) is established with 14+ types.

**"New" does not mean "infrastructure."** A new targeting type is content — add a match arm. A new effect type is content — add an elif branch. A new field on StatusEffectDefinition is content — the pattern of "add field + add handler" has been done 20+ times.

### Infrastructure (present approach to Ben before coding):
- Creating or modifying a fundamental system (how targeting resolution works, how the damage pipeline flows, how the tick order operates)
- Work where no existing pattern in the codebase answers the design question
- Finding two conflicting patterns for the same mechanic — flag to Ben before choosing

**Bias toward content.** The cost of building something slightly wrong and adjusting after Ben tests is far lower than stopping for an approach presentation that didn't need to happen.

---

## Step 3: Read the code you're touching.

### Content path — targeted reads:

**Always read in full:**
- `scripts/entities/enemy.gd` — the animation state machine, hit-frame dispatch, choreography executor, all behavior types. Non-negotiable full read every session.
- The data factory you're extending or copying patterns from

**Spot-check (verify the primitives you need exist):**
- `scripts/systems/effect_dispatcher.gd` — confirm your effect types are dispatched
- `scripts/components/behavior_component.gd` — confirm your targeting types exist
- `scripts/components/ability_component.gd` — confirm your condition types exist
- `scripts/components/status_effect_component.gd` — confirm lifecycle hooks are wired

**Pattern reference (read ONE existing factory that uses similar patterns):**
- Ranged enemies with projectiles → `data/factories/enemies/caster_data.gd`
- Aura effects → `data/factories/enemies/herald_data.gd`
- Status effects with DoT/modifiers → `data/factories/status_factory.gd`
- Weapons → `data/factories/weapon_factory.gd`

### Infrastructure path — full reads:

Read every `.gd` file (skip `addons/`):
```
find . -name "*.gd" ! -path "*/addons/*"
```

Read all design docs listed in the table above. Read full files, not grep snippets.

---

## Step 4: Match existing patterns exactly.

When building something that resembles an existing pattern, find that pattern and match it. Four abilities that do the same type of thing must use the same method. Consistency in how established patterns are called is as important as consistency in the patterns themselves.

- Before writing a new status effect → read an existing similar one in StatusFactory
- Before writing a new ability → read an existing factory with similar targeting/effects
- Before adding a new dispatch path → check how every existing one is structured
- Before extending a Resource with a new field → check how existing fields are consumed

**When no existing pattern fits**, that's infrastructure — flag it.

---

## Step 5: The 300x lens.

This game targets vampire-survivors entity density. Every system must scale to 300 simultaneous entities.

- No O(N^2) hot paths. Use SpatialGrid, not full-array scans.
- No per-frame array allocations in hot paths. `.filter()` creates arrays. Iterate inline.
- `distance_squared_to()` over `distance_to()`.
- Be aware of node count and draw calls per entity.
- EventBus listeners must early-return cheaply when irrelevant.

---

## Step 6: Implement.

On the content path, proceed directly. On the infrastructure path, present approach first, then implement after Ben confirms.

### Guardrails:

**GDScript `:=` rule:** Never use `:=` when the expression involves Resource property access. Always use explicit `var x: float =`.

---

## Step 7: Verify with MCP — constructed scenarios, not organic combat.

**`execute_game_script` runs arbitrary GDScript inside the live game process.** Full access to the scene tree, every node, every component, every method. This is a scenario construction tool, not a state snapshot tool. Use it to build the exact conditions your code needs and call the exact function under test. Don't wait for organic combat to roll the dice.

### Instrumentation first.

Before verifying, bake debug prints into the code you just wrote — aimed at **terminal state**, not intermediate steps. One question: *what does the effect this code ultimately produces look like in the log?* Damage actually dealt, modifier actually applied, status actually expired, trigger actually fired AND its downstream effect resolved.

Design your tag scheme for `get_output_log(filter=...)` efficiency. Short prefix, rich payload. Example: `print("[IMPL_BURN] status applied to %s, stacks=%d" % [entity.name, stack_count])`. A single filter substring should pull exactly the lines you care about.

### The verification loop.

1. `clear_output`
2. `play_scene` (main scene)
3. `execute_game_script` → `Engine.time_scale = 0.0` — freeze game-time so buff durations don't decay between MCP calls and live combat doesn't pollute the state you're reading. Use `0.5` only if your test requires the sim to advance (e.g. a DoT tick). Use `8.0` only as a last resort for organic-combat fallback.
4. **State inspection:** verify your feature's components are wired correctly before constructing scenarios. Find the player (`/root/MainArena/.../Player`), find relevant components (`HealthComponent`, `StatusEffectComponent`, `ModifierComponent`, `TriggerComponent`), confirm listeners are registered and modifiers are in the right state. If the component isn't there, no scenario will exercise it.
5. **Construct the scenario:** force the exact precondition and call the function under test. Strip leftover state first (remove existing statuses, confirm baseline modifier sum), then apply. Each edge case gets its own script — don't test five things in one call.
6. `get_output_log(filter="<your tag>", max_lines=<tight>)` — targeted, never blob-dumped.
7. **Stop after the golden path** unless your code contains a branch the golden path didn't reach — an explicit `if/else`, a dead-source fallback, a recursion guard. If it does, construct one more scenario for that branch. Otherwise stop. Don't test engine primitives, EventBus fan-out, or anything your code doesn't directly produce.
8. `stop_scene`

### Constructed scenario shape for this engine.

```gdscript
# 1. Find live nodes — walk the tree or use known autoload paths
var arena = get_tree().root.get_node_or_null("/root/MainArena")
var player = arena.get_node_or_null("Player") if arena else null

# 2. Find or spawn an enemy to use as source/target
var enemies = get_tree().get_nodes_in_group("enemies")
var target = enemies[0] if enemies.size() > 0 else null

# 3. Build the data resource on the fly from existing factories
var status_def = StatusFactory.create_burn(3)  # or load and instantiate

# 4. Strip leftover state — confirm clean baseline
if target:
	target.status_effect_component.clear_all()
	_mcp_print("[IMPL_TAG] baseline hp: " + str(target.health_component.current_health))

# 5. Force the precondition
target.status_effect_component.apply_status(status_def, player, 1)

# 6. Fire the function under test (or let time advance if timing-dependent)
target.status_effect_component._tick(1.0)

# 7. Read terminal state — your baked-in prints capture the chain
_mcp_print("[IMPL_TAG] result hp: " + str(target.health_component.current_health))
```

The trigger fires, the EventBus signal propagates, EffectDispatcher runs, damage lands — exactly as in organic combat, driven deterministically. No mocks. The thing being tested is the actual production code in the actual production environment.

---

## Step 8: After verification passes — update docs, gentle github reminder.

Write doc changes yourself in the main context. After Ben has also tested (or confirmed the logs look right), update:
- `docs/engine_reference.md` if new systems/capabilities were added
- CLAUDE.md if architecture changed
- Relevant design docs if values changed
- Give Ben a subtle, creative, almost passive-aggressive reminder he probably wants to ask you to commit and push to github now


---

## Post-implementation troubleshooting

### Always fix X, never mask it by fixing Y.

X = the root cause defect. Y = the visible symptom. A defensive handler that silently recovers from X hides X. Fix the actual broken thing.

**The test:** If your fix doesn't make the originally-broken thing work correctly, you're fixing the wrong thing.

### Verify data references against actual assets.

When "nothing happens" or "entity gets stuck," first check that strings in data factories match what actually exists:
- Animation names: read the .tres SpriteFrames file
- Status IDs: grep for the string across apply/consume/check paths
- Ability IDs: grep for references
