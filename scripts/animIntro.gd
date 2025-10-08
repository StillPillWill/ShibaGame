extends CharacterBody2D

var enemy
var triggered = false
var settings = false
var controls = false
var waiting_for_key = false
var current_action_to_bind = ""
var prev=0
@onready var new_scene: PackedScene = preload("res://node_2d.tscn")

func _ready() -> void:
	$AnimationPlayer.play("RESET")
	enemy = get_parent().get_node("AnimatedSprite2D2")
	enemy.play("default")
	# Initialize all button labels with current key bindings
	_initialize_button_labels()

func playPunch():
	$AnimationPlayer.play("LeftPunch")

func _process(delta: float) -> void:
	var bus = AudioServer.get_bus_index("Master")
	var db = linear_to_db(get_parent().get_node("Settings/HSlider").value / 100.0)
	if db!= prev:
		AudioManager.play_sfx(preload("res://sfx/thud2.wav"))
	prev=db
	AudioServer.set_bus_volume_db(bus, db)
	
	if Input.is_action_just_pressed("Attack"):
		if triggered:
			return
		if settings or controls:
			return
		triggered = true
		if get_parent().get_node("Controls/CheckButton").button_pressed:

			var ev1 := InputEventMouseButton.new(); ev1.button_index = MOUSE_BUTTON_RIGHT; InputMap.action_add_event("Stretch", ev1)
			var ev2 := InputEventMouseButton.new(); ev2.button_index = MOUSE_BUTTON_LEFT;  InputMap.action_add_event("Attack", ev2)
			AudioManager.mouseMode=true
		else:
			AudioManager.mouseMode=false
		$AnimationPlayer.play("LeftPunch")
		get_parent().get_node("AnimationPlayer2").play("full")
		await get_tree().create_timer(8).timeout
		get_tree().change_scene_to_packed(new_scene)

	if Input.is_action_just_pressed("ui_text_backspace"):
		if controls:
			controls = false
			get_parent().get_node("Buttons/AnimationPlayer").play_backwards("controls")
		elif settings:
			settings = false
			get_parent().get_node("Buttons/AnimationPlayer").play_backwards("settings")

func _on_button_pressed2() -> void:
	settings = true
	var ap = get_parent().get_node("Buttons/AnimationPlayer")
	if ap: ap.play("settings")
	print("f")

func _on_button_pressed() -> void:
	controls = true
	var ap = get_parent().get_node("Buttons/AnimationPlayer")
	if ap: ap.play("controls")

func explode():
	AudioManager.play_sfx(preload("res://sfx/explosion.wav"))
	get_parent().get_node("AnimatedSprite2D2").play("new_animation")

func default():
	get_parent().get_node("AnimatedSprite2D").play("default")

func mus():
	AudioManager.play_sfx(preload("res://sfx/clang.mp3"))
	await get_tree().create_timer(1).timeout
	AudioManager.play_music(preload("res://music/music2.mp3"), true, 0.5)

func defaul2t():
	$AnimationPlayer.play_backwards("LeftPunch")


# ---------- Rebinding system ----------
func _on_up_but_pressed() -> void:
	start_rebind("Up")

func _on_down_but_pressed() -> void:
	start_rebind("Down")

func _on_left_but_pressed() -> void:
	start_rebind("Left")

func _on_right_but_pressed() -> void:
	start_rebind("Right")

func _on_stretch_pressed() -> void:
	start_rebind("Stretch")

func _on_jump_but_pressed() -> void:
	start_rebind("Jump")

func _on_attack_but_pressed() -> void:
	start_rebind("Attack")


func start_rebind(action_name: String) -> void:
	waiting_for_key = true
	current_action_to_bind = action_name
	# Clear the button label while waiting
	_update_button_label(action_name, "")
	_show_message("Waiting for key for " + action_name + " ...")


func _input(event):
	# Global cancel (Backspace / Escape)
	# handle even if not waiting_for_key so user can exit menus
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_text_backspace"):
		# prefer closing controls first
		if controls:
			controls = false
			var apc = get_parent().get_node_or_null("Buttons/AnimationPlayer")
			if apc: apc.play_backwards("controls")
			get_viewport().set_input_as_handled()
			return
		elif settings:
			settings = false
			var aps = get_parent().get_node_or_null("Buttons/AnimationPlayer")
			if aps: aps.play_backwards("settings")
			get_viewport().set_input_as_handled()
			return

	# If we're not waiting for a rebind, ignore rebind input handling
	if not waiting_for_key:
		return

	# Rebinding logic
	if event is InputEventKey and event.pressed and not event.echo:
		# Consume the event to prevent it from triggering other actions
		get_viewport().set_input_as_handled()
		
		waiting_for_key = false
		var action = current_action_to_bind

		# Add the new key event FIRST
		var new_ev = InputEventKey.new()
		new_ev.physical_keycode = event.physical_keycode
		InputMap.action_add_event(action, new_ev)

		# THEN remove all old events except the one we just added
		var events = InputMap.action_get_events(action)
		for old_event in events:
			if old_event != new_ev:
				InputMap.action_erase_event(action, old_event)

		var key_name: String = event.as_text()
		# Remove " (Physical)" suffix
		key_name = key_name.replace(" (Physical)", "")
		_show_message("Bound " + action + " to " + key_name)

		# UPDATE BUTTON TEXT
		_update_button_label(action, key_name)

		_clear_message_later(2.0)


func _show_message(text: String) -> void:
	var buttons_root = _find_buttons_root()
	if buttons_root:
		var msg = buttons_root.get_node_or_null("MessageLabel")
		if msg and msg.has_method("set_text"):
			msg.text = text
			return
	print(text)


func _clear_message_later(seconds: float) -> void:
	call_deferred("_do_clear_message_later", seconds)

func _do_clear_message_later(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	var buttons_root = _find_buttons_root()
	if buttons_root:
		var msg = buttons_root.get_node_or_null("MessageLabel")
		if msg and msg.has_method("set_text"):
			msg.text = ""
			return


func _initialize_button_labels() -> void:
	# Wait a frame to ensure the scene is fully loaded
	await get_tree().process_frame
	var actions = ["Up", "Down", "Left", "Right", "Stretch", "Jump", "Attack"]
	for action in actions:
		var key_name = _get_current_key_name(action)
		print("Initializing ", action, " with key: ", key_name)
		_update_button_label(action, key_name)


func _get_current_key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "Not Set"
	
	var events = InputMap.action_get_events(action)
	if events.size() == 0:
		return "Not Set"
	
	# Get the first key event
	for event in events:
		if event is InputEventKey:
			# Get just the key name without (Physical) suffix
			var key_text = event.as_text()
			# Remove " (Physical)" if present
			key_text = key_text.replace(" (Physical)", "")
			return key_text
	
	# If no key event found, check for other input types
	if events.size() > 0:
		var key_text = events[0].as_text()
		key_text = key_text.replace(" (Physical)", "")
		return key_text
	
	return "Not Set"


func _update_button_label(action: String, key_name: String) -> void:
	var root = get_parent()
	if not root:
		print("No parent found. Bound", action, "->", key_name)
		return

	# Map action names to button node paths from root
	var button_paths = {
		"Up": "Controls/ScrollContainer/HBoxContainer/VBoxContainer2/UpBut",
		"Down": "Controls/ScrollContainer/HBoxContainer/VBoxContainer2/DownBut",
		"Left": "Controls/ScrollContainer/HBoxContainer/VBoxContainer2/LeftBut",
		"Right": "Controls/ScrollContainer/HBoxContainer/VBoxContainer2/RightBut",
		"Stretch": "Controls/ScrollContainer/HBoxContainer/VBoxContainer2/Stretch",
		"Jump": "Controls/ScrollContainer/HBoxContainer/VBoxContainer2/JumpBut",
		"Attack": "Controls/ScrollContainer/HBoxContainer/VBoxContainer2/AttackBut"
	}
	
	if action in button_paths:
		var btn = root.get_node_or_null(button_paths[action])
		if btn:
			if btn.has_method("set_text"):
				btn.text = key_name
				print("Updated ", action, " button to: ", key_name)
				return
			elif "text" in btn:
				btn.text = key_name
				print("Updated ", action, " button to: ", key_name)
				return
		else:
			print("Could not find node at path: ", button_paths[action])
	
	# fallback
	print("Could not find button for", action, "->", key_name)


func _find_buttons_root():
	if get_parent() and get_parent().has_node("Buttons"):
		return get_parent().get_node("Buttons")
	if has_node("Buttons"):
		return get_node("Buttons")
	return null
