shader_type spatial;
render_mode unshaded;
void fragment() {
    vec3 sky = mix(vec3(0.84, 0.75, 0.69), vec3(0.55, 0.65, 0.73), UV.y);
    float glow = exp(-length((UV - vec2(0.32, 0.40)) * vec2(3.0, 2.0)));
    ALBEDO = sky + vec3(0.16, 0.12, 0.06) * glow;
}
