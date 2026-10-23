extends Node2D
## Broken bottle remains: a dynamic decal, drawn only while in LOS.


func _ready() -> void:
	add_to_group(&"dynamic_object")
	z_index = 2


func get_perception_points() -> PackedVector2Array:
	return PackedVector2Array([global_position])


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 7 + global_position.y * 13)
	for i in 7:
		var p := Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7))
		var a := rng.randf() * TAU
		draw_colored_polygon(PackedVector2Array([p, p + Vector2.from_angle(a) * 3, p + Vector2.from_angle(a + 1.2) * 2]), Color(0.55, 0.8, 0.6, 0.8))
