extends CharacterBody2D

var speed = 500
var accel = 1500
var gravity = 1000
var inRange=false
# Attack
var is_hit = false

var player

func _ready():
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$AnimatedSprite2D.animation = "idle"
	player = get_parent().get_node("Zoomer")
	$Hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	$Hitbox.body_exited.connect(_on_attack_hitbox_body_exited)
	var player_hitbox = player.get_node("Hit")

func _physics_process(delta: float) -> void:
	if player.attacking and inRange and not is_hit:
		velocity.y=-50
		velocity.x-=50*player.playerDirection
		print("hit")
		hit()
	velocity.y+=gravity*delta
	if player.attacking and inRange:
		print("f")

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
	if body.name == "Zoomer":
		inRange=true
		print("f")

func _on_attack_hitbox_body_exited(body):
	if body.name == "Zoomer":
		inRange=false
		print("fv")
func hit():
	if is_hit:
		return # already flashing, don't restart
	is_hit = true

	modulate = Color(1, 0, 0) # turn red

	# Wait 1 second without freezing physics/game
	await get_tree().create_timer(1.0).timeout

	modulate = Color(1, 1, 1) # back to normal
	is_hit = false
