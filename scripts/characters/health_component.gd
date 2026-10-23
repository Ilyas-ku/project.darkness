class_name HealthComponent
extends Node
## Survivor health: HEALTHY -> (hit) WOUNDED -> (hit) DOWNED -> (finisher) DEAD.
## A wound never slows the survivor; it leaves blood traces (see SurvivorController).

signal state_changed(old_state: int, new_state: int)
signal wounded
signal downed
signal died

enum HState { HEALTHY, WOUNDED, DOWNED, DEAD }

var state := HState.HEALTHY
var hits := 0
var transitions: Array[String] = []


func is_down() -> bool:
	return state == HState.DOWNED or state == HState.DEAD


func can_be_hit() -> bool:
	return state == HState.HEALTHY or state == HState.WOUNDED


func state_name() -> String:
	return HState.keys()[state]


## One successful hit = exactly one state transition.
func take_hit(_source: Node) -> bool:
	if not can_be_hit():
		return false
	hits += 1
	_set_state(HState.WOUNDED if state == HState.HEALTHY else HState.DOWNED)
	return true


func finish(_source: Node) -> bool:
	if state != HState.DOWNED:
		return false
	_set_state(HState.DEAD)
	return true


func _set_state(s: int) -> void:
	var old := state
	state = s
	transitions.append("%6.1fs %s -> %s" % [GameClock.now(), HState.keys()[old], HState.keys()[s]])
	state_changed.emit(old, s)
	match s:
		HState.WOUNDED:
			wounded.emit()
		HState.DOWNED:
			downed.emit()
		HState.DEAD:
			died.emit()
