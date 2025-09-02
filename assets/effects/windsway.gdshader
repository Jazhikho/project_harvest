shader_type spatial;

uniform float wind_strength : hint_range(0.0, 1.0) = 0.35;
uniform float wind_freq : hint_range(0.0, 10.0) = 0.8;
uniform vec3  wind_dir = vec3(1.0, 0.0, 0.2);

// if your mesh came in Z-up from Max, set to (0,0,1)
uniform vec3  up_axis = vec3(0.0, 0.0, 1.0);

uniform float base_offset = 0.0;              // base along up_axis (mesh units)
uniform float height      = 2.0;              // total extent along up_axis
uniform float stiffness   : hint_range(0.1, 5.0) = 1.8;
uniform float phase_scale = 2.4;

// basic textured shading
uniform sampler2D albedo_tex : source_color;
uniform vec4 albedo_color : source_color = vec4(1.0);

float sat(float x){ return clamp(x, 0.0, 1.0); }

void vertex() {
    vec3 wdir = normalize(wind_dir);
    vec3 u = normalize(up_axis);

    float along = dot(VERTEX, u);
    float t = sat((along - base_offset) / max(height, 0.0001));
    float w = pow(t, stiffness);

    // per-object phase so instances don't sync
    vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    float phase = phase_scale * dot(world_pos.xz, vec2(0.113, 0.071));

    float sway = sin(TIME * (6.2831853 * wind_freq) + phase) * wind_strength;

    VERTEX += wdir * (sway * w);
}

void fragment() {
    vec4 tex = texture(albedo_tex, UV);
    ALBEDO = tex.rgb * albedo_color.rgb;
    ALPHA  = tex.a * albedo_color.a;
}
