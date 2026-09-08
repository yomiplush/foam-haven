shader_type spatial;
render_mode unshaded;
uniform float clock = 0.0;
uniform vec4 base_color : source_color = vec4(0.09, 0.29, 0.34, 1.0);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world_position.xz;
    float a = sin(p.x * 1.7 + sin(p.y * 1.4 + clock * 0.22));
    float b = sin(p.y * 2.0 - sin(p.x * 1.1 - clock * 0.18));
    float c = pow(1.0 - abs(a * 0.52 + b * 0.48), 18.0);
    float distance_fade = exp(-length(p) * 0.02);
    ALBEDO = base_color.rgb + vec3(0.045, 0.14, 0.13) * c * distance_fade;
}
