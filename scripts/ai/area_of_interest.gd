class_name AreaOfInterest
extends Node2D
## A place the killer patrols. Child Marker2D nodes are visited in name order;
## a marker whose name contains "sweep" makes the killer stop and look around.
## For the house, hiding spots (lockers) inside `bounds_gu` may be checked.
## This is static map knowledge, allowed for the AI.

@export var area_id: StringName = &"area"
@export var weight := 1.0
@export var is_house := false
## World-space rectangle of the area in gu (used for hiding spots and logging).
@export var bounds_gu := Rect2()


func _ready() -> void:
	add_to_group(&"area_of_interest")


func get_steps() -> Array[Dictionary]:
	var markers: Array = get_children().filter(func(c): return c is Marker2D)
	markers.sort_custom(func(a, b): return String(a.name) < String(b.name))
	var steps: Array[Dictionary] = []
	for m in markers:
		steps.append({"kind": &"move", "pos": m.global_position, "name": String(m.name)})
		if String(m.name).contains("sweep"):
			steps.append({"kind": &"sweep", "pos": m.global_position, "name": String(m.name)})
		if String(m.name).contains("hide"):
			steps.append({"kind": &"hide_check", "pos": m.global_position, "name": String(m.name)})
	return steps


func bounds_px() -> Rect2:
	return Rect2(bounds_gu.position * GameParams.PX_PER_GU, bounds_gu.size * GameParams.PX_PER_GU)


func contains(p: Vector2) -> bool:
	return bounds_gu.size != Vector2.ZERO and bounds_px().has_point(p)


func hiding_spots() -> Array:
	return get_tree().get_nodes_in_group(&"locker").filter(func(l): return contains(l.global_position))
