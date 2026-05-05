extends TileMapLayer



# This dictionary remembers the Y-coordinate of the surface for every X-column
var surface_heights: Dictionary = {}

func _ready():
	# Wait one frame to ensure the level is fully loaded
	await get_tree().process_frame
	_scan_surface()

func _scan_surface():
	var rect = get_used_rect()
	
	# Loop left-to-right across the entire generated world
	for x in range(rect.position.x, rect.end.x):
		# Loop top-to-bottom to find the first solid block
		for y in range(rect.position.y, rect.end.y):
			if get_cell_source_id(Vector2i(x, y)) != -1:
				surface_heights[x] = y
				break # Found the surface for this column, move to the next X
				
				
	# Tell Godot to apply our custom color changes to all tiles
	notify_runtime_tile_data_update()



# ---------------------------------------------------
# Runtime Shading Generation
# ---------------------------------------------------

func _use_tile_data_runtime_update(_coords: Vector2i) -> bool:
	# Return true so Godot processes every single tile through the function below
	return true

func _tile_data_runtime_update(_coords: Vector2i, tile_data: TileData):
	if surface_heights.has(_coords.x):
		var surface_y = surface_heights[_coords.x]
		
		# How many blocks deep is this specific tile from the absolute surface?
		var depth = _coords.y - surface_y
		
		# Set how many tiles deep remain at 100% brightness and color
		var fully_bright_tiles = 0
		
		if depth > fully_bright_tiles:
			# Calculate how far past our safe zone we are
			var dark_depth = depth - fully_bright_tiles
			
			# Subtract 20% brightness for every block PAST the bright zone
			var brightness = max(1.0 - (dark_depth * 0.15), 0.05)
			
			# Tint the deep blocks darker
			tile_data.modulate = Color(brightness, brightness, brightness, 1.0)
		else:
			# Guarantee the surface and the top tiles stay perfectly bright
			tile_data.modulate = Color.WHITE
