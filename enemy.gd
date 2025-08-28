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
var animationState=["idle",0.5]
var animationTimer={"PunchHitbox":0.5, "KickHitbox":1}
var inRange={"KickHitbox":false, "PunchHitbox":false}
var attackAnimation={"KickHitbox":"hitRight", "PunchHitbox": "hitRight", null:"idle"}
var attackKnockback={"KickHitbox":Vector2(-400,500), "PunchHitbox":Vector2(-200,-400)}
var hitStun=0
var justFloor
var velocityBuffer=Vector2.ZERO
func _ready():
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	$Hitbox.area_exited.connect(_on_hitbox_area_exited)

	

func _physics_process(delta: float) -> void:
			
			
	if is_on_floor():
		player.comboCount=0
	applyGravity(delta)
	#print("g"+str(velocity.x))
	applyFriction(delta)
	#print("f"+str(velocity.x))
	handleSound()

	#print("s"+str(velocity.x))
	handleAnimations(delta)
	#velocity.x=40
	velocity+=velocityBuffer
	velocityBuffer=Vector2.ZERO
	
	move_and_slide()

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
	if abs(velocity.x) < 1 and friction > 0:  # Only zero out if friction is active
		velocity.x = 0
func applyGravity(delta):
	if not is_on_floor():
		velocity.y+=gravity*delta

		
func handleAnimations(delta=0,attack=null):
	if animationState[1]<=0:
		
		$AnimatedSprite2D.play("idle")
		if is_on_floor():
			$AnimatedSprite2D.pause()
		previousAttack=null
	
	if sign(position.x-player.position.x)==-1:
		$AnimatedSprite2D.flip_h=true
	if sign(position.x-player.position.x)==1:
		$AnimatedSprite2D.flip_h=false	
	animationState[1]-=delta
	
	$AnimatedSprite2D.play(attackAnimation[previousAttack])
	if attack==null:
		return

	
	if attack=="PunchHitbox":
		$AnimatedSprite2D.play("hitRight")
	if attack=="KickHitbox":
		$AnimatedSprite2D.play("hitRight")
	

func _on_hitbox_area_entered(body: Node2D) -> void:
	if "KickHitbox" in str(body):
		inRange["KickHitbox"]=true # Replace with function body.
	if "PunchHitbox" in str(body):
		inRange["PunchHitbox"]=true
	print("entered"+str(body))

func _on_hitbox_area_exited(body: Node2D) -> void:
	if "KickHitbox" in str(body):
		inRange["KickHitbox"]=false # Replace with function body.
	if "PunchHitbox" in str(body):
		inRange["PunchHitbox"]=false
	print("exited"+str(body))


func attacked(attack):
	if inRange[attack]:
		hit(attack)

func hit(attack):
	player.comboCount+=1
	if player.comboCount==4:
		AudioManager.play_sfx(preload("res://sfx/shiba.mp3"))
	animationState = [attack, animationTimer[attack]]
	velocityBuffer.x += attackKnockback[attack].x * -1*sign(position.x - player.position.x)
	velocityBuffer.y += attackKnockback[attack].y   # fixed
	if attack == "PunchHitbox":
		velocityBuffer.y += player.velocity.y
		print("super")
	AudioManager.play_sfx(preload("res://sfx/hit2.wav"))
	print("hit")

	if attack=="KickHitbox":
		velocityBuffer.x += player.velocity.x * sign(position.x - player.position.x)

	previousAttack = attack
	handleAnimations()

func handleSound():
	if position.y < 0:
		highFlag = true
	print(position.y)
	if is_on_floor():
		if not justFloor:
			# Player just landed
			justFloor = true
			if highFlag:
				AudioManager.play_sfx(preload("res://sfx/thud.wav"))
				highFlag = false
			else:
				AudioManager.play_sfx(preload("res://sfx/thud2.wav"))
	else:
		justFloor = false
