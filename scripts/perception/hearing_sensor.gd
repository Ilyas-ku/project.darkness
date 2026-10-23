class_name HearingSensor
extends Node
## Receives world SoundEvents from the SoundEventBus and turns them into sanitized
## Observation.HeardObservation records. Footsteps lose all positional data here.

signal heard(observation: Observation.HeardObservation)

var rng := RandomNumberGenerator.new()
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


func receive_sound(ev: SoundEventBus.SoundEvent) -> void:
	heard.emit(sanitize(ev.kind, ev.source_world_position, GameClock.now(), rng, GameParams.current()))


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
	obs.intensity_band = &"loud" if kind == &"impact" else &"medium"
	var r := GameParams.gu(p.approx_region_radius)
	var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, r * p.approx_region_offset_ratio)
	obs.approximate_region = {"center": source + off, "radius": r}
	return obs
