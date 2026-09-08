shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform float opacity = 1.0;
uniform float clock = 0.0;
uniform float latex = 0.0;
void fragment() {
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.4);
    vec3 rainbow = 0.58 + 0.42 * cos(vec3(0.0,2.1,4.2) + UV.y * 9.0 + clock * 0.24);
    float gleam = pow(max(0.0, dot(normalize(NORMAL), normalize(vec3(-0.4,0.7,0.6)))), 36.0);
    ALBEDO = mix(rainbow, vec3(1.0,0.5,0.73),latex) + gleam * 0.8;
    ALPHA = min(0.78, (0.022 + edge * 0.64 + gleam * 0.65 + latex * 0.04) * opacity);
}
