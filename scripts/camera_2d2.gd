extends Camera2D

@export var player_padding: Vector2 = Vector2(50, 50)  # x = horizontal, y = vertical
@export var enemy_padding: Vector2  = Vector2(50, 50)
@export var floor_margin: float = 20.0
@export var floor: Node2D
@export var smooth_speed: float = 6.0
@export var zoom_smooth_factor: float = 0.5  # slower smoothing for zoom
@export var zoom_threshold: float = 0.01  # minimal change to update zoom
@export var debug_prints: bool = false

var player: Node2D
var enemy: Node2D
var player_height: float = 64.0
var enemy_height: float = 64.0

func _ready() -> void:
	#current = true
	#AudioManager.play_music(preload("res://music/music.mp3"),true, 0.5)

	player = get_parent().get_node_or_null("PlayerScratch")
	enemy  = get_parent().get_node_or_null("Clanker1")
	if player: player_height = get_shape_height(player)
	if enemy:  enemy_height  = get_shape_height(enemy)
	if debug_prints:
		print("ready:", "player:", player, "enemy:", enemy, "floor:", floor)

func _process(delta: float) -> void:

	if not player or not enemy or not floor:
		if debug_prints: print("missing nodes:", player, enemy, floor)
		return
		#hel
	var vp = get_viewport().get_visible_rect().size
	if vp.x <= 0 or vp.y <= 0:
		pass#ints: print("bad viewport:", vp); return

	# world feet/top
	var player_feet = player.global_position.y + player_height * 0.5
	var enemy_feet  = enemy.global_position.y  + enemy_height  * 0.5
	var lowest_feet = max(player_feet, enemy_feet)

	var player_top = player.global_position.y - player_height * 0.5
	var enemy_top  = enemy.global_position.y  - enemy_height  * 0.5
	var highest_point = min(player_top, enemy_top)

	# decide left/right actor for horizontal padding
	var player_is_left = player.global_position.x <= enemy.global_position.x
	var left_padding = player_padding.x
	var right_padding = enemy_padding.x
	if not player_is_left:
		left_padding = enemy_padding.x
		right_padding = player_padding.x

	# distances to fit
	var dist_x = abs(player.global_position.x - enemy.global_position.x) + left_padding + right_padding
	var dist_y = max((lowest_feet - highest_point) + (player_padding.y + enemy_padding.y), 1.0)

	# compute target zoom
	var zoom_allowed_x = vp.x / max(dist_x, 1.0)
	var zoom_allowed_y = vp.y / max(dist_y, 1.0)
	var target_zoom_val = clamp(min(zoom_allowed_x, zoom_allowed_y), 0.3, 2.5)
	var target_zoom = Vector2(target_zoom_val, target_zoom_val)

	# compute target camera Y to keep floor at floor_margin
	var floor_world_y = floor.global_position.y
	var screen_desired_y = vp.y - floor_margin
	var target_cam_y = floor_world_y - (screen_desired_y - vp.y * 0.5) / target_zoom.y

	# compute target camera X (midpoint)
	var target_cam_x = (player.global_position.x + enemy.global_position.x) * 0.5
	var target_cam = Vector2(target_cam_x, target_cam_y)

	# smooth position
	global_position = global_position.lerp(target_cam, smooth_speed * delta)

	# smooth zoom only if difference exceeds threshold
	if abs(zoom.x - target_zoom.x) > zoom_threshold:
		zoom = zoom.lerp(target_zoom, smooth_speed * delta * zoom_smooth_factor)

	if debug_prints:
		pass#print("vp:", vp, "target_zoom:", target_zoom_val, "cam:", global_position)

# helper: detect CollisionShape2D or Sprite height
func get_shape_height(node: Node2D) -> float:
	var cs = node.get_node_or_null("CollisionShape2D")
	if not cs:
		for c in node.get_children():
			if c is CollisionShape2D:
				cs = c; break
	if cs and cs.shape:
		if cs.shape is RectangleShape2D:
			return cs.shape.size.y
		if cs.shape is CapsuleShape2D:
			return cs.shape.height + cs.shape.radius * 2.0
		if cs.shape is CircleShape2D:
			return cs.shape.radius * 2.0
	var sprite = node.get_node_or_null("Sprite2D") or node.get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.texture:
		return sprite.texture.get_height()
	return 64.0
