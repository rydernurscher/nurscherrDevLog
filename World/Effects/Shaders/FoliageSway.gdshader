shader_type canvas_item;

uniform float speed : hint_range(0, 10) = 2.0;
uniform float strength : hint_range(0, 100) = 8.0;
uniform float detail : hint_range(0, 1) = 0.5;

void vertex() {
    // In Godot 2D, VERTEX_ID 0 and 1 are usually the top vertices.
    // This pins the bottom of the tile and only sways the top.
    if (VERTEX_ID == 0 || VERTEX_ID == 1) {
        
        // Use the vertex's starting position to create a unique offset per tile
        // Even in procedural gen, VERTEX.xy contains the local 'draw' position
        float unique_offset = VERTEX.x + VERTEX.y;
        
        float sway = sin(TIME * speed + unique_offset * detail) * strength;
        VERTEX.x += sway;
    }
}