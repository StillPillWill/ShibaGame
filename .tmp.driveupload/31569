extends Node2D

@onready var enemy=get_parent()

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if enemy.get_node("AnimatedSprite2D").animation=="shoot":
		enemy.get_node("AnimatedSprite2D").position.y=-14
		show()
	else:
		enemy.get_node("AnimatedSprite2D").position.y=0
		hide()
	$AnimatedSprite2D.play("idle")
