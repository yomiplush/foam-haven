shader_type spatial;
uniform vec4 color : source_color = vec4(0.8, 0.17, 0.29, 1.0);
uniform float seeds = 0.0;
void fragment() {
    vec2 p = UV * vec2(18.0, 10.0);
    p.x += mod(floor(p.y), 2.0) * 0.5;
    vec2 cell = fract(p) - 0.5;
    float d = length(cell * vec2(1.25, 0.80));
    float aa = max(fwidth(d), 0.025);
    float seed = (1.0 - smoothstep(0.075, 0.075 + aa, d)) * seeds;
    float dimple = (1.0 - smoothstep(0.12, 0.25 + aa, d)) * seeds;
    ALBEDO = mix(color.rgb * (1.0 - dimple * 0.22), vec3(0.95, 0.69, 0.34), seed * 0.8);
    ROUGHNESS = 0.48 - seeds * 0.10;
    SPECULAR = 0.32;
}
