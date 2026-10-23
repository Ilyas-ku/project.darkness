extends Node2D
## Primitive character drawing: body circle + facing wedge. The parent provides get_facing().

@export var body_color := Color(0.35, 0.6, 1.0)
@export var radius_gu := 0.3
## Set true while an attack is being telegraphed.
var telegraph := false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := GameParams.gu(radius_gu)
	var f: Vector2 = get_parent().get_facing() if get_parent().has_method(&"get_facing") else Vector2.RIGHT
	var col := body_color
	if telegraph:
		col = Color(1.0, 0.9, 0.2)
	draw_circle(Vector2.ZERO, r, col)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, col.darkened(0.5), 1.5)
	var tip := f * r * 1.7
	var side := f.orthogonal() * r * 0.55
	draw_colored_polygon(PackedVector2Array([f * r * 0.6 + side, tip, f * r * 0.6 - side]), col.lightened(0.3))
