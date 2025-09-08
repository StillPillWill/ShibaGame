extends Label

@onready var target_button=get_parent().get_parent().get_node("Button")        # The button in world space
@onready var camera =get_parent().get_parent().get_node("Camera2D")    # Your active Camera2D



func _process(_delta: float) -> void:
	if not target_button or not camera:
		return

	# Button global position in world space
	var button_pos = target_button.global_position

	# Camera properties
	var cam_pos = camera.global_position
	var cam_zoom = camera.zoom
	var viewport_size = Vector2(camera.get_viewport().size)  # cast to Vector2

	# Convert world position to screen coordinates
	var screen_pos = (button_pos - cam_pos) / cam_zoom + viewport_size / 2

	# Calculate scaled size for label
	var button_size = target_button.get_rect().size
	var scaled_size = button_size * target_button.scale / cam_zoom  # divide by zoom to counteract camera

	# Apply position and size to label
	position = screen_pos
	custom_minimum_size = scaled_size
	size = scaled_size
