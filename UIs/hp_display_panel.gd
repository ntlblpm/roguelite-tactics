extends Panel

func _ready():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)  # Slightly darker background
	
	# Thinner borders for sub-panels
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.15, 0.15)  # Darker red tint for HP
	
	# Rounded corners
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("panel", style)