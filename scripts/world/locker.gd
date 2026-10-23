extends StaticBody2D
## Locker: impassable; a survivor inside is invisible to normal LOS.
## States EMPTY / OCCUPIED_CLOSED / PEEKING. Enter/exit 0.6 s, peek after 0.25 s
## of holding RMB. The killer may open it while searching: an occupant is revealed.

enum State { EMPTY, OCCUPIED_CLOSED, PEEKING }

@export var size_gu := Vector2(1.0, 0.6)

var state := State.EMPTY
var occupant: Node = null


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"locker")
	collision_layer = GameParams.L_FURNITURE
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size_gu * GameParams.PX_PER_GU
	cs.shape = r
	add_child(cs)


func get_facing() -> Vector2:
	return Vector2.DOWN.rotated(global_rotation)


func _front(extra_gu: float) -> Vector2:
	return global_position + get_facing() * GameParams.gu(size_gu.y * 0.5 + extra_gu)


func get_peek_origin() -> Vector2:
	return _front(0.08)


func get_exit_position() -> Vector2:
	return _front(GameParams.current().survivor_radius + 0.1)


## Where the killer stands to open the locker.
func get_search_position() -> Vector2:
	return _front(0.6)


func is_peeking() -> bool:
	return state == State.PEEKING


func set_peeking(v: bool) -> void:
	if occupant == null:
		return
	state = State.PEEKING if v else State.OCCUPIED_CLOSED
	queue_redraw()


## Killer opens the locker. Returns true if someone was inside (now revealed).
func killer_open(_killer: Node) -> bool:
	if occupant == null:
		return false
	var o := occupant
	occupant = null
	state = State.EMPTY
	o.exit_locker()
	queue_redraw()
	return true


# --- Interactable ------------------------------------------------------------

func get_interact_position() -> Vector2:
	return _front(0.0)


func can_interact(actor: Node) -> bool:
	if occupant == null:
		return actor.has_method(&"enter_locker")
	return occupant == actor


func get_interact_duration(_actor: Node) -> float:
	return GameParams.current().locker_enter_exit_time


func get_interact_hint(actor: Node) -> String:
	if occupant == actor:
		return "E — выйти из шкафа · ПКМ (удерж.) — выглянуть"
	return "E — спрятаться в шкаф"


func interact(actor: Node) -> void:
	if occupant == null:
		occupant = actor
		state = State.OCCUPIED_CLOSED
		actor.enter_locker(self)
	elif occupant == actor:
		occupant = null
		state = State.EMPTY
		actor.exit_locker()
	queue_redraw()


func _draw() -> void:
	var s := size_gu * GameParams.PX_PER_GU
	var rect := Rect2(-s * 0.5, s)
	draw_rect(rect, Color(0.3, 0.2, 0.12))
	draw_rect(rect, Color(0.12, 0.08, 0.04), false, 2.0)
	draw_line(Vector2(0, -s.y * 0.5), Vector2(0, s.y * 0.5), Color(0.12, 0.08, 0.04), 1.5)
	# slit on the front side
	draw_line(Vector2(-s.x * 0.3, s.y * 0.5 - 2), Vector2(s.x * 0.3, s.y * 0.5 - 2), Color(0.05, 0.05, 0.05), 2.0)
