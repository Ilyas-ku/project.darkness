class_name HealthComponent
extends Node
## Hit interface between attackers and characters. MVP: the first successful hit
## downs the survivor (ends the technical test). The full GDD rule
## (first hit wounds, second downs, then finishing) replaces only this script.

signal hit_taken(hits: int)
signal downed

var hits := 0
var hits_to_down := 1
var is_down := false


func _ready() -> void:
	hits_to_down = GameParams.current().hits_to_down


func take_hit(_source: Node) -> bool:
	if is_down:
		return false
	hits += 1
	hit_taken.emit(hits)
	if hits >= hits_to_down:
		is_down = true
		downed.emit()
	return true
