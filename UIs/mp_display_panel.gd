extends Panel

@onready var mp_container: HBoxContainer = $MPContainer
@onready var mp_text: Label = $MPContainer/MPText
@onready var discrete_bar: DiscreteBarDisplay
@onready var text_overlay: Label

func _ready():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)  # Slightly darker background
	
	# Thinner borders for sub-panels
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0, 0.5, 0)  # Darker green tint for MP
	
	# Rounded corners
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("panel", style)
	
	# Hide the original container and text
	mp_container.visible = false
	
	# Create discrete bar display that fills the panel
	discrete_bar = DiscreteBarDisplay.new()
	discrete_bar.filled_color = Color(0.2, 0.8, 0.2)  # Green for MP
	discrete_bar.empty_color = Color(0.1, 0.3, 0.1, 0.5)  # Dark green-gray
	discrete_bar.segment_height = 8.0
	discrete_bar.segment_separation = 2
	discrete_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	discrete_bar.add_theme_constant_override("margin_left", 8)
	discrete_bar.add_theme_constant_override("margin_right", 8)
	discrete_bar.add_theme_constant_override("margin_top", 8)
	discrete_bar.add_theme_constant_override("margin_bottom", 8)
	add_child(discrete_bar)
	
	# Create text overlay
	text_overlay = Label.new()
	text_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
	text_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_overlay.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	text_overlay.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	text_overlay.add_theme_constant_override("shadow_offset_x", 1)
	text_overlay.add_theme_constant_override("shadow_offset_y", 1)
	text_overlay.text = "MP: 0/0"
	add_child(text_overlay)

func update_mp_display(current: int, maximum: int) -> void:
	"""Update both text and discrete bar display"""
	if text_overlay:
		text_overlay.text = "MP: %d/%d" % [current, maximum]
	if discrete_bar:
		discrete_bar.update_display(current, maximum)