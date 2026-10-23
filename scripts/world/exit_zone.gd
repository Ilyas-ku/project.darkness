extends Area2D
## Test exit trigger. Becomes active only after the killer has appeared.

signal survivor_reached

@export var size_gu := Vector2(1.4, 3.5)

var active := false


func _ready() -> void:
	add_to_group(&"exit_zone")
	collision_layer = 0
	collision_mask = GameParams.L_SURVIVOR
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size_gu * GameParams.PX_PER_GU
	cs.shape = r
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(b: Node) -> void:
	if active and b.is_in_group(&"survivor"):
		survivor_reached.emit()


func contains_survivor() -> bool:
	for b in get_overlapping_bodies():
		if b.is_in_group(&"survivor"):
			return true
	return false


func _physics_process(_delta: float) -> void:
	# Survivor may already stand in the zone when it becomes active.
	if active and contains_survivor():
		survivor_reached.emit()


func _draw() -> void:
	var s := size_gu * GameParams.PX_PER_GU
	var rect := Rect2(-s * 0.5, s)
	draw_rect(rect, Color(0.85, 0.75, 0.25, 0.25))
	draw_rect(rect, Color(0.95, 0.85, 0.3, 0.8), false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(2, s.y * 0.5), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.95, 0.6))
