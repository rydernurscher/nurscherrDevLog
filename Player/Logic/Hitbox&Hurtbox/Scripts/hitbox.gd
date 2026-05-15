# res://Player/Logic/Hitbox&Hurtbox/Scripts/hitbox.gd
extends Area2D
class_name Hitbox

@export var damage: float = 10.0
@export var knockback_force: float = 100.0
@export var poise_damage: float = 20.0

# We use this to prevent hitting the same enemy multiple times in one swing
var hit_list: Array[Hurtbox] = []

func _ready():
	# Hitboxes should LOOK (monitor) but don't need to be LOOKED AT (monitorable)
	monitoring = true
	monitorable = false
	enabled_hitbox(false)

func enabled_hitbox(is_enabled: bool):
	# Using set_deferred is safer for physics properties
	set_deferred("monitoring", is_enabled)
	# Clear the list when we start a new attack
	if is_enabled:
		hit_list.clear()

func _physics_process(_delta):
	if not monitoring:
		return
	
	# Every physics frame the attack is active, we check who is inside
	# This works for stationary enemies because it checks the OVERLAP, not the ENTERING
	var overlaps = get_overlapping_areas()
	for area in overlaps:
		if area is Hurtbox and not hit_list.has(area):
			_apply_hit(area)

func _apply_hit(hurtbox: Hurtbox):
	hit_list.append(hurtbox)
	hurtbox.take_hit(damage, knockback_force, global_position, poise_damage)
