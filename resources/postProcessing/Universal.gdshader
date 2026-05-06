shader_type canvas_item;

/**
 * THE TARNISHED MATERIAL PIPELINE (AAA 2D)
 * Use this on Sprites, Tilemaps, and Parallax Layers.
 * Supports: Normal Mapping, Rim Lighting, Emissive Glow, and Depth Fog.
 */

// --- UNIFORMS ---
group_uniforms Lighting_and_Texture;
uniform sampler2D normal_map : hint_normal;
uniform float normal_strength : hint_range(0.0, 5.0) = 1.0;
uniform vec4 specular_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float glossiness : hint_range(0.0, 1.0) = 0.5;

group_uniforms Emissive_Magic;
uniform sampler2D emissive_mask : hint_default_black;
uniform vec4 emissive_tint : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float emissive_intensity : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 0.0;

group_uniforms Rim_Lighting; // Picks out silhouettes against dark backgrounds
uniform bool enable_rim = true;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float rim_width : hint_range(0.0, 5.0) = 1.5;

group_uniforms Atmospheric_Depth;
uniform float world_depth : hint_range(0.0, 1.0) = 0.0; // Set via script based on Z-index
uniform vec3 fog_color : source_color = vec3(0.05, 0.07, 0.1);
uniform float fog_max_density : hint_range(0.0, 1.0) = 0.8;

// --- FUNCTIONS ---

void fragment() {
	vec4 diffuse = texture(TEXTURE, UV);
	vec3 normal_tex = texture(normal_map, UV).rgb;
	vec4 emissive_tex = texture(emissive_mask, UV);
	
	// 1. DISCARD TRANSPARENCY (Optimization)
	if (diffuse.a < 0.01) discard;

	// 2. NORMAL MAPPING & LIGHTING (The AAA "Pop")
	// This makes your 2D sprites react to Godot Light2D nodes like 3D objects.
	vec3 normal = normalize(mix(vec3(0.5, 0.5, 1.0), normal_tex, normal_strength) * 2.0 - 1.0);
	
	// 3. RIM LIGHTING
	// Logic: If the pixel is at the edge of the alpha mask, add a highlight.
	if (enable_rim) {
		float size_x = rim_width * fwidth(UV.x);
		float size_y = rim_width * fwidth(UV.y);
		float au = texture(TEXTURE, UV + vec2(0.0, -size_y)).a;
		float ad = texture(TEXTURE, UV + vec2(0.0, size_y)).a;
		float al = texture(TEXTURE, UV + vec2(-size_x, 0.0)).a;
		float ar = texture(TEXTURE, UV + vec2(size_x, 0.0)).a;
		float edge = 4.0 * diffuse.a - au - ad - al - ar;
		diffuse.rgb += clamp(edge, 0.0, 1.0) * rim_color.rgb * rim_color.a;
	}

	// 4. EMISSIVE GLOW (Magic / Runes)
	float pulse = 1.0 + (sin(TIME * pulse_speed) * 0.2);
	vec3 glow = emissive_tex.rgb * emissive_tint.rgb * emissive_intensity * pulse;
	diffuse.rgb += glow;

	// 5. DEPTH FOG (Atmospheric Perspective)
	// Darkens and desaturates objects further "back" in the world.
	float fog_factor = world_depth * fog_max_density;
	diffuse.rgb = mix(diffuse.rgb, fog_color, fog_factor);

	// 6. FINAL COLOR GRADING (Per-Material)
	// Apply a slight "S-Curve" to give it that cinematic punch
	diffuse.rgb = smoothstep(0.0, 1.0, diffuse.rgb);

	COLOR = diffuse;
	
	// Pass the normal to Godot's Light2D engine
	NORMAL = normal;
}