class_name FootstepEmitter
extends Node
## Emits a FootstepEvent for every stride the parent actor ACTUALLY travels (not on
## key presses or animation). Each actor has its own phase and slightly jittered
## rhythm, so two actors produce two independent, overlapping sequences.
## Also emits a BushRustleEvent while the actor really moves inside foliage
## (cadence by distance with a minimum interval; several bushes do not stack).
## Parent contract: get_movement_mode(), get_stride_gu(mode), get_footstep_radius_gu(mode),
## get_rustle_radius_gu(mode), is_in_bush().

signal stepped(material: StringName)

var rng := RandomNumberGenerator.new()
var steps_emitted := 0
var rustles_emitted := 0

var _last_pos := Vector2.INF
var _acc := 0.0
var _stride := 0.0
var _rustle_acc := 0.0
var _last_rustle := -INF


func _ready() -> void:
	rng.seed = get_parent().get_instance_id()
	# random initial phase: two actors starting together do not step in unison
	_acc = rng.randf() * GameParams.gu(GameParams.current().stride_walk)


func reset_position() -> void:
	_last_pos = Vector2.INF


func _physics_process(_delta: float) -> void:
	var actor := get_parent() as Node2D
	var pos := actor.global_position
	if _last_pos == Vector2.INF:
		_last_pos = pos
		return
	var moved := pos.distance_to(_last_pos)
	_last_pos = pos
	var mode: StringName = actor.get_movement_mode()
	# teleports (locker, respawn) and standing still never make steps
	if mode == &"idle" or moved < 0.05 or moved > GameParams.gu(1.0):
		return
	var p := GameParams.current()
	if _stride <= 0.0:
		_stride = _next_stride(actor, mode, p)
	_acc += moved
	if _acc >= _stride:
		_acc -= _stride
		_stride = _next_stride(actor, mode, p)
		var mat := Surface.at(actor, pos)
		steps_emitted += 1
		SoundEventBus.emit(&"footsteps", pos, actor.get_footstep_radius_gu(mode), actor.get_instance_id(),
			{"material": mat, "speed": moved * Engine.physics_ticks_per_second / GameParams.PX_PER_GU, "gait": mode})
		stepped.emit(mat)
	if actor.is_in_bush():
		_rustle_acc += moved
		var now := GameClock.now()
		var interval: float = maxf(p.rustle_cadence_min, {&"careful": p.rustle_interval_careful, &"sprint": p.rustle_interval_sprint}.get(mode, p.rustle_interval_walk))
		if _rustle_acc >= GameParams.gu(p.rustle_stride) and now - _last_rustle >= interval:
			_rustle_acc = 0.0
			_last_rustle = now
			rustles_emitted += 1
			SoundEventBus.emit(&"foliage", pos, actor.get_rustle_radius_gu(mode), actor.get_instance_id(),
				{"material": &"leaves", "gait": mode})
			for b in actor.get_tree().get_nodes_in_group(&"bush"):
				if b.contains_point(pos):
					b.shake(mode)


func _next_stride(actor: Node, mode: StringName, p: GameParams) -> float:
	return GameParams.gu(actor.get_stride_gu(mode)) * (1.0 + rng.randf_range(-p.stride_jitter, p.stride_jitter))
