class_name TestRunner
extends CharacterBody2D
## Debug-only scripted actor (no combat AI) for the two-runners hearing test.
## Loops between waypoints at a gait speed; its footsteps come from its own
## FootstepEmitter, so it is an independent sound source like any actor.

@export var gait: StringName = &"sprint"
var waypoints: Array[Vector2] = []
var stop_after := -1.0
var facing := Vector2.RIGHT
var movement_mode: StringName = &"idle"

var _i := 0
var _t := 0.0


func _ready() -> void:
	add_to_group(&"npc_perceivable")
	collision_layer = 0
	collision_mask = GameParams.MOVE_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = GameParams.gu(0.3)
	cs.shape = c
	add_child(cs)


func _physics_process(delta: float) -> void:
	_t += delta
	movement_mode = &"idle"
	if waypoints.is_empty() or (stop_after >= 0.0 and _t >= stop_after):
		velocity = Vector2.ZERO
		return
	var to := waypoints[_i] - global_position
	if to.length() < 6.0:
		_i = (_i + 1) % waypoints.size()
		return
	var p := GameParams.current()
	var speed := p.sprint_speed if gait == &"sprint" else (p.careful_speed if gait == &"careful" else p.walk_speed)
	facing = to.normalized()
	velocity = facing * GameParams.gu(speed)
	move_and_slide()
	movement_mode = gait


func get_facing() -> Vector2:
	return facing


func get_movement_mode() -> StringName:
	return movement_mode


func get_perception_points() -> PackedVector2Array:
	return PackedVector2Array([global_position])


func get_stride_gu(mode: StringName) -> float:
	var p := GameParams.current()
	return p.stride_sprint if mode == &"sprint" else (p.stride_careful if mode == &"careful" else p.stride_walk)


func get_footstep_radius_gu(mode: StringName) -> float:
	return SurvivorController.footstep_radius(mode, GameParams.current())


func get_rustle_radius_gu(_mode: StringName) -> float:
	return GameParams.current().rustle_radius_walk


func is_in_bush() -> bool:
	return false
