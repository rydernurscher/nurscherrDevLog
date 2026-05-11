shader_type canvas_item;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // COLOR.rgb is the value you set in _tile_data_runtime_update (the depth)
    // AT_LIGHT_PASS is true when a PointLight2D is hitting the pixel
    
    // We use the vertex color as the "Ambient" base
    vec3 ambient_light = COLOR.rgb; 
    
    // This allows the texture to show the depth shading by default
    COLOR = vec4(tex_color.rgb * ambient_light, tex_color.a);
}

void light() {
    // This function runs for every light source (Torch, Player Aura)
    // LIGHT_COLOR is the color of your PointLight2D
    // LIGHT_ENERGY is the intensity
    
    // We ADD the light on top of the existing depth shading
    LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY, 1.0);
}