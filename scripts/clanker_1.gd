extends CharacterBody2D


@export var friction=5
@export var gravity = 1500
@export var jumpSpeed = 600
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
var hp=2
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
# --- Added for smooth attack launch ---
var attackLaunch=false
var desiredVelocity=Vector2.ZERO
var attackAccel=3000.0
var maxAttackSpeed=900.0
# --------------------------------------

func _ready():
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	$Hitbox.area_exited.connect(_on_hitbox_area_exited)
	$AnimatedSprite2D.play("idle")

var hoverOn=false
var attackInProgress=false

func _physics_process(delta: float) -> void:
	if isDead:
		print(dead)
		return
	dac+=delta
	if Input.is_action_just_pressed("M"):
		attackPlayer()
		#player.comboCount=0
	if attackInProgress:
		continueAttack()
	#print("g"+str(velocity.x))
	applyFriction(delta)
	#applyGravity(delta)
	#print("f"+str(velocity.x))
	if not hoverOn:
		applyGravity(delta)
	if not attackFlag and not attackInProgress:
		if dac>3:
			attackPlayer()
	# If we're currently in the smooth attack launch, move velocity toward desiredVelocity
	if attackLaunch:
		velocity = velocity.move_toward(desiredVelocity, attackAccel * delta)
	else:
		velocity += velocityBuffer
		velocityBuffer = Vector2.ZERO
	if dac>=3:
		dac=0
	handleAnimations()
	move_and_slide()

	# When we land after an attack, clear leftover momentum and flags
	if is_on_floor() and attackFlag:
		velocity = Vector2.ZERO
		attackFlag = false
		attackLaunch = false
		velocityBuffer = Vector2.ZERO
		print("stuff")

	#handleAnimations(delta)
	#velocity.x=40

func stepTowards(num, target, step):
	var out=num
	if num<target:
		out+=step
	if num>target:
		out-=step
	return out

func applyFriction(delta):
	if is_on_floor():
		rotation=0		
	if is_on_floor() and friction > 0:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
	if abs(velocity.x) < 1 and friction > 0:  # Only zero out if friction is active
		velocity.x = 0

func applyGravity(delta):
	if not is_on_floor():
		velocity.y+=gravity*delta

func attackPlayer():
	velocityBuffer[1]-=1000	
	attackInProgress=true	

func continueAttack():
	
	if velocity.y > 0 and not hoverOn:
		hoverOn = true
		velocity.y = 0
		target = [(player.position - position).angle() + PI / 2,player.position]
		if target[0]>PI:
			target[0]-=PI*2
	if hoverOn:
		rotation = stepTowards(rotation, target[0], 0.1)  # shortest path automatically
		#print(rotation)
		#print(target[0])
		
	if abs(rotation - target[0]) < 0.1 and hoverOn:
		await get_tree().create_timer(0.1).timeout
		var direction = (target[1] - position).normalized()
		var distance = (target[1] - position).length()
		var speed = distance * 2  # adjust multiplier for acceleration strength

		# --- Instead of instantly adding a large velocity, set a desiredVelocity and enable smooth launch ---
		speed = min(speed, maxAttackSpeed)
		desiredVelocity = direction * speed
		attackLaunch = true
		# ------------------------------------------------------------------------------

		hoverOn = false
		attackInProgress = false
		attackFlag = true
	
func handleAnimations(delta=0,attack=null):
	var anim=$AnimatedSprite2D
	anim.play("idle")

func _on_hitbox_area_entered(body: Node2D) -> void:
	if "KickHitbox" in str(body):
		inRange["KickHitbox"]=true # Replace with function body.
	if "PunchHitbox" in str(body):
		inRange["PunchHitbox"]=true
	
	print("entered"+str(body))

func _on_hitbox_area_exited(body: Node2D) -> void:

	print("exited"+str(body))

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
	#AudioManager.play_sfx(preload("res://sfx/shiba.mp3"))
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
		player.slamHit()# Replace with function body.
func dead():
	isDead=true
	$AnimatedSprite2D.play("explode")
	$AnimatedSprite2D/CPUParticles2D.emitting = true
	await get_tree().create_timer(0.5).timeout
	hide()
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	print("dead")
