shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 upper_color : source_color = vec4(1.0, 0.88, 0.81, 1.0);
uniform vec4 lower_color : source_color = vec4(0.54, 0.48, 0.66, 1.0);
varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float light = smoothstep(-0.7, 0.9, dot(normalize(world_normal), normalize(vec3(-0.5, 0.8, -0.2))));
    float detail = sin(world_pos.x * 2.0 + sin(world_pos.z * 1.7)) * sin(world_pos.y * 2.7) * 0.025;
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
    ALBEDO = mix(lower_color.rgb, upper_color.rgb, clamp(light + detail, 0.0, 1.0)) + edge * vec3(0.10, 0.07, 0.04);
}
