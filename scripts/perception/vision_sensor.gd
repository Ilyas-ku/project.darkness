class_name VisionSensor
extends Node
## Directional sector + line-of-sight vision. Used by both the survivor (for the
## on-screen visibility mask) and the killer (for detection), with the same LOS
## physics mask, so nothing "glows" through walls for either side.
##
## The owner (parent) provides get_eye_position() and get_facing().

@export var fov_deg := 110.0
@export var base_range_gu := 5.0
@export_flags_2d_physics var los_mask := GameParams.LOS_MASK

var enabled := true
var _range_modifiers := {}
var _bush_accum := {}


func _ready() -> void:
	var p := GameParams.current()
	base_range_gu = p.vision_range()
	fov_deg = p.vision_fov_deg


func get_eye_position() -> Vector2:
	var o := get_parent()
	if o.has_method(&"get_eye_position"):
		return o.get_eye_position()
	return (o as Node2D).global_position


func get_facing() -> Vector2:
	var o := get_parent()
	if o.has_method(&"get_facing"):
		return o.get_facing()
	return Vector2.RIGHT


## Range modifiers (e.g. +10% after the police call, powerful flashlight later).
func add_range_modifier(id: StringName, multiplier: float) -> void:
	_range_modifiers[id] = multiplier


func remove_range_modifier(id: StringName) -> void:
	_range_modifiers.erase(id)


func effective_range_px() -> float:
	var m := 1.0
	for v in _range_modifiers.values():
		m *= v
	return GameParams.gu(base_range_gu) * m


## Detection range multiplier for a target inside dense foliage, by its movement.
static func bush_visibility(mode: StringName, p: GameParams) -> float:
	match mode:
		&"careful":
			return p.bush_visibility_careful
		&"walk":
			return p.bush_visibility_walk
		&"sprint":
			return p.bush_visibility_sprint
	return p.bush_visibility_stationary


static func is_in_sector(origin: Vector2, facing: Vector2, fov: float, range_px: float, point: Vector2) -> bool:
	var to := point - origin
	var d := to.length()
	if d > range_px:
		return false
	if d < 0.001:
		return true
	return absf(facing.angle_to(to)) <= deg_to_rad(fov) * 0.5


func _space() -> PhysicsDirectSpaceState2D:
	return (get_parent() as Node2D).get_world_2d().direct_space_state


## True when nothing on the LOS mask blocks from->to. A hit on target_collider counts as seen.
func has_line_of_sight(from: Vector2, to: Vector2, target_collider: Object = null) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to, los_mask)
	q.collide_with_areas = false
	var hit := _space().intersect_ray(q)
	if hit.is_empty():
		return true
	return target_collider != null and hit.collider == target_collider


func can_see_point(point: Vector2, target_collider: Object = null) -> bool:
	if not enabled:
		return false
	var eye := get_eye_position()
	if not is_in_sector(eye, get_facing(), fov_deg, effective_range_px(), point):
		return false
	return has_line_of_sight(eye, point, target_collider)


func count_visible_points(points: PackedVector2Array) -> int:
	var n := 0
	for p in points:
		if can_see_point(p):
			n += 1
	return n


## Checks a perceivable target (get_perception_points / is_concealed) and applies the
## bush accumulation rule. Call once per tick per target with that tick's dt.
func check_target(target: Node, dt: float) -> bool:
	var id := target.get_instance_id()
	var pts: PackedVector2Array = target.get_perception_points()
	if pts.is_empty() or count_visible_points(pts) == 0:
		_bush_accum[id] = 0.0
		return false
	if target.has_method(&"is_concealed") and target.is_concealed():
		var p := GameParams.current()
		var mode: StringName = target.get_movement_mode() if target.has_method(&"get_movement_mode") else &"idle"
		if get_eye_position().distance_to(pts[0]) > effective_range_px() * bush_visibility(mode, p):
			_bush_accum[id] = 0.0
			return false
		_bush_accum[id] = _bush_accum.get(id, 0.0) + dt
		return _bush_accum[id] >= p.bush_detect_time
	_bush_accum[id] = 0.0
	return true


## Returns an observation of the first visible target in the group, or null.
func scan_group(group: StringName, dt: float) -> Observation.ObservedVictim:
	if not enabled:
		_bush_accum.clear()
		return null
	for t in get_tree().get_nodes_in_group(group):
		if check_target(t, dt):
			var pts: PackedVector2Array = t.get_perception_points()
			var downed: bool = t.has_method(&"is_downed") and t.is_downed()
			var peeking: bool = t.has_method(&"is_peeking_from_hiding") and t.is_peeking_from_hiding()
			return Observation.ObservedVictim.new(pts[0], GameClock.now(), downed, peeking)
	return null


## Evidence (blood) currently in view, newer than `newer_than`. Returns WorldEvidence or null.
func scan_evidence(newer_than: float, max_age: float, seen: Dictionary) -> Observation.WorldEvidence:
	if not enabled:
		return null
	var now := GameClock.now()
	for e in get_tree().get_nodes_in_group(&"evidence"):
		var id := e.get_instance_id()
		if seen.has(id) or e.created_at <= newer_than or now - e.created_at > max_age:
			continue
		if can_see_point(e.global_position):
			seen[id] = true
			return Observation.WorldEvidence.new(&"blood", e.global_position, now)
	return null


## Fan polygon of the current view (eye first). Ray ends are pushed slightly past the
## hit so the faces of walls are inside the visible area.
func compute_visibility_polygon(ray_count: int, edge_eps: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not enabled:
		return pts
	var eye := get_eye_position()
	var r := effective_range_px()
	var half := deg_to_rad(fov_deg) * 0.5
	var base := get_facing().angle()
	var space := _space()
	pts.append(eye)
	for i in ray_count + 1:
		var a := base - half + 2.0 * half * float(i) / float(ray_count)
		var dir := Vector2.from_angle(a)
		var q := PhysicsRayQueryParameters2D.create(eye, eye + dir * r, los_mask)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			pts.append(eye + dir * r)
		else:
			pts.append(hit.position + dir * edge_eps)
	return pts
