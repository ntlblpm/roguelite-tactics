class_name GridManager
extends Node2D

## Grid manager for tactical combat system
## Handles coordinate conversion between world and grid space, pathfinding, and tile accessibility

# Grid configuration
@export var tile_size: Vector2i = Vector2i(32, 16)  # Isometric tile size
@export var grid_width: int = 20
@export var grid_height: int = 20

# References to TileMapLayer
@onready var tilemap_layer: TileMapLayer = null

# A* pathfinding
var astar_grid: AStarGrid2D = AStarGrid2D.new()
var astar_initialized: bool = false

# Visual feedback
var movement_highlights: Array[Vector2i] = []
var highlight_tiles_parent: Node2D = null

# Grid border visualization
var grid_borders_parent: Node2D = null
var grid_borders_visible: bool = false

# Signals
signal tile_clicked(grid_position: Vector2i)

func _ready() -> void:
	_setup_highlight_system()
	_setup_grid_borders_system()
	_initialize_astar_grid()

func _setup_highlight_system() -> void:
	"""Setup the visual highlight system for valid movement tiles"""
	highlight_tiles_parent = Node2D.new()
	highlight_tiles_parent.name = "MovementHighlights"
	add_child(highlight_tiles_parent)

func _setup_grid_borders_system() -> void:
	"""Setup the visual grid borders system for all tiles"""
	grid_borders_parent = Node2D.new()
	grid_borders_parent.name = "GridBorders"
	add_child(grid_borders_parent)

func _initialize_astar_grid() -> void:
	"""Initialize the A* grid for pathfinding"""
	if astar_initialized:
		return
	
	# Set up the grid size (AStarGrid2D uses 0-based indexing)
	astar_grid.size = Vector2i(grid_width, grid_height)
	astar_grid.cell_size = Vector2(1, 1)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	
	astar_grid.update()
	_update_walkable_points()
	
	astar_initialized = true


func _grid_to_astar_coords(grid_pos: Vector2i) -> Vector2i:
	"""Convert game grid coordinates to A* grid coordinates"""
	return Vector2i(grid_pos.x + grid_width/2, grid_pos.y + grid_height/2)

func _astar_to_grid_coords(astar_pos: Vector2i) -> Vector2i:
	"""Convert A* grid coordinates to game grid coordinates"""
	return Vector2i(astar_pos.x - grid_width/2, astar_pos.y - grid_height/2)

func _update_walkable_points() -> void:
	"""Update which points are walkable in the A* grid"""
	for x in range(-grid_width/2, grid_width/2):
		for y in range(-grid_height/2, grid_height/2):
			var grid_pos = Vector2i(x, y)
			var astar_pos = _grid_to_astar_coords(grid_pos)
			var is_walkable = is_position_walkable(grid_pos)
			astar_grid.set_point_solid(astar_pos, not is_walkable)

func set_tilemap_layer(layer: TileMapLayer) -> void:
	"""Set the reference to the TileMapLayer"""
	tilemap_layer = layer
	if tilemap_layer:
		print("Grid manager connected to TileMapLayer")
		_initialize_astar_grid()

func refresh_pathfinding_grid() -> void:
	"""Refresh the A* grid to match current tilemap state"""
	if not astar_initialized:
		print("Warning: Cannot refresh pathfinding grid - A* not initialized")
		return
	
	print("Refreshing pathfinding grid to match current tilemap state")
	_update_walkable_points()
	astar_grid.update()
	print("Pathfinding grid refresh completed")

func world_to_grid(world_position: Vector2) -> Vector2i:
	"""Convert world coordinates to grid coordinates"""
	if not tilemap_layer:
		# Fallback calculation if no tilemap
		var grid_x: int = int(world_position.x / tile_size.x)
		var grid_y: int = int(world_position.y / tile_size.y)
		return Vector2i(grid_x, grid_y)
	
	# Use TileMapLayer's built-in coordinate conversion
	var local_pos: Vector2 = tilemap_layer.to_local(world_position)
	return tilemap_layer.local_to_map(local_pos)

func grid_to_world(grid_position: Vector2i) -> Vector2:
	"""Convert grid coordinates to world coordinates"""
	if not tilemap_layer:
		# Fallback calculation if no tilemap
		return Vector2(
			grid_position.x * tile_size.x + tile_size.x / 2,
			grid_position.y * tile_size.y + tile_size.y / 2
		)
	
	# Use TileMapLayer's built-in coordinate conversion
	var local_pos: Vector2 = tilemap_layer.map_to_local(grid_position)
	return tilemap_layer.to_global(local_pos)

func is_position_valid(grid_position: Vector2i) -> bool:
	"""Check if a grid position is within valid bounds"""
	return grid_position.x >= -grid_width/2 and grid_position.x < grid_width/2 and \
		   grid_position.y >= -grid_height/2 and grid_position.y < grid_height/2

func is_position_walkable(grid_position: Vector2i) -> bool:
	"""Check if a grid position is walkable (not blocked by obstacles)"""
	if not tilemap_layer:
		return is_position_valid(grid_position)
	
	# Check if position is valid first
	if not is_position_valid(grid_position):
		return false
	
	# Get tile data at position
	var tile_data: TileData = tilemap_layer.get_cell_tile_data(grid_position)
	
	# If no tile data, position is not walkable
	if not tile_data:
		return false
	
	# Check terrain type - terrain 0 is walkable, terrain 1 is blocked for all terrain sets
	# Validate that the terrain set exists and has the expected setup
	var terrain_set: int = tile_data.terrain_set
	var terrain: int = tile_data.terrain
	
	# Ensure terrain set is valid (should be 0-4 based on tileset configuration)
	if terrain_set < 0 or terrain_set > 4:
		print("Warning: Invalid terrain set ", terrain_set, " at position ", grid_position)
		return false
	
	# For all terrain sets in the isometric tileset:
	# - terrain 0 = "Pathable" or walkable terrain
	# - terrain 1 = "Non-pathable" or blocked terrain
	return terrain == 0

func get_valid_movement_positions(from_position: Vector2i, movement_range: int) -> Array[Vector2i]:
	"""Get all valid positions within movement range from a starting position using pathfinding"""
	var valid_positions: Array[Vector2i] = []
	
	if not astar_initialized:
		return valid_positions
	
	# Check all positions in movement range
	for x in range(-movement_range, movement_range + 1):
		for y in range(-movement_range, movement_range + 1):
			var check_pos: Vector2i = Vector2i(from_position.x + x, from_position.y + y)
			var distance: int = abs(x) + abs(y)
			
			if distance > movement_range or distance == 0:
				continue
			
			# Use pathfinding to check if position is reachable within movement range
			var path: Array[Vector2i] = find_path(from_position, check_pos, movement_range)
			if path.size() > 0:
				valid_positions.append(check_pos)
	
	return valid_positions

func highlight_movement_range(from_position: Vector2i, movement_range: int) -> void:
	"""Visually highlight tiles within movement range"""
	clear_movement_highlights()
	
	var valid_positions: Array[Vector2i] = get_valid_movement_positions(from_position, movement_range)
	
	for grid_pos in valid_positions:
		_create_highlight_tile(grid_pos)
	
	movement_highlights = valid_positions

func _create_highlight_tile(grid_position: Vector2i) -> void:
	"""Create a visual highlight at a grid position"""
	var highlight: Polygon2D = Polygon2D.new()
	
	# Create diamond shape that matches isometric tile appearance
	var half_width: float = tile_size.x * 0.45  # Full tile size for complete coverage
	var half_height: float = tile_size.y * 0.45
	
	# Define diamond vertices (clockwise from top)
	var diamond_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -half_height),           # Top
		Vector2(half_width, 0),             # Right  
		Vector2(0, half_height),            # Bottom
		Vector2(-half_width, 0)             # Left
	])
	
	highlight.polygon = diamond_points
	highlight.color = Color(0, 0.9, 0, 0.9)  # Semi-transparent green with 90% opacity
	highlight.position = grid_to_world(grid_position)
	highlight.z_index = 1  # Render above tilemap but below characters
	
	highlight_tiles_parent.add_child(highlight)

func clear_movement_highlights() -> void:
	"""Remove all movement highlight visuals"""
	if highlight_tiles_parent:
		for child in highlight_tiles_parent.get_children():
			child.queue_free()
	movement_highlights.clear()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_grid_pos: Vector2i = world_to_grid(get_global_mouse_position())
		tile_clicked.emit(clicked_grid_pos)
	
	# Debug keyboard shortcuts for testing pathfinding
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_T:
				# Test pathfinding validation with keyboard shortcut
				_run_pathfinding_tests()
			KEY_R:
				# Refresh pathfinding grid
				refresh_pathfinding_grid()
			KEY_I:
				# Print tile info for position under mouse
				var mouse_grid_pos = world_to_grid(get_global_mouse_position())
				debug_print_tile_info(mouse_grid_pos)

func _run_pathfinding_tests() -> void:
	"""Run a series of pathfinding tests to validate the fixes"""
	print("=== Running Pathfinding Validation Tests ===")
	
	# Test 1: Valid path on walkable terrain
	debug_test_pathfinding(Vector2i(0, 0), Vector2i(3, 3))
	
	# Test 2: Try to path to a known blocked terrain
	# We'll test some positions that should be blocked based on the tileset
	debug_test_pathfinding(Vector2i(0, 0), Vector2i(-5, -5))
	
	# Test 3: Try a longer path that might go through blocked terrain
	debug_test_pathfinding(Vector2i(-3, -3), Vector2i(5, 5))
	
	print("=== Pathfinding Tests Complete ===")
	print("Press 'R' to refresh pathfinding grid")
	print("Press 'I' while hovering over a tile to get tile info")


func find_path(from: Vector2i, to: Vector2i, max_cost: int = -1) -> Array[Vector2i]:
	"""Find a path from one position to another using A* pathfinding"""
	if not astar_initialized:
		return []
	
	# Check if positions are valid and walkable
	if not is_position_valid(from) or not is_position_valid(to) or not is_position_walkable(to):
		return []
	
	# Convert to A* coordinate system
	var astar_from = _grid_to_astar_coords(from)
	var astar_to = _grid_to_astar_coords(to)
	
	# Use A* to find the path
	var path_points: PackedVector2Array = astar_grid.get_point_path(astar_from, astar_to)
	
	if path_points.size() == 0:
		return []
	
	# Convert to Array[Vector2i] and remove starting position
	var path: Array[Vector2i] = []
	for i in range(1, path_points.size()):
		var astar_pos = Vector2i(path_points[i])
		var grid_pos = _astar_to_grid_coords(astar_pos)
		path.append(grid_pos)
	
	# Validate that every step in the path is actually walkable
	# This prevents paths through terrain that should be blocked
	for step_pos in path:
		if not is_position_walkable(step_pos):
			print("Warning: Generated path contains non-walkable tile at ", step_pos, " - rejecting path")
			return []
	
	# Filter by max_cost if specified
	if max_cost != -1 and path.size() > max_cost:
		path = path.slice(0, max_cost)
	
	return path

func get_grid_bounds() -> Rect2i:
	"""Get the bounds of the grid"""
	return Rect2i(-grid_width/2, -grid_height/2, grid_width, grid_height)

func debug_print_tile_info(grid_position: Vector2i) -> void:
	"""Debug function to print information about a tile"""
	print("=== Tile Info for ", grid_position, " ===")
	print("Valid: ", is_position_valid(grid_position))
	print("Walkable: ", is_position_walkable(grid_position))
	print("World position: ", grid_to_world(grid_position))
	
	if tilemap_layer:
		var tile_data: TileData = tilemap_layer.get_cell_tile_data(grid_position)
		if tile_data:
			print("Terrain set: ", tile_data.terrain_set)
			print("Terrain: ", tile_data.terrain)
		else:
			print("No tile data found")
	
	# Also check A* grid state
	if astar_initialized:
		var astar_pos = _grid_to_astar_coords(grid_position)
		print("A* coordinates: ", astar_pos)
		print("A* solid: ", astar_grid.is_point_solid(astar_pos))
	else:
		print("A* not initialized")
	
	print("========================")

func debug_test_pathfinding(from: Vector2i, to: Vector2i) -> void:
	"""Debug function to test pathfinding between two positions"""
	print("=== Testing Pathfinding from ", from, " to ", to, " ===")
	
	print("From position walkable: ", is_position_walkable(from))
	print("To position walkable: ", is_position_walkable(to))
	
	var path = find_path(from, to)
	if path.size() > 0:
		print("Path found with ", path.size(), " steps: ", path)
		print("Validating each step:")
		for i in range(path.size()):
			var step = path[i]
			var walkable = is_position_walkable(step)
			print("  Step ", i + 1, ": ", step, " - Walkable: ", walkable)
			if not walkable:
				print("  ERROR: Non-walkable step detected!")
	else:
		print("No path found")
	
	print("================================") 

func show_grid_borders() -> void:
	"""Display borders on all valid grid tiles"""
	if grid_borders_visible:
		return
	
	grid_borders_visible = true
	_create_all_grid_borders()

func hide_grid_borders() -> void:
	"""Hide all grid border visuals"""
	if not grid_borders_visible:
		return
	
	grid_borders_visible = false
	_clear_grid_borders()

func toggle_grid_borders() -> void:
	"""Toggle grid border visibility"""
	if grid_borders_visible:
		hide_grid_borders()
	else:
		show_grid_borders()

func _create_all_grid_borders() -> void:
	"""Create border visuals for tiles that actually exist in the tilemap"""
	_clear_grid_borders()
	
	# Only create borders for tiles that actually have tile data
	for x in range(-grid_width/2, grid_width/2):
		for y in range(-grid_height/2, grid_height/2):
			var grid_pos = Vector2i(x, y)
			if _has_tile_data(grid_pos):
				_create_grid_border_tile(grid_pos)

func _has_tile_data(grid_position: Vector2i) -> bool:
	"""Check if a tile actually exists at the given position"""
	if not tilemap_layer or not is_position_valid(grid_position):
		return false
	
	# Get tile data at position
	var tile_data: TileData = tilemap_layer.get_cell_tile_data(grid_position)
	return tile_data != null

func _create_grid_border_tile(grid_position: Vector2i) -> void:
	"""Create a border visual at a specific grid position"""
	var border: Polygon2D = Polygon2D.new()
	
	# Create diamond shape outline that matches isometric tile appearance
	var half_width: float = tile_size.x * 0.5
	var half_height: float = tile_size.y * 0.5
	
	# Define diamond vertices (clockwise from top) - slightly larger for border visibility
	var diamond_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -half_height),           # Top
		Vector2(half_width, 0),             # Right  
		Vector2(0, half_height),            # Bottom
		Vector2(-half_width, 0)             # Left
	])
	
	border.polygon = diamond_points
	border.color = Color.TRANSPARENT  # Transparent fill
	border.position = grid_to_world(grid_position)
	border.z_index = 0  # Render below movement highlights and characters
	
	# Add outline using a Line2D for the border
	var outline: Line2D = Line2D.new()
	var outline_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -half_height),           # Top
		Vector2(half_width, 0),             # Right  
		Vector2(0, half_height),            # Bottom
		Vector2(-half_width, 0),            # Left
		Vector2(0, -half_height)            # Close the shape
	])
	
	outline.points = outline_points
	outline.width = 0.5
	outline.default_color = Color(0.2, 0.2, 0.2, 1)  # Darker semi-transparent gray
	outline.z_index = 0
	
	border.add_child(outline)
	grid_borders_parent.add_child(border)

func _clear_grid_borders() -> void:
	"""Remove all grid border visuals"""
	if grid_borders_parent:
		for child in grid_borders_parent.get_children():
			child.queue_free() 
