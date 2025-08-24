extends CharacterBody2D

@export var friction=70	
@export var gravity = 2300
@export var jumpSpeed = 600
var fastFallSpeed=20
var speed=2000
var screen_width = 1152
var playerDirection=1
@onready var enemy=%Enemy
var cooldown=false
var player_direction = 1
var maxSpeed=500
func _ready():
	pass
func _physics_process(delta: float) -> void:
			
	
	handleInput(delta)
	applyGravity(delta)
	
	if position.x < 0:
		position.x = screen_width
	if position.x > screen_width:
		position.x = 0
	

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
		velocity.y+=gravity*delta
		
func handleInput(delta):
	var keys=[]
	playerDirection=0
	if Input.is_action_pressed("ui_up"):
		#print(is_on_floor())
		if is_on_floor():
			velocity.y-=jumpSpeed
		keys.append("up")
	if Input.is_action_pressed("ui_down"):
		velocity.y+=fastFallSpeed
		keys.append("down")
	if Input.is_action_pressed("ui_left"):
		velocity.x+=speed*-1*delta
		playerDirection-=1
		keys.append("left")
	if Input.is_action_pressed("ui_right"):
		velocity.x+=speed*delta
		playerDirection+=1
		keys.append("right")
	if playerDirection==0 or sign(playerDirection) != sign(velocity.x):
		applyFriction(delta)
	if Input.is_action_just_pressed("F"):
		attack("basic")
		keys.append("F")
	if abs(velocity.x)>maxSpeed:
		velocity.x=maxSpeed*sign(velocity.x)
	handleAnimations(keys)
		
func handleAnimations(keys):

	if playerDirection==1:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = false
	if playerDirection==-1:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = true 
	if playerDirection==0:
		$AnimatedSprite2D.play("idle")	
	if "F" in keys:
		$AnimatedSprite2D.play("punch")
		
func attack(type):
	if cooldown:
		return
	if type=="basic":
		pass
	
