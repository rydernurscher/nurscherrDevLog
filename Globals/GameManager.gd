extends Node
const MAIN_MENU_PATH = "res://UI/MainMenu.tscn"
const WORLD_SCENE_PATH = "res://World/WorldTerrain/Scenes/World.tscn"
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
func start_game():
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)
func return_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
func game_over():
	print("Player Died! Game Over.")
# In the future, we will instance a GameOver UI overlay here
# For now, we will just return to the main menu after a short delay
	await get_tree().create_timer(1.5).timeout
	return_to_menu()
