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

func update_health(new_value):
	health_bar.value = new_value

func update_mana(new_value):
	mana_bar.value = new_value

func update_stamina(new_value):
	stamina_bar.value = new_value
