shader_type canvas_item;

// Easy Inspector tweaks
uniform vec4 color_deep : source_color = vec4(0.0, 0.4, 0.0, 1.0);
uniform vec4 color_bright : source_color = vec4(0.0, 0.9, 0.0, 1.0);
uniform float speed = 1.2;

// Because the health bar is long and thin, X needs a higher number than Y to stay circular!
uniform vec2 wave_stretch = vec2(5.0, 1.0); 

void fragment() {
    // 1. Fix the stretching by multiplying the UVs
    vec2 p = UV * wave_stretch;
    
    // 2. Pan the coordinates to make the blood flow left-to-right
    p.x -= TIME * speed;
    p.y += TIME * speed * 0.2; // Slight vertical drift
    
    // 3. DOMAIN WARPING: Nesting sine inside cosine creates swirly liquid blobs, NOT grids!
    float wave1 = sin(p.x + cos(p.y * 1.5 + TIME));
    float wave2 = cos(p.y + sin(p.x * 1.2 - TIME));
    
    // 4. Combine the waves (Range is roughly -1.0 to 1.0)
    float fluid = (wave1 + wave2) * 0.5;
    
    // Remap to 0.0 to 1.0
    fluid = fluid * 0.5 + 0.5;
    
    // Sharpen the contrast so the bright red looks like thick plasma
    fluid = smoothstep(0.2, 0.8, fluid);
    
    // 5. The Heartbeat Pulse
    float pulse = (sin(TIME * 4.0) * 0.5 + 0.5) * 0.15;
    
    // Mix the deep and bright blood together
    vec3 final_color = mix(color_deep.rgb, color_bright.rgb, fluid + pulse);
    
    // 6. Apply to the progress bar (uses tex_color.a to hide the shader when the bar empties)
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = vec4(final_color, tex_color.a);
}