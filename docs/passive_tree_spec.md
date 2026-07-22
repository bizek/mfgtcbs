# Passive Skill Tree — Design Spec

**Status:** Designed 2026-07-01 (Ben + Fable session). Updated 2026-07-06 for the 10-character
combo-kit roster (affinities, generalized Might keystone, combo-projectile stat audit).
Supersedes the passive-tree sketch in
`docs/Archived Session Prompts - Completed/deliberate-pacing-dash-passive-tree.md` (Tasks 4.1/4.2).
Implementation prompts: `docs/Session Prompts - Road to Release/26–28_passive_tree_*.md`.

> **Implemented — this is no longer a forward-looking spec.** The backend, the 59-node table, the
> gate rules and the hub panel all shipped (prompts 26–28). The deliberate-pacing roadmap is complete.
> For the live data contract read `docs/passive_tree.md` and `data/passive_tree.gd`; this doc holds the
> design intent. Note it was written against a **10**-character roster and predates the Verdant and
> Devout; affinity assignments for those two live in code, not here. (Reconciled 2026-07-21.)

Originally the last unbuilt piece of the deliberate-pacing roadmap (Phases 1–3: rebalance,
dash, level-up mobility routes — see `docs/pacing_rebalance.md`, `docs/dash.md`).

---

## 1. Design Decisions (locked with Ben)

| Decision | Choice |
|---|---|
| Topology | **Core + 3 archetype branches** — Might (melee/tank), Finesse (ranged/mobility/crit), Arcana (magic/status/utility). Any class can path anywhere; classes *lean* toward a branch. |
| Node flavor | **Stats + behavior nodes** — mostly stat nodes, notables mid-branch, one build-defining **keystone** per branch. |
| Size | **~59 nodes** (11 core + 15×3 branches + 3 bridges), most multi-rank. |
| Points | **1 passive point per character level gained during a run** (level − 1 at run end), banked on **both extraction and death**. The tree is the "you always progress" pillar; resources stay the extraction-gated pillar. |
| Respec | **Free** `refund_all()` for now (tuning lever later). |
| Gating | **Branch-investment tiers**, not per-node adjacency (see §3). |
| Effects | All stat nodes = `ModifierDefinition`s applied to the player's `ModifierComponent` at run start, after character base + passive so percentages stack correctly. Behavior nodes = hidden permanent `StatusEffectDefinition` with `trigger_listeners` (established TriggerComponent pattern), plus 2 small player.gd hooks (§6). |

### Class → branch affinity (flavor only, no mechanical lock)
*(Updated 2026-07-07 for the full 12-character roster — see `data/characters.gd`; Verdant/Devout
now shipped, 4 classes per branch.)*

- **Might** — Sellsword (Fighter) · Warden (Paladin) · Ravager (Barbarian) · Devout (Cleric)
- **Finesse** — Scavenger (Ranger) · Shade (Rogue) · Whisper (Ninja) · Deadeye (Gunslinger)
- **Arcana** — Spark (Wizard) · Herald (Bard) · Cursed (Blood Mage) · Verdant (Druid)

The hub UI may show the selected character's affinity as a subtle highlight; nothing is gated by class.

---

## 2. Points Economy

- On run end, bank `max(player.level - 1, 0)` passive points via ProgressionManager.
  Wire as a new parameter on `record_extraction(...)` / `record_death(...)` (defaulted `0` so
  existing call sites don't break); callers pass the player's final level.
- Persisted: `passive_points: int` (unspent), `passive_allocations: Dictionary {node_id: ranks}`,
  `lifetime_passive_points: int` (for stats display).
- A decent run is 8–15 levels → full-clearing the tree (~110 points) is a long-haul goal, ~10–15
  runs gets a full branch + core. That's the intended pacing.
- **Tuning lever (not v1):** if death-banking makes extraction feel pointless, reduce death
  banking to 50%. Ship at 100% first.

---

## 3. Gating Model

**Branch-investment tiers** instead of per-node prerequisite graphs:

- Every node has a `branch` (`core`/`might`/`finesse`/`arcana`/`bridge`) and a `tier` (0–4).
- **Core** nodes: always allocatable (tier 0).
- **Branch** node at tier N is allocatable when **total ranks spent in that branch ≥ 3×N**.
  (Tier 0 entries: free to start; tier 4 keystone: needs 12 ranks in the branch.)
- **Bridge** nodes: allocatable when the player has ≥4 ranks in *either* of its two branches.
- Multi-rank nodes: buying rank 2+ needs no re-check beyond points.

Why: authoring/balancing 59 adjacency lists is the expensive part of PoE-style webs and adds
little at this scale. Tier gating gives the same "commit to a direction" feel, and the UI still
renders as a connected tree (tier rows with connector lines). If Ben later wants true adjacency,
`links` can be added per-node without breaking saves (allocations are by node_id).

**Costs:** normal node = 1 point/rank · notable = 2 points/rank · keystone = 3 points.

---

## 4. The Tree (v1 node list)

Values are deliberately modest — these are *permanent* and stack multiplicatively with in-run
level-up upgrades. All stat keys below exist in `player.gd::_base_stats` or resolve through
`ModifierComponent`/DamageCalculator today, except the two hooks in §6.

Operation column: `bonus` = percent modifier, `add` = flat. Stat names are the exact
`ModifierDefinition` target tags.

> **Combo-kit audit (added 2026-07-06):** every character now runs a combo kit and drops weapon
> auto-fire (`player.gd` `set_combo_ability` — "the combo IS the attack"). During prompt 26,
> verify that `projectile_count`, `pierce`, and `projectile_size` nodes (f_split_shot, f_fletcher,
> a_broad_bolts, a_elementalist, b_spellblade) actually affect combo-fired projectiles
> (arrows/shurikens/fireballs routed through ChainFactory → EffectDispatcher). If a stat is dead
> under combos, either wire it through the combo projectile path or swap the node's stat for a
> live one — do not ship dead nodes.

### Core (11 nodes, tier 0, always available)

| id | Name | Effect per rank | Ranks |
|---|---|---|---|
| c_vigor | Vigor | +12 max_hp (add) | 3 |
| c_power | Power | +5% damage | 3 |
| c_haste | Haste | +4% attack_speed | 3 |
| c_swift | Swiftness | +3% move_speed | 3 |
| c_magnet | Magnetism | +12% pickup_radius | 2 |
| c_fortune | Fortune | +2% crit_chance (add 0.02) | 2 |
| c_bulwark | Bulwark | +6 armor (Physical resist, add) | 2 |
| c_resolve | Resolve | −3% All damage_taken | 2 |
| c_reflex | Reflex | −6% dash_cooldown | 2 |
| c_evasion | Evasion | +1.5% dodge_chance (add 0.015) | 2 |
| c_greed | Greed | +8% XP gain *(hook §6.1)* | 2 |

### Might (melee / tank) — 15 nodes

| id | Name | Effect per rank | Ranks | Tier |
|---|---|---|---|---|
| m_heavy_hands | Heavy Hands | +6% damage | 3 | 0 |
| m_reach | Reach | +8% melee_range | 3 | 0 |
| m_thick_hide | Thick Hide | +8 armor (add) | 2 | 1 |
| m_bloodied_fists | Bloodied Fists | +15 max_hp (add) | 2 | 1 |
| m_battle_rhythm | Battle Rhythm | +4% attack_speed | 2 | 1 |
| m_crusher | Crusher | +12% crit_multiplier | 2 | 2 |
| m_juggernaut | Juggernaut | −4% All damage_taken | 2 | 2 |
| m_unstoppable | Unstoppable | +8% dash_speed | 2 | 2 |
| m_colossus | **Colossus** (notable) | +10% melee_range AND +15 max_hp | 2 | 2 |
| m_bloodletter | **Bloodletter** (notable) | on_kill: 10% chance heal 2 HP *(trigger)* | 1 | 3 |
| m_iron_wall | **Iron Wall** (notable) | +4% block_chance AND +10% block_mitigation (add) | 2 | 3 |
| m_warlord | **Warlord** (notable) | +8% damage AND +8% crit_multiplier | 2 | 3 |
| m_titan_grip | Titan Grip | +6% damage | 2 | 3 |
| m_second_wind | **Second Wind** (notable) | on_hit_received while below 30% HP: +25% move_speed for 2s (internal cooldown 8s) *(trigger)* | 1 | 3 |
| m_keystone | **KEYSTONE — Berserker's Cadence** | Completing any combo **finisher** (per-kit — every class kit marks its finisher/channel phases, see §6.2; channel ticks count once per 3s) grants **Frenzy**: +25% attack_speed, +15% move_speed for 3s *(hook §6.2)* | 1 | 4 |

### Finesse (ranged / mobility / crit) — 15 nodes

| id | Name | Effect per rank | Ranks | Tier |
|---|---|---|---|---|
| f_deadeye | Deadeye | +2% crit_chance (add 0.02) | 3 | 0 |
| f_lightfoot | Lightfoot | +4% move_speed | 3 | 0 |
| f_sharpened | Sharpened Edges | +10% crit_multiplier | 2 | 1 |
| f_quickdraw | Quickdraw | +5% attack_speed | 2 | 1 |
| f_acrobat | Acrobat | −8% dash_cooldown | 2 | 1 |
| f_long_stride | Long Stride | +8% dash_speed | 2 | 2 |
| f_evasion | Uncanny Evasion | +2% dodge_chance (add 0.02) | 2 | 2 |
| f_windrunner | Windrunner | +3% move_speed AND +4% dash_speed | 2 | 2 |
| f_fletcher | **Fletcher** (notable) | +1 pierce (add) | 2 | 2 |
| f_hunters_eye | **Hunter's Eye** (notable) | +3% crit_chance AND +15% crit_multiplier | 1 | 3 |
| f_opportunist | **Opportunist** (notable) | on_dodge: +20% damage for 2s *(trigger)* | 1 | 3 |
| f_precision | Precision | +2% crit_chance (add 0.02) | 2 | 3 |
| f_ghost | **Ghost** (notable) | +1 dash_charges (add) | 1 | 3 |
| f_split_shot | **Split Shot** (notable) | +1 projectile_count (add) | 1 | 3 |
| f_keystone | **KEYSTONE — Slipstream** | Dashing grants **Slipstream**: +30% attack_speed, +15% damage for 2.5s *(hook §6.2)* | 1 | 4 |

### Arcana (magic / status / utility) — 15 nodes

| id | Name | Effect per rank | Ranks | Tier |
|---|---|---|---|---|
| a_attunement | Attunement | +5% damage | 3 | 0 |
| a_broad_bolts | Broad Bolts | +10% projectile_size | 3 | 0 |
| a_focus | Focus | +4% attack_speed | 2 | 1 |
| a_leyline | Leyline | +10% pickup_radius | 2 | 1 |
| a_scholar | Scholar | +10% XP gain *(hook §6.1)* | 2 | 1 |
| a_wards | Elemental Wards | +8 Fire, Cold, Lightning resist (3 add-modifiers/rank) | 2 | 2 |
| a_barrier | Barrier | +3% block_chance (add) | 2 | 2 |
| a_conduit | Conduit | +4% attack_speed AND +4% damage | 2 | 2 |
| a_elementalist | **Elementalist** (notable) | +6% damage AND +8% projectile_size | 2 | 2 |
| a_siphon | **Siphon** (notable) | +1.5% lifesteal *(reuse the mod system's lifesteal modifier tag — verify exact tag in player.gd ~line 310 / ModFactory before authoring)* | 2 | 3 |
| a_ignition | **Ignition** (notable) | on_crit: apply Burn to the target *(trigger; reuse StatusFactory burn from the mod system)* | 1 | 3 |
| a_sage | Sage | +8% XP gain AND +8% pickup_radius | 2 | 3 |
| a_catalyst | **Catalyst** (notable) | Statuses you apply last +20% longer *(hook — implement ONLY if EffectDispatcher's apply-status path can cleanly read a "status_duration" modifier from the source; otherwise defer to v1.1 and leave the node out)* | 1 | 3 |
| a_runeward | Runeward | −3% All damage_taken | 2 | 3 |
| a_keystone | **KEYSTONE — Volatile Souls** | Enemies you kill while afflicted by any status have a 25% chance to explode (small AoE, ~40% weapon damage) *(trigger on_kill + victim-has-status condition; REUSE the explosive-mod AoE path from ModComboFactory — do not build a new explosion)* | 1 | 4 |

### Bridges (3 nodes — allocatable at ≥4 ranks in either adjacent branch)

| id | Name | Between | Effect per rank | Ranks |
|---|---|---|---|---|
| b_warpath | Warpath | Might↔Finesse | +3% move_speed AND +3% damage | 2 |
| b_spellblade | Spellblade | Might↔Arcana | +4% melee_range AND +4% projectile_size | 2 |
| b_trickster | Trickster | Finesse↔Arcana | +2% crit_chance (add 0.02) AND +4% attack_speed | 2 |

**Totals:** 59 nodes, ~110 points to full-clear.

---

## 5. Architecture

### 5.1 Data — `data/passive_tree.gd` (`class_name PassiveTreeData`)
Static dictionary data, matching `characters.gd` / `WeaponData.ALL` style. Zero behavior.

```gdscript
const NODES: Dictionary = {
    "c_vigor": {
        "name": "Vigor", "branch": "core", "tier": 0,
        "desc": "+12 Max HP", "cost": 1, "max_ranks": 3,
        "effects": [{"stat": "max_hp", "op": "add", "value": 12.0}],
    },
    "m_keystone": {
        "name": "Berserker's Cadence", "branch": "might", "tier": 4,
        "desc": "Melee finishers grant Frenzy: +25% ATK SPD, +15% MOVE SPD (3s)",
        "cost": 3, "max_ranks": 1, "kind": "keystone",
        "behavior": "berserkers_cadence",   ## resolved by PassiveTreeFactory
    },
    ...
}
```

- `effects` (stat nodes): list of `{stat, op ("add"/"bonus"), value}` → built into
  `ModifierDefinition`s. Multi-effect nodes = multiple entries. `value` × ranks at build time.
- `behavior` (behavior nodes): string id resolved by a `PassiveTreeFactory` that returns either a
  `StatusEffectDefinition` (hidden, permanent, `trigger_listeners` populated) or is handled by a
  named player hook (§6.2). Notables with pure stats use `effects` like normal nodes.
- `kind`: absent = normal, `"notable"`, `"keystone"` (UI styling + cost conventions).

### 5.2 ProgressionManager API (backend, prompt 26)
```gdscript
var passive_points: int
var passive_allocations: Dictionary   ## {node_id: ranks}
var lifetime_passive_points: int

func get_passive_points() -> int
func get_node_ranks(node_id: String) -> int
func branch_ranks(branch: String) -> int          ## total ranks spent in a branch
func can_allocate(node_id: String) -> bool        ## points ≥ cost, ranks < max, tier gate (§3)
func allocate(node_id: String) -> bool            ## spend, record, save; returns success
func refund_all() -> void                         ## return every spent point, clear allocations, save
func bank_passive_points(levels_gained: int) -> void   ## called by record_extraction/record_death
```
Save/load: follow the existing `save_data()`/`load_data()` style exactly — defensive `.get()`
defaults so old saves load clean (CLAUDE.md rule).

### 5.3 Apply at run start (player.gd)
`_apply_passive_tree()` called immediately after `_load_character_stats()` (after
`CharacterFactory.build_base_modifiers` so percent stacking order is: base → character passive →
tree). For each allocation: stat effects → `ModifierDefinition`s into `modifier_component`;
behavior nodes → hidden permanent status via the normal status-apply path (TriggerComponent
registration comes free). Dash/melee stats already resolve via `get_stat()` so those nodes work
with zero extra wiring.

### 5.4 Hub UI (prompt 28)
New hub panel following `hub_panel_base.gd` siblings. Requirements:
- Points balance prominent; branch layout: Core center/top, three branch columns (Might /
  Finesse / Arcana) rendered as tier rows with connector lines; bridges between columns.
- Node states: **available / affordable**, **locked (tier gate — show "requires N points in
  Branch")**, **maxed**. Notables/keystones visually distinct (size/border).
- Click → `allocate()` → live refresh of points + all node states. Respec button → `refund_all()`.
- Optional flavor: subtle highlight on the selected character's affinity branch.
- 640×360 @ 3× scaling; ScrollContainer SHOW_AS_NEEDED (the tree WILL overflow); Godot MCP tools
  only for scene edits; check hub font sizes and match.

---

## 6. Required Hooks (small, enumerated — everything else is pure data)

### 6.1 `xp_gain` stat (prompt 26)
Where the player gains XP (player.gd XP path), multiply by
`1.0 + modifier_component.sum_modifiers("xp_gain", "bonus")`. One-line hook; enables c_greed,
a_scholar, a_sage.

### 6.2 Keystone hooks (prompt 27)
- **Slipstream**: in the dash-start block in player.gd, if the player has the keystone (checked
  via a flag set during `_apply_passive_tree()`), apply the Slipstream status
  (StatusEffectDefinition with the two modifiers, 2.5s). No `on_dash` trigger exists — direct
  apply is the clean path.
- **Berserker's Cadence**: in the combo runner's finisher-completion path, same flag-gated status
  apply. **Do NOT hardcode Fighter phase names** (Tempest/Cataclysm/Taunt) — all 10 kits have their
  own finishers. Instead, mark finisher phases in the kit data (an `is_finisher` flag on the
  `ChoreographyPhase` or a per-kit finisher list in ChainFactory) and fire the keystone from the
  generic phase-completion path in `choreography_runner.gd`/player combo wiring. Channel-loop
  finishers (Taunt-style held phases) count once per 3s internal cooldown.
- **Bloodletter / Second Wind / Opportunist / Ignition / Volatile Souls**: pure
  TriggerListenerDefinition data on hidden statuses — no player.gd edits. Verify each trigger's
  chance/condition fields against `trigger_component.gd` before authoring; Volatile Souls reuses
  the ModComboFactory explosion effect.

### 6.3 Deferred unless clean (prompt 27, optional)
- **Catalyst** (status_duration modifier read at apply time) — only if EffectDispatcher's
  apply-status path makes this a ≤5-line change; otherwise drop the node from v1 data.

---

## 7. Implementation Order

1. **Prompt 26 (Sonnet)** — data file (all 59 nodes; behavior nodes present but inert), points
   economy, save/load, tier gating, run-start stat application, xp_gain hook, `docs/passive_tree.md`
   API doc. Tree is fully playable with stat nodes only after this.
2. **Prompt 27 (Opus)** — behavior nodes: PassiveTreeFactory statuses + trigger listeners, the two
   keystone hooks, Catalyst go/no-go. Depends on 26.
3. **Prompt 28 (Opus)** — hub UI panel. Depends on 26 (API), benefits from 27 (keystone display).

Balance pass after Ben plays with a few branches — values in §4 are first-guess conservative.
