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

# Scene Properties
@export var screen_width = 1152

# Private variables
var player_direction = 1

func _ready():
	# This connects the animation signal via code, which is reliable.
	# It correctly passes the animation name to the function.
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$AnimatedSprite2D.animation = "idle"

	# Connect the signal from our "Hit" Area2D to detect when we hit an enemy.
	$Hit.body_entered.connect(_on_hit_body_entered)
	# Start with the hitbox disabled.
	$Hit/CollisionShape2D.disabled = true


func _physics_process(delta: float) -> void:
	# --- Handle dash state ---
	if dash_timer > 0:
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

		move_and_slide()
		handleAnimations()
		return

	# --- Handle attack state ---
	if attacking:
		# Apply gravity while attacking so the player doesn't float.
		velocity.y += gravity * delta
		move_and_slide()
		handleAnimations()
		return

	# --- Handle Inputs ---
	handle_attack_input()
	handle_dash_input(delta)

	# --- Normal Movement ---
	var input_dir = Input.get_axis("ui_left", "ui_right")

	if input_dir != 0:
		velocity.x = move_toward(velocity.x, input_dir * speed, accel * delta)
		player_direction = sign(input_dir)
		$AnimatedSprite2D.flip_h = (input_dir < 0)
	else:
		# Apply more friction when stopping for a snappier feel.
		velocity.x = move_toward(velocity.x, 0, accel * delta * 5)

	# --- Vertical Movement & Gravity ---
	# Apply gravity only when in the air. This prevents jitter on slopes.
	if not is_on_floor():
		velocity.y += gravity * delta
		# Add a little extra gravity when falling for better game feel
		if velocity.y > 0:
			velocity.y += 20
	
	# Jump Input
	if is_on_floor() and Input.is_action_just_pressed("ui_up"):
		velocity.y = -jump_speed
		attacking = false
	
	# Fast-fall Input
	if Input.is_action_pressed("ui_down"):
		velocity.y += 50

	# --- Wrap-around screen ---
	if position.x < 0:
		position.x = screen_width
	if position.x > screen_width:
		position.x = 0

	# --- Final move call ---
	move_and_slide()
	handleAnimations()


# --- Input Handling Functions ---

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
		else: # Buffer the input
			buffered_dash_input = new_dash_input
			buffer_timer = input_buffer_time

	if buffered_dash_input:
		buffer_timer -= delta
		if buffer_timer <= 0:
			buffered_dash_input = null


# --- State-changing Functions ---

func attack():
	velocity.x += attack_lunge_speed * player_direction
	attacking = true
	can_dash = false
	$Hit/CollisionShape2D.disabled = false # Enable hitbox on attack
	$AnimatedSprite2D.play("attack")

func start_dash(dir: Vector2):
	dash_dir = dir
	dash_timer = dash_duration
	dash_progress = 0
	dash_override_timer = dash_override_window
	velocity *= 0.1
	dash_gravity_timer = dash_gravity_delay


# --- Animations and Signals ---

func handleAnimations():
	if attacking:
		return

	if not is_on_floor():
		pass
	elif abs(velocity.x) > 1:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.sprite_frames.set_animation_speed("walk", abs(velocity.x) / 50)
	else:
		$AnimatedSprite2D.play("idle")


# This function now correctly receives the animation name.
func _on_animation_finished(anim_name):
	# We check if the animation that just finished is the "attack" one.
	if anim_name == "attack":
		# If it is, we reset the player's state to unlock their controls.
		attacking = false
		can_dash = true
		$Hit/CollisionShape2D.disabled = true # Disable hitbox after attack
		$AnimatedSprite2D.play("idle")


# This function handles the attack hitting an enemy.
func _on_hit_body_entered(body):
	# Check if the body we hit has a "hit" method (our enemy does).
	if body.has_method("hit"):
		body.hit()
