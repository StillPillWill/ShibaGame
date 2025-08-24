extends CharacterBody2D

# Movement & Physics
@export var speed = 500
@export var accel = 1500
@export var gravity = 1000
@export var jump_speed = 450

# Attack
@export var attack_lunge_speed = 50
var attacking = false

# Dash Settings
@export var dash_distance = 100
@export var dash_duration = 0.1
var dash_steps = 5
var dash_timer = 0.0
var dash_dir = Vector2.ZERO
var dash_progress = 0
var dash_gravity_delay = 0.05
var dash_gravity_timer = 0.0
var dash_override_window = 0.01
var dash_override_timer = 0.0
var can_dash = true

# Input Buffering
var buffered_dash_input = null
var input_buffer_time = 0.05
var buffer_timer = 0.0
@export var screen_width = 1152
@onready var enemy=get_parent().get_node("Enemy")

# Private variables
var player_direction = 1
var hit_offset_x = 0.0 # absolute x offset to mirror

func _ready():
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$AnimatedSprite2D.animation = "idle"
	

	#$Hit.body_entered.connect(_on_hit_body_entered)
	#$Hit/CollisionShape2D.disabled = true

	# cache absolute hit offset so we can mirror reliably
	hit_offset_x = abs($Hit.position.x)

func _physics_process(delta: float) -> void:
	# --- Dash ---
	if dash_timer > 0:
		_process_dash(delta)
		return

	# --- Attack state ---
	if attacking:
		velocity.y += gravity * delta
		_process_move_and_anim()
		return
	if not enemy.cooldown and enemy.playerInRange:
		velocity.x -=200#*sign(position.x-enemy.position.x)
		velocity.y -=200
		
		attacked()
	# --- Inputs ---
	handle_attack_input()
	handle_dash_input(delta)

	# --- Movement ---
	var input_dir = Input.get_axis("ui_left", "ui_right")
	
	if input_dir != 0:
		velocity.x = move_toward(velocity.x, input_dir * speed, accel * delta)
		var new_dir = int(sign(input_dir))
		if new_dir != player_direction:
			player_direction = new_dir
			_flip_visuals_and_hitbox()
		$AnimatedSprite2D.flip_h = (player_direction < 0)
	else:
		velocity.x = move_toward(velocity.x, 0, accel * delta * 5)
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > 0:
			velocity.y += 20
	
	# Jump
	if is_on_floor() and Input.is_action_just_pressed("ui_up"):
		velocity.y = -jump_speed
		attacking = false
	
	# Fast-fall
	if Input.is_action_pressed("ui_down"):
		velocity.y += 50

	# Wrap
	if position.x < 0:
		position.x = screen_width
	if position.x > screen_width:
		position.x = 0


	_process_move_and_anim()
	past_dir=player_direction
# --- helpers ---
var past_dir
func _flip_visuals_and_hitbox() -> void:
	# flip sprite visually
	$AnimatedSprite2D.flip_h = (player_direction < 0)
	# mirror hitbox by moving its position.x rather than scaling
	$Hit/CollisionShape2D.position.x = hit_offset_x * player_direction

func _process_move_and_anim() -> void:
	move_and_slide()
	handleAnimations()

func _process_dash(delta: float) -> void:
	dash_timer -= delta
	dash_override_timer -= delta
	dash_gravity_timer = dash_gravity_delay

	if dash_progress < dash_steps:
		position += dash_dir * (dash_distance / dash_steps)
		dash_progress += 1

	if buffered_dash_input and dash_override_timer > 0:
		dash_dir = buffered_dash_input.normalized()
		dash_override_timer = dash_override_window
		buffered_dash_input = null

	_process_move_and_anim()

# --- input handlers ---

func handle_attack_input():
	if Input.is_action_just_pressed("F") and not attacking:
		attack()

func handle_dash_input(delta: float):
	if not can_dash:
		return
	
	var new_dash_input = Vector2.ZERO
	if Input.is_action_just_pressed("dup"): new_dash_input.y -= 1
	if Input.is_action_just_pressed("ddown"): new_dash_input.y += 1
	if Input.is_action_just_pressed("dleft"): new_dash_input.x -= 1
	if Input.is_action_just_pressed("dright"): new_dash_input.x += 1

	if new_dash_input != Vector2.ZERO:
		if dash_timer <= 0:
			start_dash(new_dash_input.normalized())
		else:
			buffered_dash_input = new_dash_input
			buffer_timer = input_buffer_time

	if buffered_dash_input:
		buffer_timer -= delta
		if buffer_timer <= 0:
			buffered_dash_input = null

# --- state changes ---

func attack():
	print(enemy.inRange)
	print(attacking)
	velocity.x += attack_lunge_speed * player_direction
	attacking = true
	can_dash = false
	$Hit/CollisionShape2D.disabled = false
	$AnimatedSprite2D.play("attack")
	if enemy.inRange:
		await get_tree().create_timer(1).timeout
	attacking=false
	
func start_dash(dir: Vector2):
	dash_dir = dir
	dash_timer = dash_duration
	dash_progress = 0
	dash_override_timer = dash_override_window
	velocity *= 0.1
	dash_gravity_timer = dash_gravity_delay

# --- animations ---
func attacked():
	if enemy.cooldown:
		return # already flashing, don't restart
	enemy.cooldown = true
	modulate = Color(1, 0, 0) # back to normal
	await get_tree().create_timer(.3).timeout
	
	modulate = Color(1, 1, 1) # back to normal
	await get_tree().create_timer(2).timeout
	
	enemy.cooldown = false
	
func handleAnimations():
	if attacking:
		return
	if not is_on_floor():
		pass
	elif abs(velocity.x) > 1:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.sprite_frames.set_animation_speed("walk", abs(velocity.x)/50)
	else:
		$AnimatedSprite2D.play("idle")

func _on_animation_finished(anim_name: String = "") -> void:
	var name = anim_name if anim_name != "" else $AnimatedSprite2D.animation
	if name == "attack":
		attacking = false
		can_dash = true
		$Hit/CollisionShape2D.disabled = true
		$AnimatedSprite2D.play("idle")

func _on_hit_body_entered(body):
	print("hit bbody")
	if "Enemy" in str(body.name):
		enemy.inRange=true
		print("body")
		print(enemy.inRange)
		
func _on_hit_body_exited(body):
	#print("hit bbodyo")
	if "Enemy" in str(body.name):
		enemy.inRange=false
		#print(body)
		#print(enemy.inRange)
		
		
		
func _on_hitarea_body_entered(body: Node2D) -> void:
	#print("hitarea entered")
	if str(body).contains("Enemy"):
		enemy.playerInRange=true
		 #print("hit") # Replace with function body.


func _on_hitarea_body_exited(body: Node2D) -> void:
	#print("hitarea exited")
	if str(body).contains("Enemy"):
		enemy.playerInRange=false# Replace with function body.
