# Script for PathFollow2D
extends PathFollow2D

@export var speed = 150.0 # Pixels per second
var a=1

func _process(delta):
	set_progress(get_progress() + speed * delta)
	# To loop, you can use fmod with the path's length
	# var path_length = get_parent().curve.get_baked_length()
	# set_progress(fmod(get_progress() + speed * delta, path_length))
