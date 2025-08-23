extends Camera2D

var player: Node2D
var viewport_size = Vector2.ZERO

func _ready() -> void:
	viewport_size = get_viewport().size
	player = get_parent().get_node("Zoomer")
	offset=viewport_size/2	
	
func _process(delta: float) -> void:
	pass
