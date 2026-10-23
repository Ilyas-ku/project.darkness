extends StaticBody2D
## Tree: the trunk blocks movement and LOS; the canopy is visual only and fades
## when a visible character stands under it.

@export var trunk_radius_gu := 0.4
@export var canopy_radius_gu := 1.4

var canopy: Node2D


func _ready() -> void:
	add_to_group(&"navigation_source")
	collision_layer = GameParams.L_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = GameParams.gu(trunk_radius_gu)
	cs.shape = c
	add_child(cs)
	canopy = _Canopy.new()
	canopy.radius = GameParams.gu(canopy_radius_gu)
	canopy.z_index = 10
	canopy.add_to_group(&"canopy")
	add_child(canopy)


func _draw() -> void:
	var r := GameParams.gu(trunk_radius_gu)
	draw_circle(Vector2.ZERO, r, Color(0.36, 0.24, 0.14))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, Color(0.2, 0.12, 0.06), 1.5)


class _Canopy extends Node2D:
	var radius := 40.0

	func covers(p: Vector2) -> bool:
		return global_position.distance_to(p) <= radius

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(0.1, 0.28, 0.14, 0.85))
		draw_circle(Vector2(-radius * 0.3, -radius * 0.25), radius * 0.55, Color(0.13, 0.33, 0.17, 0.6))
