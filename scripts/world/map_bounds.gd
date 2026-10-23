extends StaticBody2D
## Impassable map border and ground. Placed at the origin; the playable map is
## Rect2(0, 0, map_size). Also the source of the navigation outline.

const THICK_GU := 2.0


func _ready() -> void:
	add_to_group(&"navigation_source")
	collision_layer = GameParams.L_WORLD
	collision_mask = 0
	z_index = -10
	var m := GameParams.current().map_size_px()
	var t := GameParams.gu(THICK_GU)
	_add_rect(Rect2(-t, -t, m.x + 2 * t, t))
	_add_rect(Rect2(-t, m.y, m.x + 2 * t, t))
	_add_rect(Rect2(-t, 0, t, m.y))
	_add_rect(Rect2(m.x, 0, t, m.y))


func _add_rect(r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	cs.shape = s
	cs.position = r.get_center()
	add_child(cs)


func _draw() -> void:
	var m := GameParams.current().map_size_px()
	draw_rect(Rect2(Vector2.ZERO, m), Color(0.15, 0.24, 0.15))
	# central clearing
	draw_circle(Vector2(15, 13) * GameParams.PX_PER_GU, GameParams.gu(3.2), Color(0.2, 0.3, 0.18))
	# subtle grid every 2 gu for orientation
	var g := GameParams.gu(2.0)
	var x := 0.0
	while x <= m.x:
		draw_line(Vector2(x, 0), Vector2(x, m.y), Color(1, 1, 1, 0.025), 1.0)
		x += g
	var y := 0.0
	while y <= m.y:
		draw_line(Vector2(0, y), Vector2(m.x, y), Color(1, 1, 1, 0.025), 1.0)
		y += g
	draw_rect(Rect2(Vector2.ZERO, m), Color(0.05, 0.07, 0.05), false, 6.0)
