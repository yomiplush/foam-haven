shader_type spatial;
render_mode cull_back;
uniform vec4 tint : source_color = vec4(1.0, 0.65, 0.78, 1.0);
uniform float squeeze = 0.0;
uniform vec3 contact_axis = vec3(0.0, 0.0, 1.0);
uniform float pearl = 0.25;
varying vec3 local_normal;

void vertex() {
    vec3 axis = normalize(contact_axis);
    // Volume-preserving squash, with an elastic overshoot after release.
    float squash = clamp(squeeze, -0.10, 0.42);
    float axial = 1.0 - squash;
    float lateral = inversesqrt(axial);
    VERTEX = VERTEX * lateral + axis * dot(VERTEX, axis) * (axial - lateral);
    NORMAL = normalize(NORMAL / lateral + axis * dot(NORMAL, axis) * (1.0 / axial - 1.0 / lateral));
    local_normal = NORMAL;
}

void fragment() {
    float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float rim = pow(1.0 - facing, 2.8);
    vec3 n = normalize(local_normal);
    float window = pow(max(0.0, dot(n, normalize(vec3(-0.45, 0.6, 0.65)))), 34.0);
    float strip = pow(max(0.0, dot(n, normalize(vec3(0.65, 0.28, 0.55)))), 85.0);
    vec3 edge = mix(tint.rgb, vec3(0.90, 0.77, 1.0), pearl * rim);
    ALBEDO = edge;
    ROUGHNESS = 0.21 + pearl * 0.10;
    SPECULAR = 0.7;
    CLEARCOAT = 0.65;
    CLEARCOAT_ROUGHNESS = 0.18;
    METALLIC = pearl * 0.16;
    EMISSION = tint.rgb * rim * 0.035 + vec3(1.0, 0.92, 0.94) * (window * 0.35 + strip * 0.18);
}
