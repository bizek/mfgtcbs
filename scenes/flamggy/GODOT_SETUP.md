# Flame Mascot — Godot 4 setup (mobile)

**Asset:** `flame_mascot.glb` — ~4,000 triangles, no textures (color baked into vertex
colors), two surfaces: `Mascot_Body` and `Mascot_Face`.

## 1. Import
Drop `flame_mascot.glb` into the project. It imports as a scene with the two meshes.
Vertex colors ride along as `COLOR` in the shaders below — no UVs or texture memory needed.

## 2. Materials
- **Mascot_Body** → `ShaderMaterial` using `flame_toon.gdshader` (cel bands + rim).
- **Mascot_Face** → `ShaderMaterial` using `flame_face.gdshader` (flat/unlit).
- **Outline** → on the body material, set **Next Pass** to a `ShaderMaterial` using
  `flame_outline.gdshader`. Tweak `outline_width` (~0.02–0.035). Add the same as a next
  pass on the face if you want the eyes inked too.

If you'd rather skip custom shaders, a `StandardMaterial3D` with **Vertex Color → Use as
Albedo** on, **Shading = Toon**, and **Grow** enabled for the outline gets you ~80% there.

## 3. Lighting
The cel banding is driven by a real light, so give the scene one clear **DirectionalLight3D**
as the key (front-upper, ~40°). The shader bands the N·L into 3 tones; a single directional
is enough. Ambient/secondary light just lifts the shadow tone.

## 4. Screen post-FX (the Spider-Verse polish)
These are screen effects, not per-asset — set them up once on the camera/environment:
- **Glow/bloom:** `WorldEnvironment` → Glow on, low HDR threshold (the bright flame blooms).
- **Chromatic aberration:** a fullscreen `CanvasLayer` / post-process quad shader sampling
  the screen texture with a tiny per-channel UV offset (~1–2 px). Keep it subtle.
- **Grain:** overlay a low-opacity noise texture on the same post layer.

## Budget
~4k tris, 0 textures, 2–3 materials (body / face / shared outline pass). Comfortable for
mobile. If you need lower, the face surface decimates further without hurting the read.

## Note on what changed from the render version
The EEVEE Shader-to-RGB material, the Solidify outline geometry, the 3-sun rig, and the
compositor effects do **not** export — they're rebuilt here as: vertex-color albedo + the
toon `light()` function, a cull_front inverted-hull pass, one directional light, and the
WorldEnvironment/screen post above.
