extends Control

func _ready():
# Ensure the UI can be navigated with a keyboard/controller
	$VBoxContainer/StartButton.grab_focus()

func _on_start_button_pressed():
	GameManager.start_game()

func _on_quit_button_pressed():
	get_tree().quit()
