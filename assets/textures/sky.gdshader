shader_type sky;

uniform sampler2D hdr_day  : source_color;
uniform sampler2D hdr_dusk : source_color;
uniform float blend = 0.0;  // 0 = day, 1 = dusk
uniform float rot   = 0.0;  // 0..1 = full 360° horizontal wrap

void sky() {
    vec2 uv = SKY_COORDS;     // equirect UV 0..1
    uv.x = fract(uv.x + rot); // yaw
    vec3 a = texture(hdr_day,  uv).rgb;
    vec3 b = texture(hdr_dusk, uv).rgb;
    COLOR = mix(a, b, blend); // COLOR is vec3 in sky shaders
}
