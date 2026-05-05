# hitbox.gd
extends Area2D
class_name Hitbox

@export var damage: float = 10.0
@export var knockback_force: float = 100.0

func _ready():
	# Hitboxes don't need to monitor their surroundings, 
	# they only need to be monitorable BY Hurtboxes.
	monitoring = false
