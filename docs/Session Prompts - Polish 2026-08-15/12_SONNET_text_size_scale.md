# Task 12: Make TEXT_SIZE_SCALE mean something game-wide

> **Tier:** 2 → Sonnet-class · **Depends on:** 01 committed · No decision gate, but **do not run
> concurrently with 05/06/07** (broad UI file overlap).
> **Est. tokens:** ~2k in / ~4k out · Paste everything below the rule into a fresh session.

---

<goal>
The accessibility text-size setting is nearly a placebo: only 8 of 151 font sites route through
`Settings.scaled_font_size()` (`hud.gd`, `first_run_overlay.gd`); everything else hardcodes 16 or
32. Route every player-facing site through the scaler so LARGE actually enlarges the game's text.
</goal>

<context>
- The font law (CLAUDE.md, hard-won): m5x7 is 16px-native — only 16 and its integer multiples
  are crisp; below 16 glyphs FUSE. `Settings.snap_font_size()` already enforces this: scaled
  sizes snap to the nearest multiple of 16, never below 16. Consequence: **LARGE must map to
  2.0** (16→32, 32→64) to do anything — 1.25 snaps back to 16. SMALL stays a no-op at base-16
  and that is correct; consider removing SMALL from the options UI rather than shipping a
  setting that does nothing (flag it in the report either way).
- **Counting sites by grepping digits under-reports by ~half** (measured 2026-08-03). Sizes come
  from named constants (`FS_MD`, `FS_XS`, `_FS_LG`, `FS_TINY`) applied via
  `add_theme_font_size_override`, from `LabelSettings.font_size`, from `normal_font_size`
  rich-text properties, AND from shared helpers that take a size as a plain argument
  (`GlyphBar.rich_prompt` — that seam now snaps internally, but audit for others like it).
  Resolve constants and helper params, not just literal call sites.
- **Exclusions, all deliberate — leave every one alone:** the 18 debug-tool sites (anim lab,
  debug panel, entity inspector, passive-tree debug, ldtk harness — they use
  `DebugUI.use_vector_font`); floating damage numbers (`combat_feedback_manager`, vector @ 7,
  DECIDED 2026-08-09, do not "fix"); the theme's own default (the theme is a floor — scaling
  happens at override sites).
- **The layout footgun** (measured on `hub_launch_panel.gd`): changing text size re-flows any
  container that hugs content minimum — a bare `Panel` never stretches children and collapses.
  At 2.0 the risk inverts: text GROWS, so the hazards are clipping and overflow. Hub panels must
  keep scrollable content in `ScrollContainer` with SHOW_AS_NEEDED; check every panel at LARGE
  against the 640×360 viewport.
</context>

<requirements>
- Build the full site inventory FIRST (constants and helper params resolved), write it into the
  report table, and only then start converting. The 2026-08-03 inventory counted 191 sites /
  173 crisp — reconcile against it; the count has since grown.
- Convert player-facing sites to `Settings.scaled_font_size(base)`; sites that are already 32
  scale to 64 at LARGE — verify screen titles still fit, and where one cannot, cap that site
  with a comment stating the measured width that forced it.
- Set LARGE's multiplier to 2.0 in `settings.gd`.
- Live-verify at LARGE and NORMAL (ask Ben to open Godot; back up `progression.json`, restore
  after): HUD, level-up cards (three two-line cards + weapon cache open was the historical worst
  case), results screens, settings, all five hub panels — **remember the five hub panel scenes
  must never be saved**; all changes are script-side.
- One grouped conventional commit; update CLAUDE.md's `TEXT_SIZE_SCALE` note (it currently
  documents the 8/151 state), `docs/polish_plan_2026-08-15.md` §3.2, and the 00_EXECUTION_PLAN
  status table.
</requirements>

<output_format>
The commit, the site-inventory table (site · base · scaled path · verified-at-LARGE result)
appended to the session report, and the three doc updates listed above.
</output_format>
