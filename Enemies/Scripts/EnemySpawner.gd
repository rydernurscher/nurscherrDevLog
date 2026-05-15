extends Node2D
class_name EnemySpawner

@export_group("Spawner Settings")
@export var enemy_scene: PackedScene
@export var player: Node2D
@export var max_enemies: int = 5
@export var spawn_interval: float = 3.0

@export_group("Spawn Distances")
@export var min_spawn_x: float = 400.0 # Minimum distance off-screen horizontally
@export var max_spawn_x: float = 800.0 # Maximum distance off-screen horizontally
@export var raycast_height: float = 600.0 # How far above the player to start looking for ground

# The physics layer your terrain is on (usually 1 by default)
@export_flags_2d_physics var terrain_mask: int = 1 

var _spawn_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not player or not enemy_scene: 
		return
	
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_attempt_spawn()

func _attempt_spawn() -> void:
	# 1. Check if we have hit the enemy cap
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	if current_enemies >= max_enemies:
		return
		
	# 2. Pick a random direction (left or right) and distance
	var dir = 1 if randi() % 2 == 0 else -1
	var dist_x = randf_range(min_spawn_x, max_spawn_x)
	var spawn_x = player.global_position.x + (dir * dist_x)
	
	# 3. Raycast downwards to find the floor
	var ray_start = Vector2(spawn_x, player.global_position.y - raycast_height)
	var ray_end = Vector2(spawn_x, player.global_position.y + raycast_height)
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = terrain_mask
	
	var result = space_state.intersect_ray(query)
	
	# 4. If we hit the ground, spawn the enemy!
	if result:
		var spawn_pos = result.position
		# Offset slightly upwards so they don't spawn stuck in the floor
		spawn_pos.y -= 15.0 
		
		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_pos
		
		# Add the enemy to the spawner's parent (usually the World node)
		get_parent().add_child(enemy)
