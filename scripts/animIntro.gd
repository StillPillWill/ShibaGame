extends AnimatedSprite2D

var enemy
var triggered = false
var settings = false
var controls = false

@onready var new_scene: PackedScene = preload("res://node_2d.tscn")

func _ready() -> void:
	play("default")
	enemy = get_parent().get_node("AnimatedSprite2D2")
	enemy.play("default")

func playPunch():
	play("punch1")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("F"):
		if triggered:
			return
		if settings or controls:
			return
		triggered = true
		get_parent().get_node("AnimationPlayer2").play("full")

		await get_tree().create_timer(8).timeout

		# Correct: pass the PackedScene directly
		get_tree().change_scene_to_packed(new_scene)

func _on_button_pressed() -> void:
	settings = true
	get_parent().get_node("Buttons/AnimationPlayer").play("settings")
	print("f")
	await get_tree().create_timer(3).timeout
	get_parent().get_node("Buttons/AnimationPlayer").play_backwards("settings")
	settings=false
func _on_button_pressed2() -> void:
	controls = true
	get_parent().get_node("Buttons/AnimationPlayer").play("controls")
	await get_tree().create_timer(5).timeout
	get_parent().get_node("Buttons/AnimationPlayer").play_backwards("controls")
	controls=false
func explode():
	AudioManager.play_sfx(preload("res://sfx/explosion.wav"))

	get_parent().get_node("AnimatedSprite2D2").play("new_animation")

func default():
	get_parent().get_node("AnimatedSprite2D").play("default")
func mus():
	AudioManager.play_sfx(preload("res://sfx/clang.mp3"))
	await get_tree().create_timer(1)
	
	AudioManager.play_music(preload("res://music/music2.mp3"),true, 0.5)
