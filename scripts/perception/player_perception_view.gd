class_name PlayerPerceptionView
extends Node
## Presents the world to the player strictly through the survivor's VisionSensor:
## updates the fog mask and memory, shows dynamic objects (killer, stones) only
## while actually visible, and keeps doors drawn in their last *seen* state.

var survivor: Node
var fog: FogRenderer
var params: GameParams
## Debug overlay may reveal the killer (developer mode only).
var debug_reveal := false
var killer_perceived := false

var _fog_accum := 0.0
var _polygon := PackedVector2Array()


func setup(s: Node, f: FogRenderer) -> void:
	survivor = s
	fog = f
	params = GameParams.current()


func get_visibility_polygon() -> PackedVector2Array:
	return _polygon


func _physics_process(delta: float) -> void:
	if survivor == null or not is_instance_valid(survivor):
		return
	var sv: VisionSensor = survivor.vision
	_polygon = sv.compute_visibility_polygon(params.visibility_ray_count, params.los_edge_epsilon_px)
	fog.set_visible_polygon(_polygon)
	_fog_accum += delta
	if _fog_accum >= 1.0 / params.fog_update_hz:
		_fog_accum = 0.0
		if fog.memory.update_from_polygon(_polygon):
			fog.refresh_texture()

	killer_perceived = false
	var killer_pos := Vector2.INF
	for k in get_tree().get_nodes_in_group(&"killer_perceivable"):
		var seen := sv.check_target(k, delta)
		killer_perceived = killer_perceived or seen
		if seen:
			killer_pos = k.global_position
		k.visual.visible = _renderable(seen, k.global_position) or debug_reveal
		# In developer mode the killer is drawn above the fog.
		k.visual.z_index = 60 if debug_reveal and not seen else 0

	for n in get_tree().get_nodes_in_group(&"npc_perceivable"):
		var vis := n.get_node_or_null(^"Visual")
		if vis != null:
			vis.visible = sv.count_visible_points(n.get_perception_points()) > 0 or debug_reveal

	for s in get_tree().get_nodes_in_group(&"dynamic_object"):
		var pts: PackedVector2Array = s.get_perception_points()
		if pts.is_empty():
			s.visible = false
			continue
		var seen := sv.count_visible_points(pts) > 0
		s.visible = _renderable(seen, pts[0]) or debug_reveal

	for d in get_tree().get_nodes_in_group(&"door"):
		if sv.can_see_point(d.global_position, d):
			d.set_displayed_open(d.is_open())

	for b in get_tree().get_nodes_in_group(&"bush"):
		b.reveal = killer_perceived and b.contains_point(killer_pos)

	for c in get_tree().get_nodes_in_group(&"canopy"):
		var under: bool = c.covers(survivor.global_position) or (killer_perceived and c.covers(killer_pos))
		c.modulate.a = 0.3 if under else 1.0


## Dynamic objects are rendered only in VISIBLE state (never from memory).
func _renderable(seen_now: bool, pos: Vector2) -> bool:
	var st := ExplorationMemory.CellState.VISIBLE if seen_now else mini(fog.memory.get_state_at(pos), ExplorationMemory.CellState.EXPLORED)
	return ExplorationMemory.is_renderable(true, st)
