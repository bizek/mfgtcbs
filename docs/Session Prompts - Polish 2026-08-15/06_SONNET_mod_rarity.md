# Task 06: Mod rarity — restore it or retire it

> **Tier:** 2 → Sonnet-class · **Depends on:** 01 committed; Ben's gate D-C — this prompt has two
> mutually exclusive branches. Ben's decision on plan §2.3 picks ONE. Do not run without it.
> **Est. tokens:** ~1.5k in / ~3k out · Paste everything below the rule into a fresh session,
> with Ben's decision filled into the first line.

---

**BEN'S DECISION: [ A — restore rarity | B — retire the pills ]**

<goal>
Since the mod rework (class-locked, 8-deep hand-picked pools), the merchant charges one flat
`MOD_PRICE` for every mod and loot rarity no longer influences drops — but the rarity pills on
the haul manifest (landed in `54cfd02`) still display a distinction the economy no longer makes.
Resolve the contradiction in the direction Ben chose.
</goal>

<context>
- Claim provenance: `polish_plan_2026-08-08.md` §2.3, carried unverified into the 2026-08-15
  plan. **Verify it first**: read the merchant's mod pricing and the mod drop roll. If rarity
  already does something again, stop and report — the premise died.
- The mod system's current shape: `docs/class_mod_system.md` (read the doc-audit caveat — verify
  against source), `docs/mod_levelup_rework_plan.md` §"Still open", `ClassModData` /
  `ClassModFactory` in `data/factories/`.
- Ben's direction note (2026-07-21): the mod system gets a fresh pass eventually. Whichever
  branch runs, keep the change SMALL — this is polish, not the fresh pass.
</context>

<requirements>
**Branch A — restore rarity (drop weight + price):**
- Rarity tiers already exist on the data (the pills render from something — find the field).
  Wire them into: merchant price (rarity-scaled multipliers on `MOD_PRICE`) and drop selection
  (weighted roll within the class pool, common-heavy).
- Numbers are first-pass: 1×/2×/4× price and 60/30/10 weights unless the data's tier names
  suggest otherwise. State them clearly in the report for Ben's tuning pass.
- Verify in the Training Room via the mod bench (`e88481e`) and a merchant visit in a controlled
  descent if needed. Back up `progression.json` first; restore after.

**Branch B — retire the pills:**
- Remove the rarity display from the haul manifest and anywhere else it renders for mods; keep
  rarity rendering for non-mod loot if any uses it.
- Grep for the pill's render path first — remove display, not data. Do not delete rarity fields
  from mod data; a future fresh pass may want them.

Both branches: one conventional commit; update `docs/polish_plan_2026-08-15.md` §2.3 with the
decision and outcome, plus the 00_EXECUTION_PLAN status table.
</requirements>

<output_format>
The commit plus a short report: premise verification result, branch executed, numbers chosen (A)
or surfaces cleaned (B), and what was deliberately left for the future mod pass.
</output_format>
