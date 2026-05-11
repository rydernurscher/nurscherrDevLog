# res://NPC/Wisp/Scripts/Wisp.gd
extends Node2D

@export_group("Follow Settings")
@export var target_node: Node2D
@export var acceleration: float = 220.0    # Speed of "catching up"
@export var friction: float = 2.8         # How much it drifts/overshoots
@export var max_speed: float = 450.0      # Maximum chase velocity
@export var orbit_radius: float = 55.0
@export var orbit_speed: float = 1.8

@export_group("Visual Settings")
@export var light_color: Color = Color("#4df7ff") # Spectral Teal
@export var glow_intensity: float = 2.8          # HDR Multiplier for Bloom bleed
@export var base_energy: float = 0.9
@export var flicker_intensity: float = 0.12
@export var pulse_speed: float = 1.5

var _velocity: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _light: PointLight2D
var _particles: GPUParticles2D

func _ready() -> void:
	# Priority setup
	_setup_light()
	_setup_particles()
	
	if not target_node:
		# Fallback to player group
		target_node = get_tree().get_first_node_in_group("Player")
	
	# Set starting position to target to avoid a wild zip on spawn
	if target_node:
		global_position = target_node.global_position

func _setup_light() -> void:
	_light = PointLight2D.new()
	add_child(_light)
	
	# Procedural radial gradient for smooth "Bleed"
	var grad = Gradient.new()
	grad.offsets = [0.0, 0.15, 0.7, 1.0]
	grad.colors = [
		Color.WHITE,               # Core center
		Color(0.8, 0.8, 0.8, 1.0), # Bright inner ring
		Color(0.1, 0.1, 0.1, 1.0), # Soft falloff
		Color.BLACK                # Edge (0 energy)
	]
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0) 
	tex.width = 256
	tex.height = 256
	
	_light.texture = tex
	_light.texture_scale = 1.8
	_light.color = light_color * glow_intensity # Applying HDR for Bloom
	_light.energy = base_energy
	_light.shadow_enabled = true
	_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF13

func _setup_particles() -> void:
	_particles = GPUParticles2D.new()
	add_child(_particles)
	_particles.amount = 40
	_particles.process_material = _create_particle_material()
	_particles.lifetime = 1.5
	# Trail effect: Particles stay in the world, not stuck to the wisp
	_particles.local_coords = false 

func _process(delta: float) -> void:
	if not target_node: return
	
	_time += delta
	_handle_physics_movement(delta)
	_handle_visuals(delta)

func _handle_physics_movement(delta: float) -> void:
	# 1. Calculate the "Ideal" destination (Orbit + Bobbing)
	var orbit_offset = Vector2(
		cos(_time * orbit_speed),
		sin(_time * orbit_speed) * 0.5 # Elliptical
	) * orbit_radius
	
	# Organic vertical sway
	orbit_offset.y += sin(_time * 2.2) * 12.0
	
	var target_pos = target_node.global_position + orbit_offset
	
	# 2. Physics Logic: Velocity-based chasing
	var direction = global_position.direction_to(target_pos)
	var distance = global_position.distance_to(target_pos)
	
	# "Less Forgiving" ramp: Wisp accelerates harder as it gets left behind
	var aggression = clamp(distance / 80.0, 0.4, 2.5)
	
	if distance > 4.0: # Deadzone to stop micro-jitter
		_velocity += direction * acceleration * aggression * delta
	
	# 3. Apply Friction/Drag
	_velocity -= _velocity * friction * delta
	
	# 4. Speed Limit
	if _velocity.length() > max_speed:
		_velocity = _velocity.limit_length(max_speed)
	
	# 5. Position Update
	global_position += _velocity * delta

func _handle_visuals(_delta: float) -> void:
	# High-frequency flicker + low-frequency pulse
	var flicker = sin(_time * 18.0) * cos(_time * 9.0) * flicker_intensity
	var pulse = sin(_time * pulse_speed) * 0.08
	
	_light.energy = base_energy + flicker + pulse
	
	# Subtle "stretching" effect based on speed
	var stretch = (_velocity.length() / max_speed) * 0.2
	_light.texture_scale = 1.8 + pulse + stretch

func _create_particle_material() -> ParticleProcessMaterial:
	var mat = ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, -15, 0) # Drift upwards slowly
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 4.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 20.0
	mat.damping_min = 3.0
	mat.damping_max = 6.0
	mat.scale_min = 0.4
	mat.scale_max = 1.2
	
	# Color fading out over life
	var grad = Gradient.new()
	grad.set_color(0, Color(light_color.r, light_color.g, light_color.b, 1.0))
	grad.set_color(1, Color(light_color.r, light_color.g, light_color.b, 0.0))
	var tex = GradientTexture1D.new()
	tex.gradient = grad
	mat.color_ramp = tex
	
	return mat
