// res://World/WorldTerrain/Shaders/NightSky.gdshader
shader_type canvas_item;

uniform vec4 night_color : source_color = vec4(0.05, 0.08, 0.18, 1.0);
uniform float brightness : hint_range(0.0, 1.0) = 0.9;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    // Convert to grayscale first to remove "daytime" colors
    float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    // Tint it deep blue and darken it
    vec3 night_vision = mix(night_color.rgb, vec3(gray), 0.1);
    COLOR = vec4(night_vision * brightness, tex.a);
}