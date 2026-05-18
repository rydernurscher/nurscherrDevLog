extends Camera2D

@export var max_roll: float = 0.03 # Max rotation in radians (slight tilt)
@export var max_offset: Vector2 = Vector2(8, 8) # Max horizontal/vertical shake pixels

var shake_strength: float = 0.0 # Current shake value in pixels
var decay_rate: float = 5.0 # How fast the shake stops (higher = faster stop)

func _ready() -> void:
	# Keep your global signal bus connection
	SignalBus.shake_requested.connect(add_shake)

func _process(delta: float) -> void:
	if shake_strength > 0:
		# Linearly decay the absolute pixel strength over time
		shake_strength = move_toward(shake_strength, 0.0, decay_rate * delta * 10.0)
		_apply_shake()
	else:
		# Force back to pristine center when done
		offset = Vector2.ZERO
		rotation = 0

func add_shake(intensity: float, duration: float) -> void:
	# Map intensity directly to actual pixel weight
	# An intensity of 0.5 * 10 = 5 pixels of aggressive displacement
	shake_strength = clamp(shake_strength + (intensity * 10.0), 0.0, 15.0)

func _apply_shake() -> void:
	# Pure, rapid, reliable calculation using engine randf_range
	# This guarantees non-zero rapid displacement every single frame
	rotation = max_roll * (shake_strength / 10.0) * randf_range(-1.0, 1.0)
	offset.x = randf_range(-shake_strength, shake_strength)
	offset.y = randf_range(-shake_strength, shake_strength)
