shader_type spatial;
render_mode cull_disabled;
uniform vec4 color : source_color = vec4(0.12, 0.43, 0.35, 1.0);
uniform float clock = 0.0;
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.x += sin(clock * 0.65 + world.x * 0.7 + world.z * 0.3 + UV.y * 2.0) * UV.y * UV.y * 0.18;
}
void fragment() {
    float vein = 1.0 - smoothstep(0.015, 0.07, abs(UV.x - 0.5));
    ALBEDO = color.rgb * (0.72 + UV.y * 0.30) + vein * vec3(0.06, 0.09, 0.025);
    ROUGHNESS = 0.68;
    SPECULAR = 0.20;
}
