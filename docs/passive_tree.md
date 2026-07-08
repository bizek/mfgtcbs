# Passive Skill Tree — Backend API Reference

**Session 26 (backend) complete. Session 28 (hub UI) reads this doc.**

---

## Data File

`data/passive_tree.gd` — `class_name PassiveTreeData`

```gdscript
const NODES: Dictionary        ## 59 nodes, keyed by node_id string
static func nodes_in_branch(branch: String) -> Array   ## node_id strings for one branch
```

Each node dict:

| Key | Type | Notes |
|---|---|---|
| `name` | String | Display name |
| `branch` | String | `"core"` / `"might"` / `"finesse"` / `"arcana"` / `"bridge"` |
| `tier` | int | 0–4; gate threshold = 3×tier ranks in branch |
| `cost` | int | Points per rank: 1 normal, 2 notable, 3 keystone |
| `max_ranks` | int | Total purchasable ranks |
| `desc` | String | Tooltip text |
| `effects` | Array | `[{stat, op, value}]` — absent on behavior-only nodes |
| `behavior` | String | Behavior id (inert until prompt 27) |
| `kind` | String | Absent / `"notable"` / `"keystone"` — for UI styling |
| `bridges` | Array | Bridge nodes only: `[branch_a, branch_b]` |

---

## ProgressionManager API

All passive state lives in `ProgressionManager` (autoload).

### Variables (persisted in `progression.json`)

```gdscript
var passive_points: int           ## unspent points available to allocate
var passive_allocations: Dictionary   ## {node_id: ranks_purchased}
var lifetime_passive_points: int  ## all-time banked points (for stats display)
```

### Methods

```gdscript
func get_passive_points() -> int
func get_node_ranks(node_id: String) -> int
func branch_ranks(branch: String) -> int
    ## total ranks spent in that branch — used for tier gates and bridge gates
func can_allocate(node_id: String) -> bool
    ## checks: points ≥ cost, ranks < max_ranks, tier gate (first rank only)
func allocate(node_id: String) -> bool
    ## spends points, records rank, saves; returns false if can_allocate was false
func refund_all() -> void
    ## returns all spent points, clears all allocations, saves
func bank_passive_points(levels_gained: int) -> void
    ## called internally by record_extraction / record_death
```

### Save keys (added to `progression.json`)

```
"passive_points"          int   (default 0)
"passive_allocations"     dict  (default {})
"lifetime_passive_points" int   (default 0)
```

Old saves load cleanly via `.get(..., default)` guards.

---

## Tier-Gate Rule

- **Core** nodes: always allocatable (tier 0, no gate).
- **Branch** node at tier N: requires `branch_ranks(branch) >= 3 × N`.
  - Tier 0 → free to start (0 ranks required).
  - Tier 1 → 3 ranks in that branch.
  - Tier 2 → 6 ranks. Tier 3 → 9 ranks. Tier 4 keystone → 12 ranks.
- **Bridge** nodes: require `branch_ranks(adj_a) >= 4 OR branch_ranks(adj_b) >= 4`.
- **Rank 2+** on any already-purchased node: only points are re-checked (no tier re-gate).

---

## How to Render a Node's State (5-line recipe)

```gdscript
var ranks: int     = ProgressionManager.get_node_ranks(node_id)
var max_r: int     = PassiveTreeData.NODES[node_id].get("max_ranks", 1)
var can_buy: bool  = ProgressionManager.can_allocate(node_id)
var is_maxed: bool = ranks >= max_r
var is_locked: bool = not is_maxed and not can_buy
## States: is_maxed → gold/filled; is_locked → grey/dim; else → available (highlight if affordable)
```

---

## Run-Start Application (`player.gd`)

`_apply_passive_tree()` is called in `_ready()` after `_apply_passive_mods()`.  
It iterates `ProgressionManager.passive_allocations` and handles each node:
- **Stat nodes** (`effects` key): add `ModifierDefinition`s (source `"passive_tree"`) × ranks to `modifier_component`.
- **Behavior nodes** (`behavior` key): call `PassiveTreeFactory.build(behavior_id)` and apply the returned `StatusEffectDefinition` as a hidden permanent status.
- **Keystone flags** (`"slipstream"`, `"berserkers_cadence"`): set `_has_slipstream_keystone` / `_has_berserkers_cadence_keystone` flags on the player (no hidden status; player code hooks these directly).

After all allocations, `health.setup(get_stat("max_hp"))` re-syncs the HP bar.

---

## XP Gain Hook

In `player.gd::add_xp()`:
```gdscript
var xp_mult: float = 1.0 + modifier_component.sum_modifiers("xp_gain", "bonus")
xp += amount * xp_mult
```
Enables `c_greed`, `a_scholar`, `a_sage`.

---

## Combo-Kit Projectile Audit

**Nodes audited:** `f_split_shot` (projectile_count), `f_fletcher` (pierce), `a_broad_bolts` / `a_elementalist` / `b_spellblade` (projectile_size).

**Finding:** Auto-attack projectiles (`_on_auto_attack`) already synced live stats.
Combo-kit projectiles fired through `choreo_fire_effects()` did **not** inherit player
stats — the ChainFactory SpawnProjectilesEffect objects had fixed values.

**Fix applied (session 26):** Before dispatching `proj_effects` in `choreo_fire_effects()`,
each `SpawnProjectilesEffect` is deep-duplicated and overwritten with live stats:
- `count = get_stat("projectile_count")`
- `pierce_count += get_stat("pierce")` (−1 pierce-all is preserved)
- `visual_scale *= get_stat("projectile_size")`
- `hit_radius *= get_stat("projectile_size")`

The original phase-data resources are never mutated; duplicates are fire-and-forget.
All five nodes (`f_split_shot`, `f_fletcher`, `a_broad_bolts`, `a_elementalist`, `b_spellblade`) are live for both auto-attack and combo-kit characters.

**`melee_range` / dash stats:** Already `get_stat()`-driven throughout player.gd — no extra wiring needed.

---

## Modifier Tag Reference

| Spec phrase | `target_tag` | `operation` |
|---|---|---|
| `+N% damage` | `"All"` | `"bonus"` |
| `+N max_hp` | `"max_hp"` | `"add"` |
| `+N armor` | `"Physical"` | `"resist"` |
| `+N% attack_speed` | `"attack_speed"` | `"bonus"` |
| `+N% crit_chance` (decimal) | `"crit_chance"` | `"add"` |
| `+N% crit_multiplier` | `"crit_multiplier"` | `"bonus"` |
| `+N% move_speed` | `"move_speed"` | `"bonus"` |
| `+N% pickup_radius` | `"pickup_radius"` | `"bonus"` |
| `+N% melee_range` | `"melee_range"` | `"bonus"` |
| `+1 projectile_count` | `"projectile_count"` | `"add"` |
| `+N pierce` | `"pierce"` | `"add"` |
| `+N% projectile_size` | `"projectile_size"` | `"bonus"` |
| `+N% dash_speed` | `"dash_speed"` | `"bonus"` |
| `−N% dash_cooldown` | `"dash_cooldown"` | `"bonus"` (negative) |
| `+1 dash_charges` | `"dash_charges"` | `"add"` |
| `−N% all damage_taken` | `"All"` | `"damage_taken"` (negative) |
| `+N% dodge_chance` | `"dodge_chance"` | `"add"` |
| `+N% XP gain` | `"xp_gain"` | `"bonus"` |
| `+N% lifesteal` | `"leech"` | `"bonus"` |
| `+N% block_chance` | `"block_chance"` | `"add"` |
| `+N% block_mitigation` | `"block_mitigation"` | `"add"` |
| `+N Fire/Cold/Lightning resist` | `"Fire"` / `"Cold"` / `"Lightning"` | `"resist"` |
| `+N% status duration` | `"status_duration"` | `"bonus"` |

---

## Behavior Nodes (Session 27)

All behavior nodes are implemented via `data/factories/passive_tree_factory.gd`.

### Infrastructure additions (session 27)

| Change | File | What it does |
|---|---|---|
| `chance: float` on TriggerListenerDefinition | `data/resources/triggers/trigger_listener_definition.gd` | Probabilistic firing (0.0–1.0) |
| `internal_cooldown: float` on TriggerListenerDefinition | same | Seconds between firings |
| `last_fired_time` on `ActiveListener` | `trigger_component.gd` | Tracks ICD per listener |
| `TriggerConditionTargetHasAnyStatus` | `data/resources/triggers/…` | Passes when target has ≥1 active status |
| `has_any_active_status()` | `status_effect_component.gd` | Returns true if entity has any status |
| Catalyst scaling in `ApplyStatusEffectData` block | `effect_dispatcher.gd` | Reads `"status_duration"/"bonus"` from source |

### Trigger-based behavior nodes

| Node | behavior id | Status id | Mechanic |
|---|---|---|---|
| m_bloodletter | `"bloodletter"` | `passive_bloodletter` | `on_kill`, 10% chance, heal 2 HP flat |
| m_second_wind | `"second_wind"` | `passive_second_wind` | `on_hit_received`, below 30% HP, apply `tree_second_wind_burst` (+25% move_speed 2s), ICD 8s |
| f_opportunist | `"opportunist"` | `passive_opportunist` | `on_dodge`, apply `opportunist_burst` (+20% damage 2s) |
| a_ignition | `"ignition"` | `passive_ignition` | `on_crit`, apply `StatusFactory.burning` to the target |
| a_keystone (Volatile Souls) | `"volatile_souls"` | `passive_volatile_souls` | `on_kill`, victim has any status, 25% chance, 60px Physical AoE (base 8 damage, scales with player mods) |

### Keystone hooks (direct player.gd code, flag-gated)

| Node | behavior id | Flag | Buff applied | Trigger point |
|---|---|---|---|---|
| f_keystone (Slipstream) | `"slipstream"` | `_has_slipstream_keystone` | `slipstream` (+30% attack_speed, +15% damage, 2.5s) | `_on_dash_started()` — called from both standard dash and teleport dash paths |
| m_keystone (Berserker's Cadence) | `"berserkers_cadence"` | `_has_berserkers_cadence_keystone` | `frenzy` (+25% attack_speed, +15% move_speed, 3s) | `choreo_on_finisher_hit()` — all 10 kits already mark finisher phases via `ChoreographyPhase.is_finisher`; channel finishers gated by 3s ICD via `_berserkers_cadence_last_trigger` |

### a_siphon — moved to stat path

`a_siphon` has no `behavior` key in `PassiveTreeData.NODES` — it was already wired as `effects: [{stat: "leech", op: "bonus", value: 0.015}]` in session 26. The lifesteal modifier tag (`"leech"/"bonus"`) matches what ModComboFactory and EffectDispatcher use. No factory entry needed.

### a_catalyst — IMPLEMENTED (stat path)

Catalyst does NOT use a hidden status. `a_catalyst` node has `effects: [{stat: "status_duration", op: "bonus", value: 0.20}]`. The player gains a `"status_duration"/"bonus"/0.20` modifier. In `effect_dispatcher.gd`'s `ApplyStatusEffectData` block, when the source has a non-zero `status_duration` bonus, the applied duration is scaled up accordingly. This covers all status applications routed through `EffectDispatcher` (the entire engine pipeline). Permanent statuses (`base_duration = -1`) are unaffected.
