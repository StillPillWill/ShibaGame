extends CharacterBody2D

var friction=70	
var gravity = 1800
var jumpSpeed = 600
var fastFallSpeed=40
var speed=2000
var screen_width = get_viewport_rect().size.x
var playerDirection=1
var cooldown=false
var maxSpeed=500
var slowed=false
var interuptAnimation=false
var slowFactor=0.25
var hitboxOriginal={}
var previousDirection=-1
var comboCount=0
@onready var comboLabel=get_parent().get_node("CanvasLayer/Label")
var attacks={"punch":"PunchHitbox", "kick":"KickHitbox"}

var animationState=["idle",0.5]
var animationDict={
	"punch":["punch", 0.1],
	"kick":["kick", 0.2]
}

@onready var enemy=get_parent().get_node("Enemy")
@onready var hitboxes={"punch":$PunchHitbox, "kick":$KickHitbox, "hurtbox":$HurtBox}







func _ready():
	friction=50	
	gravity = 2000
	jumpSpeed = 900
	fastFallSpeed=50
	speed=5000
	screen_width = 1152
	playerDirection=1
	cooldown=0
	maxSpeed=1000
	slowed=false
	interuptAnimation=false
	slowFactor=0.5
	hitboxOriginal=[]
	previousDirection=-1


	var animationState=["idle",0.5]
	gravity=2300
	friction=70	
	#print(gravity)

	for value in hitboxes.values():
		var hitbox = value.position.x
		hitboxOriginal.append(hitbox)
	
func _physics_process(delta: float) -> void:
	
	if comboCount>0:
		comboLabel.text="COMBO X "+str(comboCount)
	else:
		comboLabel.text=""
	
	maxSpeed=min(500, position.distance_to(enemy.position))
	speed=min(2000,position.distance_to(enemy.position)*4)
	
	slowFactor=min(position.distance_to(enemy.position)/500,1)
	handleInput(delta)
	applyGravity(delta)
	handleTime(delta)
	"""
	if position.x < 0:
		position.x = screen_width
	if position.x > screen_width:
		position.x = 0
	"""

	move_and_slide()

func stepTowards(num, target, step):
	var out=num
	if num<target:
		num+=step
	if num>target:
		num-=step
	return out

func applyFriction(delta):
	if is_on_floor():
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
	if abs(velocity.x)<1:
		velocity.x=0
		
func applyGravity(delta):
	if not is_on_floor():
		velocity.y+=gravity*existsOrZero(delta)
		
func handleInput(delta):
	var keys = []
	playerDirection = 0

	if Input.is_action_pressed("ui_up"):
		if is_on_floor():
			velocity.y -= jumpSpeed
		keys.append("up")

	# speedUp handled with its own else so it doesn't get reset by other checks
	if Input.is_action_pressed("speedUp"):
		maxSpeed = 10000
		speed = 4000
		keys.append("speedUp")
	else:
		maxSpeed = 500
		speed = 2000

	if Input.is_action_pressed("ui_down"):
		velocity.y += fastFallSpeed
		keys.append("down")

	if Input.is_action_pressed("ui_left"):
		velocity.x += speed * -1 * delta
		playerDirection -= 1
		keys.append("left")

	if Input.is_action_pressed("ui_right"):
		velocity.x += speed * delta
		playerDirection += 1
		keys.append("right")

	# apply friction when no directional input or when changing direction
	if playerDirection == 0 or sign(playerDirection) != sign(velocity.x):
		applyFriction(delta)

	if Input.is_action_just_pressed("F"):
		keys.append("F")

	# clamp once
	if abs(velocity.x) > maxSpeed:
		velocity.x = maxSpeed * sign(velocity.x)

	if Input.is_action_just_pressed("R"):
		keys.append("R")

	if Input.is_action_just_pressed("space"):
		slowed = not slowed

	handleAnimations(keys, delta)
	handleHitboxFlip()

func handleAnimations(keys,delta):
	#print(animationState)
	if animationState[1]-delta>0 and not interuptAnimation:
		if $AnimatedSprite2D.animation==animationState[0]:
			animationState[1]-=delta
			return
		elif $AnimatedSprite2D.animation!=animationState[0]:
			$AnimatedSprite2D.animation=animationState[0]
		animationState[1]-=delta
		return
	if playerDirection==1:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = false
	if playerDirection==-1:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = true 
	if playerDirection==0:
		$AnimatedSprite2D.play("idle")	
	if "F" in keys:
		print("punch "+str(delta)+" "+str(animationState))
		print(animationDict["punch"])
		animationState=animationDict["punch"].duplicate()
		attack("punch",delta)
	if "R" in keys:
		print("kick "+str(delta)+" "+str(animationState))
		print(animationDict["kick"])
		animationState=animationDict["kick"].duplicate()
		attack("kick",delta)
			
func handleHitboxFlip():
	if playerDirection==1:
		var c=0
		for x in hitboxes.values():
			x.position.x=hitboxOriginal[c]
			c+=1
	if playerDirection==-1:
		var c=0
		for x in hitboxes.values():
			x.position.x=hitboxOriginal[c]*-1
			c+=1
	#print(playerDirection)	
func attack(type,delta):
	if cooldown>0:
		return
	enemy.attacked(attacks[type])


func handleTime(delta):

	if slowed:
		Engine.time_scale = slowFactor
		speed=3000
	else:
		Engine.time_scale = 1
		speed=2000
func existsOrZero(x):
	if x== null:
		return 0
	return x
