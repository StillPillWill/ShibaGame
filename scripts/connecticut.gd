#
# Script: CurveManager.gd
# Godot Version: 4.5
# Description: An optimized, all-in-one manager that draws a controllable Bézier curve,
#              spawns follower objects, and controls their movement and rotation
#              along the curve. The follower scenes themselves require no code.
#
@tool
extends Node2D

# --- Inner Class to Store Follower State ---
class Follower:
	var node: Node2D      # The actual instanced follower node
	var progress: float = 0.0 # Its progress along the curve (0.0 to 1.0)
	var speed: float = 100.0  # Its individual speed in pixels/sec

# --- ENUM DEFINITIONS ---
enum HandleMode {
	PERPENDICULAR, # The original S-curve
	ROTATION,      # Handle follows the node's rotation
	VELOCITY       # Handle follows the node's movement (momentum)
}

# -- EXPORTED VARIABLES --
@export_group("Follower Settings")
@export var follower_scene: PackedScene # The scene to instance (e.g., raycon.tscn)
@export var follower_default_speed: float = 250.0
@export var follower_scale: float = 40.0
@export var follower_rotation_offset: float = 0.0 # NEW: Offset in degrees for the follower's rotation

@export_group("Curve Target Nodes")
@export var node_a_path: NodePath
@export var node_b_path: NodePath

@export_group("Handle A (Start Point)")
@export var handle_mode_a: HandleMode = HandleMode.PERPENDICULAR
@export var handle_length_a: float = 100.0
@export var handle_rotation_offset_a: float = 0.0 # NEW: Offset in degrees for Handle A

@export_group("Handle B (End Point)")
@export var handle_mode_b: HandleMode = HandleMode.PERPENDICULAR
@export var handle_length_b: float = 100.0
@export var handle_rotation_offset_b: float = 0.0 # NEW: Offset in degrees for Handle B

@export_group("Curve Appearance")
@export var line_width: float = 5.0
@export var color: Color = Color.WHITE

# --- Private Variables ---
var _point_a: Vector2
var _point_b: Vector2
var _last_pos_a: Vector2
var _last_pos_b: Vector2
var _velocity_a: Vector2
var _velocity_b: Vector2
var _curve: Curve2D
var _followers: Array[Follower] = []

# --- Spawning Logic ---
func _unhandled_input(event: InputEvent) -> void:
	if not Engine.is_editor_hint() and event.is_action_pressed("ui_accept"):
		spawn_follower()

func spawn_follower() -> void:
	if not follower_scene:
		push_warning("Cannot spawn follower: Follower Scene is not set.")
		return

	var new_node = follower_scene.instantiate()
	new_node.scale = Vector2.ONE * follower_scale

	var new_follower = Follower.new()
	new_follower.node = new_node
	new_follower.progress = 0.0
	new_follower.speed = follower_default_speed

	add_child(new_node)
	_followers.append(new_follower)

# --- Core Update Logic ---
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		
	if not node_a_path.is_empty() and not node_b_path.is_empty():
		_update_points(delta)
	
	# --- OPTIMIZED FOLLOWER UPDATE LOOP ---
	# Guard clause: If there's nothing to do, exit early.
	if _followers.is_empty() or not is_instance_valid(_curve):
		return
	
	# OPTIMIZATION: Calculate curve length and rotation offset once per frame, not per follower.
	var curve_length = _curve.get_baked_length()
	if curve_length <= 0:
		return
	var follower_rot_rad = deg_to_rad(follower_rotation_offset)

	# Iterate backwards to safely remove items while looping.
	for i in range(_followers.size() - 1, -1, -1):
		var follower = _followers[i]
		
		# 1. UPDATE PROGRESS
		var progress_this_frame = (follower.speed / curve_length) * delta
		follower.progress += progress_this_frame
		
		# 2. UPDATE NODE'S POSITION & ROTATION
		if follower.progress < 1.0:
			# OPTIMIZATION: Directly calculate position and direction from baked curve data.
			var distance_on_curve = curve_length * follower.progress
			var local_pos = _curve.sample_baked(distance_on_curve)
			
			# Sample a point slightly ahead to determine direction
			var next_pos = _curve.sample_baked(min(distance_on_curve + 1.0, curve_length))
			var direction = (next_pos - local_pos).normalized()
			
			follower.node.global_position = to_global(local_pos)
			follower.node.rotation = direction.angle() + follower_rot_rad
		else:
			# 3. HANDLE END OF PATH: Remove the follower
			follower.node.queue_free()
			_followers.remove_at(i)

func _update_points(delta: float) -> void:
	# (This function is unchanged)
	var node_a: Node2D = get_node_or_null(node_a_path); var node_b: Node2D = get_node_or_null(node_b_path)
	if not is_instance_valid(node_a) or not is_instance_valid(node_b):
		if _curve != null: _curve = null; queue_redraw(); return
	var new_point_a = to_local(node_a.global_position); var new_point_b = to_local(node_b.global_position)
	if delta > 0:
		_velocity_a = (new_point_a - _last_pos_a) / delta; _velocity_b = (new_point_b - _last_pos_b) / delta
	_last_pos_a = new_point_a; _last_pos_b = new_point_b
	if new_point_a != _point_a or new_point_b != _point_b:
		_point_a = new_point_a; _point_b = new_point_b; _update_curve(); queue_redraw()

func _update_curve() -> void:
	var node_a: Node2D = get_node_or_null(node_a_path); var node_b: Node2D = get_node_or_null(node_b_path)
	if not is_instance_valid(node_a) or not is_instance_valid(node_b) or _point_a.is_equal_approx(_point_b): _curve = null; return
	var handle_dir_a: Vector2; var handle_dir_b: Vector2
	
	# Pre-calculate rotation offsets in radians
	var rot_offset_a_rad = deg_to_rad(handle_rotation_offset_a)
	var rot_offset_b_rad = deg_to_rad(handle_rotation_offset_b)
	
	match handle_mode_a:
		HandleMode.PERPENDICULAR: handle_dir_a = (_point_b - _point_a).orthogonal().normalized()
		HandleMode.ROTATION: handle_dir_a = Vector2.RIGHT.rotated(node_a.global_rotation + rot_offset_a_rad) # Added offset
		HandleMode.VELOCITY:
			if _velocity_a.length_squared() > 0.01: handle_dir_a = _velocity_a.normalized()
			else: handle_dir_a = (_point_b - _point_a).orthogonal().normalized()
	match handle_mode_b:
		HandleMode.PERPENDICULAR: handle_dir_b = -(_point_b - _point_a).orthogonal().normalized()
		HandleMode.ROTATION: handle_dir_b = -Vector2.RIGHT.rotated(node_b.global_rotation + rot_offset_b_rad) # Added offset
		HandleMode.VELOCITY:
			if _velocity_b.length_squared() > 0.01: handle_dir_b = -_velocity_b.normalized()
			else: handle_dir_b = -(_point_b - _point_a).orthogonal().normalized()
	var control_point_1 = _point_a + handle_dir_a * handle_length_a; var control_point_2 = _point_b + handle_dir_b * handle_length_b
	_curve = Curve2D.new(); _curve.add_point(_point_a, Vector2.ZERO, control_point_1 - _point_a); _curve.add_point(_point_b, control_point_2 - _point_b, Vector2.ZERO)

func _draw() -> void:
	# (This function is unchanged)
	if is_instance_valid(_curve) and _curve.get_point_count() > 1:
		draw_polyline(_curve.get_baked_points(), color, line_width)

# --- HELPER FUNCTIONS FOR OTHER SCRIPTS (if needed) ---
# These are no longer used by the internal follower loop but are kept for external use.
func get_point_at_progress(progress: float) -> Vector2:
	if not is_instance_valid(_curve) or _curve.get_point_count() < 2: return Vector2.ZERO
	var progress_clamped = clamp(progress, 0.0, 1.0); var distance_on_curve = _curve.get_baked_length() * progress_clamped
	return _curve.sample_baked(distance_on_curve)

func get_direction_at_progress(progress: float) -> Vector2:
	if not is_instance_valid(_curve) or _curve.get_point_count() < 2: return Vector2.RIGHT
	var pos1 = get_point_at_progress(progress); var pos2 = get_point_at_progress(progress + 0.001)
	if pos1.is_equal_approx(pos2): pos1 = get_point_at_progress(progress - 0.001); return (pos2 - pos1).normalized()
	return (pos2 - pos1).normalized()
