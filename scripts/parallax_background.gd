# Attach this script to your ParallaxLayer with the background that has a floor
extends ParallaxLayer

@export var game_floor: Node2D  # Reference to your actual game floor
@export var background_floor_offset: float = 0.0  # Adjust if needed to align floors
var cam
func _ready():
	# Set motion scale so X scrolls but Y follows camera perfectly
	#motion_scale = Vector2(0.5, 1.0)  # Adjust X value for desired parallax effect
	cam=get_parent().get_parent()
func _process(delta):
	if game_floor:
		# Calculate where the background floor should be relative to game floor
		var target_y = game_floor.global_position.y + background_floor_offset
		postition=cam.position
		scale=1184*cam.
		# Adjust the parallax offset to align the floors
		# This compensates for the parallax effect to keep floors aligned
		motion_offset.y = target_y - game_floor.global_position.y
