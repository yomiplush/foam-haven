shader_type spatial;
render_mode cull_back;
varying vec3 world_position;
uniform vec2 room_extent = vec2(8.0, 9.0);
uniform vec4 contact_shadows[12];
uniform int shadow_count = 0;
uniform float daylight = 1.0;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 p = world_position.xz;
    float board = floor(p.x * 1.2);
    float offset = fract(sin(board * 43.1) * 437.3);
    float edge = min(fract(p.x * 1.2), 1.0 - fract(p.x * 1.2));
    float width = max(fwidth(p.x * 1.2), 0.002);
    float join = 1.0 - smoothstep(0.003, 0.003 + width, edge);
    float grain = sin(p.y * 17.0 + sin(p.x * 5.0 + offset) * 2.0) * 0.012;
    vec3 oak = mix(vec3(0.65, 0.48, 0.36), vec3(0.76, 0.61, 0.47), offset);
    float end_joint = 1.0 - smoothstep(0.003, 0.003 + max(fwidth(p.y * 0.32), 0.002), min(fract(p.y * 0.32 + offset), 1.0 - fract(p.y * 0.32 + offset)));
    float wall_distance = min(room_extent.x - abs(p.x), room_extent.y - abs(p.y));
    float occlusion = 1.0 - exp(-max(wall_distance, 0.0) * 2.0) * 0.22;
    for (int i = 0; i < shadow_count; i++) {
        vec4 shadow = contact_shadows[i];
        vec2 q = (p - shadow.xy) / shadow.zw;
        occlusion *= 1.0 - exp(-dot(q, q) * 2.5) * 0.24;
    }
    // Soft window illumination is analytic and stable in both eyes; no screen-space pass.
    float window_pool = exp(-pow(p.x / 3.8, 4.0) - pow((p.y + 4.0) / 4.5, 4.0)) * daylight;
    ALBEDO = (oak + grain - max(join, end_joint * 0.65) * 0.045) * occlusion;
    EMISSION = vec3(0.15, 0.10, 0.06) * window_pool;
    ROUGHNESS = 0.82;
    SPECULAR = 0.18;
}
