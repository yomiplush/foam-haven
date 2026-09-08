shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D left_eye : source_color, filter_linear;
uniform sampler2D right_eye : source_color, filter_linear;
uniform bool stereo = false;
void fragment() {
    vec2 reflection_uv = vec2(1.0 - UV.x, UV.y);
    if (stereo && VIEW_INDEX == VIEW_RIGHT) {
        ALBEDO = texture(right_eye, reflection_uv).rgb;
    } else {
        ALBEDO = texture(left_eye, reflection_uv).rgb;
    }
}
