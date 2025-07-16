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

# Visual feedback
var movement_highlights: Array[Vector2i] = []
var highlight_tiles_parent: Node2D = null
var current_hovered_tile: Vector2i = Vector2i(-999, -999)  # Track currently hovered tile
var current_path_highlights: Array[Vector2i] = []  # Track currently highlighted path
var path_highlights_parent: Node2D = null  # Separate parent for path highlights
var movement_source_position: Vector2i = Vector2i.ZERO  # Source position for current movement range

# Grid border visualization
var grid_borders_parent: Node2D = null
var grid_borders_visible: bool = false

# Signals
signal tile_clicked(grid_position: Vector2i)
signal tile_hovered(grid_position: Vector2i)  # New signal for tile hover events

func _ready() -> void:
	_setup_highlight_system()
	_setup_grid_borders_system()

func _setup_highlight_system() -> void:
	"""Setup the visual highlight system for valid movement tiles"""
	highlight_tiles_parent = Node2D.new()
	highlight_tiles_parent.name = "MovementHighlights"
	add_child(highlight_tiles_parent)
	
	# Create separate parent for path highlights to render them on top
	path_highlights_parent = Node2D.new()
	path_highlights_parent.name = "PathHighlights"
	add_child(path_highlights_parent)

func _setup_grid_borders_system() -> void:
	"""Setup the visual grid borders system for all tiles"""
	grid_borders_parent = Node2D.new()
	grid_borders_parent.name = "GridBorders"
	add_child(grid_borders_parent)

func set_tilemap_layer(layer: TileMapLayer) -> void:
	"""Set the reference to the TileMapLayer"""
	tilemap_layer = layer
	if tilemap_layer:
		print("Grid manager connected to TileMapLayer")

func refresh_pathfinding_grid() -> void:
	"""Refresh the pathfinding grid to match current tilemap state"""
	# With flood-fill pathfinding, this is essentially a no-op
	# since we always check walkability in real-time during flood-fill
	print("Pathfinding grid refresh completed (using flood-fill pathfinding)")

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
	"""Get all valid positions within movement range from a starting position using flood-fill pathfinding"""
	var flood_fill_result = _flood_fill_pathfinding(from_position, movement_range)
	return flood_fill_result.reachable_positions

func highlight_movement_range(from_position: Vector2i, movement_range: int) -> void:
	"""Visually highlight tiles within movement range"""
	clear_movement_highlights()
	
	# Store the source position for path calculation
	movement_source_position = from_position
	
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
	highlight.color = Color(0, 0.9, 0, 0.3)  # Dimmed movement range tiles
	highlight.position = grid_to_world(grid_position)
	highlight.z_index = 1  # Render above tilemap but below characters
	
	# Store grid position as metadata for easy access
	highlight.set_meta("grid_position", grid_position)
	
	highlight_tiles_parent.add_child(highlight)

func _create_path_highlight_tile(grid_position: Vector2i, is_destination: bool = false) -> void:
	"""Create a visual highlight for a path tile"""
	var highlight: Polygon2D = Polygon2D.new()
	
	# Create diamond shape that matches isometric tile appearance
	var half_width: float = tile_size.x * 0.45
	var half_height: float = tile_size.y * 0.45
	
	# Define diamond vertices (clockwise from top)
	var diamond_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -half_height),           # Top
		Vector2(half_width, 0),             # Right  
		Vector2(0, half_height),            # Bottom
		Vector2(-half_width, 0)             # Left
	])
	
	highlight.polygon = diamond_points
	
	# Different colors for path vs destination
	if is_destination:
		highlight.color = Color(0, 0.9, 0, 0.9)  # Bright green for destination
	else:
		highlight.color = Color(0, 0.9, 0, 0.6)  # More transparent green for path tiles
	
	highlight.position = grid_to_world(grid_position)
	highlight.z_index = 2  # Render above movement highlights
	
	path_highlights_parent.add_child(highlight)

func _update_path_preview(destination: Vector2i) -> void:
	"""Update the path preview to show route to destination"""
	_clear_path_highlights()
	
	# Calculate path from source to destination
	var path: Array[Vector2i] = find_path(movement_source_position, destination)
	
	if path.size() == 0:
		return  # No valid path
	
	# Highlight each tile in the path
	for i in range(path.size()):
		var path_tile: Vector2i = path[i]
		var is_destination: bool = (i == path.size() - 1)
		_create_path_highlight_tile(path_tile, is_destination)
	
	current_path_highlights = path



func clear_movement_highlights() -> void:
	"""Remove all movement highlight visuals"""
	if highlight_tiles_parent:
		for child in highlight_tiles_parent.get_children():
			child.queue_free()
	movement_highlights.clear()
	current_hovered_tile = Vector2i(-999, -999)  # Reset hovered tile
	_clear_path_highlights()  # Also clear path highlights

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_grid_pos: Vector2i = world_to_grid(get_global_mouse_position())
		tile_clicked.emit(clicked_grid_pos)
	
	# Track mouse motion for path preview
	if event is InputEventMouseMotion:
		var mouse_grid_pos: Vector2i = world_to_grid(get_global_mouse_position())
		
		# Only update if we're hovering over a different tile
		if mouse_grid_pos != current_hovered_tile:
			current_hovered_tile = mouse_grid_pos
			
			# Show path preview if this tile is in the movement range
			if mouse_grid_pos in movement_highlights:
				tile_hovered.emit(mouse_grid_pos)
				_update_path_preview(mouse_grid_pos)
			else:
				# Clear path preview if hovering outside movement range
				_clear_path_highlights()
	
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
	"""Find a path from one position to another using flood-fill pathfinding"""
	# Check if tilemap is available
	if not tilemap_layer:
		return []
	
	# Check if positions are valid and walkable
	if not is_position_valid(from) or not is_position_valid(to) or not is_position_walkable(to):
		return []
	
	# If trying to path to the same position, return empty path
	if from == to:
		return []
	
	# Use flood-fill to find path and reachable positions
	var movement_range = max_cost if max_cost != -1 else 999  # Use large number if no limit
	var flood_fill_result = _flood_fill_pathfinding(from, movement_range)
	
	# Check if target is reachable
	if to not in flood_fill_result.reachable_positions:
		return []
	
	# Reconstruct path using parent tracking
	var path: Array[Vector2i] = []
	var current = to
	
	# Follow parent chain backwards to build path
	while current != from and flood_fill_result.parent_map.has(current):
		path.push_front(current)
		current = flood_fill_result.parent_map[current]
	
	# Validate path length against max_cost
	if max_cost != -1 and path.size() > max_cost:
		return []
	
	return path

func _flood_fill_pathfinding(from_position: Vector2i, movement_range: int) -> Dictionary:
	"""
	Unified flood-fill algorithm for both pathfinding and movement range calculation
	Returns: {
		"reachable_positions": Array[Vector2i] - all positions within range
		"parent_map": Dictionary - parent position for each reachable position (for path reconstruction)
	}
	"""
	var reachable_positions: Array[Vector2i] = []
	var parent_map: Dictionary = {}
	var visited: Dictionary = {}
	var queue: Array = []
	
	# Check if tilemap is available
	if not tilemap_layer:
		return {"reachable_positions": reachable_positions, "parent_map": parent_map}
	
	# Start flood-fill from the starting position with cost 0
	queue.append({"position": from_position, "cost": 0, "parent": null})
	visited[from_position] = 0
	
	# Directions for 4-directional movement (isometric grid)
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left  
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_pos: Vector2i = current.position
		var current_cost: int = current.cost
		var current_parent = current.parent
		
		# Store parent for path reconstruction (except for starting position)
		if current_parent != null:
			parent_map[current_pos] = current_parent
		
		# Check all adjacent positions
		for direction in directions:
			var next_pos: Vector2i = current_pos + direction
			var next_cost: int = current_cost + 1
			
			# Skip if we've exceeded movement range
			if next_cost > movement_range:
				continue
			
			# Skip if position is invalid or not walkable
			if not is_position_valid(next_pos) or not is_position_walkable(next_pos):
				continue
			
			# Skip if we've already visited this position with a lower or equal cost
			if visited.has(next_pos) and visited[next_pos] <= next_cost:
				continue
			
			# Add to visited and queue for further exploration
			visited[next_pos] = next_cost
			queue.append({"position": next_pos, "cost": next_cost, "parent": current_pos})
			
			# Add to reachable positions if it's not the starting position
			if next_pos != from_position and next_pos not in reachable_positions:
				reachable_positions.append(next_pos)
	
	return {"reachable_positions": reachable_positions, "parent_map": parent_map}

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
	# With flood-fill pathfinding, there's no A* grid state to check
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

func _clear_path_highlights() -> void:
	"""Clear all path highlight visuals"""
	if path_highlights_parent:
		for child in path_highlights_parent.get_children():
			child.queue_free()
	current_path_highlights.clear() 
