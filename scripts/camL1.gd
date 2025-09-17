extends Camera2D

@onready var player=get_parent().get_node("Zoomer")

func _process(delta: float) -> void:
	position.x=player.position.x
