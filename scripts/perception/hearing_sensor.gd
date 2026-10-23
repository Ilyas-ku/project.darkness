class_name HearingSensor
extends Node
## Receives world SoundEvents from the SoundEventBus and turns them into sanitized
## Observation.HeardObservation records. Footsteps lose all positional data here.

signal heard(observation: Observation.HeardObservation)

var rng := RandomNumberGenerator.new()
## Latest footsteps evaluation for this listener (debug only):
## {time, distance_gu, radius_gu, walls, heard, reason}
var last_footsteps_diag := {}
var _modifiers := {}


func _ready() -> void:
	var bus := SoundEventBus.instance()
	if bus != null:
		bus.register_listener(self)


func _exit_tree() -> void:
	var bus := SoundEventBus.instance()
	if bus != null:
		bus.unregister_listener(self)


func get_listener_id() -> int:
	return get_parent().get_instance_id()


func get_listener_position() -> Vector2:
	return (get_parent() as Node2D).global_position


func add_hearing_modifier(id: StringName, multiplier: float) -> void:
	_modifiers[id] = multiplier


func remove_hearing_modifier(id: StringName) -> void:
	_modifiers.erase(id)


func get_hearing_multiplier() -> float:
	var m := 1.0
	for v in _modifiers.values():
		m *= v
	return m


func receive_sound(ev: SoundEventBus.SoundEvent, distance_px: float = 0.0, radius_px: float = 0.0, walls: bool = false) -> void:
	if ev.kind == &"footsteps":
		# Footsteps are only a signal of someone moving OUTSIDE direct view.
		var emitter: Object = instance_from_id(ev.emitter_id) if is_instance_id_valid(ev.emitter_id) else null
		var vis: VisionSensor = get_parent().get_node_or_null(^"VisionSensor")
		if emitter != null and vis != null and emitter.has_method(&"get_perception_points") \
				and vis.count_visible_points(emitter.get_perception_points()) > 0:
			note_footsteps(false, "source in direct LOS", distance_px, radius_px, walls)
			return
		note_footsteps(true, "heard", distance_px, radius_px, walls)
	heard.emit(sanitize(ev.kind, ev.source_world_position, GameClock.now(), rng, GameParams.current()))


func note_footsteps(was_heard: bool, reason: String, distance_px: float, radius_px: float, walls: bool) -> void:
	last_footsteps_diag = {
		"time": GameClock.now(), "distance_gu": distance_px / GameParams.PX_PER_GU,
		"radius_gu": radius_px / GameParams.PX_PER_GU, "walls": walls, "heard": was_heard, "reason": reason,
	}


## Pure conversion from an internal event to the public observation.
static func sanitize(kind: StringName, source: Vector2, now: float, rng: RandomNumberGenerator, p: GameParams) -> Observation.HeardObservation:
	var obs := Observation.HeardObservation.new()
	obs.kind = kind
	obs.timestamp = now
	if kind == &"footsteps":
		obs.is_nearby_presence = true
		obs.intensity_band = &"none"
		obs.approximate_region = null
		return obs
	obs.is_nearby_presence = false
	obs.intensity_band = &"loud" if kind == &"impact" or kind == &"glass" else &"medium"
	var r := GameParams.gu(p.approx_region_radius)
	var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, r * p.approx_region_offset_ratio)
	obs.approximate_region = {"center": source + off, "radius": r}
	return obs
