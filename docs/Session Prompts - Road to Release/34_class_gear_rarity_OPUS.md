# Task 34 — Class gear & rarity system (weapons, trinkets, smart-loot)
**Tier**: 3 → Opus (new loot architecture touching drops, armory, insurance, economy, FX)
**Depends on**: 30 (all 12 classes exist). Blocks 31 (mods attach to this gear). Design locked by Ben — see `docs/design_audit_2026-07-06.md` §3.1 (AUTHORITATIVE; do not re-decide it).

---

<goal>
Implement the "class gear" loot design that resolves audit decision D1: class-locked themed
weapons + 2 universal trinket slots, green/blue/purple rarity, smart-loot drop bias toward the
current class. This makes loot honest (stats that really apply), restores weapon identity
(themed to the class, never a bow on a Barbarian), and engineers the purple jackpot moment.
</goal>

<context>
- Audit §3.1 is the spec. Key facts about today's code: every class runs a combo kit and drops
  weapon auto-fire — the weapon feeds damage/stats into the kit (`player.gd::set_combo_ability`,
  ChainFactory reads WeaponData). WeaponData behavior fields (spread/orbit/artillery/beam) no
  longer execute for players — retire them from player-facing gear (keep only what the kits
  actually consume; check ChainFactory/WeaponFactory for exactly which fields feed in).
- Loadouts are already per-character; the armory equips weapons + mods; workshop has dormant
  Artifact Chamber slot upgrades; insurance values items; blueprints add items to the drop pool.
</context>

<requirements>
DATA (factory pattern, zero behavior in data files):
- Weapon lines: per class, the existing signature weapon becomes the GREEN tier; author one BLUE
  (better stats) and one PURPLE (stats + unique effect) per class, themed to the kit fantasy
  (names/copy in the class's voice). 12 classes × 3 tiers; greens mostly exist already.
- Trinkets: 8–12 universal (class-agnostic) items across the three rarities; 2 equip slots
  (decide with the Workshop: base 2 slots, and repurpose/rename Artifact Chamber upgrades — a
  3rd slot as a workshop purchase is fine; kill the "artifact" naming everywhere it appears).
- Rarity drives: stat budget, mod slots (green 1 / blue 2 / purple 3), and purple's ONE unique
  effect. Uniques are built ONLY from existing machinery (ModifierDefinition stats,
  StatusEffectDefinition + trigger_listeners, established mod effect types) — if a unique needs
  bespoke code, redesign the unique.

DROPS (smart-loot):
- Drop rolls bias toward the current class (~75–80% on-class, constant in one place as a tuning
  lever). Purples: rare overall, ~90% on-class when they do drop. Trinkets roll from the
  universal pool. Rarity weights per depth/phase follow existing loot-scaling conventions.
- Off-class drops are CARGO: extractable and banked to the target character's stash (per-character
  loadouts already exist — verify the armory can hold unequipped gear per character). Roster
  panel gets a small "new gear waiting" badge for characters with unequipped finds.

PRESENTATION (the honesty rules — non-negotiable):
- Item pickup/inspect card: rarity color, ≤3 stat lines + the unique line, readable at 3×
  scaling (CLAUDE.md UI rules; ScrollContainer SHOW_AS_NEEDED where lists grow).
- Weapon damage type tints the combo FX / hit effects so an equipped drop VISIBLY changes the
  attack — verify damage_type actually inherits through each kit's damage path first (some kit
  effects hardcode an element; fix those to read the weapon's type where sensible).
- Rarity colors on drops in the world (pickup glow/label) so the purple moment reads at a glance.

INTEGRATION:
- Insurance valuation understands rarity (a purple is worth insuring — check the pricing).
- Research/blueprints repurpose to activating higher-tier gear into the drop pool.
- Save/load: new gear + stashes with defensive .get() defaults; old saves load clean.
- Mods equip onto the new gear exactly as before (mod slots per rarity) — do NOT redesign mods
  here; task 31 handles the class-mod layer on top of this.

Full-loop verify: debug run → on-class green/blue drops, a forced purple drop (temporary debug
weight, then restore), off-class drop banked to another character's stash + roster badge,
insurance on a purple, FX tint visibly changes with damage type. Ben feel-tests the drop rates.
</requirements>

<output_format>
Data + drop logic + armory/roster/insurance integration + FX tint, grouped conventional commits.
Summary: the full gear table (class × tier + trinkets), the tuning levers (bias %, rarity
weights) with file:line, and Ben's playtest checklist.
</output_format>
