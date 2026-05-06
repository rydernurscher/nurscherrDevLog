shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

group_uniforms Cinematic_Lens;
uniform float contrast : hint_range(0.0, 2.0) = 1.25;
uniform float brightness : hint_range(-1.0, 1.0) = -0.05;
uniform float saturation : hint_range(0.0, 2.0) = 0.85;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.002;
uniform float vignette_intensity : hint_range(0.0, 3.0) = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.8;

group_uniforms Elden_Color_Grading;
// Elden Shadows: Deep Teal/Blue (The Night)
uniform vec3 shadow_tint : source_color = vec3(0.05, 0.08, 0.12);
// Elden Highlights: Tarnished Gold (The Erdtree)
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.85, 0.6);
uniform float split_toning_intensity : hint_range(0.0, 1.0) = 0.3;

group_uniforms Atmosphere;
uniform float grain_amount : hint_range(0.0, 0.1) = 0.03;
uniform float mist_density : hint_range(0.0, 1.0) = 0.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center_dist = uv - 0.5;
	
	// 1. CHROMATIC ABERRATION
	// Shifts the Red and Blue channels towards the edges for a "lens" look
	float ca_offset = length(center_dist) * chromatic_aberration;
	float r = texture(screen_texture, uv - vec2(ca_offset, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv + vec2(ca_offset, 0.0)).b;
	vec3 color = vec3(r, g, b);
	
	// 2. BRIGHTNESS & CONTRAST
	color = (color - 0.5) * contrast + 0.5 + brightness;
	
	// 3. SATURATION (Desaturate for that "grim" feel)
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, saturation);
	
	// 4. ELDEN SPLIT TONING
	// Tint shadows cool and highlights warm gold
	vec3 shadows = mix(color, color * shadow_tint * 2.0, split_toning_intensity);
	vec3 highlights = mix(color, color * highlight_tint, split_toning_intensity);
	color = mix(shadows, highlights, smoothstep(0.2, 0.8, luma));
	
	// 5. DISTANCE HAZING (Vertical Mist)
	// Darkens the bottom of the screen and adds a bit of "ground dust" vibe
	float ground_mist = smoothstep(1.0, 0.2, uv.y) * mist_density;
	color = mix(color, shadow_tint, ground_mist * 0.5);

	// 6. VIGNETTE
	// Makes the center feel like a point of focus (the player) and edges dark
	float vignette = 1.0 - dot(center_dist, center_dist) * (vignette_intensity * 2.0);
	color *= mix(1.0, clamp(vignette, 0.0, 1.0), vignette_opacity);
	
	// 7. CINEMATIC FILM GRAIN
	// Elden Ring has a subtle "dirty" look to the air. 
	// This grain is subtle and moves over time.
	float noise = hash(uv + mod(TIME, 10.0));
	color += (noise - 0.5) * grain_amount;
	
	// 8. FINAL CURVE (Slightly boost the blacks for that "crushed" look)
	color = pow(color, vec3(1.1));

	COLOR = vec4(color, 1.0);
}