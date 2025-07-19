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
var path_preview_type: String = "none"  # Type of preview: "path", "tiles", "none"
var preview_base_color: Color = Color.WHITE  # Base color for preview highlights

# Grid border visualization
var grid_borders_parent: Node2D = null
var grid_borders_visible: bool = false

# Character position tracking
var occupied_positions: Dictionary = {}  # Vector2i -> BaseCharacter
var character_positions: Dictionary = {}  # BaseCharacter -> Vector2i

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

func refresh_pathfinding_grid() -> void:
	"""Refresh the pathfinding grid to match current tilemap state"""
	# With flood-fill pathfinding, this is essentially a no-op
	# since we always check walkability in real-time during flood-fill
	pass

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
			grid_position.x * tile_size.x + tile_size.x / 2.0,
			grid_position.y * tile_size.y + tile_size.y / 2.0
		)
	
	# Use TileMapLayer's built-in coordinate conversion
	var local_pos: Vector2 = tilemap_layer.map_to_local(grid_position)
	return tilemap_layer.to_global(local_pos)

func is_position_valid(grid_position: Vector2i) -> bool:
	"""Check if a grid position is within valid bounds"""
	return grid_position.x >= -(grid_width / 2) and grid_position.x < (grid_width / 2) and \
		   grid_position.y >= -(grid_height / 2) and grid_position.y < (grid_height / 2)

func is_position_walkable(grid_position: Vector2i, moving_character: BaseCharacter = null) -> bool:
	"""Check if a grid position is walkable (not blocked by obstacles or characters)"""
	if not tilemap_layer:
		return is_position_valid(grid_position)
	
	# Check if position is valid first
	if not is_position_valid(grid_position):
		return false
	
	# Check if position is occupied by a character (but allow the moving character to pass through their own position)
	if is_position_occupied_by_character(grid_position):
		var occupying_character = get_character_at_position(grid_position)
		if occupying_character != moving_character:
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
		return false
	
	# For all terrain sets in the isometric tileset:
	# - terrain 0 = "Pathable" or walkable terrain
	# - terrain 1 = "Non-pathable" or blocked terrain
	return terrain == 0

func _is_terrain_walkable(grid_position: Vector2i) -> bool:
	"""Check if a grid position has walkable terrain (ignoring characters)"""
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
	var terrain_set: int = tile_data.terrain_set
	var terrain: int = tile_data.terrain
	
	# Ensure terrain set is valid (should be 0-4 based on tileset configuration)
	if terrain_set < 0 or terrain_set > 4:
		return false
	
	# For all terrain sets in the isometric tileset:
	# - terrain 0 = "Pathable" or walkable terrain
	# - terrain 1 = "Non-pathable" or blocked terrain
	return terrain == 0

func is_position_occupied_by_character(grid_position: Vector2i) -> bool:
	"""Check if a grid position is occupied by a character"""
	return occupied_positions.has(grid_position)

func get_character_at_position(grid_position: Vector2i) -> BaseCharacter:
	"""Get the character at a specific position, or null if none"""
	return occupied_positions.get(grid_position, null)

func register_character_position(character: BaseCharacter, grid_position: Vector2i) -> void:
	"""Register a character's position on the grid"""
	# Remove character from previous position if it exists
	if character_positions.has(character):
		var old_position = character_positions[character]
		occupied_positions.erase(old_position)
	
	# Register new position
	character_positions[character] = grid_position
	occupied_positions[grid_position] = character

func unregister_character(character: BaseCharacter) -> void:
	"""Remove a character from the grid tracking (e.g., when character is destroyed)"""
	if character_positions.has(character):
		var character_position = character_positions[character]
		occupied_positions.erase(character_position)
		character_positions.erase(character)

func move_character_position(character: BaseCharacter, from_position: Vector2i, to_position: Vector2i) -> void:
	"""Move a character from one position to another on the grid"""
	# Remove from old position
	occupied_positions.erase(from_position)
	
	# Add to new position
	character_positions[character] = to_position
	occupied_positions[to_position] = character

func get_valid_movement_positions(from_position: Vector2i, movement_range: int, moving_character: BaseCharacter = null) -> Array[Vector2i]:
	"""Get all valid positions within movement range from a starting position using flood-fill pathfinding"""
	var flood_fill_result = _flood_fill_pathfinding(from_position, movement_range, moving_character)
	return flood_fill_result.reachable_positions

func show_range_preview(origin: Vector2i, range: int, color: Color, include_entities_in_range: bool = true, preview_type: String = "none", moving_character: BaseCharacter = null) -> void:
	"""Generic function to show range previews with customizable options
	
	Args:
		origin: Center position for the range
		range: Maximum distance from origin  
		color: Color for the highlight tiles
		include_entities_in_range: Whether to show preview for tiles with characters
		preview_type: Type of preview - "path" (movement path), "tiles" (highlight hovered tile), "none"
		moving_character: Character that is moving (for pathfinding validation)
	"""
	clear_movement_highlights()
	
	# Store source position, preview type, and color
	path_preview_type = preview_type
	preview_base_color = color
	if preview_type != "none":
		movement_source_position = origin
	
	# Get tiles within range - use pathfinding for movement, simple range for abilities
	var valid_positions: Array[Vector2i] = []
	
	if preview_type == "path":
		# For movement, use pathfinding to respect obstacles
		valid_positions = get_valid_movement_positions(origin, range, moving_character)
	else:
		# For abilities, get all tiles within range that are walkable (but may have entities)
		var all_tiles_in_range = get_tiles_within_range(origin, range)
		for tile in all_tiles_in_range:
			# Check if tile is walkable terrain (ignoring entities)
			if _is_terrain_walkable(tile):
				valid_positions.append(tile)
	
	# Filter out tiles with entities if requested
	if not include_entities_in_range:
		var filtered_positions: Array[Vector2i] = []
		for pos in valid_positions:
			if not occupied_positions.has(pos):
				filtered_positions.append(pos)
		valid_positions = filtered_positions
	
	# Create highlights for all valid tiles except the origin
	for grid_pos in valid_positions:
		if grid_pos != origin:
			_create_range_highlight_tile(grid_pos, color)
	
	# Store highlighted positions for interaction (excluding origin)
	movement_highlights.clear()
	for pos in valid_positions:
		if pos != origin:
			movement_highlights.append(pos)
	
	# Immediately update tile preview if in tiles mode
	if preview_type == "tiles":
		var mouse_grid_pos: Vector2i = world_to_grid(get_global_mouse_position())
		if mouse_grid_pos in movement_highlights:
			current_hovered_tile = mouse_grid_pos
			_update_tile_preview(mouse_grid_pos)

func _create_range_highlight_tile(grid_position: Vector2i, color: Color) -> void:
	"""Create a visual highlight at a grid position with specified color"""
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
	highlight.color = color
	highlight.position = grid_to_world(grid_position)
	highlight.z_index = 1  # Render above tilemap but below path previews
	
	# Store grid position as metadata for easy access
	highlight.set_meta("grid_position", grid_position)
	
	highlight_tiles_parent.add_child(highlight)

func highlight_movement_range(from_position: Vector2i, movement_range: int, moving_character: BaseCharacter = null) -> void:
	"""Visually highlight tiles within movement range"""
	# Use the generic function with movement-specific settings
	show_range_preview(
		from_position, 
		movement_range, 
		Color(0, 0.9, 0, 0.3),  # Green for movement
		false,  # Don't show preview for occupied tiles
		"path",  # Show full path preview on hover
		moving_character
	)


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
	
	# Use the base color with different opacity levels
	# Base range tiles have alpha around 0.3-0.5, so we scale up from there
	var base_alpha = preview_base_color.a
	if is_destination:
		# Destination tile is brightest (3x base alpha, capped at 1.0)
		highlight.color = Color(preview_base_color.r, preview_base_color.g, preview_base_color.b, min(base_alpha * 3.0, 1.0))
	else:
		# Path tiles are medium brightness (2x base alpha, capped at 1.0)
		highlight.color = Color(preview_base_color.r, preview_base_color.g, preview_base_color.b, min(base_alpha * 2.0, 1.0))
	
	highlight.position = grid_to_world(grid_position)
	highlight.z_index = 1  # Above range tiles but below characters (which are at z_index 2)
	
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

func _update_tile_preview(tile: Vector2i) -> void:
	"""Update the preview to highlight a single tile (for abilities)"""
	_clear_path_highlights()
	
	# Highlight just the hovered tile as destination
	_create_path_highlight_tile(tile, true)
	
	current_path_highlights = [tile]

func clear_movement_highlights() -> void:
	"""Remove all movement highlight visuals"""
	if highlight_tiles_parent:
		for child in highlight_tiles_parent.get_children():
			child.queue_free()
	movement_highlights.clear()
	current_hovered_tile = Vector2i(-999, -999)  # Reset hovered tile
	path_preview_type = "none"  # Reset preview type
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
			
			# Handle different preview types
			if path_preview_type != "none" and mouse_grid_pos in movement_highlights:
				tile_hovered.emit(mouse_grid_pos)
				if path_preview_type == "path":
					_update_path_preview(mouse_grid_pos)
				elif path_preview_type == "tiles":
					_update_tile_preview(mouse_grid_pos)
			elif path_preview_type != "none":
				# Clear preview if hovering outside range
				_clear_path_highlights()
	

func find_path(from: Vector2i, to: Vector2i, max_cost: int = -1, moving_character: BaseCharacter = null) -> Array[Vector2i]:
	"""Find a path from one position to another using flood-fill pathfinding"""
	# Check if tilemap is available
	if not tilemap_layer:
		return []
	
	# Check if positions are valid and walkable
	if not is_position_valid(from) or not is_position_valid(to) or not is_position_walkable(to, moving_character):
		return []
	
	# If trying to path to the same position, return empty path
	if from == to:
		return []
	
	# Use flood-fill to find path and reachable positions
	var movement_range = max_cost if max_cost != -1 else 999  # Use large number if no limit
	var flood_fill_result = _flood_fill_pathfinding(from, movement_range, moving_character)
	
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

func _flood_fill_pathfinding(from_position: Vector2i, movement_range: int, moving_character: BaseCharacter = null) -> Dictionary:
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
			if not is_position_valid(next_pos) or not is_position_walkable(next_pos, moving_character):
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
	var half_width: int = grid_width / 2
	var half_height: int = grid_height / 2
	return Rect2i(-half_width, -half_height, grid_width, grid_height)

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
	var half_width: int = grid_width / 2
	var half_height: int = grid_height / 2
	for x in range(-half_width, half_width):
		for y in range(-half_height, half_height):
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

func get_tiles_within_range(center: Vector2i, range_value: int) -> Array[Vector2i]:
	"""Get all tiles within a certain range from a center position"""
	var tiles: Array[Vector2i] = []
	
	for x in range(-range_value, range_value + 1):
		for y in range(-range_value, range_value + 1):
			var tile_pos = Vector2i(center.x + x, center.y + y)
			# Check Manhattan distance for diamond pattern
			if abs(x) + abs(y) <= range_value and is_position_valid(tile_pos):
				tiles.append(tile_pos)
				
	return tiles

func highlight_tile(grid_position: Vector2i, color: Color) -> void:
	"""Highlight a single tile with a specific color"""
	if not is_position_valid(grid_position):
		return
		
	var highlight: Polygon2D = Polygon2D.new()
	
	# Create diamond shape that matches isometric tile
	var half_width: float = tile_size.x * 0.5
	var half_height: float = tile_size.y * 0.5
	
	var diamond_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -half_height),
		Vector2(half_width, 0),
		Vector2(0, half_height),
		Vector2(-half_width, 0)
	])
	
	highlight.polygon = diamond_points
	highlight.color = color
	highlight.position = grid_to_world(grid_position)
	highlight.z_index = -1
	
	# Add to highlights parent
	if highlight_tiles_parent:
		highlight_tiles_parent.add_child(highlight) 
