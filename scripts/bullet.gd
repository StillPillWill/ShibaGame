extends CharacterBody2D


@onready var player=get_parent().get_node("Zoomer")
func _ready() -> void:
	pass
	
func _physics_process(delta: float) -> void:
	move_and_slide()


func _on_hit_area_body_entered(body: Node2D) -> void:
	print(body) # Replace with function body.
	if "Zoomer" in str(body):
		player.hp-=1
		player.hitByBullet(velocity)
		AudioManager.play_sfx(preload("res://sfx/hitLaser.wav"))
	$CPUParticles2D.emitting=true
	$Sprite2D.hide()
	
	await get_tree().create_timer(0.2).timeout
	queue_free()
