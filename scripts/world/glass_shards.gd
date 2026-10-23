extends Node2D
## Broken bottle remains: a dynamic decal, drawn only while in LOS.


func _ready() -> void:
	add_to_group(&"dynamic_object")
	z_index = 2


func get_perception_points() -> PackedVector2Array:
	return PackedVector2Array([global_position])


func _draw() -> void:
	draw_texture_rect(Art.tex("sprites/glass_shards.png"), Rect2(-10, -10, 20, 20), false)
