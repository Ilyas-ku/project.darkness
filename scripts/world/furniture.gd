extends StaticBody2D
## House furniture. Low pieces (bed, table, chairs) block walking but not sight;
## tall pieces (crate) also block sight. Movable pieces can be pushed with a held
## E (1.5 s) by furniture_push_distance away from the actor if the spot is free;
## pushing makes noise and rebuilds the killer's navigation.

signal moved

@export var kind: StringName = &"table"
@export var display_name := "стол"
@export var size_gu := Vector2(1.6, 1.0)
@export var tall := false
@export var movable := false

var _shape: CollisionShape2D
var _tween: Tween


func _ready() -> void:
	add_to_group(&"furniture")
	if movable:
		add_to_group(&"interactable")
	collision_layer = GameParams.L_FURNITURE if tall else GameParams.L_LOW_FURNITURE
	collision_mask = 0
	z_index = 4
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size_gu * GameParams.PX_PER_GU
	_shape.shape = r
	add_child(_shape)


func push_target(actor: Node2D) -> Vector2:
	var d := global_position - actor.global_position
	var axis := Vector2(signf(d.x), 0) if absf(d.x) >= absf(d.y) else Vector2(0, signf(d.y))
	return global_position + axis * GameParams.gu(GameParams.current().furniture_push_distance)


func can_push(actor: Node2D) -> bool:
	var to := push_target(actor)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape.shape
	q.transform = Transform2D(global_rotation, to)
	q.collision_mask = GameParams.MOVE_MASK | GameParams.L_SURVIVOR | GameParams.L_KILLER
	q.exclude = [get_rid(), actor.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


# --- Interactable (movable only) ----------------------------------------------

func get_interact_position() -> Vector2:
	return global_position


func can_interact(actor: Node) -> bool:
	return movable and actor.is_in_group(&"survivor")


func can_start(actor: Node) -> bool:
	return can_push(actor)


func requires_hold() -> bool:
	return true


func get_interact_duration(_actor: Node) -> float:
	return GameParams.current().furniture_move_time


func get_interact_hint(actor: Node) -> String:
	if not can_push(actor):
		return "%s: некуда сдвинуть" % display_name.capitalize()
	return "Удерживайте E — сдвинуть %s" % display_name


func interact(actor: Node) -> void:
	if not can_push(actor):
		return
	var to := push_target(actor)
	SoundEventBus.emit(&"furniture", global_position, 5.0, actor.get_instance_id())
	# Collision moves at once (navigation and blocking stay truthful); the drawing slides.
	var from := global_position
	global_position = to
	var vis_offset := from - to
	_draw_offset = vis_offset
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_draw_offset", Vector2.ZERO, 0.3)
	moved.emit()
	var nav := get_tree().get_first_node_in_group(&"nav_builder")
	if nav != null:
		nav.build()


var _draw_offset := Vector2.ZERO:
	set(v):
		_draw_offset = v
		queue_redraw()


func _draw() -> void:
	var s := size_gu * GameParams.PX_PER_GU
	var r := Rect2(-s * 0.5 + _draw_offset, s)
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0.02, 0.05, 0.4))
	draw_texture_rect(Art.tex("sprites/%s.png" % kind), r, false)
