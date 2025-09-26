# In bullet.gd
extends CharacterBody2D

var sender = null
var dac=0
var double=false
func _physics_process(delta: float) -> void:
	move_and_slide()
	# REMOVE the if/else block that changes the collision mask/layer
	dac+=delta
	if dac==20:
		queue_free()


func _on_hit_area_entered(area) -> void:
	var a=area.get_parent()
	print(a.get_parent().get_groups())
	#print(sender)
	if sender=="Player" and a.is_in_group("Player"):
		return
	elif sender=="Enemy" and a.is_in_group("Enemy"):
		return
	elif sender=="Player" and a.is_in_group("Enemy"):
		a.take_damage()
	elif sender=="Enemy" and a.is_in_group("Player"):
		get_parent().get_node("PlayerScratch").take_damage()
	velocity*=0.1
	$CPUParticles2D.emitting = true
	$Sprite2D.hide()
	await get_tree().create_timer(0.2).timeout
	
	queue_free()

func enstein():
	pass
