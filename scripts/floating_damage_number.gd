class_name FloatingDamageNumber
extends Node2D

## Displays floating damage numbers that rise and fade out

@onready var label: RichTextLabel = $RichTextLabel

func display_damage(damage: int, start_position: Vector2) -> void:
	"""Display the damage number at the given position"""
	global_position = start_position
	
	# Set the damage text with formatting
	label.text = "[center][b]-%d[/b][/center]" % damage
	
	# Ensure font size is set
	label.add_theme_font_size_override("normal_font_size", 11)
	
	# Create animation tween
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Float upward movement (reduced distance)
	tween.tween_property(self, "position:y", position.y - 8, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# Fade out (happens simultaneously with movement)
	tween.tween_property(self, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_IN)
	
	# Queue free when animation completes
	tween.chain().tween_callback(queue_free)