shader_type spatial;
render_mode cull_disabled;

void vertex() {
    float fold = VERTEX.x * 27.0;
    VERTEX.z += sin(fold) * 0.045;
    NORMAL = normalize(vec3(-cos(fold) * 1.215, 0.0, 1.0));
}

void fragment() {
    ALBEDO = vec3(0.66, 0.62, 0.68);
    ROUGHNESS = 0.96;
    SPECULAR = 0.12;
}
