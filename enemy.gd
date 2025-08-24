extends CharacterBody2D
"""

var speed = 500
var accel = 1500
var gravity = 1000
var inRange=false
var cooldown
var playerInRange=false
var is_hit = false
var hp=3
var player

func _ready():
	player = get_parent().get_node("Zoomer")
	var player_hitbox = player.get_node("Hit")
	
func _physics_process(delta: float) -> void:
	#print(player.attacking,inRange,is_hit)
	
	if player.attacking and inRange and not is_hit:
		print("hit2")
		hit()
	velocity.y+=gravity*delta
	if player.attacking and inRange:
		pass
	if velocity.x>0:
		velocity.x-=10
	if velocity.x<0:
		velocity.x+=10
	if position.x<0:
		position.x=1152
	if position.x>1152:
		position.x=0
	# --- Move player ---
	move_and_slide()
	handleAnimations()
	
	
func handleAnimations():
	var horizontal_speed = abs(velocity.x)
	if horizontal_speed < 1 and is_on_floor():
		$AnimatedSprite2D.play("idle")
	else:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.sprite_frames.set_animation_speed("walk", horizontal_speed / 10)


func _on_animation_finished():
	if $AnimatedSprite2D.animation == "attack":
		$AnimatedSprite2D.play("idle")
		
func _on_attack_hitbox_body_entered(body):
	
	if str(body.name).contains("Zoomer"):
		print("enemy hitobx enter" +str(body))
		inRange=true

func _on_attack_hitbox_body_exited(body):
	
	if str(body.name).contains("Zoomer"):
		print("enemy hitobx exit")
		inRange=false
		
func hit():
	print("g")
	if is_hit:
		return # already flashing, don't restart
	is_hit = true
	velocity.y-=200
	velocity.x+= player.player_direction*200
	modulate = Color(1, 0, 0) # turn red
	hp-=1
	if hp==0:
		dead()
	# Wait 1 second without freezing physics/game
	await get_tree().create_timer(.3).timeout

	modulate = Color(1, 1, 1) # back to normal
	is_hit = false
	
	

func dead():
	hp=3
	position.y=-2000
	position.x=randi_range(0,1160)
"""
