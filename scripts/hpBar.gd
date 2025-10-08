extends CanvasLayer

@onready var clankerInitHp
@onready var clanker = get_parent().get_node("Clanker1")

func _ready() -> void:
	clankerInitHp = clanker.hp

func _physics_process(delta: float) -> void:
	if is_instance_valid(clanker):
		$ColorRect2/ColorRect.scale.x = relu(float(clanker.hp) / clankerInitHp)
	else:
		queue_free() # or hide(), depending on what you want
		
func relu(x):
	return max(x, 0)
