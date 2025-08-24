extends StaticBody2D


func _ready() -> void:
	$CollisionPolygon2D.polygon.append(Vector2(-20,-20))
