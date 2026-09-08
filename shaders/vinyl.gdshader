shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform vec4 color_a : source_color = vec4(1.0, 0.45, 0.7, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.86, 0.93, 1.0);
uniform float panels = 0.0;
uniform float transparency = 1.0;
uniform float clock = 0.0;

void fragment() {
    float sector = floor(UV.x * 8.0);
    vec3 candy = mix(color_a.rgb, color_b.rgb, mod(sector, 2.0));
    // A coordinated sorbet palette avoids neon stripes in the quiet room.
    vec3 beach = vec3(0.92, 0.71, 0.73);
    float stripe = mod(sector, 4.0);
    if (stripe > 0.5) beach = vec3(0.70, 0.85, 0.81);
    if (stripe > 1.5) beach = vec3(0.96, 0.85, 0.66);
    if (stripe > 2.5) beach = vec3(0.78, 0.74, 0.87);
    vec3 base = mix(color_a.rgb, mix(candy, beach, max(0.0, panels - 1.0)), min(panels, 1.0));
    float seam = 1.0 - smoothstep(0.003, 0.011, abs(UV.y - 0.5));
    float panel_edge = 1.0 - smoothstep(0.008, 0.026, min(fract(UV.x * 8.0), 1.0 - fract(UV.x * 8.0)));
    seam = max(seam, panel_edge * min(panels, 1.0) * 0.65);
    float grazing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
    ALBEDO = base * (1.0 - seam * 0.13) + seam * 0.12;
    ROUGHNESS = mix(0.24, 0.36, seam);
    SPECULAR = 0.65;
    METALLIC = 0.03;
    CLEARCOAT = 0.55;
    CLEARCOAT_ROUGHNESS = 0.24;
    EMISSION = base * grazing * 0.045;
    ALPHA = clamp(transparency + grazing * 0.25 + seam * 0.12, 0.0, 1.0);
}
