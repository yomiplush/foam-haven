shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 color : source_color = vec4(0.7, 0.48, 0.35, 1.0);
uniform float weave_scale = 180.0;
void fragment() {
    vec2 thread = UV * weave_scale;
    vec2 footprint = fwidth(thread);
    float resolved = 1.0 - smoothstep(0.25, 0.8, max(footprint.x, footprint.y));
    float weave = sin(thread.x * 6.283) * sin(thread.y * 6.283);
    float nap = sin(UV.x * 83.0 + sin(UV.y * 51.0)) * 0.018;
    ALBEDO = color.rgb * (0.96 + weave * resolved * 0.055 + nap);
    ROUGHNESS = 0.96;
    SPECULAR = 0.12;
    RIM = 0.40;
    RIM_TINT = 0.78;
}
