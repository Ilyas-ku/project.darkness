extends StaticBody2D
## Door: CLOSED blocks passage and LOS, OPEN does not. E toggles in 0.3 s.
## Opening emits a "door" sound event. The drawn state is the survivor's
## remembered state: it only updates while the door is actually visible.

signal toggled(open: bool)

enum State { CLOSED, OPEN }

@export var width_gu := 1.2
@export var thickness_gu := 0.3

var state := State.CLOSED
## What the player last saw. Updated by PlayerPerceptionView.
var displayed_open := false

var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"door")
	collision_layer = GameParams.L_DOOR
	collision_mask = 0
	z_index = 1
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width_gu, thickness_gu) * GameParams.PX_PER_GU
	_shape.shape = r
	add_child(_shape)
	displayed_open = is_open()


func is_open() -> bool:
	return state == State.OPEN


## Low-level state change: collision follows the state immediately (the doorway is
## passable from the same frame the opening starts); open and close each make a sound.
func set_open(open: bool, actor: Node = null) -> bool:
	if open == is_open():
		return true
	if not open and _doorway_occupied():
		return false
	state = State.OPEN if open else State.CLOSED
	_last_toggle = GameClock.now()
	_shape.set_deferred(&"disabled", open)
	var id := actor.get_instance_id() if actor != null else 0
	var p := GameParams.current()
	if open:
		SoundEventBus.emit(&"door", global_position, p.door_open_radius, id)
	else:
		SoundEventBus.emit(&"door_close", global_position, p.door_close_radius, id)
	toggled.emit(open)
	return true


var _last_toggle := -INF


func _doorway_occupied() -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape.shape
	q.transform = global_transform
	q.collision_mask = GameParams.L_SURVIVOR | GameParams.L_KILLER
	return not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func set_displayed_open(v: bool) -> void:
	if v != displayed_open:
		displayed_open = v
		queue_redraw()


# --- Interactable ------------------------------------------------------------

func get_interact_position() -> Vector2:
	return global_position


func can_interact(_actor: Node) -> bool:
	return true


func get_interact_duration(_actor: Node) -> float:
	return 0.0


## Doors are a single press, not a timed channel: the actor keeps moving.
func is_instant() -> bool:
	return true


func get_interact_hint(_actor: Node) -> String:
	return "E — закрыть дверь" if is_open() else "E — открыть дверь"


func interact(actor: Node) -> void:
	if GameClock.now() - _last_toggle < GameParams.current().door_debounce:
		return
	set_open(not is_open(), actor)


var _swing := 0.0


func _process(delta: float) -> void:
	var target := 1.0 if displayed_open else 0.0
	if not is_equal_approx(_swing, target):
		_swing = move_toward(_swing, target, delta / GameParams.current().door_anim_time)
		queue_redraw()


func _draw() -> void:
	var w := GameParams.gu(width_gu)
	var t := GameParams.gu(thickness_gu)
	var tex := Art.tex("sprites/door.png")
	# threshold
	draw_rect(Rect2(-w * 0.5, -t * 0.5, w, t), Color(0.18, 0.13, 0.09))
	# leaf swung inward (-y) around the left hinge; the drawn state is the remembered one
	var hinge := Vector2(-w * 0.5, 0)
	draw_set_transform(hinge, -_swing * PI * 0.5, Vector2.ONE)
	draw_texture_rect(tex, Rect2(Vector2(0, -t * 0.5), Vector2(w, t)), false)
