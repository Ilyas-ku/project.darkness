extends StaticBody2D
## Solid rectangular obstacle (shed). Blocks movement and LOS. Origin = centre.

@export var size_gu := Vector2(4, 3)
@export var color := Color(0.33, 0.27, 0.22)


func _ready() -> void:
	add_to_group(&"navigation_source")
	collision_layer = GameParams.L_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size_gu * GameParams.PX_PER_GU
	cs.shape = r
	add_child(cs)


func _draw() -> void:
	var s := size_gu * GameParams.PX_PER_GU
	var rect := Rect2(-s * 0.5, s)
	draw_rect(rect, color)
	draw_rect(rect, color.darkened(0.5), false, 2.0)
	draw_line(rect.position, rect.end, color.darkened(0.3), 1.5)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y), color.darkened(0.3), 1.5)
