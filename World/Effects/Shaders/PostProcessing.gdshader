shader_type canvas_item;

// This grabs whatever is rendered behind this ColorRect
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// --- Fog Controls ---
uniform vec3 fog_color : source_color = vec3(0.12, 0.15, 0.18); 
uniform float fog_density : hint_range(0.0, 1.0) = 0.4;
uniform float fog_speed : hint_range(0.0, 1.0) = 0.05;

// --- Color Grading Controls ---
uniform float desaturation : hint_range(0.0, 1.0) = 0.45; 
uniform vec3 tint_color : source_color = vec3(0.6, 0.7, 0.75); 
uniform float vignette_intensity : hint_range(0.0, 3.0) = 1.5; 

// --- Grit Controls ---
uniform float grain_strength : hint_range(0.0, 0.2) = 0.04;

// 1. Pseudo-random generator
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 2. Smooth Noise for the fog
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 3. Fractal Brownian Motion (Layered noise for fluffy, thick mist)
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    
    // --- THE FIX: A rotation matrix to destroy the visible grid boxes ---
    mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)); 
    
    for (int i = 0; i < 4; ++i) {
        v += a * noise(p);
        // Rotate, scale, and shift the grid for the next layer
        p = rot * p * 2.0 + shift; 
        a *= 0.5;
    }
    return v;
}

void fragment() {
    // A. READ THE SCREEN
    vec4 original_color = texture(screen_texture, SCREEN_UV);

    // B. ADD ROLLING MIST
    // PRO-TIP: If the clouds still feel too "chunky", increase this 3.0 to a 5.0 or 8.0 to zoom out!
    vec2 fog_uv = SCREEN_UV * 3.0; 
    fog_uv.x += TIME * fog_speed; 
    
    float n = fbm(fog_uv);
    
    float fog_gradient = smoothstep(-0.2, 1.0, SCREEN_UV.y);
    float fog_amount = n * fog_density * fog_gradient;
    
    vec3 color_with_fog = mix(original_color.rgb, fog_color, fog_amount);

    // C. COLOR GRADING (Desaturate & Tint)
    float luminance = dot(color_with_fog, vec3(0.299, 0.587, 0.114));
    vec3 grayscale = vec3(luminance);
    
    vec3 tinted_grayscale = grayscale * tint_color * 2.0;
    
    vec3 graded_color = mix(color_with_fog, tinted_grayscale, desaturation);

    // D. VIGNETTE (Oppressive framing)
    vec2 center_dist = SCREEN_UV - 0.5;
    float vignette = 1.0 - dot(center_dist, center_dist) * vignette_intensity;
    vignette = smoothstep(0.0, 1.0, vignette); 
    
    graded_color *= vignette;

    // E. FILM GRAIN
    // --- THE FIX: mod(TIME) prevents the grain from turning into blocks after a few minutes ---
    float grain = hash(SCREEN_UV + mod(TIME, 10.0)) * grain_strength;
    graded_color -= grain;

    // F. FINAL OUTPUT
    COLOR = vec4(graded_color, 1.0);
}