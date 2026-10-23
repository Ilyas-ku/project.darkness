class_name Interactable
extends RefCounted
## Contract for E-interactable world objects (duck-typed; objects join group
## "interactable" and implement):
##   get_interact_position() -> Vector2
##   can_interact(actor) -> bool
##   get_interact_duration(actor) -> float
##   get_interact_hint(actor) -> String
##   interact(actor) -> void


## Picks the object within interact_range that is closest to the cursor;
## ties are broken by distance to the actor. Objects behind walls are ignored.
static func find_best(actor: Node2D, cursor: Vector2) -> Node:
	var p := GameParams.current()
	var reach := GameParams.gu(p.interact_range)
	var best: Node = null
	var best_c := INF
	var best_a := INF
	for n in actor.get_tree().get_nodes_in_group(&"interactable"):
		if not n.can_interact(actor):
			continue
		var pos: Vector2 = n.get_interact_position()
		var da := actor.global_position.distance_to(pos)
		if da > reach:
			continue
		if not _reachable(actor, n, pos):
			continue
		var dc := cursor.distance_to(pos)
		if dc < best_c - 0.5 or (absf(dc - best_c) <= 0.5 and da < best_a):
			best = n
			best_c = dc
			best_a = da
	return best


static func _reachable(actor: Node2D, target: Node, pos: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(actor.global_position, pos, GameParams.LOS_MASK)
	var hit := actor.get_world_2d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == target
