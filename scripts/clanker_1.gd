extends CharacterBody2D


@export var friction=5
@export var gravity = 1500
@export var jumpSpeed = 1000
@onready var player=get_parent().get_node("Zoomer")
var recentAttack=""
var screen_width = get_viewport_rect().size.x
var cooldown=false
var previousAttack=null
var highFlag=true
var dac=0
var animationState=["idle",0.5]
var animationTimer={"PunchHitbox":0.5, "KickHitbox":1}
var inRange={"KickHitbox":false, "PunchHitbox":false}
var attackAnimation={"KickHitbox":"hitRight", "PunchHitbox": "hitRight", null:"idle"}
var playerDir=[0,0]
var attack=false
var target=[0,0]
var attackFlag=false
var shotsFired=false
var hp=50
const ROTATE_BEFORE_SHOOT = 0.45

var attackMode=""
var bullet=preload("res://bullet.tscn")
var isDead=false
var attackKnockback={
"KickHitbox":Vector2(-400,500),
"PunchHitbox":Vector2(-200,-400),
"uppercut":Vector2(-100,-500),
"lowercut":Vector2(-100,500),
"straight":Vector2(-300,200),
"verticalup":Vector2(-20,-800),
"verticaldown":Vector2(-20,800)
}
var hitStun=0
var justFloor
var velocityBuffer=Vector2.ZERO
var upDownInFlight = false

# --- Added for smooth attack launch ---
var attackLaunch=false
var desiredVelocity=Vector2.ZERO
var attackAccel=3000.0
var maxAttackSpeed=900.0
# --------------------------------------

# +++ ADDED +++ New state variables for the Shoot attack's powerup phase
var isPoweringUp = false
var powerupTimer = 0.0
const POWERUP_DURATION = 2.15 # The duration of the powerup animation
var isShooting = false
var laser_sfx = preload("res://sfx/laserShoot.wav")
@export var per_shot_delay = 0.2
@export var between_shots_delay = 0.06
@export var max_shots_allowed = 100
@export var bullet_lifetime = 5.0

func _ready():
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	$Hitbox.area_exited.connect(_on_hitbox_area_exited)
	$AnimatedSprite2D.play("idle")

var hoverOn=false
var attackInProgress=false
@export var bullet_spawn_offset = Vector2(0, -30) # local sprite offset (x right, y down)

func _physics_process(delta: float) -> void:
	if isDead:
		return
	if player.isDead:
		rotation+=0.001
		return
	if isPoweringUp:
		handlePowerup(delta)
		return 

	dac+=delta

	if attackInProgress:
		continueAttack()

	applyFriction(delta)

	# --- CHANGED --- 'hoverOn' is now exclusively for the 'upDown' attack.
	if hoverOn:
		velocity.y=0
	else:
		applyGravity(delta)

	if not attackFlag and not attackInProgress and not isShooting:
		if dac > 3:
			attackPlayer()
			print("attacking")

			
	if attackLaunch:
		velocity = velocity.move_toward(desiredVelocity, attackAccel * delta)
	else:
		velocity += velocityBuffer
		velocityBuffer = Vector2.ZERO
		
	handleAnimations()
	move_and_slide()

	if is_on_floor():
		if upDownInFlight:
			# landed after upDown attack — clear rotation and flight flag
			rotation = 0
			AudioManager.play_sfx(preload("res://sfx/thud.wav"))
			upDownInFlight = false

		if attackFlag:
			velocity = Vector2.ZERO
			attackFlag = false
			attackLaunch = false
			velocityBuffer = Vector2.ZERO
			print("stuff")



# +++ ADDED +++ New function to handle the powerup state frame-by-frame

func stepTowards(num, target, step):
	var out=num
	if num<target:
		out+=step
	if num>target:
		out-=step
	return out

func applyFriction(delta):
	if is_on_floor() and not attackInProgress: # --- CHANGED --- Don't reset body rotation if mid-attack
		rotation=0
	if is_on_floor() and friction > 0:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
	if abs(velocity.x) < 1 and friction > 0:
		velocity.x = 0

func applyGravity(delta):
	if not is_on_floor():
		velocity.y+=gravity*delta

# --- Unchanged helper functions from here ... ---

func _on_hitbox_area_entered(body: Node2D) -> void:
	if "KickHitbox" in str(body):
		inRange["KickHitbox"]=true
	if "PunchHitbox" in str(body):
		inRange["PunchHitbox"]=true
	print("entered"+str(body))

func _on_hitbox_area_exited(body: Node2D) -> void:
	if "KickHitbox" in str(body):
		inRange["KickHitbox"]=false
	if "PunchHitbox" in str(body):
		inRange["PunchHitbox"]=false
	
func attacked(attack,direction):
	if inRange[attack]:
		hit(attack,direction)

func attackName(attack, direction):
	var attackName=""
	if attack=="PunchHitbox":
		if direction==[0,0] or [abs(direction[0]),direction[1]]==[1,0]:
			attackName="straight"
		elif direction[1]==1 and abs(direction[0])==1:
			attackName="uppercut"
		elif direction[1]==-1 and abs(direction[0])==1:
			attackName="lowercut"
		elif direction==[0,1]:
			attackName="verticalup"
		elif direction==[0,-1]:
			attackName="verticaldown"
		return attackName
	else:
		return attack

func hit(attack,direction):
	print("hit")
	playerDir=direction
	animationState = [attack, animationTimer[attack]]
	var attackName=attackName(attack,direction)
	if attack == "PunchHitbox":
		velocityBuffer.y += player.velocity.y
		print("super")
	AudioManager.play_sfx(preload("res://sfx/hit2.wav"))
	hp-=1
	print("hit")
	if hp==0:
		dead()
		
func _on_hitbox_body_entered(body: Node2D) -> void:
	if "Zoomer" in str(body) and attackFlag:
		player.slamHit()

func dead():
	isDead=true
	$AnimatedSprite2D.play("explode")
	AudioManager.play_sfx(preload("res://sfx/explosion.wav"))
	$AnimatedSprite2D/CPUParticles2D.emitting = true
	await get_tree().create_timer(0.5).timeout
	hide()
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	print("dead")
	get_parent().get_node("AttackUI").show()
	get_parent().get_node("AttackUI/Label").text="You Win"
# --- ... until here. Significant changes below. ---

func attackPlayer():
	dac = 0
	# single-frame upward impulse to start jump
	velocityBuffer.y -= jumpSpeed
	attackInProgress = true
	shotsFired = false
	var c = randi_range(0, 2)
	if c == 0:
		attackMode = "Shoot"
	else:
		attackMode = "upDown"

# continueAttack handles the frame-by-frame state after the initial jump
func continueAttack():
	# UPDOWN: detect apex, hover, rotate toward stored target, then launch
	if attackMode == "upDown":
		# detect apex (started falling)
		if velocity.y > 0 and not hoverOn:
			hoverOn = true
			velocity.y = 0
			var target_angle = (player.position - position).angle() + PI / 2
			# wrap to [-PI, PI]
			if target_angle > PI:
				target_angle -= PI * 2
			elif target_angle < -PI:
				target_angle += PI * 2
			# store as [angle, position]
			target = [target_angle, player.position]

		if hoverOn:
			var targ_angle = (player.position - position).angle() + PI / 2
			if target is Array and target.size() > 0:
				targ_angle = float(target[0])

			rotation = lerp_angle(rotation, targ_angle, 6.0 * get_physics_process_delta_time())

			# when nearly aligned, wait a beat then launch (keep body rotated during flight)
			if abs(angwrap(rotation - targ_angle)) < 0.08:
				await get_tree().create_timer(0.08).timeout

				# resolve target position into a Vector2
				var target_pos = player.position
				if target is Array and target.size() > 1 and target[1] is Vector2:
					target_pos = target[1]
				elif target is Vector2:
					target_pos = target

				var dir_vec = target_pos - position
				if dir_vec == Vector2.ZERO:
					dir_vec = Vector2(0, -1)
				var direction = dir_vec.normalized()
				var distance = dir_vec.length()
				var speed = distance * 5.0
				if speed > maxAttackSpeed:
					speed = maxAttackSpeed
				desiredVelocity = direction * speed

				attackLaunch = true
				hoverOn = false
				attackInProgress = false
				attackFlag = true
				upDownInFlight = true
		return

	# SHOOT: wait until apex then hover, play powerup (handled by handlePowerup)
	if attackMode == "Shoot":
		if velocity.y > 0 and not hoverOn:
			hoverOn = true
			velocity.y = 0
			velocity = Vector2.ZERO
			isPoweringUp = true
			powerupTimer = POWERUP_DURATION
			$AnimatedSprite2D.play("powerup")
			shotsFired = true
		return


	# SHOOT: wait until apex then hover, play powerup (handled by handlePowerup)
	if attackMode == "Shoot":
		if velocity.y > 0 and not hoverOn:
			hoverOn = true
			velocity.y = 0
			# stop movement completely while powering up
			velocity = Vector2.ZERO
			# prepare sprite rotation target (handled by handlePowerup)
			isPoweringUp = true
			powerupTimer = POWERUP_DURATION
			$AnimatedSprite2D.play("powerup")
			# store that we started the powerup so we don't re-enter
			shotsFired = true
		return

# helper to keep angles small for comparison
func angwrap(a):
	if a > PI:
		return a - PI * 2
	if a < -PI:
		return a + PI * 2
	return a

# handlePowerup rotates the sprite to face the player while counting down the powerup timer.
func handlePowerup(delta: float):
	# hold still while powering up, but DO NOT rotate the sprite yet
	velocity = Vector2.ZERO
	powerupTimer -= delta

	# ensure powerup animation is playing
	if $AnimatedSprite2D.animation != "powerup":
		$AnimatedSprite2D.play("powerup")

	if powerupTimer <= 0:
		isPoweringUp = false
		# start shooting sequence; shoot() will rotate the sprite exactly when play("shoot") runs
		isShooting = true
		shoot(10)

func shoot(times):
	# lock states so animations won't be overridden
	attackInProgress = false
	attackFlag = false
	hoverOn = true
	velocity = Vector2.ZERO
	isShooting = true

	for i in range(times):
		if isDead:
			break

		# retarget just before each shot
		var dir = (player.position - position).normalized()

		# rotate sprite to face player immediately before shot
		$AnimatedSprite2D.rotation = dir.angle() + PI / 2

		# compute spawn point using the sprite's rotation
		var rotated_offset = bullet_spawn_offset.rotated($AnimatedSprite2D.rotation)
		var spawn_pos = position + rotated_offset

		# play shoot animation
		$AnimatedSprite2D.play("shoot")
		await get_tree().create_timer(per_shot_delay).timeout

		# spawn bullet
		var c = bullet.instantiate()
		c.position = spawn_pos
		var bullet_speed = 400
		c.velocity = dir * bullet_speed
		c.scale = Vector2(0.25, 0.25)
		get_parent().add_child(c)
		AudioManager.play_sfx(laser_sfx)

		# small pause before next shot
		await get_tree().create_timer(between_shots_delay).timeout

	# finish shooting
	isShooting = false
	hoverOn = false
	attackInProgress = false
	attackFlag = true
	$AnimatedSprite2D.rotation = 0
	$AnimatedSprite2D.play("idle")

func handleAnimations(delta=0, attack=null):
	var anim = $AnimatedSprite2D
	# prevent idle override while attacking/powering/shooting
	if attackInProgress or isPoweringUp or isShooting:
		return
	anim.play("idle")
