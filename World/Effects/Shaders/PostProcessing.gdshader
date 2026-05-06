shader_type canvas_item;

// --- UNIFORMS ---
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

group_uniforms Technical_Settings;
uniform float exposure : hint_range(0.0, 5.0) = 1.0;
uniform float sharpness : hint_range(0.0, 1.0) = 0.2; // CAS-style sharpening

group_uniforms Color_Grading;
uniform float contrast : hint_range(0.5, 1.5) = 1.1;
uniform float saturation : hint_range(0.0, 2.0) = 0.9;
uniform vec3 shadow_tint : source_color = vec3(0.05, 0.08, 0.15);
uniform vec3 midtone_tint : source_color = vec3(0.3, 0.25, 0.2);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.9, 0.7);

group_uniforms Lens_Effects;
uniform float ca_strength : hint_range(0.0, 0.05) = 0.003;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.7;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.5;

group_uniforms Atmosphere;
uniform float film_grain : hint_range(0.0, 0.1) = 0.04;
uniform float scanline_opacity : hint_range(0.0, 0.1) = 0.02; // AAA games often have subtle texture

// --- HELPER FUNCTIONS ---

// ACES Filmic Tonemapping (The "Secret Sauce" for the Elden Ring look)
vec3 tonemap_aces(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// Better noise function (Blue-ish noise distribution)
float interleaved_gradient_noise(vec2 uv) {
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(uv, magic.xy)));
}

// Convert sRGB to Linear for math
vec3 srgb_to_linear(vec3 color) {
    return pow(color, vec3(2.2));
}

// Convert Linear to sRGB for display
vec3 linear_to_srgb(vec3 color) {
    return pow(color, vec3(1.0 / 2.2));
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 dist_from_center = uv - 0.5;
    
    // 1. RADIAL CHROMATIC ABERRATION
    // AAA method: Distort R and B channels based on distance from center (lens curvature)
    float ca_offset = length(dist_from_center) * ca_strength;
    float r = texture(screen_texture, uv - (dist_from_center * ca_offset)).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv + (dist_from_center * ca_offset)).b;
    vec3 color = vec3(r, g, b);
    
    // 2. LINEAR SPACE CONVERSION
    // AAA math must be done in linear space, not sRGB
    color = srgb_to_linear(color);
    color *= exposure;

    // 3. SHARPENING (Subtle Contrast Adaptive Sharpening)
    // Helps pixel art pop against the blur of post-processing
    vec3 neighbors = srgb_to_linear(texture(screen_texture, uv + vec2(SCREEN_PIXEL_SIZE.x, 0)).rgb);
    color += (color - neighbors) * sharpness;

    // 4. COLOR GRADING (Advanced 3-Way Power/Slope/Offset)
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    
    // Apply contrast around a pivot
    color = pow(color, vec3(contrast));
    
    // Advanced Split Toning
    vec3 graded_color = mix(shadow_tint, midtone_tint, smoothstep(0.0, 0.5, luma));
    graded_color = mix(graded_color, highlight_tint, smoothstep(0.5, 1.0, luma));
    color *= graded_color;
    
    // Saturation
    color = mix(vec3(luma), color, saturation);

    // 5. TONEMAPPING
    // This compresses bright "Erdtree" golds so they glow without "clipping" to white
    color = tonemap_aces(color);

    // 6. VIGNETTE (Physical falloff)
    float vignette = smoothstep(0.8, vignette_softness * 0.4, length(dist_from_center * vignette_intensity));
    color *= vignette;

    // 7. FILM GRAIN & DITHERING
    // AAA grain is stronger in the midtones and subtle in blacks/whites
    float noise = interleaved_gradient_noise(uv * vec2(TIME * 0.01));
    float grain_mask = pow(1.0 - luma, 2.0) * luma * 4.0; // Mask grain to midtones
    color += (noise - 0.5) * film_grain * grain_mask;
    
    // 8. FINAL OUTPUT
    // Convert back to sRGB for the monitor
    COLOR = vec4(linear_to_srgb(color), 1.0);
}