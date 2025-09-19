extends CharacterBody2D

var speed = 500
var accel_time = 0.1     # how fast it tweens when starting
var friction_time = 0.05  # how fast it slows when released
var gravity=16000
var mov_tween: Tween

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		$AnimationPlayer.play("EngineTurnLeft")
		start_tween(Vector2(-speed, 0), accel_time)
	elif Input.is_action_pressed("ui_right"):
		start_tween(Vector2(speed, 0), accel_time)
		$AnimationPlayer.play("EngineTurnRight")
	else:
		start_tween(Vector2.ZERO, friction_time)
		$AnimationPlayer.play("RESET")
	if not is_on_floor():
		velocity.y+=gravity*delta
	move_and_slide()

func start_tween(target_vel: Vector2, duration: float) -> void:
	if mov_tween and mov_tween.is_valid():
		mov_tween.kill()

	mov_tween = create_tween()
	mov_tween.tween_property(self, "velocity", target_vel, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
