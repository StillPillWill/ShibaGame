extends Camera2D

@export var player_path: NodePath
@export var enemy_path: NodePath
@export var extra_size := 32.0        # padding in world units (pixels)
@export var min_zoom := 0.25
@export var max_zoom := 4.0
@export var floor_world_y := 0.0      # world Y of the floor you want fixed
@export var floor_screen_from_bottom := 64.0  # pixels above bottom where floor should sit
@export var keep_floor_fixed := true

@onready var player = get_node_or_null(player_path)
@onready var enemy = get_node_or_null(enemy_path)
const EPS = 0.0001

func _process(delta):
	if not player or not enemy:
		return

	var vp = get_viewport_rect().size
	var dx = abs(player.position.x - enemy.position.x)
	var dy = abs(player.position.y - enemy.position.y)

	# world-units-per-pixel required (larger = more zoomed out)
	var desired = max((dx + extra_size) / vp.x, (dy + extra_size) / vp.y, EPS)
	var z = clamp(desired, min_zoom, max_zoom)
	zoom = Vector2(z, z)

	var midpoint = (player.position + enemy.position) * 0.5
	var half_h = (vp.y * 0.5) * zoom.y

	# compute center_y. If locking floor, convert desired screen Y -> world center using:
	# camera_center = floor_world - (screen_y - vp/2) * zoom
	var center_y = midpoint.y
	if keep_floor_fixed and player.has_method("is_on_floor") and player.is_on_floor():
		var desired_screen_y = vp.y - floor_screen_from_bottom
		center_y = floor_world_y - (desired_screen_y - vp.y * 0.5) * zoom.y

	# keep both player and enemy vertically visible
	var min_y = min(player.position.y, enemy.position.y)
	var max_y = max(player.position.y, enemy.position.y)
	var min_center = max_y - half_h
	var max_center = min_y + half_h
	center_y = clamp(center_y, min_center, max_center)

	position = Vector2(midpoint.x, center_y)
