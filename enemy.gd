extends CharacterBody2D

@export var friction=70	
@export var gravity = 2300
@export var jumpSpeed = 600


var screen_width = 1152
var playerDirection=1
var cooldown=false

var inRange={"KickHitbox":false, "PunchHitbox":false}

func _ready():
	$Hitbox.body_entered.connect(_on_hitbox_body_entered)
	$Hitbox.body_exited.connect(_on_hitbox_body_exited)

	

func _physics_process(delta: float) -> void:
			
	
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

		
func handleAnimations():
	pass


func _on_hitbox_body_entered(body: Node2D) -> void:
	if "KickHitbox" in str(body):
		inRange["KickHitbox"]=true # Replace with function body.
	if "PunchHitbox" in str(body):
		inRange["PunchHitbox"]=true
	print("entered"+str(body))

func _on_hitbox_body_exited(body: Node2D) -> void:
	if "KickHitbox" in str(body):
		inRange["KickHitbox"]=false # Replace with function body.
	if "PunchHitbox" in str(body):
		inRange["PunchHitbox"]=false
	print("exited"+str(body))
