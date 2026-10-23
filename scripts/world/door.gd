extends StaticBody2D
## Door: CLOSED blocks passage and LOS, OPEN does not. E toggles in 0.3 s.
## Opening emits a "door" sound event. The drawn state is the survivor's
## remembered state: it only updates while the door is actually visible.

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


func set_open(open: bool, actor: Node = null) -> bool:
	if open == is_open():
		return true
	if not open and _doorway_occupied():
		return false
	state = State.OPEN if open else State.CLOSED
	_shape.set_deferred(&"disabled", open)
	if open:
		var id := actor.get_instance_id() if actor != null else 0
		SoundEventBus.emit(&"door", global_position, GameParams.current().door_open_radius, id)
	return true


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
	return GameParams.current().door_toggle_time


func get_interact_hint(_actor: Node) -> String:
	return "E — закрыть дверь" if is_open() else "E — открыть дверь"


func interact(actor: Node) -> void:
	set_open(not is_open(), actor)


func _draw() -> void:
	var w := GameParams.gu(width_gu)
	var t := GameParams.gu(thickness_gu)
	var col := Color(0.5, 0.33, 0.18)
	if displayed_open:
		# swung inward around the left hinge
		draw_rect(Rect2(-w * 0.5 - t * 0.5, -w, t * 0.6, w), col)
		draw_rect(Rect2(-w * 0.5, -t * 0.5, w, t), Color(0.2, 0.15, 0.1, 0.6), false, 1.0)
	else:
		draw_rect(Rect2(-w * 0.5, -t * 0.5, w, t), col)
		draw_rect(Rect2(-w * 0.5, -t * 0.5, w, t), col.darkened(0.5), false, 1.5)
