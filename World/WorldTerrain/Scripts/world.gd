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

@export_group("References")
@export var player_node: CharacterBody2D 
@onready var base_layer: TileMapLayer = $ForegroundLayer
@onready var wall_base_layer: TileMapLayer = get_node_or_null("BackgroundLayer")

# Master data dictionary
var world_data: Dictionary = {}
var wall_data: Dictionary = {}
var chunks: Dictionary = {} 
var wall_chunks: Dictionary = {}

var surface_noise: FastNoiseLite
var cave_noise: FastNoiseLite

# Mapping for 0-15 bitmask
const MASK_MAP = {
	15: Vector2i(3, 4), 14: Vector2i(3, 3), 13: Vector2i(3, 5),
	11: Vector2i(2, 4), 7:  Vector2i(4, 4), 10: Vector2i(2, 3),
	6:  Vector2i(4, 3), 9:  Vector2i(2, 5), 5:  Vector2i(4, 5), 0: Vector2i(3, 3)
}

const WALL_MASK_MAP = {
	15: Vector2i(3, 2), 14: Vector2i(3, 1), 13: Vector2i(3, 3),
	11: Vector2i(4, 2), 7:  Vector2i(2, 2), 10: Vector2i(2, 1),
	6:  Vector2i(4, 1), 9:  Vector2i(2, 3), 5:  Vector2i(4, 3), 0: Vector2i(3, 2)
}

func _ready():
	base_layer.hide() 
	if wall_base_layer: wall_base_layer.hide()
	add_to_group("generator")
	_initialize_noise()
	generate_world()
	spawn_player()

func _initialize_noise():
	randomize()
	var s = randi()
	surface_noise = FastNoiseLite.new()
	surface_noise.seed = s
	surface_noise.frequency = surface_frequency
	cave_noise = FastNoiseLite.new()
	cave_noise.seed = s + 1
	cave_noise.frequency = 0.04

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
		
		for y in range(map_height):
			var pos = Vector2i(x, y)
			if world_data.has(pos):
				var mask = _get_bitmask(pos, world_data)
				active_chunk.set_cell(pos, 0, MASK_MAP.get(mask, Vector2i(3, 4)))
			if wall_data.has(pos):
				var mask = _get_bitmask(pos, wall_data)
				active_wall_chunk.set_cell(pos, 1, WALL_MASK_MAP.get(mask, Vector2i(3, 2)))
		
		_update_shading_for_column(x, world_data)

func update_tile_at(map_pos: Vector2i):
	var chunk_id = floor(map_pos.x / float(chunk_width))
	if !chunks.has(chunk_id): return
	
	var chunk = chunks[chunk_id]
	# If the dictionary doesn't have it, ensure the tile is erased
	if !world_data.has(map_pos):
		chunk.set_cell(map_pos, -1)
		return

	# Recalculate bitmask based on neighbors in world_data
	var mask = _get_bitmask(map_pos, world_data)
	chunk.set_cell(map_pos, 0, MASK_MAP.get(mask, Vector2i(3, 4)))

func _update_shading_for_column(x: int, data_set: Dictionary):
	var found_y = -1
	for y in range(map_height):
		if data_set.has(Vector2i(x, y)):
			found_y = y
			break
	
	var c_id = floor(x / float(chunk_width))
	if chunks.has(c_id) and chunks[c_id].has_method("apply_shading_at"):
		chunks[c_id].apply_shading_at(x, found_y)
	if wall_chunks.has(c_id) and wall_chunks[c_id].has_method("apply_shading_at"):
		wall_chunks[c_id].apply_shading_at(x, found_y)

func _is_cave(x, y, surf_y) -> bool:
	var depth = y - surf_y
	var threshold = 0.45 if depth < 5 else (0.2 if depth < 15 else 0.1)
	return cave_noise.get_noise_2d(x, y) > threshold

func _get_bitmask(pos: Vector2i, data_set: Dictionary) -> int:
	var mask = 0
	if data_set.has(pos + Vector2i.UP):    mask |= 1
	if data_set.has(pos + Vector2i.DOWN):  mask |= 2
	if data_set.has(pos + Vector2i.LEFT):  mask |= 4
	if data_set.has(pos + Vector2i.RIGHT): mask |= 8
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

func spawn_player():
	if !player_node: return
	var mid_x = map_width / 2
	var mid_y = surface_level + int(surface_noise.get_noise_1d(mid_x) * surface_amplitude)
	player_node.global_position = base_layer.map_to_local(Vector2i(mid_x, mid_y - 5))
	player_node.generator = self
