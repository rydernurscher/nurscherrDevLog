shader_type canvas_item;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	// COLOR.rgb is the depth-based shading we set in GDScript
	// We treat it as the "minimum" brightness
	vec3 ambient = COLOR.rgb;
	COLOR = vec4(tex_color.rgb * ambient, tex_color.a);
}

void light() {
	// This allows PointLight2D (Torches/Aura) to add brightness 
	// even if the block is deep underground (ambient is near 0)
	float boost = LIGHT_ENERGY;
	LIGHT = vec4(LIGHT_COLOR.rgb * boost, LIGHT_COLOR.a);
}