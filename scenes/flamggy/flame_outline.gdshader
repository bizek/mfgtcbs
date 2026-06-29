shader_type spatial;
// Inverted-hull ink outline. Attach as a ShaderMaterial in the body material's
// "Next Pass" slot (and optionally the face). Zero extra asset geometry.
render_mode cull_front, unshaded, shadows_disabled;

uniform float outline_width = 0.025;   // mesh-local units; ~0.02-0.035 reads well here
uniform vec4  outline_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);

void vertex() {
    VERTEX += normalize(NORMAL) * outline_width;   // grow shell along smoothed normals
}
void fragment() {
    ALBEDO = outline_color.rgb;
}
