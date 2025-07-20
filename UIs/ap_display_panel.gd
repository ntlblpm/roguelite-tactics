extends Panel

@onready var ap_container: HBoxContainer = $APContainer
@onready var ap_text: Label = $APContainer/APText
@onready var discrete_bar: DiscreteBarDisplay
@onready var text_label: Label
@onready var content_container: HBoxContainer

func _ready():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)  # Slightly darker background
	
	# Thinner borders for sub-panels
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.1, 0.3, 0.5)  # Darker blue tint for AP
	
	# Rounded corners
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("panel", style)
	
	# Hide the original container and text
	ap_container.visible = false
	
	# Create horizontal container for text and bar
	content_container = HBoxContainer.new()
	content_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_container.add_theme_constant_override("margin_left", 8)
	content_container.add_theme_constant_override("margin_right", 8)
	content_container.add_theme_constant_override("margin_top", 8)
	content_container.add_theme_constant_override("margin_bottom", 8)
	content_container.add_theme_constant_override("separation", 8)
	add_child(content_container)
	
	# Create text label on the left
	text_label = Label.new()
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	text_label.add_theme_constant_override("shadow_offset_x", 1)
	text_label.add_theme_constant_override("shadow_offset_y", 1)
	text_label.text = "AP: 0/0"
	content_container.add_child(text_label)
	
	# Create discrete bar display on the right
	discrete_bar = DiscreteBarDisplay.new()
	discrete_bar.filled_color = Color(0.3, 0.6, 1.0)  # Blue for AP
	discrete_bar.empty_color = Color(0.1, 0.2, 0.3, 0.5)  # Dark blue-gray
	discrete_bar.segment_height = 8.0
	discrete_bar.segment_width = 16.0  # Thin vertical bar
	discrete_bar.segment_separation = 2
	discrete_bar.is_vertical = true
	discrete_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	discrete_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(discrete_bar)

func update_ap_display(current: int, maximum: int) -> void:
	"""Update both text and discrete bar display"""
	if text_label:
		text_label.text = "AP: %d/%d" % [current, maximum]
	if discrete_bar:
		discrete_bar.update_display(current, maximum)
