shader_type canvas_item;

// You can edit these values directly in the Godot Inspector later!
uniform float surface_y = 300.0;      // The Y pixel coordinate where darkness begins
uniform float pitch_black_y = 1000.0; // The Y pixel coordinate where it becomes fully black

varying vec2 world_pos;

void vertex() {
	// Grab the absolute world coordinates of the tiles
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Get the original colors of your tile sprites
	vec4 original_color = texture(TEXTURE, UV);
	
	// Calculate the depth percentage (0.0 is the surface, 1.0 is pitch black)
	float depth = clamp((world_pos.y - surface_y) / (pitch_black_y - surface_y), 0.0, 1.0);
	
	// Darken the block (1.0 is full color, 0.0 is pitch black)
	original_color.rgb *= (1.0 - depth);
	
	COLOR = original_color;
}