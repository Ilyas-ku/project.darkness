extends StaticBody2D
## Solid rectangular obstacle (shed). Blocks movement and LOS. Origin = centre.
## Drawn as a corrugated roof with a ground shadow.

@export var size_gu := Vector2(4, 3)


func _ready() -> void:
	add_to_group(&"navigation_source")
	add_to_group(&"obstacle_box")
	collision_layer = GameParams.L_WORLD
	collision_mask = 0
	z_index = 10
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size_gu * GameParams.PX_PER_GU
	cs.shape = r
	add_child(cs)
	var s := size_gu * GameParams.PX_PER_GU
	var sh := Art.sprite(self, "sprites/shed_roof.png", 0, s)
	sh.z_as_relative = false
	sh.z_index = -7
	sh.position = Vector2(GameParams.gu(0.3), GameParams.gu(0.4))
	sh.modulate = Color(0, 0.02, 0.06, 0.5)
	Art.sprite(self, "sprites/shed_roof.png", 0, s)


func get_bounds() -> Rect2:
	var s := size_gu * GameParams.PX_PER_GU
	return Rect2(global_position - s * 0.5, s)
