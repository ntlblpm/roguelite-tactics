extends Button

func _ready():
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.15)  # Dark background
	
	# Cyan border
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0, 0.5, 0.5)  # Darker cyan
	
	# Rounded corners
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("normal", style_normal)
	
	# Hover state
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.25, 0.25)  # Lighter on hover
	style_hover.border_width_left = 2
	style_hover.border_width_right = 2
	style_hover.border_width_top = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(0, 0.5, 0.5)  # Darker cyan
	
	# Rounded corners
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("hover", style_hover)
	
	# Pressed state
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.1, 0.1, 0.1)  # Darker when pressed
	style_pressed.border_width_left = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_top = 2
	style_pressed.border_width_bottom = 2
	style_pressed.border_color = Color(0, 0.4, 0.4)  # Even darker cyan when pressed
	
	# Rounded corners
	style_pressed.corner_radius_top_left = 4
	style_pressed.corner_radius_top_right = 4
	style_pressed.corner_radius_bottom_left = 4
	style_pressed.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("pressed", style_pressed)