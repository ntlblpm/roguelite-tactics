class_name DiscreteBarDisplay
extends Container

## Displays a discrete bar with individual segments for each point
## Used for MP and AP display in combat UI

@export var filled_color: Color = Color.WHITE
@export var empty_color: Color = Color(0.3, 0.3, 0.3, 0.5)
@export var segment_height: float = 8.0
@export var segment_width: float = 20.0  # Width for vertical bars
@export var segment_separation: int = 2
@export var is_vertical: bool = true  # Whether to display vertically

var current_value: int = 0
var max_value: int = 0
var segments: Array[Panel] = []

func _ready() -> void:
	# Set custom minimum size
	if is_vertical:
		custom_minimum_size.x = segment_width
	else:
		custom_minimum_size.y = segment_height

func update_display(current: int, maximum: int) -> void:
	"""Update the discrete bar display with new values"""
	current_value = current
	max_value = maximum
	
	# Clear existing segments
	for segment in segments:
		segment.queue_free()
	segments.clear()
	
	# Create new segments
	for i in range(max_value):
		var segment := Panel.new()
		
		# Create stylebox for the segment
		var style := StyleBoxFlat.new()
		style.bg_color = filled_color if i < current_value else empty_color
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 2
		style.corner_radius_bottom_left = 2
		style.corner_radius_bottom_right = 2
		
		# Add a subtle border
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.2, 0.2, 0.2, 0.8)
		
		segment.add_theme_stylebox_override("panel", style)
		
		add_child(segment)
		segments.append(segment)
	
	# Trigger layout update
	queue_sort()

func set_filled_color(color: Color) -> void:
	"""Set the color for filled segments"""
	filled_color = color
	_update_segment_colors()

func set_empty_color(color: Color) -> void:
	"""Set the color for empty segments"""
	empty_color = color
	_update_segment_colors()

func _update_segment_colors() -> void:
	"""Update colors of existing segments"""
	for i in range(segments.size()):
		var style := segments[i].get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.bg_color = filled_color if i < current_value else empty_color

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_do_layout()

func _do_layout() -> void:
	"""Perform custom layout for segments"""
	if segments.is_empty():
		return
	
	var available_size := size
	var segment_count := segments.size()
	
	if is_vertical:
		# Vertical layout (bottom to top)
		var total_height := available_size.y - (segment_separation * (segment_count - 1))
		var segment_h := total_height / segment_count
		
		for i in range(segment_count):
			var segment := segments[i]
			var y_pos := available_size.y - ((i + 1) * segment_h) - (i * segment_separation)
			segment.position = Vector2(0, y_pos)
			segment.size = Vector2(available_size.x, segment_h)
	else:
		# Horizontal layout (left to right)
		var total_width := available_size.x - (segment_separation * (segment_count - 1))
		var segment_w := total_width / segment_count
		
		for i in range(segment_count):
			var segment := segments[i]
			var x_pos := i * (segment_w + segment_separation)
			segment.position = Vector2(x_pos, 0)
			segment.size = Vector2(segment_w, available_size.y)