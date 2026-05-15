# res://World/WorldTerrain/Scripts/world.gd
extends Node2D
class_name WorldGenerator


@export_group("World Size")
@export var map_width: int = 1200
@export var map_height: int = 500
@export var chunk_width: int = 32

@export_group("Generation Stats")
@export var surface_level: int = 60
@export var surface_amplitude: int = 15
@export var surface_frequency: float = 0.015
@export var lamp_spacing: int = 25 # How many tiles between lamps

# Structures Dictionary
@export var structures: Dictionary = {
	"spawnStructure": {
		"scene": preload("res://World/Structures/Scenes/SpawnStructure.tscn"),
		"limit": 1,
		"chance": 1.0,
	},
	
	# ---
	
	# ---
}


@export_group("References")
@export var player_node: CharacterBody2D
@onready var base_layer: TileMapLayer = $ForegroundLayer
@onready var wall_base_layer: TileMapLayer = get_node_or_null("BackgroundLayer")
@onready var foliage_template: TileMapLayer = get_node_or_null("FoliageLayer")
@export var background_music: AudioStreamMP3



# Master data dictionary
var world_data: Dictionary = {}
var wall_data: Dictionary = {}
var chunks: Dictionary = {}
var wall_chunks: Dictionary = {}
var foliage_chunks: Dictionary = {}
var lightPosts: PackedScene = preload( "res://World/Structures/Scenes/lampPost1.tscn",

)

const MINING_THRESHOLD_DEPTH = 160

var surface_noise: FastNoiseLite
var cave_noise: FastNoiseLite
var ruin_noise = FastNoiseLite
var biome_noise = FastNoiseLite

# BIOMES
enum BiomeType { FOREST, RUINS, CRIMSON }

# Define blocks and styles per biome
const BIOME_SETTINGS = {
	BiomeType.FOREST: {
		"main_block": 0, # Grass/Dirt source ID
		"brick_chance": 0.05,
		"foliage_density": 0.8,
		"bg_wall": Vector2i(3, 2)
	},
	BiomeType.RUINS: {
		"main_block": 2, # Stone Brick source ID
		"brick_chance": 0.6,
		"foliage_density": 0.3,
		"bg_wall": Vector2i(2, 1)
	},
	BiomeType.CRIMSON: {
		"main_block": 0, # Red Grass
		"brick_chance": 0.0,
		"foliage_density": 0.5,
		"bg_wall": Vector2i(4, 2)
	}
}

# Mapping for 0-15 bitmask
const MASK_MAP = {
# --- Standard Cardinal Set ---
	15: Vector2i(3, 4), 
	14: Vector2i(3, 3), 
	13: Vector2i(3, 5),
	11: Vector2i(2, 4), 
	7:  Vector2i(4, 4), 
	10: Vector2i(2, 3),
	6:  Vector2i(4, 3), 
	9:  Vector2i(2, 5), 
	5:  Vector2i(4, 5),
	
	# --- Cap/Line Set ---
	0:  Vector2i(1, 6), # Isolated
	3:  Vector2i(1, 4), # Vertical Line
	12: Vector2i(3, 6), # Horizontal Line
	1:  Vector2i(1, 5), # Bottom Cap
	2:  Vector2i(1, 3), # Top Cap
	4:  Vector2i(4, 6), # Right Cap
	8:  Vector2i(2, 6), # Left Cap
	
	# --- Inner Corners  ---
	100: Vector2i(6, 4), # Inner Top-Left
	101: Vector2i(5, 4), # Inner Top-Right
	102: Vector2i(6, 3), # Inner Bottom-Left
	103: Vector2i(5, 3)  # Inner Bottom-Right
}

const STONE_BRICK_MASK_MAP = {
# --- Standard Cardinal Set ---
	15: Vector2i(2, 2), # Centre
	14: Vector2i(2, 1), # Top-middle
	13: Vector2i(2, 3), # Bottom-middle
	11: Vector2i(1, 2), # Middle-left
	7:  Vector2i(3, 2), # Middle-right
	10: Vector2i(1, 1), # Top-left
	6:  Vector2i(3, 1), # Top-right
	9:  Vector2i(1, 3), # Bottom-left
	5:  Vector2i(3, 3), # Bottom-right
	
	# --- Cap/Line Set ---
	0:  Vector2i(0, 4), # Isolated
	3:  Vector2i(0, 2), # Vertical Line
	12: Vector2i(2, 4), # Horizontal Line
	1:  Vector2i(0, 3), # Bottom Cap
	2:  Vector2i(0, 1), # Top Cap
	4:  Vector2i(3, 4), # Right Cap
	8:  Vector2i(1, 4), # Left Cap
	
	# --- Inner Corners ---
	100: Vector2i(5, 2), # Inner Top-Left
	101: Vector2i(4, 2), # Inner Top-Right
	102: Vector2i(5, 1), # Inner Bottom-Left
	103: Vector2i(4, 1)  # Inner Bottom-Right
}

const WALL_MASK_MAP = {
	15: Vector2i(3, 2), 
	14: Vector2i(3, 1), 
	13: Vector2i(3, 3),
	11: Vector2i(4, 2), 
	7:  Vector2i(2, 2), 
	10: Vector2i(2, 1),
	6:  Vector2i(4, 1), 
	9:  Vector2i(2, 3), 
	5:  Vector2i(4, 3), 
	0: Vector2i(3, 2) # UNUSED ATM
}
const FOLIAGE_MAP = {
	
	1: Vector2i(1,2), # Purple Flower
	2: Vector2i(2,2), # Grass Blade 1
	3: Vector2i(3,2), # Sunflower
	4: Vector2i(4,2), # Grass Blade 2
	5: Vector2i(5,2), # Grass Blade 3
	6: Vector2i(6,2), # Jasmine Flower
	7: Vector2i(7,2), # Jasmine Flower
	8: Vector2i(8,2), # Jasmine Flower
	9: Vector2i(0,2), # Fluffy Grass

}

func _ready():
	base_layer.hide()
	if wall_base_layer: wall_base_layer.hide()
	if foliage_template: foliage_template.hide()
	
	add_to_group("generator")
	
	_initialize_noise()
	
	generate_world()
	
	@warning_ignore("integer_division")
	var mid_x = map_width / 2
	var mid_y = surface_level + int(surface_noise.get_noise_1d(mid_x) * surface_amplitude)
	spawn_named_structure("spawnStructure", Vector2i(mid_x, mid_y), 25) # 9 tiles wide flat area
	
	_spawn_random_structures()
	
	spawn_player()
	
	manage_music() # Function for playing music, only plays one set song as of now.

func _initialize_noise():
	randomize()
	var s = randi()
	surface_noise = FastNoiseLite.new()
	surface_noise.seed = s
	surface_noise.frequency = surface_frequency
	
	cave_noise = FastNoiseLite.new()
	cave_noise.seed = s + 1
	cave_noise.frequency = 0.033
	
	ruin_noise = FastNoiseLite.new()
	ruin_noise.seed = randi()
	ruin_noise.frequency = 0.0078
	
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = randi()
	biome_noise.frequency = 0.005 # Low frequency = Large biomes
	

func get_biome_at(x: int) -> BiomeType:
	var val = biome_noise.get_noise_1d(x)
	
	if val < -0.2:
		return BiomeType.CRIMSON
	elif val < 0.2:
		return BiomeType.FOREST
	else:
		return BiomeType.RUINS


func generate_world():
	for c in chunks.values(): c.queue_free()
	for c in wall_chunks.values(): c.queue_free()
	chunks.clear()
	wall_chunks.clear()
	world_data.clear()
	wall_data.clear()
	
	# PASS 1: Logic
	for x in range(map_width):
		var surf_y = surface_level + int(surface_noise.get_noise_1d(x) * surface_amplitude)
		for y in range(surf_y, map_height):
			if not _is_cave(x, y, surf_y):
				world_data[Vector2i(x, y)] = true
		for y in range(surf_y + 3, map_height):
			wall_data[Vector2i(x, y)] = true
	
	# PASS 2: Visuals
	for x in range(map_width):
		var active_chunk = get_or_create_chunk(x)
		var active_wall_chunk = get_or_create_wall_chunk(x)
		
		# Determine Biome for this column
		var current_biome = get_biome_at(x)
		@warning_ignore("unused_variable")
		var settings = BIOME_SETTINGS[current_biome]
		
		
		var surf_y_tile = surface_level + int(surface_noise.get_noise_1d(x) * surface_amplitude)
		
		for y in range(map_height):
			var pos = Vector2i(x, y)
			
			
			if world_data.has(pos):
				var tile_depth = y - surf_y_tile
				var mask = _get_bitmask(pos, world_data)
				
				# --- CLUSTER LOGIC ---
					# Get noise value for this specific tile (-1.0 to 1.0)
				var brick_value = ruin_noise.get_noise_2d(x, y)
			
				if tile_depth <= 4 and brick_value > 0.1:
					active_chunk.set_cell(pos, 2, STONE_BRICK_MASK_MAP.get(mask, Vector2i(2, 2)))
				else:
				# Normal Dirt/Grass
					active_chunk.set_cell(pos, 0, MASK_MAP.get(mask, Vector2i(3, 4)))
			
		
				
			if wall_data.has(pos):
				var mask = _get_bitmask(pos, wall_data)
				active_wall_chunk.set_cell(pos, 1, WALL_MASK_MAP.get(mask, Vector2i(3, 2)))
	
	# Foliage Pass 
		var surf_y = surface_level + int(surface_noise.get_noise_1d(x) * surface_amplitude)
		var surf_pos = Vector2i(x, surf_y)
		
		var tile_data = active_chunk.get_cell_tile_data(surf_pos)
		var can_grow = false
		if tile_data:
			can_grow = tile_data.get_custom_data("can_grow_foliage")

		if foliage_template and can_grow:
			if randf() < 0.8:
				var foliage_atlas_pos = FOLIAGE_MAP[(randi() % FOLIAGE_MAP.size()) + 1]
				var source_id = 0
				if randf() < 0.05: # 10% chance
					source_id = 5
					if source_id == 5:
						foliage_atlas_pos = Vector2i(0,0)
						

							
				var f_chunk = get_or_create_foliage_chunk(x)
				var alt_id = TileSetAtlasSource.TRANSFORM_FLIP_H if randf() < 0.5 else 0
				f_chunk.set_cell(Vector2i(x, surf_y - 1), source_id, foliage_atlas_pos, alt_id)
		
	
		if x % lamp_spacing == 0 and can_grow:
			spawn_lamp_post(Vector2i(x, surf_y))
	

func _process(_delta):
	# Manual visibility chunking removed:
	# Godot's TileMapLayer automatically uses spatial indexing (quadrants) to 
	# efficiently cull off-screen tiles. Setting visible = true on massive chunks 
	# forces sudden rendering batch rebuilds, causing stuttering frame drops.
	pass
		
func spawn_lamp_post(grid_pos: Vector2i):
	
	if not lightPosts: return
	
	var lamp = lightPosts.instantiate()
	
			# Convert grid coordinates to world pixels
			# Assuming 16px tiles; adjust if your tiles are 8 or 32!
	var world_pos = Vector2(grid_pos.x * 16, grid_pos.y * 16)
	
			# Add it to the scene
	add_child(lamp)
	lamp.position = world_pos
	
			# Optional: Slight offset so the post sits "in" the ground properly
	lamp.position.y -= 48
			
func update_tile_at(map_pos: Vector2i):
	var chunk_id = floor(map_pos.x / float(chunk_width))
	if !chunks.has(chunk_id): return
	
	var chunk = chunks[chunk_id]
	if !world_data.has(map_pos):
		chunk.set_cell(map_pos, -1) # Clear visual tile
		return

	# This MUST use the logic that checks diagonals now
	var mask = _get_bitmask(map_pos, world_data)
	chunk.set_cell(map_pos, 0, MASK_MAP.get(mask, Vector2i(3, 4)))
	
# Converts a global X pixel position into the noise-based Y pixel height
func get_surface_y_at_x(pixel_x: float) -> float:
	# 1. Convert pixel position to tile coordinate
	var tile_x = int(pixel_x / 16.0) # Assuming 16px tiles
	
	# 2. Re-run the noise formula used in generation
	var surf_y_tile = surface_level + int(surface_noise.get_noise_1d(tile_x) * surface_amplitude)
	
	# 3. Convert back to pixels
	return surf_y_tile * 16.0
	
func can_player_mine_at(target_position: Vector2) -> bool:
	# 1. Get the surface height at this specific X coordinate
	var surface_y = get_surface_y_at_x(target_position.x)
	
	# 2. Calculate the distance between the target block and the surface
	# In Godot, Y increases as you go down.
	var depth_below_surface = target_position.y - surface_y
	
	# 3. Check if the block is deep enough
	if depth_below_surface >= MINING_THRESHOLD_DEPTH:
		return true # Player is deep enough to break blocks
	else:
		# Optional: Trigger a "clink" sound or sparks to show it's unbreakable
		return false
	

func manage_music():
	if background_music:
		var music_player = AudioStreamPlayer.new()
		add_child(music_player)
		music_player.stream = background_music
		music_player.volume_db = -15.0
		music_player.play()
	else:
		push_error("Don't forget to drag MP3 into the Inspector!")
		
func spawn_named_structure(structure_key: String, tile_pos: Vector2i, flat_width: int = 7):
	if not structures.has(structure_key):
		push_error("Structure key not found: " + structure_key)
		return

	var data = structures[structure_key]
	var scene = data["scene"]
	
	if scene:
		# 1. Bulldoze the area in the data
		@warning_ignore("integer_division")
		var start_x = tile_pos.x - (flat_width / 2)
		var target_y = tile_pos.y
		
		for x in range(start_x, start_x + flat_width):
			# Clear air above
			for y in range(target_y - 15, target_y):
				world_data.erase(Vector2i(x, y))
			# Fill solid ground below (foundation)
			for y in range(target_y, target_y + 6):
				world_data[Vector2i(x, y)] = true
		
		# 2. Instantiate the building
		var instance = scene.instantiate()
		add_child(instance)
		instance.global_position = base_layer.map_to_local(tile_pos)
		
		# 3. Force visual update for the "Bulldozed" area
		# We go slightly wider/taller than the flat area to fix bitmasks
		_update_visuals_for_area(start_x - 2, target_y - 16, flat_width + 4, 25)
		
		print("Spawned ", structure_key, " at ", tile_pos)
		
func _update_visuals_for_area(x_start: int, y_start: int, w: int, h: int):
	for x in range(x_start, x_start + w):
		# Important: Get the correct chunk for this X coordinate
		var active_chunk = get_or_create_chunk(x)
		if not active_chunk: continue
		
		for y in range(y_start, y_start + h):
			var pos = Vector2i(x, y)
			if world_data.has(pos):
				var mask = _get_bitmask(pos, world_data)
				# Use your MASK_MAP to redraw the tile correctly
				active_chunk.set_cell(pos, 0, MASK_MAP.get(mask, Vector2i(3, 4)))
			else:
				# If it's no longer in world_data, delete the tile
				active_chunk.set_cell(pos, -1)

func _can_place_on_tile(pos: Vector2i) -> bool:
	# 1. Get the tile's atlas coordinates from the base layer
	var atlas_coords = base_layer.get_cell_atlas_coords(pos)
	
	# 2. If the cell is empty (-1, -1), we obviously can't grow anything
	if atlas_coords == Vector2i(-1, -1): return false
	
	# 3. Get the TileData object for that specific tile in the TileSet
	var tile_data = base_layer.tile_set.get_source(0).get_tile_data(atlas_coords, 0)
	
	if tile_data:
		# 4. Return the boolean value from your Custom Data Layer
		return tile_data.get_custom_data("can_grow_foliage")
	return false


func _spawn_random_structures():
	# Spawns your custom structures automatically across the world
	for key in structures.keys():
		if key == "spawnStructure": continue
		
		var data = structures[key]
		var limit = data.get("limit", 1)
		var chance = data.get("chance", 0.1)
		
		var spawned = 0
		for x in range(10, map_width - 10, 40): # Spacing to avoid overlap
			if spawned >= limit: break
			if randf() <= chance:
				var surf_y = surface_level + int(surface_noise.get_noise_1d(x) * surface_amplitude)
				spawn_named_structure(key, Vector2i(x, surf_y))
				spawned += 1

func _is_cave(x, y, surf_y) -> bool:
	var depth = y - surf_y
	var threshold = 0.45 if depth < 5 else (0.2 if depth < 15 else 0.1)
	return cave_noise.get_noise_2d(x, y) > threshold

func _get_bitmask(pos: Vector2i, data_set: Dictionary) -> int:
	var mask = 0
	# Cardinal Checks
	var top    = data_set.has(pos + Vector2i.UP)
	var bottom = data_set.has(pos + Vector2i.DOWN)
	var left   = data_set.has(pos + Vector2i.LEFT)
	var right  = data_set.has(pos + Vector2i.RIGHT)
	
	if top:    mask |= 1
	if bottom: mask |= 2
	if left:   mask |= 4
	if right:  mask |= 8
	
	# Inner Corner Logic
	# If we have cardinal neighbors but are MISSING a diagonal, we override the mask
	if mask == 15: # Full Cardinal Surround
		if not data_set.has(pos + Vector2i(-1, -1)): return 100 # Inner Top-Left missing
		if not data_set.has(pos + Vector2i(1, -1)):  return 101 # Inner Top-Right missing
		if not data_set.has(pos + Vector2i(-1, 1)):  return 102 # Inner Bottom-Left missing
		if not data_set.has(pos + Vector2i(1, 1)):   return 103 # Inner Bottom-Right missing
		
	# Specific corner cases (e.g. L-shapes)
	if mask == 10 and not data_set.has(pos + Vector2i(1, 1)):   return 103 # Bottom-Right inner
	if mask == 6  and not data_set.has(pos + Vector2i(-1, 1)):  return 102 # Bottom-Left inner
	if mask == 9  and not data_set.has(pos + Vector2i(1, -1)):  return 101 # Top-Right inner
	if mask == 5  and not data_set.has(pos + Vector2i(-1, -1)): return 100 # Top-Left inner
	
	return mask

func get_or_create_chunk(x_pos: int) -> TileMapLayer:
	var id = floor(x_pos / float(chunk_width))
	if chunks.has(id): return chunks[id]
	var new_chunk = base_layer.duplicate()
	new_chunk.name = "Chunk_" + str(id)
	new_chunk.show()
	add_child(new_chunk)
	chunks[id] = new_chunk
	return new_chunk

func get_or_create_wall_chunk(x_pos: int) -> TileMapLayer:
	var id = floor(x_pos / float(chunk_width))
	if wall_chunks.has(id): return wall_chunks[id]
	var template = wall_base_layer if wall_base_layer else base_layer
	var new_chunk = template.duplicate()
	new_chunk.name = "WallChunk_" + str(id)
	new_chunk.show()
	new_chunk.z_index = 3 # Behind foreground
	add_child(new_chunk)
	wall_chunks[id] = new_chunk
	return new_chunk

func get_or_create_foliage_chunk(x_pos: int) -> TileMapLayer:
	var id = floor(x_pos / float(chunk_width))
	if foliage_chunks.has(id): return foliage_chunks[id]
	var new_chunk = foliage_template.duplicate()
	new_chunk.name = "FoliageChunk_" + str(id)
	new_chunk.z_index = 5
	new_chunk.show()
	add_child(new_chunk)
	foliage_chunks[id] = new_chunk
	return new_chunk


func spawn_player():
	if !player_node: return
	@warning_ignore("integer_division")
	var mid_x = map_width / 2
	var mid_y = surface_level + int(surface_noise.get_noise_1d(mid_x) * surface_amplitude)
	player_node.global_position = base_layer.map_to_local(Vector2i(mid_x, mid_y - 5))
	player_node.generator = self
