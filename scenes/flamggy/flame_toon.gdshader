shader_type spatial;
// Cel / posterized toon shader for Mascot_Body.
// Albedo comes from the baked vertex-color gradient (orange -> yellow). No textures.
render_mode cull_back, specular_disabled, diffuse_toon;

uniform vec4 shadow_color : source_color = vec4(0.70, 0.13, 0.03, 1.0); // deep red-orange
uniform vec4 rim_color    : source_color = vec4(1.0, 0.97, 0.72, 1.0);  // crisp highlight
uniform float rim_strength = 0.8;
uniform float rim_threshold = 0.55;

void fragment() {
    ALBEDO = COLOR.rgb;          // vertex-color flame gradient
    ROUGHNESS = 1.0;
    // one crisp fresnel rim on the silhouette
    float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
    EMISSION += rim_color.rgb * step(rim_threshold, fres) * rim_strength;
}

void light() {
    float ndl = clamp(dot(normalize(NORMAL), normalize(LIGHT)), 0.0, 1.0);
    // hard 3-tone cel banding (no smooth falloff)
    float band = ndl > 0.66 ? 1.0 : (ndl > 0.30 ? 0.55 : 0.0);
    vec3 shaded = mix(shadow_color.rgb, ALBEDO, band);
    DIFFUSE_LIGHT += shaded * LIGHT_COLOR.rgb * ATTENUATION;
}
