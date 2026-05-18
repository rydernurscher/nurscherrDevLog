extends CanvasLayer

# Grab the bars using the exact path to your nodes
@onready var health_bar = $MarginContainer/VBoxContainer/HealthBar
@onready var mana_bar = $MarginContainer/VBoxContainer/ManaBar
@onready var stamina_bar = $MarginContainer/VBoxContainer/StaminaBar

# These functions will be called when the player's stats change
func set_max_stats(max_hp, max_fp, max_sp):
	health_bar.max_value = max_hp
	mana_bar.max_value = max_fp
	stamina_bar.max_value = max_sp

func update_health(val):
	var tween = create_tween()
	tween.tween_property(health_bar, "value", val, 0.2)
	var ratio = val / health_bar.max_value
	health_bar.material.set_shader_parameter("health_ratio", ratio)

func update_mana(new_value):
	var tween = create_tween()
	tween.tween_property(mana_bar, "value", new_value, 0.2)

func update_stamina(new_value):
	var tween = create_tween()
	tween.tween_property(stamina_bar, "value", new_value, 0.1)
