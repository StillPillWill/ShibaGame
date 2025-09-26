extends CharacterBody2D

var speed = 500
var accel_time = 0.1
var friction_time = 0.05
var gravity = 5000
var direction = [1, 0]
var stretching = false
var mov_tween: Tween
var rot_tween: Tween
var max_jump_height = 200.0
var min_jump_height = 60.0
var bullet = preload("res://bullet.tscn")
var fist_original_position: Vector2
var max_stretch_distance = 100.0
var bullet_speed = 700
var isDead=false
var hp=5
# Punch buffering (non-blocking)
var punch_queue = [] # array of {dir:int, t:int}
var punch_state = 0 # 0 idle, 1 forward, 2 backward
var current_punch_anim = ""
const PUNCH_BUFFER_MS = 200
const PUNCH_QUEUE_MAX = 2
const shootSound=preload(("res://sfx/playerShoot.wav"))
# Cache
@onready var animation_player = $AnimationPlayer
@onready var right_fist = $RFist

func _ready():
	fist_original_position = right_fist.position
	#Engine.time_scale=0.25
func _physics_process(delta):
	if isDead:
		get_parent().get_node("AttackUI").show()
		get_parent().get_node("AttackUI/Sprite2D").show()
		return
		
	handle_gravity(delta)
	handle_variable_jump()
	handle_animations()

	# movement tween friction each frame (keeps movement smooth)
	start_tween(Vector2.ZERO, friction_time)

	# Stretch handling (held)
	if Input.is_action_pressed("R"):
		stretch()

	handle_combat_input() # enqueues punches or shoots when stretching
	handle_normal_gameplay()
	handle_stretch_release()
	get_direction()

	# CharacterBody2D movement
	move_and_slide()

func _process(delta):
	# remove expired buffered inputs
	var now = Engine.get_physics_frames()
	while punch_queue.size() > 0:
		var age = now - punch_queue[0]["t"]
		if age > 12: # ~200 ms at 60 FPS
			punch_queue.remove_at(0)
		else:
			break


	# non-blocking punch state machine so movement keeps working
	if punch_state == 0 and punch_queue.size() > 0:
		var entry = punch_queue[0]
		punch_queue.remove_at(0)
		var dir = entry["dir"]
		animation_player.speed_scale=2
		animation_player.play(current_punch_anim)
		punch_state = 1
	
	elif punch_state == 1:
		if not animation_player.is_playing():
			animation_player.speed_scale=2
			animation_player.play_backwards(current_punch_anim,2)
			punch_state = 2
	elif punch_state == 2:
		if not animation_player.is_playing():
			punch_state = 0
			animation_player.speed_scale=1
			current_punch_anim = ""
		

func handle_gravity(delta: float) -> void:
	velocity.y += gravity * delta

func handle_variable_jump() -> void:
	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		var min_v = -sqrt(2.0 * gravity * min_jump_height)
		if velocity.y < min_v:
			velocity.y = min_v

func handle_normal_gameplay() -> void:
	handle_movement_input()
	handle_jump_input()

func handle_movement_input() -> void:
	# block movement while stretching
	if stretching:
		if mov_tween and mov_tween.is_valid():
			mov_tween.kill()
		velocity.x = 0
		return

	if Input.is_action_pressed("ui_left"):
		start_tween(Vector2(-speed, 0), accel_time)
	elif Input.is_action_pressed("ui_right"):
		start_tween(Vector2(speed, 0), accel_time)
	else:
		start_tween(Vector2.ZERO, friction_time)

func handle_combat_input() -> void:
	# If stretching, F shoots immediately; otherwise enqueue punch (non-blocking)
	if Input.is_action_just_pressed("F"):
		if stretching:
			shoot_bullet()
		else:
			# Only allow punch if not currently punching
			if punch_state == 0 and punch_queue.size() < PUNCH_QUEUE_MAX:
				# Set the animation based on direction
				if direction[0] > 0:
					current_punch_anim = "RightPunch"
				else:
					current_punch_anim = "LeftPunch"
				
				punch_queue.append({"dir": direction[0], "t": Engine.get_physics_frames()})
				

func handle_jump_input() -> void:
	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		jump()

func handle_stretch_release() -> void:
	if Input.is_action_just_released("R"):
		stretching = false
		if rot_tween and rot_tween.is_valid():
			rot_tween.kill()
		var return_tween = create_tween()
		return_tween.set_parallel()
		return_tween.tween_property(right_fist, "position", fist_original_position, 0.2).set_ease(Tween.EASE_OUT)
		return_tween.tween_property(right_fist, "rotation", 0.0, 0.2).set_ease(Tween.EASE_OUT)

func shoot_bullet() -> void:
	AudioManager.play_sfx(shootSound)
	var bullet_instance = bullet.instantiate()
	get_tree().root.add_child(bullet_instance)

	bullet_instance.global_position = right_fist.get_node("sp").global_position
	var bullet_direction = Vector2.RIGHT.rotated(right_fist.rotation+PI/2)
	bullet_instance.velocity = bullet_direction * bullet_speed

	# ----------------

	# Your original visual code
	if randi_range(0, 50) == 5:
		bullet_instance.modulate = Color(1, 0.3, 0.5)
	else:
		bullet_instance.modulate = Color(0.3, 1, 0.5)
	
	bullet_instance.scale = Vector2(0.3, 0.3)
	bullet_instance.sender = "Player"
	
func jump() -> void:
	var jump_v = -sqrt(2.0 * gravity * max_jump_height)
	velocity.y = jump_v

func get_direction() -> void:
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_vector.x != 0:
		direction[0] = sign(input_vector.x)
	direction[1] = input_vector.y

func start_tween(target_vel: Vector2, duration: float):
	if mov_tween and mov_tween.is_valid():
		mov_tween.kill()
	mov_tween = create_tween()
	mov_tween.tween_property(self, "velocity:x", target_vel.x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func handle_animations() -> void:
	# don't override punch while a punch is active
	if punch_state != 0:
		return

	# allow stretch/punch priority: if stretching, skip engine turn animations
	if stretching:
		return

	if Input.is_action_just_pressed("ui_left"):
		animation_player.play("EngineTurnLeft")
	elif Input.is_action_just_pressed("ui_right"):
		animation_player.play("EngineTurnRight")
	elif Input.is_action_just_released("ui_left") or Input.is_action_just_released("ui_right"):
		if not Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_right"):
			animation_player.play("RESET")

	# Play RESET when stopping due to friction
	if is_on_floor() and is_zero_approx(velocity.x) and not Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_right"):
		var anim = animation_player.current_animation
		if anim != "RESET" and anim != "EngineTurnLeft" and anim != "EngineTurnRight" and anim != "RightPunch" and anim != "LeftPunch":
			animation_player.play("RESET")

func stretch() -> void:
	if not Input.is_action_pressed("R"):
		stretching = false
		return
	# start stretching — block movement while held
	stretching = true

	# require directional input to stretch
	if not (Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")):
		return

	var input_dir = Vector2(direction[0], direction[1])
	if input_dir.length_squared() == 0:
		return

	var move_dir = input_dir.normalized()
	var new_position = right_fist.position + move_dir * 5
	var distance_from_origin = fist_original_position.distance_to(new_position)

	if distance_from_origin <= max_stretch_distance:
		right_fist.position = new_position
	else:
		var direction_to_fist = (new_position - fist_original_position).normalized()
		right_fist.position = fist_original_position + direction_to_fist * max_stretch_distance

	var target_angle = input_dir.angle() - PI / 2
	if rot_tween and rot_tween.is_valid():
		rot_tween.kill()
	rot_tween = create_tween()
	rot_tween.tween_property(right_fist, "rotation", target_angle, 0.05).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	
func take_damage():
	hp-=1
	AudioManager.play_sfx(preload("res://sfx/hitHurt.wav"))
	if hp<=0:
		isDead=true
		AudioManager.play_sfx(preload("res://sfx/death.wav"))

func _on_hit_area_area_entered(area) -> void:
	print(area)
	if area.get_parent().get_parent()==get_node("RFist"):
		print("entered")

func slamHit():
	
	velocity.y=-1000
	print("f")
	hp-=1
	#AudioManager.play_sfx(preload("res://sfx/thud2.wav"))

	if hp==0:
		isDead=true		
		AudioManager.play_sfx(preload("res://sfx/death.wav"))
	position.y-=6
	velocity.x=randf_range(-5000,5000)
	
