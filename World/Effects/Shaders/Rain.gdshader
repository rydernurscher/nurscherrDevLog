shader_type canvas_item;

uniform vec4 rain_color : source_color = vec4(0.6, 0.75, 0.9, 0.7);
uniform float rain_density : hint_range(0.0, 1.0) = 0.6; // Higher = thicker storm
uniform float speed : hint_range(1.0, 20.0) = 12.0; 
uniform float slant : hint_range(-1.0, 1.0) = 0.25; // The wind angle

// Generates a random value based on a 1D input
float hash(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    
    // 1. Skew the entire coordinate system for wind slant
    uv.x += uv.y * slant;
    
    float total_rain = 0.0;
    
    // 2. Generate 3 depth layers of rain for parallax
    for (float i = 1.0; i <= 3.0; i++) {
        
        // Scale the UVs. Further layers get thinner (more X scale) and longer (less Y scale)
        vec2 scale = vec2(100.0 * i, 1.5 * i);
        vec2 scaled_uv = uv * scale;
        
        // Give every single vertical column a random Y offset so they don't line up
        float column_id = floor(scaled_uv.x);
        float column_offset = hash(column_id + i * 100.0);
        
        // THE FIX: Subtracting from UV.y makes the texture scroll DOWN the screen.
        // We multiply by speed, layer depth, and add the column offset to stagger them.
        scaled_uv.y -= TIME * speed * (0.8 + i * 0.2) + column_offset * 10.0;
        
        // Get the local position inside the current grid cell
        vec2 cell_uv = fract(scaled_uv);
        float cell_id = floor(scaled_uv.y);
        
        // Decide if a drop spawns in this specific cell
        float drop_chance = hash(column_id + cell_id * 13.0);
        float is_visible = step(drop_chance, rain_density / i); // Further layers have fewer visible drops
        
        // 3. Draw the streak
        // Make the drop a razor-sharp thin line in the center of the column
        float dist_x = abs(cell_uv.x - 0.5);
        float line_x = smoothstep(0.1, 0.02, dist_x); 
        
        // Taper the streak so it has a fading tail at the top and a harder edge at the bottom
        float line_y = smoothstep(0.0, 0.1, cell_uv.y) * smoothstep(1.0, 0.6, cell_uv.y);
        
        // Add this layer to the final output. Further layers fade into the background.
        total_rain += line_x * line_y * is_visible * (1.0 - (i - 1.0) * 0.35);
    }
    
    // Output the final clamped rain color
    COLOR = vec4(rain_color.rgb, clamp(total_rain, 0.0, 1.0) * rain_color.a);
}