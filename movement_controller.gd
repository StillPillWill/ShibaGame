## Spawns instances along a dynamic Bézier path that automatically connects two target nodes.
## Followers travel at a CONSTANT LINEAR SPEED, without the natural easing of a Bézier curve.
extends Node2D

@export_group("Target Nodes")
@export var start_node_path: NodePath:
	set(value): start_node_path = value; _update_node_references()
@export var start_offset: Vector2 = Vector2.ZERO
@export var end_node_path: NodePath:
	set(value): end_node_path = value; _update_node_references()
@export var end_offset: Vector2 = Vector2.ZERO

@export_group("Curve Shape")
@export_range(0.0, 2.0) var momentum_scale: float = 0.5:
	set(value): momentum_scale = value; queue_redraw()
@export var start_handle_rotation_offset: float = 0.0:
	set(value): start_handle_rotation_offset = value; queue_redraw()
@export var end_handle_rotation_offset: float = 0.0:
	set(value): end_handle_rotation_offset = value; queue_redraw()

@export_group("Spawning")
@export var follower_scene: PackedScene
@export var spawn_interval: float = 1.0
@export var autostart_spawning: bool = true
@export var loop_spawning: bool = true

@export_group("Path Animation")
@export var duration: float = 4.0
@export var rotate_follower: bool = true
@export_range(-360, 360) var rotation_offset_degrees: float = 0.0

@export_group("Path Drawing and Accuracy")
@export var draw_path: bool = true:
	set(value): draw_path = value; queue_redraw()
@export var path_color: Color = Color.WHITE:
	set(value): path_color = value; queue_redraw()
@export var path_width: float = 2.0:
	set(value): path_width = value; queue_redraw()
## Controls draw quality AND the accuracy of the constant speed calculation. Higher is more accurate.
@export_range(20, 500) var path_segments: int = 100:
	set(value): path_segments = value; queue_redraw()

@export_group("Real-Time Controls")
@export var move_endpoint_with_keys: bool = false
@export var key_move_speed: float = 300.0
@export var rotate_handles_with_keys: bool = false
@export var key_rotate_speed: float = 180.0 # Degrees per second

# --- Internal Variables ---
var _spawn_timer: Timer
var _active_followers: Array[Dictionary] = []
var _start_node: Node2D
var _end_node: Node2D
# --- For Arc-Length Parameterization (Constant Speed) ---
var _baked_distances: Array[float] = []
var _total_path_length: float = 0.0

func _ready():
	_update_node_references()
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.one_shot = not loop_spawning
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	if autostart_spawning:
		start_spawning()

func _process(delta: float):
	if not is_instance_valid(_start_node) or not is_instance_valid(_end_node):
		return

	# --- Automatic Path Calculation ---
	var start_point = _start_node.global_position + start_offset
	var end_point = _end_node.global_position + end_offset
	var distance = start_point.distance_to(end_point)
	var momentum_strength = distance * momentum_scale
	var start_angle_rad = deg_to_rad(_start_node.rotation_degrees + start_handle_rotation_offset)
	var end_angle_rad = deg_to_rad(_end_node.rotation_degrees + end_handle_rotation_offset)
	
	var start_handle_vec = Vector2.RIGHT.rotated(start_angle_rad) * momentum_strength
	var end_handle_vec = Vector2.RIGHT.rotated(end_angle_rad) * momentum_strength
	var control_point1 = start_point + start_handle_vec
	var control_point2 = end_point - end_handle_vec
	
	# --- Bake Path for Constant Speed and Drawing ---
	_bake_path_and_arc_lengths(start_point, control_point1, control_point2, end_point)
	queue_redraw()
	
	_handle_real_time_input(delta)
	
	# --- Follower Processing ---
	if _total_path_length < 0.001: return # Path has no length, do nothing.

	for i in range(_active_followers.size() - 1, -1, -1):
		var follower_data = _active_followers[i]
		follower_data.time += delta

		if follower_data.time >= duration:
			follower_data.node.queue_free()
			_active_followers.remove_at(i)
			continue

		# --- Constant Speed Calculation ---
		# Determine how far along the path's length the follower should be
		var distance_along_path = _total_path_length * (follower_data.time / duration)
		# Get the Bézier 't' value that corresponds to that distance
		var corrected_t = _get_t_for_distance(distance_along_path)
		
		# Position and rotate the follower using the corrected 't'
		var follower_node = follower_data.node
		follower_node.global_position = _cubic_bezier(start_point, control_point1, control_point2, end_point, corrected_t)

		if rotate_follower:
			var direction = _cubic_bezier_derivative(start_point, control_point1, control_point2, end_point, corrected_t)
			if direction.length_squared() > 0.0001:
				follower_node.rotation = direction.angle() + deg_to_rad(rotation_offset_degrees)

## Re-calculates the points and distances of the curve for arc-length parameterization.
func _bake_path_and_arc_lengths(p0: Vector2, c1: Vector2, c2: Vector2, p1: Vector2):
	_baked_distances.clear()
	_baked_distances.push_back(0.0) # The first point is at distance 0
	
	var last_point = p0
	_total_path_length = 0.0
	
	for i in range(1, path_segments + 1):
		var t = float(i) / path_segments
		var current_point = _cubic_bezier(p0, c1, c2, p1, t)
		var dist = last_point.distance_to(current_point)
		_total_path_length += dist
		_baked_distances.push_back(_total_path_length)
		last_point = current_point

## Finds the Bézier parameter 't' that corresponds to a certain distance along the curve.
func _get_t_for_distance(distance: float) -> float:
	if distance <= 0.0: return 0.0
	if distance >= _total_path_length: return 1.0

	# Find the segment that contains the target distance
	for i in range(1, _baked_distances.size()):
		var dist_prev = _baked_distances[i-1]
		var dist_curr = _baked_distances[i]
		
		if distance < dist_curr:
			# How far are we into this specific segment?
			var segment_len = dist_curr - dist_prev
			var dist_into_segment = distance - dist_prev
			var segment_t = dist_into_segment / segment_len
			
			# Interpolate to find the actual Bézier 't'
			var t_prev = float(i-1) / path_segments
			var t_curr = float(i) / path_segments
			return lerp(t_prev, t_curr, segment_t)
			
	return 1.0 # Should not be reached, but is a safe fallback

func _draw():
	# The points are already calculated during the baking process, so we just redraw them.
	if not draw_path or not is_instance_valid(_start_node) or not is_instance_valid(_end_node):
		return
	
	var start_point = _start_node.global_position + start_offset
	var end_point = _end_node.global_position + end_offset
	var distance = start_point.distance_to(end_point)
	var momentum_strength = distance * momentum_scale
	var start_angle_rad = deg_to_rad(_start_node.rotation_degrees + start_handle_rotation_offset)
	var end_angle_rad = deg_to_rad(_end_node.rotation_degrees + end_handle_rotation_offset)
	
	var start_handle_vec = Vector2.RIGHT.rotated(start_angle_rad) * momentum_strength
	var end_handle_vec = Vector2.RIGHT.rotated(end_angle_rad) * momentum_strength
	var control_point1 = start_point + start_handle_vec
	var control_point2 = end_point - end_handle_vec

	var last_point = start_point
	for i in range(1, path_segments + 1):
		var t = float(i) / path_segments
		var current_point = _cubic_bezier(start_point, control_point1, control_point2, end_point, t)
		draw_line(last_point, current_point, path_color, path_width)
		last_point = current_point

func _on_spawn_timer_timeout():
	if not follower_scene or not is_instance_valid(_start_node): return
	var new_follower = follower_scene.instantiate()
	if not new_follower is Node2D:
		push_error("'follower_scene' must be a Node2D-based scene.")
		new_follower.queue_free()
		return
	add_child(new_follower)
	new_follower.global_position = _start_node.global_position + start_offset
	_active_followers.append({"node": new_follower, "time": 0.0})

func _update_node_references():
	if is_inside_tree():
		_start_node = get_node_or_null(start_node_path)
		_end_node = get_node_or_null(end_node_path)
		if not start_node_path.is_empty() and not _start_node: push_warning("Start node not found.")
		if not end_node_path.is_empty() and not _end_node: push_warning("End node not found.")

func start_spawning(): _spawn_timer.start()
func stop_spawning(): _spawn_timer.stop()

func _handle_real_time_input(delta: float):
	if move_endpoint_with_keys:
		var move_vector := Vector2.ZERO
		if Input.is_action_pressed("ui_up"): move_vector.y -= 1
		if Input.is_action_pressed("ui_down"): move_vector.y += 1
		if move_vector != Vector2.ZERO: self.end_offset += move_vector.normalized() * key_move_speed * delta
	if rotate_handles_with_keys:
		var rotation_dir := 0.0
		if Input.is_action_pressed("ui_left"): rotation_dir -= 1.0
		if Input.is_action_pressed("ui_right"): rotation_dir += 1.0
		if rotation_dir != 0.0:
			if Input.is_key_pressed(KEY_SHIFT):
				self.start_handle_rotation_offset += rotation_dir * key_rotate_speed * delta
			else:
				self.end_handle_rotation_offset += rotation_dir * key_rotate_speed * delta

func _cubic_bezier(p0: Vector2, c1: Vector2, c2: Vector2, p1: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	var t2 = t * t
	var u2 = u * u
	var u3 = u2 * u
	var t3 = t2 * t
	return u3 * p0 + 3.0 * u2 * t * c1 + 3.0 * u * t2 * c2 + t3 * p1

func _cubic_bezier_derivative(p0: Vector2, c1: Vector2, c2: Vector2, p1: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	var u2 = u * u
	var t2 = t * t
	return 3.0 * u2 * (c1 - p0) + 6.0 * u * t * (c2 - c1) + 3.0 * t2 * (p1 - c2)
