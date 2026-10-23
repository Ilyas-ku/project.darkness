class_name GameClock
extends Node
## Simulation time of the current match. Stops while the tree is paused and
## restarts from zero on scene reload. Used for observation timestamps.

static var _cached: GameClock

var time := 0.0


func _enter_tree() -> void:
	add_to_group(&"game_clock")
	_cached = self


func _exit_tree() -> void:
	if _cached == self:
		_cached = null


func _physics_process(delta: float) -> void:
	time += delta


static func now() -> float:
	if _cached != null and is_instance_valid(_cached):
		return _cached.time
	return Time.get_ticks_msec() / 1000.0
