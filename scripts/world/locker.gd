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
	z_index = 4
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
func killer_open(killer: Node) -> bool:
	SoundEventBus.emit(&"locker", global_position, 3.0, killer.get_instance_id())
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


## The door of the locker creaks when someone starts getting in or out.
func on_channel_started(actor: Node) -> void:
	SoundEventBus.emit(&"locker", global_position, 3.0, actor.get_instance_id())


func interact(actor: Node) -> void:
	if occupant == null:
		occupant = actor
		state = State.OCCUPIED_CLOSED
		actor.enter_locker(self)
	elif occupant == actor:
		occupant = null
		state = State.EMPTY
		actor.exit_locker()
	SoundEventBus.emit(&"locker_close", global_position, 2.5, actor.get_instance_id())
	queue_redraw()


func _draw() -> void:
	var s := size_gu * GameParams.PX_PER_GU
	draw_rect(Rect2(-s * 0.5 + Vector2(3, 4), s), Color(0, 0.02, 0.05, 0.45))
	draw_texture_rect(Art.tex("sprites/locker.png"), Rect2(-s * 0.5, s), false)
	if state == State.PEEKING:
		draw_line(Vector2(-s.x * 0.2, s.y * 0.5 - 2), Vector2(s.x * 0.2, s.y * 0.5 - 2), Color(0.9, 0.8, 0.6, 0.8), 2.0)
