extends ParallaxBackground

@export var follow_camera: Camera2D

func _process(delta):
	if not follow_camera:
		return

	var zoom_factor = follow_camera.zoom
	for layer in get_children():
		if layer is ParallaxLayer:
			# Inverse scale to compensate camera zoom
			layer.scale = Vector2(1, 1) / zoom_factor

			# Update motion_mirroring dynamically
			if layer.get_child_count() > 0:
				var child = layer.get_child(0)
				if child is Sprite2D and child.texture:
					layer.motion_mirroring = child.texture.get_size() * child.scale
