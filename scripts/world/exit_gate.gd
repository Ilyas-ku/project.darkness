extends StaticBody2D
## Exit gate in the map fence. Not a trigger: the survivor must stand within
## exit_interaction_distance and HOLD E for exit_hold_time seconds without moving.
## Releasing E, getting hit or downed resets the progress to zero (the survivor's
## timed channel is cancelled). On completion the gate swings open and the match is won.

signal opened

@export var size_gu := Vector2(0.3, 2.2)

var is_open := false
var _open_anim := 0.0


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"exit_gate")
	collision_layer = GameParams.L_WORLD
	collision_mask = 0
	z_index = 6
	var lantern := Art.sprite(self, "sprites/lamp.png", 1)
	lantern.position = Vector2(-GameParams.gu(0.25), -GameParams.gu(1.35))
	Art.point_light(self, Color(1.0, 0.7, 0.4), 3.0, 0.9).position = lantern.position
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size_gu * GameParams.PX_PER_GU
	cs.shape = r
	add_child(cs)


func is_unlocked() -> bool:
	var p := GameParams.current()
	return p.exit_unlocked_in_test_scene or not p.exit_requires_sunrise


func get_interact_position() -> Vector2:
	return global_position + Vector2(-GameParams.gu(size_gu.x * 0.5 + 0.1), 0)


func can_interact(actor: Node) -> bool:
	return not is_open and actor.is_in_group(&"survivor")


func can_start(_actor: Node) -> bool:
	return is_unlocked()


func requires_hold() -> bool:
	return true


func get_interact_duration(_actor: Node) -> float:
	return GameParams.current().exit_hold_time


func get_interact_hint(_actor: Node) -> String:
	if not is_unlocked():
		return "Выход откроется на рассвете"
	return "Удерживайте E — открыть выход (%d с)" % int(GameParams.current().exit_hold_time)


func on_channel_started(actor: Node) -> void:
	SoundEventBus.emit(&"gate", global_position, 2.0, actor.get_instance_id())


func interact(_actor: Node) -> void:
	if is_open:
		return
	is_open = true
	opened.emit()


func _process(delta: float) -> void:
	if is_open and _open_anim < 1.0:
		_open_anim = minf(1.0, _open_anim + delta / 0.6)
	queue_redraw()


func _draw() -> void:
	var s := size_gu * GameParams.PX_PER_GU
	var hinge := Vector2(0, -s.y * 0.5)
	var ang := _open_anim * PI * 0.5
	var leaf := Transform2D(ang, hinge)
	draw_set_transform(hinge, ang, Vector2.ONE)
	draw_texture_rect(Art.tex("sprites/gate.png"), Rect2(Vector2(-s.x * 0.5, 0), s), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(hinge, 3, Color(0.3, 0.3, 0.3))
	draw_circle(Vector2(0, s.y * 0.5), 3, Color(0.3, 0.3, 0.3))
	# progress of the survivor holding E, drawn over the gate
	for sv in get_tree().get_nodes_in_group(&"survivor"):
		if sv.get_channel_target() == self:
			var pr: float = sv.get_channel_progress()
			var bar := Rect2(Vector2(-26, -s.y * 0.5 - 14), Vector2(36, 5))
			draw_rect(bar, Color(0, 0, 0, 0.7))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * pr, bar.size.y)), Color(0.95, 0.85, 0.35))
