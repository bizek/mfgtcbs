class_name DebugUI
extends RefCounted

## Shared chrome rules for the debug tools (training panel, anim lab, debug panel,
## passive-tree debug, LDtk harness).
##
## ── Why this exists ───────────────────────────────────────────────────────────
##
## The debug panels are dense: they pack a lot of rows into a 640x360 viewport, so
## they size their text at 9-14px. That was a deliberate, working decision while
## Godot's built-in VECTOR font was the default — a vector face stays readable at
## 10px, and `training_panel.gd` recorded the reasoning in a comment:
##
##     "Default theme font only — the m5x7 pixel font below its native size renders
##      illegibly at this viewport scale (Ben, 2026-07-20)."
##
## On 2026-08-07 the project gained a Theme (`assets/ui/grim_theme.tres`, wired as
## `project.godot [gui] theme/custom`) whose default font is **m5x7 at 16**. That
## silently made "the default theme font" mean the pixel font, so every one of those
## 9-14px sizes became m5x7 below its native grid — exactly what the comment forbids.
##
## m5x7 does not merely soften below 16, it FUSES: the 1px inter-letter gap vanishes,
## so "PACK" reads as "FACh", "HIT BACK" as "KIT BACh", and a title turns into
## something closer to Cyrillic. Reported by Ben 2026-08-09 against the training panel,
## which matters more than an ordinary debug screen because it is the *only* surface
## Claude is permitted to test in (CLAUDE.md, "In-Game Testing — Training Room ONLY").
##
## ── Why a Theme and not a font override per control ───────────────────────────
##
## Theme resolution walks node overrides → the node's own theme → ancestor Controls'
## themes → the project theme → ThemeDB. It resolves each ITEM independently, so a
## theme that defines *only* `default_font` supplies the vector face and lets every
## StyleBox, colour and constant fall straight through to `grim_theme.tres`. One
## assignment on a panel root therefore reaches every descendant, keeps the Grim
## button plates, and changes no layout — where bumping the sizes to 16 would grow
## every panel by ~45% inside a 360px-tall viewport.
##
## `default_font_size` is deliberately left unset for the same reason: controls with
## their own size override keep it, and controls without inherit 16 from the project
## theme rather than from here.
##
## This is for DEBUG TOOLS ONLY. Player-facing text is m5x7 at 16 or 32, no exceptions
## — see CLAUDE.md "Godot Rules".

static var _vector_theme: Theme = null
static var _crisp_font: Font = null


## The vector face, rasterised for a pixel viewport. `ThemeDB.fallback_font` as shipped is
## anti-aliased with sub-pixel positioning: at 9-14px in a 640x360 buffer every glyph edge is a
## grey pixel, and the integer window upscale turns each one into a 2x2 / 3x3 grey block — the
## "blurry" training room / anim lab text (clerveu, 2026-08-17). Same face, same sizes, but
## AA off + sub-pixel positioning off + the FreeType autohinter (`force_autohinter`, which is
## what snaps stems to whole pixels — normal hinting alone left them 1px/2px uneven) renders
## 1-bit glyphs that stay 1px-per-pixel through the upscale. Nothing about layout changes.
## Falls back to the plain fallback font if it isn't a FontFile we can duplicate.
static func crisp_vector_font() -> Font:
	if _crisp_font != null:
		return _crisp_font
	var base: Font = ThemeDB.fallback_font
	if base is FontFile:
		var f: FontFile = (base as FontFile).duplicate()
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		f.hinting = TextServer.HINTING_NORMAL
		f.force_autohinter = true
		f.oversampling = 1.0
		_crisp_font = f
	else:
		_crisp_font = base
	return _crisp_font


## Make `root` and its whole subtree render in Godot's built-in vector font, so the
## dense sub-16 sizes debug panels use stay legible. Safe to call more than once.
static func use_vector_font(root: Control) -> void:
	if root == null:
		return
	if _vector_theme == null:
		_vector_theme = Theme.new()
		_vector_theme.default_font = crisp_vector_font()
	root.theme = _vector_theme


## Single-control variant, for debug tools whose root is not a Control and therefore
## has no `theme` to inherit from — `LdtkTestHarness` is a Node2D that parents its
## labels directly. Same intent as use_vector_font(), one node at a time.
static func use_vector_font_on(c: Control) -> void:
	if c == null:
		return
	c.add_theme_font_override("font", crisp_vector_font())
