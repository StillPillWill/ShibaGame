extends CharacterBody2D

var sender=null
#@onready var player=get_parent().get_node("Zoomer")
func _ready() -> void:
	pass
	
func _physics_process(delta: float) -> void:
	move_and_slide()


func _on_hit_area_body_entered(body: Node2D) -> void:
	#print(body) # Replace with function body.
		
	$CPUParticles2D.emitting=true
	$Sprite2D.hide()
	print(sender)
	if sender=="Player":
		collision_mask=2
		collision_layer=1
	else: 
		collision_layer=2
		collision_mask=1
	await get_tree().create_timer(0.2).timeout
	queue_free()

func enstein():
	pass
