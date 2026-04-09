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

**No self-verification via MCP.** Don't use play_scene/screenshot tools. Ben will test.

---

## Step 7: After implementation — stop and let Ben test.

State what was built and what to look for. Then stop. Do NOT:
- Use MCP tools to self-verify
- Update documentation
- Suggest next steps

Wait for Ben to test and report back.

---

## Step 8: After Ben confirms — update docs, gentle github reminder.

Write doc changes yourself in the main context. Update:
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
