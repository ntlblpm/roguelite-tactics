class_name DiscreteBarDisplay
extends VBoxContainer

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
	add_theme_constant_override("separation", segment_separation)
	alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Set custom minimum size for vertical bars
	if is_vertical:
		custom_minimum_size.x = segment_width

func update_display(current: int, maximum: int) -> void:
	"""Update the discrete bar display with new values"""
	current_value = current
	max_value = maximum
	
	# Clear existing segments
	for segment in segments:
		segment.queue_free()
	segments.clear()
	
	# Create new segments (in reverse order so filled ones are at bottom)
	for i in range(max_value - 1, -1, -1):
		var segment := Panel.new()
		
		if is_vertical:
			segment.size_flags_horizontal = Control.SIZE_FILL
			segment.size_flags_vertical = Control.SIZE_EXPAND_FILL
			segment.custom_minimum_size.y = segment_height
			segment.custom_minimum_size.x = segment_width
		else:
			segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			segment.size_flags_vertical = Control.SIZE_EXPAND_FILL
			segment.custom_minimum_size.y = segment_height
		
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
		
		# Add margins for better appearance
		if is_vertical:
			style.content_margin_left = 2
			style.content_margin_right = 2
		else:
			style.content_margin_left = 4
			style.content_margin_right = 4
		
		segment.add_theme_stylebox_override("panel", style)
		
		add_child(segment)
		segments.append(segment)

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
		var actual_index = segments.size() - 1 - i  # Reverse the index since bars are added in reverse order
		var style := segments[i].get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.bg_color = filled_color if actual_index < current_value else empty_color