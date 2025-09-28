extends Node2D

var files
var counter=0
func _ready() -> void:
	files=get_files("res://images/bs/")

func _process(delta: float) -> void:
	pass
	if Input.is_action_just_pressed("space"):
		next()


func get_files(path: String) -> Array:
	var files: Array = []
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Failed to open directory: " + path)
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	return files

func next():
	counter+=1
