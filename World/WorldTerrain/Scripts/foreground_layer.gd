# res://World/WorldTerrain/Scripts/foreground_layer.gd
extends TileMapLayer
class_name TerrainLayer

# How many blocks deep until we reach minimum brightness?
const MAX_LIGHT_DEPTH: float = 15.0 
const MIN_BRIGHTNESS: float = 0.05

var surface_heights: Dictionary = {}

func apply_shading_at(x_coord: int, y_surf: int):
	surface_heights[x_coord] = y_surf
	notify_runtime_tile_data_update()

func _use_tile_data_runtime_update(_coords: Vector2i) -> bool:
	return true

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData):
	if surface_heights.has(coords.x):
		var surface_y = surface_heights[coords.x]
		
		# If no surface block in this column, keep it bright (sky)
		if surface_y == -1 or coords.y < surface_y:
			tile_data.modulate = Color.WHITE
			return
			
		var depth = float(coords.y - surface_y)
		
		# 1. Calculate base brightness (1.0 at surface, fading to 0.05 at depth 25)
		# We use smoothstep or simple division for a smooth transition
		var light_percent = 1.0 - (depth / MAX_LIGHT_DEPTH)
		var light_level = clamp(light_percent, MIN_BRIGHTNESS, 1.0)
		
		# 2. Handle Walls vs Blocks
		# Walls are background, so they start 40% darker than the surface blocks
		if "Wall" in name:
			light_level *= 0.6
			# Ensure walls still don't go below the absolute minimum
			light_level = max(light_level, MIN_BRIGHTNESS)
		
		# 3. Apply the color
		tile_data.modulate = Color(light_level, light_level, light_level, 1.0)
