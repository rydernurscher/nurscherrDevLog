# world_generator.gd
extends Node2D
class_name WorldGenerator

@export var map_width: int = 1200
@export var map_height: int = 500
@export var chunk_width: int = 100 # Determines how wide each chunk section is
@export var surface_level: int = 50
@export var player_node: CharacterBody2D 
@export var surface_amplitude: int = 15 
@export var surface_frequency: float = 0.03 

# Surface Structures
@export var small_surface_structures: Array[PackedScene] 
@export var structure_spawn_chance: float = 0.03 
@export var min_structure_distance: int = 30 

@onready var base_layer: TileMapLayer = $ForegroundLayer

var surface_noise: FastNoiseLite
var cave_noise: FastNoiseLite
var stone_noise: FastNoiseLite 

# Dictionary to hold our chunk instances
var chunks: Dictionary = {} 

const TILE_DIRT_SOURCE_ID = 0
const TILE_STONE_SOURCE_ID = 1
const TILE_GRASS_SOURCE_ID = 0
const DIRT_ATLAS = Vector2i(5, 0)
const STONE_ATLAS = Vector2i(1, 1) 
const GRASS_ATLAS = Vector2i(1, 0)

func _ready():
	# Hide the base layer so it purely acts as a template
	base_layer.hide() 
	_initialize_noise()
	generate_world()
	generate_surface_structures()
	spawn_player()

func _initialize_noise():
	randomize()
	var seed_value = randi()
	
	surface_noise = FastNoiseLite.new()
	surface_noise.seed = seed_value
	surface_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	surface_noise.frequency = surface_frequency 

	cave_noise = FastNoiseLite.new()
	cave_noise.seed = seed_value
	cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cave_noise.frequency = 0.04
	
	stone_noise = FastNoiseLite.new()
	stone_noise.seed = seed_value + 1 
	stone_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	stone_noise.frequency = 0.06 

# --- NEW CHUNK MANAGER ---
func get_or_create_chunk(x_pos: int) -> TileMapLayer:
	# Calculate which chunk this X coordinate belongs to (e.g., x=150 is chunk 1)
	var chunk_id = floor(x_pos / float(chunk_width))
	
	if chunks.has(chunk_id):
		return chunks[chunk_id]
		
	# If chunk doesn't exist, duplicate the base layer to copy your TileSet and Physics
	var new_chunk = base_layer.duplicate()
	new_chunk.name = "Chunk_" + str(chunk_id)
	new_chunk.show()
	add_child(new_chunk)
	chunks[chunk_id] = new_chunk
	
	return new_chunk

func generate_world():
	# Clean up old chunks if regenerating
	for chunk in chunks.values():
		chunk.queue_free()
	chunks.clear()
	
	for x in range(map_width):
		var current_surface_y = surface_level + int(surface_noise.get_noise_1d(x) * 15)
		
		# Grab the correct TileMapLayer for this specific X column
		var active_chunk = get_or_create_chunk(x)
		
		for y in range(map_height):
			if y < current_surface_y:
				continue 
				
			var is_cave = false
			var depth = y - current_surface_y
			var cave_threshold = 0.0
			
			if depth < 4:
				cave_threshold = 0.45 
			elif depth < 20:
				cave_threshold = 0.25
			else:
				cave_threshold = 0.10
				
			if cave_noise.get_noise_2d(x, y) > cave_threshold:
				is_cave = true
					
			if not is_cave:
				var current_source = TILE_DIRT_SOURCE_ID
				var current_atlas = DIRT_ATLAS
				
				if y == current_surface_y:
					current_source = TILE_GRASS_SOURCE_ID
					current_atlas = GRASS_ATLAS
				elif y > current_surface_y + 3:
					if stone_noise.get_noise_2d(x, y) > 0.10:
						current_source = TILE_STONE_SOURCE_ID
						current_atlas = STONE_ATLAS
				
				# Place the tile into the specific chunk instead of the base layer
				active_chunk.set_cell(Vector2i(x, y), current_source, current_atlas)

func generate_surface_structures():
	if small_surface_structures.is_empty(): return
	var last_spawn_x = -min_structure_distance
	for x in range(map_width):
		if x - last_spawn_x < min_structure_distance: continue
		if randf() < structure_spawn_chance:
			var surface_y = surface_level + int(surface_noise.get_noise_1d(x) * 15)
			var structure_scene = small_surface_structures.pick_random()
			var structure_instance = structure_scene.instantiate()
			add_child(structure_instance)
			var spawn_pos_map = Vector2i(x, surface_y - 1)
			structure_instance.global_position = base_layer.map_to_local(spawn_pos_map)
			last_spawn_x = x

func spawn_player():
	if not player_node: return
	var spawn_x = map_width / 2
	var spawn_y = surface_level + int(surface_noise.get_noise_1d(spawn_x) * 15)
	var spawn_pos_map = Vector2i(spawn_x, spawn_y - 2)
	player_node.global_position = base_layer.map_to_local(spawn_pos_map)
