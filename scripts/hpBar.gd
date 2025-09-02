extends CanvasLayer


@onready var clankerInitHp
@onready var clanker=get_parent().get_node("Clanker1")
func _ready() -> void:
	#await get_tree().create_timer(1).timeout
	clankerInitHp=get_parent().get_node("Clanker1").hp
	
	
func _physics_process(delta: float) -> void:
	$ColorRect2/ColorRect.scale.x=relu(float(clanker.hp)/clankerInitHp)
	print(clankerInitHp)
	print(clanker.hp)
	print(clanker.hp/clankerInitHp)
func relu(x):
	if x<0:
		return 0
	return x
