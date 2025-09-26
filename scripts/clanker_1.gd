extends CharacterBody2D


@export var friction=5
@export var gravity = 1500
@export var jumpSpeed = 1000
@onready var player=get_parent().get_node("PlayerScratch")
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
var maxAttackSpeed=3000.0
# --------------------------------------

# +++ ADDED +++ New state variables for the Shoot attack's powerup phase
var isPoweringUp = false
var powerupTimer = 0.0
const POWERUP_DURATION = 2.15 # The duration of the powerup animation
var isShooting = false
var laser_sfx = preload("res://sfx/enemyShoot.wav")
@export var per_shot_delay = 0.35
@export var between_shots_delay = 0.3
@export var max_shots_allowed = 100
@export var bullet_lifetime = 5.0

func _ready():
	# --- Standard Setup ---
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	$Hitbox.area_exited.connect(_on_hitbox_area_exited)
	$AnimatedSprite2D.play("idle")
	
	# --- Variable Initializations ---

	# State & Flags
	hoverOn = false
	attackInProgress = false
	cooldown = false
	highFlag = true
	attack = false
	attackFlag = false
	shotsFired = false
	isDead = false
	upDownInFlight = false
	attackLaunch = false
	isPoweringUp = false
	isShooting = false

	# Data & Trackers
	recentAttack = ""
	previousAttack = null
	dac = 0
	animationState = ["idle", 0.5]
	playerDir = [0, 0]
	target = [0, 0]
	hp = 50
	attackMode = ""
	hitStun = 0
	justFloor = null
	powerupTimer = 0.0

	# Dictionaries
	inRange = {"KickHitbox": false, "PunchHitbox": false}

	# Physics & Environment
	# Exported variables can be overridden here if needed
	friction = 5
	gravity = 1500
	jumpSpeed = 1000
	bullet_spawn_offset = Vector2(0, -30)
	
	# This value depends on the scene being ready
	screen_width = get_viewport_rect().size.x
	
	# Vector2 Initializations
	velocityBuffer = Vector2.ZERO
	desiredVelocity = Vector2.ZERO

	# Smooth Attack Config
	attackAccel = 3000.0
	maxAttackSpeed = 3000.0

	# Shooting Attack Config
	per_shot_delay = 0.2
	between_shots_delay = 0.06
	max_shots_allowed = 100
	bullet_lifetime = 5.0
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
			#print("attacking")

			
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
			#print("stuff")



# +++ ADDED +++ New function to handle the powerup state frame-by-frame

func stepTowards(num, target, step):
	var out=num
	if num<target:
		out+=step
	if num>target:
		out-=step
	return out

func applyFriction(delta):

	if is_on_floor() and friction > 0:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
	if abs(velocity.x) < 1 and friction > 0:
		velocity.x = 0
	if is_on_floor() and not attackInProgress: # --- CHANGED --- Don't reset body rotation if mid-attack
		
		
		rotation=0
func applyGravity(delta):
	if not is_on_floor():
		velocity.y+=gravity*delta

# --- Unchanged helper functions from here ... ---

func _on_hitbox_area_entered(area) -> void:
	if "KickHitbox" in str(area):
		inRange["KickHitbox"]=true
	if "PunchHitbox" in str(area):
		inRange["PunchHitbox"]=true
	#print("entered"+str(body))
	print("entered :", area.get_parent().get_parent().is_in_group("Player"),attackFlag)
	if area.get_parent().get_parent().is_in_group("Player") and attackFlag:
		get_parent().get_node("PlayerScratch").slamHit()
		
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

func hit(direction,attack="none"):
	#print("hit")
	playerDir=direction
	if attack != "none":
		animationState = [attack, animationTimer[attack]]
		var attackName=attackName(attack,direction)
		if attack == "PunchHitbox":
			velocityBuffer.y += player.velocity.y
			#print("super")
	AudioManager.play_sfx(preload("res://sfx/hit2.wav"))
	hp-=1
	#print("hit")
	if hp==0:
		dead()
		
func _on_hitbox_body_entered(body: Node2D) -> void:
	pass
	#print(body)

	
func dead():
	isDead=true
	$AnimatedSprite2D.play("explode")
	AudioManager.play_sfx(preload("res://sfx/explosion.wav"))
	$AnimatedSprite2D/CPUParticles2D.emitting = true
	await get_tree().create_timer(0.5).timeout
	hide()

	#print("dead")
	get_parent().get_node("AttackUI").show()
	get_parent().get_node("AttackUI/Label2").show()
	
func attackPlayer():
	dac = 0
	# single-frame upward impulse to start jump
	velocityBuffer.y -= jumpSpeed
	attackInProgress = true
	shotsFired = false
	var c = randi_range(0, 4)
	if c == 0 or player.position.distance_to(position)<200:
		attackMode = "Shoot"
	else:
		attackMode = "upDown"

# continueAttack handles the frame-by-frame state after the initial jump
func continueAttack():
	# constants (tweak these)
	var TIME_TO_REACH = 0.35        # desired time (s) to reach target (controls aggression)
	var HOMING_TURN_RATE = 6.0      # how fast it homes mid-flight (higher = sharper correction)
	var ALIGN_THRESHOLD = 0.08      # radians tolerance for "aligned" before launching

	var dt = get_physics_process_delta_time()

	# -----------------------
	# UPDOWN mode: apex -> hover -> rotate -> launch
	# -----------------------
	if attackMode == "upDown":
		# Detect apex: started falling (y > 0) and not already hovering
		if velocity.y > 0 and not hoverOn:
			hoverOn = true
			# freeze vertical movement while hovering
			velocity.y = 0
			velocity = Vector2.ZERO
			# compute aim angle (keep same formula you used)
			var target_angle = (player.position - position).angle() + PI * 0.5
			target_angle = angwrap(target_angle)
			# store as [angle, position]
			target = [target_angle, player.position]

		# While hovering, rotate towards stored target angle (or dynamic player angle if you prefer)
		if hoverOn:
			var targ_angle = (player.position - position).angle() + PI * 0.5
			if target is Array and target.size() > 0:
				targ_angle = float(target[0])

			# smooth rotate toward target
			rotation = lerp_angle(rotation, targ_angle, 8.0 * dt)

			# when nearly aligned, pause a beat and launch
			if abs(angwrap(rotation - targ_angle)) < ALIGN_THRESHOLD:
				# short delay to make the telegraph noticeable
				await get_tree().create_timer(0.06).timeout

				# resolve target position to use for flight (prefer stored pos if present)
				var target_pos = player.position
				if target is Array and target.size() > 1 and target[1] is Vector2:
					target_pos = target[1]
				elif target is Vector2:
					target_pos = target

				var dir_vec = target_pos - position
				if dir_vec == Vector2.ZERO:
					dir_vec = Vector2.UP

				var direction = dir_vec.normalized()
				var distance = dir_vec.length()

				# compute speed so the enemy reaches the target in TIME_TO_REACH seconds
				var speed = distance / TIME_TO_REACH
				# respect maxAttackSpeed if you have one (assumes maxAttackSpeed exists)
				if maxAttackSpeed > 0:
					speed = max(min(speed, maxAttackSpeed),1000)

				# immediate desired velocity for your movement system to consume
				desiredVelocity = direction * speed

				# give the enemy an initial instant push so it doesn't feel weak
				# (only if your movement system accepts directly setting velocity)
				if typeof(velocity) == TYPE_VECTOR2:
					velocity = desiredVelocity

				# set flags
				attackLaunch = true
				hoverOn = false
				attackInProgress = false
				attackFlag = true
				upDownInFlight = true

		# If already in-flight, optionally apply mild homing so it corrects undershoot
		if upDownInFlight:
			# home towards the player's current or stored position
			var current_target = player.position
			if target is Array and target.size() > 1 and target[1] is Vector2:
				current_target = target[1]
			var to_target = current_target - position
			if to_target != Vector2.ZERO:
				var desired_dir = to_target.normalized()
				# keep current speed magnitude, but nudge direction towards desired_dir
				var speed_mag = max(velocity.length(), 1.0) # avoid zero-length
				var desired_vel = desired_dir * speed_mag
				velocity = velocity.lerp(desired_vel, clamp(HOMING_TURN_RATE * dt, 0.0, 1.0))

		return

	# -----------------------
	# SHOOT mode: apex -> hover -> powerup (single block)
	# -----------------------
	if attackMode == "Shoot":
		# detect apex -> enter hovering/powerup once
		if velocity.y > 0 and not hoverOn:
			hoverOn = true
			# stop movement while powering up
			velocity.y = 0
			velocity = Vector2.ZERO
			isPoweringUp = true
			powerupTimer = POWERUP_DURATION
			$AnimatedSprite2D.play("powerup")
			shotsFired = true
		return

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
		shoot(21)

func shoot(times: int):
	# --- 1. Lock the Enemy's State ---
	# This prevents the enemy from moving or doing anything else while shooting.
	attackInProgress = false
	attackFlag = false
	hoverOn = true
	isShooting = true
	velocity = Vector2.ZERO

	# --- 2. Firing Loop ---
	# This loop will run for the number of 'times' you pass into the function.
	for i in range(times):
		# A safety check to stop the attack if the enemy is defeated mid-volley.
		if isDead:
			break

		# --- 3. Aim Each Shot ---
		# Get the direction from the enemy to the player's current position.
		var dir = (player.position - position).normalized()

		# Point the sprite at the player. The '+ PI / 2' corrects the sprite's orientation.
		$AnimatedSprite2D.rotation = dir.angle() + PI / 2
		
		# --- 4. Instantiate and Configure the Bullet (The Runtime Change) ---
		# Play the visual and sound effects just before the bullet appears.
		$AnimatedSprite2D.play("shoot")
		AudioManager.play_sfx(laser_sfx)
		await get_tree().create_timer(per_shot_delay).timeout

		# Create a new bullet instance from your scene.
		var bullet_instance = bullet.instantiate()
		
		# Set its initial properties (position, velocity, etc.).
		var rotated_offset = bullet_spawn_offset.rotated($AnimatedSprite2D.rotation)
		bullet_instance.position = $AnimatedSprite2D/sp.global_position
		bullet_instance.velocity = dir * 800
		bullet_instance.scale = Vector2(0.25, 0.25)

		# This is how we differentiate it from a player's bullet.
		bullet_instance.sender = "Enemy"

		# -- THIS IS THE CRITICAL RUNTIME CONFIGURATION --
		## The bullet now exists on Layer 4 ('enemy_bullets').
		#bullet_instance.collision_layer = 1 << 3
		## The bullet will now only look for things on Layer 1 ('player').
		#bullet_instance.collision_mask = 1 << 0
		# -------------------------------------------------

		# Add the fully configured bullet to the game world.
		get_parent().add_child(bullet_instance)

		# Wait briefly before the next shot.
		await get_tree().create_timer(between_shots_delay).timeout

	# --- 5. Reset the Enemy's State --- 
	# Once the loop is done, unlock the enemy so it can move again.
	isShooting = false
	hoverOn = false 
	attackInProgress = false
	attackFlag = true 
	$AnimatedSprite2D.rotation = 0
	$AnimatedSprite2D.play("idle")

func take_damage():
	print("hit enemy")
	#p-=1
	hit(Vector2(1,1))
	
func handleAnimations(delta=0, attack=null):
	var anim = $AnimatedSprite2D
	# prevent idle override while attacking/powering/shooting
	if attackInProgress or isPoweringUp or isShooting:
		return
	anim.play("idle")
