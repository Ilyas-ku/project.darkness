class_name Throwable
extends Node2D
## Throwable world item (stone, bottle). Never consumed by a throw:
##   WORLD_PICKABLE -> HELD -> FLYING -> (SLIDING) -> RESTING_PICKABLE -> HELD ...
## E picks it up (0.4 s) only while it rests; LMB throws it towards the cursor at
## 10 gu/s up to 7 gu. The first contact (obstacle or ground) emits exactly one
## sound event at the real contact point. Breakable items (bottle) shatter instead.

enum State { WORLD_PICKABLE, HELD, FLYING, SLIDING, RESTING_PICKABLE, BROKEN }

const SHARDS_SCENE := preload("res://scenes/world/glass_shards.tscn")

@export var item_name := "камень"
@export var radius_gu := 0.14
@export var sound_kind: StringName = &"impact"
## 0 = use GameParams.impact_radius.
@export var sound_radius_gu := 0.0
@export var breaks_on_impact := false

var state := State.WORLD_PICKABLE
var throws := 0
var _dir := Vector2.ZERO
var _travel_left := 0.0
var _thrower_id := 0
var _slide_v := Vector2.ZERO


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"dynamic_object")
	add_to_group(&"throwable")
	if not breaks_on_impact:
		add_to_group(&"stone")
	z_index = 5


func is_pickable() -> bool:
	return state == State.WORLD_PICKABLE or state == State.RESTING_PICKABLE


func get_perception_points() -> PackedVector2Array:
	if state == State.HELD or state == State.BROKEN:
		return PackedVector2Array()
	return PackedVector2Array([global_position])


# --- Interactable ------------------------------------------------------------

func get_interact_position() -> Vector2:
	return global_position


func can_interact(actor: Node) -> bool:
	return is_pickable() and actor.has_node(^"Inventory") and actor.get_node(^"Inventory").has_space()


func get_interact_duration(_actor: Node) -> float:
	return GameParams.current().stone_pickup_time


func get_interact_hint(_actor: Node) -> String:
	return "E — подобрать: " + item_name


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
	SoundEventBus.emit(&"throw", origin, 1.5, thrower_id)
	throws += 1
	visible = true


func _physics_process(delta: float) -> void:
	match state:
		State.FLYING:
			_fly(delta)
		State.SLIDING:
			_slide(delta)


func _fly(delta: float) -> void:
	var step := minf(GameParams.gu(GameParams.current().stone_speed) * delta, _travel_left)
	var from := global_position
	var to := _clamp_to_map(from + _dir * step)
	var hit := _ray(from, to)
	if not hit.is_empty():
		global_position = hit.position - _dir * GameParams.gu(radius_gu)
		_contact(hit.position, _dir.bounce(hit.normal) if hit.normal != Vector2.ZERO else -_dir)
		return
	global_position = to
	_travel_left -= step
	if _travel_left <= 0.01 or to != from + _dir * step:
		_contact(global_position, _dir)


## One physical contact = one audible impulse; then slide to rest (or shatter).
func _contact(point: Vector2, slide_dir: Vector2) -> void:
	var p := GameParams.current()
	var radius := sound_radius_gu if sound_radius_gu > 0.0 else p.impact_radius
	SoundEventBus.emit(sound_kind, point, radius, _thrower_id)
	if breaks_on_impact:
		state = State.BROKEN
		var shards: Node2D = SHARDS_SCENE.instantiate()
		shards.position = point
		get_parent().add_child(shards)
		queue_free()
		return
	# v^2 = 2 a d  ->  initial speed for the configured slide distance at decel a.
	var decel := GameParams.gu(4.0)
	_slide_v = slide_dir.normalized() * sqrt(2.0 * decel * GameParams.gu(p.stone_slide_distance))
	state = State.SLIDING


func _slide(delta: float) -> void:
	var decel := GameParams.gu(4.0)
	var speed := _slide_v.length()
	if speed <= GameParams.gu(GameParams.current().stone_rest_speed):
		_rest()
		return
	var from := global_position
	var to := _clamp_to_map(from + _slide_v * delta)
	var hit := _ray(from, to)
	if not hit.is_empty():
		global_position = hit.position - _slide_v.normalized() * GameParams.gu(radius_gu)
		_rest()
		return
	global_position = to
	_slide_v = _slide_v.normalized() * maxf(0.0, speed - decel * delta)


func _rest() -> void:
	_slide_v = Vector2.ZERO
	global_position = _clamp_to_map(global_position)
	state = State.RESTING_PICKABLE


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var q := PhysicsRayQueryParameters2D.create(from, to, GameParams.THROW_MASK)
	return get_world_2d().direct_space_state.intersect_ray(q)


## Items can never leave the playable rectangle.
func _clamp_to_map(p: Vector2) -> Vector2:
	var m := GameParams.current().map_size_px()
	var e := GameParams.gu(0.35)
	return Vector2(clampf(p.x, e, m.x - e), clampf(p.y, e, m.y - e))


func _draw() -> void:
	var t := Art.tex("sprites/bottle.png" if breaks_on_impact else "sprites/stone.png")
	var sz := t.get_size() * Art.SRC_SCALE
	draw_texture_rect(t, Rect2(-sz * 0.5, sz), false)
