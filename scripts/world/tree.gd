extends StaticBody2D
## Tree: the trunk blocks movement and LOS; the canopy is visual only, casts a
## soft ground shadow and fades when a visible character stands under it.

const CANOPIES := ["sprites/canopy_pine_a.png", "sprites/canopy_pine_b.png", "sprites/canopy_birch.png"]

@export var trunk_radius_gu := 0.4
@export var canopy_radius_gu := 1.4

var canopy: Node2D


func _ready() -> void:
	add_to_group(&"navigation_source")
	add_to_group(&"tree")
	collision_layer = GameParams.L_WORLD
	collision_mask = 0
	z_index = 6
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = GameParams.gu(trunk_radius_gu)
	cs.shape = c
	add_child(cs)
	var v := Art.variant(global_position, 3)
	var r := GameParams.gu(canopy_radius_gu)
	# ground shadow of the crown (cold, offset away from the moon)
	var sh := Art.sprite(self, CANOPIES[v], -15, Vector2.ONE * r * 2.1)
	sh.z_as_relative = false
	sh.z_index = -7
	sh.position = Vector2(GameParams.gu(0.35), GameParams.gu(0.45))
	sh.modulate = Color(0, 0.02, 0.06, 0.45)
	var trunk := Art.sprite(self, "sprites/trunk_%d.png" % Art.variant(global_position + Vector2.ONE, 3), 0,
		Vector2.ONE * GameParams.gu(trunk_radius_gu) * 2.8)
	trunk.rotation = float(Art.variant(global_position, 360))
	canopy = _Canopy.new()
	canopy.radius = r
	canopy.z_as_relative = false
	canopy.z_index = 10
	canopy.add_to_group(&"canopy")
	add_child(canopy)
	var cs2 := Art.sprite(canopy, CANOPIES[v], 0, Vector2.ONE * r * 2.0)
	cs2.rotation = float(Art.variant(global_position, 628)) * 0.01


class _Canopy extends Node2D:
	var radius := 40.0

	func covers(p: Vector2) -> bool:
		return global_position.distance_to(p) <= radius
