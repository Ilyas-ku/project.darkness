class_name Throwable
extends Node2D
## Stone: picked up with E (0.4 s), thrown with LMB towards the cursor at 10 gu/s
## up to 7 gu. Hitting an obstacle or landing creates an "impact" sound event at
## the real contact point. MVP: a thrown stone cannot be picked up again.

enum State { GROUND, HELD, FLYING, LANDED }

const RADIUS_GU := 0.14

var state := State.GROUND
var _dir := Vector2.ZERO
var _travel_left := 0.0
var _thrower_id := 0


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"dynamic_object")
	z_index = 5


func get_perception_points() -> PackedVector2Array:
	if state == State.HELD:
		return PackedVector2Array()
	return PackedVector2Array([global_position])


# --- Interactable ------------------------------------------------------------

func get_interact_position() -> Vector2:
	return global_position


func can_interact(actor: Node) -> bool:
	return state == State.GROUND and actor.has_node(^"Inventory") and actor.get_node(^"Inventory").has_space()


func get_interact_duration(_actor: Node) -> float:
	return GameParams.current().stone_pickup_time


func get_interact_hint(_actor: Node) -> String:
	return "E — подобрать камень"


func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	state = State.HELD
	visible = false
	actor.get_node(^"Inventory").add(self)


# --- Throw -------------------------------------------------------------------

func throw_from(origin: Vector2, target: Vector2, thrower_id: int) -> void:
	var p := GameParams.current()
	global_position = origin
	var to := target - origin
	_dir = to.normalized() if to.length() > 0.5 else Vector2.RIGHT
	_travel_left = minf(to.length(), GameParams.gu(p.stone_max_range))
	_thrower_id = thrower_id
	state = State.FLYING
	visible = true


func _physics_process(delta: float) -> void:
	if state != State.FLYING:
		return
	var step := minf(GameParams.gu(GameParams.current().stone_speed) * delta, _travel_left)
	var from := global_position
	var to := from + _dir * step
	var q := PhysicsRayQueryParameters2D.create(from, to, GameParams.MOVE_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position - _dir * GameParams.gu(RADIUS_GU)
		_land(hit.position)
		return
	global_position = to
	_travel_left -= step
	if _travel_left <= 0.01:
		_land(global_position)


func _land(contact: Vector2) -> void:
	state = State.LANDED
	SoundEventBus.emit(&"impact", contact, GameParams.current().impact_radius, _thrower_id)


func _draw() -> void:
	var r := GameParams.gu(RADIUS_GU)
	draw_circle(Vector2.ZERO, r, Color(0.62, 0.62, 0.58))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 12, Color(0.3, 0.3, 0.3), 1.0)
