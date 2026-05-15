# res://Player/Logic/Hitbox&Hurtbox/Scripts/hurtbox.gd
extends Area2D
class_name Hurtbox

signal damage_taken(amount: float, knockback: float, hitbox_pos: Vector2, poise_damage: float)

@export var i_frames_active: bool = false

func _ready():
	# Hurtboxes don't need to look for anything, they just need to be SEEN
	monitoring = false
	monitorable = true

func take_hit(amount: float, knockback: float, source_pos: Vector2, p_damage: float):
	if i_frames_active:
		return
	damage_taken.emit(amount, knockback, source_pos, p_damage)
