extends Panel

func _ready():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)  # Dark gray background
	
	# No border for main panel
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	
	add_theme_stylebox_override("panel", style)