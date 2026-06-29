shader_type spatial;
// Flat inked face for Mascot_Face (eyes / brows / mouth / glints).
// Colors are baked into vertex colors; unshaded keeps them perfectly flat.
render_mode unshaded, cull_back;

void fragment() {
    ALBEDO = COLOR.rgb;   // black eyes, dark brows/mouth, white glints
}
