# hurtbox.gd
extends Area2D
class_name Hurtbox

# Custom signal to tell the parent node it got hit
signal damage_taken(amount: float, knockback: float)

@export var i_frames_active: bool = false

func _on_area_entered(area: Area2D):
	# If we are dodging, ignore the hit entirely!
	if i_frames_active:
		return
		
	# Check if the area that entered us is actually a Hitbox
	if area is Hitbox:
		# Emit the signal to whatever parent this hurtbox is attached to
		damage_taken.emit(area.damage, area.knockback_force)
		print("Hurtbox took ", area.damage, " damage!")
