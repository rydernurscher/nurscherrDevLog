shader_type canvas_item;

uniform float flash_strength : hint_range(0.0, 1.0);

void fragment() {
   COLOR = mix(texture(TEXTURE, UV), vec4(1.0, 0.0, 0.0, 1.0), flash_strength);
}