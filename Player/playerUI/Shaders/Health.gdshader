// res://Player/playerUI/Shaders/Health.gdshader
shader_type canvas_item;

uniform vec4 color_deep : source_color = vec4(0.4, 0.0, 0.0, 1.0);
uniform vec4 color_bright : source_color = vec4(1.0, 0.1, 0.1, 1.0);
uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 p = UV * vec2(5.0, 1.0);
    
    // Pulse speed increases as health drops
    float danger_speed = (1.0 - health_ratio) * 5.0 + 1.2;
    
    float wave1 = sin(p.x + cos(p.y * 1.5 + TIME * danger_speed));
    float wave2 = cos(p.y + sin(p.x * 1.2 - TIME * danger_speed));
    
    float fluid = smoothstep(0.2, 0.8, (wave1 + wave2) * 0.25 + 0.5);
    
    // Intense heartbeat when low health
    float pulse = (sin(TIME * (danger_speed * 2.0)) * 0.5 + 0.5) * (1.0 - health_ratio);
    
    vec3 final_color = mix(color_deep.rgb, color_bright.rgb, fluid + pulse);
    COLOR = vec4(final_color, texture(TEXTURE, UV).a);
}