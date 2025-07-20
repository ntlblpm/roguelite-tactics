class_name RoomGenerator
extends RefCounted

const ROOM_SIZE := 13
const CENTER_SIZE := 3
const MIN_ENEMY_DISTANCE := 5

static func generate(room_size := 13, blocked_ratio := 0.35) -> Dictionary:
	var terrain_set := randi_range(0, 4)
	print("RoomGenerator: Selected terrain set ", terrain_set, " (0=Brown, 1=Green, 2=Gray, 3=Sand, 4=Blue)")
	var tile_grid := _generate_tile_grid(room_size, blocked_ratio, terrain_set)
	
	# Validate connectivity
	var max_attempts := 10
	var attempt := 0
	while attempt < max_attempts and not _validate_connectivity(tile_grid):
		tile_grid = _generate_tile_grid(room_size, blocked_ratio, terrain_set)
		attempt += 1
	
	if attempt >= max_attempts:
		push_warning("Could not generate connected room after %d attempts" % max_attempts)
	
	# Convert grid to flat array of Vector2i atlas coordinates
	var tile_atlas_coords := []
	for row in tile_grid:
		for tile_atlas_coord in row:
			tile_atlas_coords.append(tile_atlas_coord)
	
	# Generate spawn positions
	var player_spawns := _get_player_spawns(room_size)
	var enemy_spawns := _get_enemy_spawns(tile_grid, room_size)
	
	return {
		"terrain_set": terrain_set,
		"tile_atlas_coords": tile_atlas_coords,
		"player_spawns": player_spawns,
		"enemy_spawns": enemy_spawns
	}

static func _generate_tile_grid(room_size: int, blocked_ratio: float, terrain_set: int) -> Array:
	var grid := []
	
	# Get walkable and blocked tile IDs for this terrain set
	var walkable_tiles := _get_walkable_tiles_for_terrain_set(terrain_set)
	var blocked_tiles := _get_blocked_tiles_for_terrain_set(terrain_set)
	
	# Initialize with walkable tiles
	for y in room_size:
		var row := []
		for x in room_size:
			row.append(walkable_tiles.pick_random())
		grid.append(row)
	
	# Calculate center bounds
	var center_start := (room_size - CENTER_SIZE) / 2
	var center_end := center_start + CENTER_SIZE
	
	# Place blocked tiles using random walk clusters
	var total_tiles := room_size * room_size
	var blocked_count := int(round(total_tiles * blocked_ratio))
	var placed_blocked := 0
	
	while placed_blocked < blocked_count:
		# Start a new cluster
		var cluster_size := randi_range(1, 3)
		var start_x := randi() % room_size
		var start_y := randi() % room_size
		
		# Skip if in center area
		if start_x >= center_start and start_x < center_end and start_y >= center_start and start_y < center_end:
			continue
		
		# Random walk to place cluster
		var current_x := start_x
		var current_y := start_y
		
		for i in cluster_size:
			if placed_blocked >= blocked_count:
				break
			
			# Place blocked tile if valid position
			if current_x >= 0 and current_x < room_size and current_y >= 0 and current_y < room_size:
				# Skip center area
				if not (current_x >= center_start and current_x < center_end and current_y >= center_start and current_y < center_end):
					if grid[current_y][current_x] in walkable_tiles:
						grid[current_y][current_x] = blocked_tiles.pick_random()
						placed_blocked += 1
			
			# Random walk to adjacent cell
			var direction := randi() % 4
			match direction:
				0: current_x += 1
				1: current_x -= 1
				2: current_y += 1
				3: current_y -= 1
	
	return grid

static func _get_walkable_tiles_for_terrain_set(terrain_set: int) -> Array:
	# Map terrain sets to their walkable tile atlas coordinates
	# Based on the tileset structure, terrain 0 tiles are walkable
	match terrain_set:
		0: return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]  # Brown/dirt tiles
		1: return [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(5, 2), Vector2i(6, 2)]  # Green/grass tiles
		2: return [Vector2i(7, 5), Vector2i(8, 5), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)]  # Gray/stone tiles
		3: return [Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10)]  # Sand/desert tiles
		4: return [Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8), Vector2i(4, 8)]  # Blue/water tiles
		_: return [Vector2i(0, 0)]  # Default to brown/dirt

static func _get_blocked_tiles_for_terrain_set(terrain_set: int) -> Array:
	# Map terrain sets to their blocked tile atlas coordinates
	# Based on the tileset structure, terrain 1 tiles are blocked
	match terrain_set:
		0: return [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)]  # Brown/dirt obstacles
		1: return [Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2), Vector2i(0, 3), Vector2i(1, 3)]  # Green/grass obstacles
		2: return [Vector2i(9, 5), Vector2i(10, 5), Vector2i(0, 6), Vector2i(1, 6), Vector2i(5, 6)]  # Gray/stone walls
		3: return [Vector2i(10, 10)]  # Sand/desert rocks (only one blocked tile in this set)
		4: return [Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 8)]  # Blue/water obstacles
		_: return [Vector2i(0, 5)]  # Default to brown/dirt obstacle

static func _validate_connectivity(grid: Array) -> bool:
	var room_size := grid.size()
	var center := room_size / 2
	
	# Flood fill from center
	var visited := {}
	var queue := [Vector2i(center, center)]
	var walkable_count := 0
	
	# Get walkable tiles (all terrain 0 tiles)
	var all_walkable_tiles := []
	for i in 5:
		all_walkable_tiles.append_array(_get_walkable_tiles_for_terrain_set(i))
	
	while queue.size() > 0:
		var pos := queue.pop_front() as Vector2i
		
		if pos in visited:
			continue
		
		if pos.x < 0 or pos.x >= room_size or pos.y < 0 or pos.y >= room_size:
			continue
		
		if not grid[pos.y][pos.x] in all_walkable_tiles:
			continue
		
		visited[pos] = true
		walkable_count += 1
		
		# Add neighbors
		queue.append(Vector2i(pos.x + 1, pos.y))
		queue.append(Vector2i(pos.x - 1, pos.y))
		queue.append(Vector2i(pos.x, pos.y + 1))
		queue.append(Vector2i(pos.x, pos.y - 1))
	
	# Count total walkable tiles
	var total_walkable := 0
	for y in room_size:
		for x in room_size:
			if grid[y][x] in all_walkable_tiles:
				total_walkable += 1
	
	# Accept if we can reach at least 90% of walkable tiles
	return walkable_count >= total_walkable * 0.9

static func _get_player_spawns(room_size: int) -> Array:
	var center := room_size / 2
	var center_start := (room_size - CENTER_SIZE) / 2
	
	# Return the four corners of the 3x3 center area
	return [
		Vector2i(center_start, center_start),  # Top-left
		Vector2i(center_start + CENTER_SIZE - 1, center_start),  # Top-right
		Vector2i(center_start, center_start + CENTER_SIZE - 1),  # Bottom-left
		Vector2i(center_start + CENTER_SIZE - 1, center_start + CENTER_SIZE - 1)  # Bottom-right
	]

static func _get_enemy_spawns(grid: Array, room_size: int) -> Array:
	var center := room_size / 2
	var enemy_spawns := []
	# Support up to 5 enemies (4 players + 1 random enemy)
	var max_enemies := 5
	
	# Get all walkable tiles
	var all_walkable_tiles := []
	for i in 5:
		all_walkable_tiles.append_array(_get_walkable_tiles_for_terrain_set(i))
	
	# Find all valid spawn positions (walkable and far from center)
	var valid_positions := []
	for y in room_size:
		for x in room_size:
			if grid[y][x] in all_walkable_tiles:
				var distance: int = abs(x - center) + abs(y - center)  # Manhattan distance
				if distance >= MIN_ENEMY_DISTANCE:
					valid_positions.append(Vector2i(x, y))
	
	# Randomly select enemy spawn positions
	valid_positions.shuffle()
	for i in min(max_enemies, valid_positions.size()):
		enemy_spawns.append(valid_positions[i])
	
	# If we don't have enough spawns and have more valid positions, add more
	if enemy_spawns.size() < max_enemies and valid_positions.size() > enemy_spawns.size():
		# Try to find more positions with slightly less distance requirement
		var reduced_distance := MIN_ENEMY_DISTANCE - 1
		while enemy_spawns.size() < max_enemies and reduced_distance >= 3:
			for y in room_size:
				for x in room_size:
					if grid[y][x] in all_walkable_tiles:
						var pos := Vector2i(x, y)
						if pos not in enemy_spawns:  # Not already selected
							var distance: int = abs(x - center) + abs(y - center)
							if distance >= reduced_distance:
								enemy_spawns.append(pos)
								if enemy_spawns.size() >= max_enemies:
									break
				if enemy_spawns.size() >= max_enemies:
					break
			reduced_distance -= 1
	
	return enemy_spawns
