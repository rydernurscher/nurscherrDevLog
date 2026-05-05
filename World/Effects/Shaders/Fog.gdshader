shader_type canvas_item;

uniform vec3 fog_color : source_color = vec3(0.6, 0.7, 0.8);
uniform float fog_density : hint_range(0.0, 1.0) = 0.5;
uniform float speed_x = 0.05;
uniform float speed_y = 0.02;

// Basic 2D noise
vec2 random(vec2 uv){
    uv = vec2( dot(uv, vec2(127.1,311.7) ),
               dot(uv, vec2(269.5,183.3) ) );
    return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float noise(vec2 uv) {
    vec2 uv_index = floor(uv);
    vec2 uv_fract = fract(uv);
    vec2 blur = smoothstep(0.0, 1.0, uv_fract);

    return mix( mix( dot( random(uv_index + vec2(0.0,0.0) ), uv_fract - vec2(0.0,0.0) ),
                     dot( random(uv_index + vec2(1.0,0.0) ), uv_fract - vec2(1.0,0.0) ), blur.x),
                mix( dot( random(uv_index + vec2(0.0,1.0) ), uv_fract - vec2(0.0,1.0) ),
                     dot( random(uv_index + vec2(1.0,1.0) ), uv_fract - vec2(1.0,1.0) ), blur.x), blur.y) + 0.5;
}

// Layering noise for a cloudier look
float fbm(vec2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(uv);
        uv *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    // Scroll the noise
    vec2 moving_uv = UV + vec2(TIME * speed_x, TIME * speed_y);
    
    // Generate fog shape
    float fog = fbm(moving_uv * 3.0);
    
    // Apply density and color
    COLOR = vec4(fog_color, fog * fog_density);
}