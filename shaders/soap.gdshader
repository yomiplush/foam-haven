shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform float clock = 0.0;
uniform float opacity = 0.30;
uniform float latex = 0.0;
uniform vec4 tint : source_color = vec4(0.65, 0.89, 0.98, 1.0);
uniform float touch_amount = 0.0;
uniform vec3 touch_point = vec3(0.0);
uniform float gel = 0.0;
uniform float shell_layer = 0.0;
uniform vec3 press_left = vec3(-0.5, 0.0, -0.8);
uniform vec3 press_right = vec3(0.5, 0.0, -0.8);
uniform float depth_left = 0.0;
uniform float depth_right = 0.0;
uniform float goo_left = 0.0;
uniform float goo_right = 0.0;
varying vec3 local_position;
void vertex() {
    local_position = VERTEX;
    float wave = sin(VERTEX.y * 5.0 + clock * 0.38) * sin(VERTEX.x * 4.0 - clock * 0.25);
    float dl = distance(normalize(VERTEX), press_left);
    float dr = distance(normalize(VERTEX), press_right);
    // The goo value softens and widens the push while it is held, so a steady
    // press keeps yielding like a jelly skin instead of locking to a peak.
    float stiff_l = 15.0 - 9.0 * goo_left;
    float stiff_r = 15.0 - 9.0 * goo_right;
    float bulge = depth_left * exp(-dl * dl * stiff_l) + depth_right * exp(-dr * dr * stiff_r);
    float goo_avg = (goo_left + goo_right) * 0.5;
    float elastic_wave = sin(dl * 32.0 - clock * 10.0) * exp(-dl * 4.0) * abs(depth_left)
                       + sin(dr * 32.0 - clock * 10.0) * exp(-dr * 4.0) * abs(depth_right);
    float jelly = goo_avg * 0.05 * (sin(clock * 2.2 + dl * 5.0) * exp(-dl * 2.0)
                                  + sin(clock * 2.2 + dr * 5.0) * exp(-dr * 2.0));
    VERTEX += NORMAL * (wave * 0.008 + (bulge + (elastic_wave + jelly) * (0.09 + 0.12 * goo_avg)) * gel);
    vec3 tangent_l = press_left - NORMAL * dot(press_left, NORMAL);
    vec3 tangent_r = press_right - NORMAL * dot(press_right, NORMAL);
    NORMAL = normalize(NORMAL - gel * 9.0 * (tangent_l * depth_left * exp(-dl * dl * 15.0) + tangent_r * depth_right * exp(-dr * dr * 15.0)));
}
void fragment() {
    float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float rim = pow(1.0 - facing, 2.4);
    float film = sin(UV.y * 16.0 + sin(UV.x * 19.0 + clock * 0.15) * 1.4 + clock * 0.22 + shell_layer * 0.5);
    vec3 rainbow = 0.57 + 0.43 * cos(vec3(0.0, 2.1, 4.2) + film * 2.0 + UV.y * 6.0);
    float ribbon = pow(0.5 + 0.5 * film, 14.0);
    float gleam = pow(max(0.0, sin(UV.x * 6.283 + 0.4) * sin(UV.y * 3.141)), 24.0);
    float distance_touch = distance(local_position, touch_point);
    float ripple = touch_amount * exp(-distance_touch * 1.7) * (0.5 + 0.5 * sin(distance_touch * 28.0 - clock * 9.0));
    // Pressed film pools colour and light near the point of contact; the goo
    // widens that patch while the finger keeps pressing.
    float contact_l = abs(depth_left) * exp(-pow(distance(normalize(local_position), press_left), 2.0) * (12.0 - 6.0 * goo_left));
    float contact_r = abs(depth_right) * exp(-pow(distance(normalize(local_position), press_right), 2.0) * (12.0 - 6.0 * goo_right));
    float contact = contact_l + contact_r;
    // From inside the shell, most rays are nearly normal to the surface.
    // Keep a visible interference film even where the Fresnel rim vanishes.
    vec3 film_color = mix(vec3(0.76, 0.9, 0.94), rainbow, mix(0.7, 0.78, gel));
    ALBEDO = mix(film_color, tint.rgb, latex * 0.95) + gleam * 0.6 + ripple * vec3(0.4, 0.8, 0.9) + contact * vec3(1.4, 1.7, 1.8);
    float gel_band = pow(0.5 + 0.5 * sin(UV.y * 20.0 + sin(UV.x * 12.56 + clock * 0.12) * 2.0 + shell_layer * 0.45), 10.0);
    // Broad reflected light has its own shape, independent of the film colours.
    vec3 direction = normalize(local_position);
    float window_light = pow(max(0.0, dot(direction, normalize(vec3(-0.55, 0.55, -0.65)))), 44.0);
    float soft_light = pow(max(0.0, dot(direction, normalize(vec3(0.7, 0.25, -0.65)))), 80.0);
    ALBEDO += gel * (gel_band * vec3(0.24, 0.28, 0.30) + (window_light + soft_light) * vec3(0.65, 0.69, 0.72));
    float thickness = gel * (mix(0.052, 0.10, latex) + gel_band * 0.20 + ribbon * 0.16 + contact * 0.9 + pow(1.0 - facing, 1.2) * 0.12);
    ALPHA = clamp((mix(0.018, 0.004, gel) + rim * 0.58 + ribbon * mix(0.14, 0.018, gel) + gleam * mix(0.26, 0.06, gel) + latex * 0.07 + gel * (window_light * 0.24 + soft_light * 0.16) + ripple * 0.16 + thickness) * opacity * mix(1.0, 0.70, shell_layer), 0.0, 0.70);
}
