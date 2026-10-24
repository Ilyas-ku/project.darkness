class_name HearingSensor
extends Node
## HearingPerception for one listener. Gets the Acoustics verdict for every world
## SoundEvent and, if audible, emits ONE sanitized Observation.HeardObservation
## (category, approximate region, volume, muffled, surface) — never the source id,
## role, exact position or a source count. A hidden listener (in a closet) keeps
## hearing; the closet only muffles. Inaudible events are kept in the debug log.

signal heard(observation: Observation.HeardObservation)

const LOG_SIZE := 10

var rng := RandomNumberGenerator.new()
## Latest footsteps evaluation for this listener (debug only).
var last_footsteps_diag := {}
## Debug chain entries (F3): newest last. Never used for gameplay decisions.
var debug_log: Array[Dictionary] = []
var _entries := {}   # observation instance id -> debug entry
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


func is_listener_hidden() -> bool:
	var o := get_parent()
	return o.has_method(&"is_hidden_in_spot") and o.is_hidden_in_spot()


## Colliders that must not count as occluders (the closet the listener sits in).
func get_listener_exclude() -> Array[RID]:
	var o := get_parent()
	if o.has_method(&"get_hiding_spot_rid"):
		var rid: RID = o.get_hiding_spot_rid()
		if rid.is_valid():
			return [rid]
	return []


func add_hearing_modifier(id: StringName, multiplier: float) -> void:
	_modifiers[id] = multiplier


func remove_hearing_modifier(id: StringName) -> void:
	_modifiers.erase(id)


func get_hearing_multiplier() -> float:
	var m := 1.0
	for v in _modifiers.values():
		m *= v
	return m


func receive_sound(ev: SoundEventBus.SoundEvent, acoustic: Dictionary) -> void:
	var entry := {
		"t": GameClock.now(), "source_actor": ev.emitter_id, "event_type": ev.kind, "moving": ev.speed > 0.0 or ev.kind == &"footsteps",
		"material": ev.material, "real_position": ev.source_world_position, "occluders": acoustic.occluders,
		"listener_state": "HIDDEN" if acoustic.hidden else "NORMAL", "audible": acoustic.audible,
		"reason": acoustic.reason, "region": null, "audio_play_called": false, "voice_active": false, "marker_spawned": false,
	}
	_push(entry)
	if ev.kind == &"footsteps":
		note_footsteps(acoustic.audible, acoustic.reason, acoustic.distance_px, acoustic.effective_radius_px, acoustic.occluders > 0)
	if not acoustic.audible:
		return
	var obs := perceive(ev.kind, ev.source_world_position, acoustic, ev.material, GameClock.now(), rng, GameParams.current())
	entry.region = obs.approximate_region
	_entries[obs.get_instance_id()] = entry
	heard.emit(obs)


func debug_entry(obs: Observation.HeardObservation) -> Dictionary:
	return _entries.get(obs.get_instance_id(), {})


func _push(entry: Dictionary) -> void:
	debug_log.append(entry)
	if debug_log.size() > LOG_SIZE:
		debug_log.pop_front()
	if _entries.size() > 64:
		_entries.clear()


func note_footsteps(was_heard: bool, reason: String, distance_px: float, radius_px: float, walls: bool) -> void:
	last_footsteps_diag = {
		"time": GameClock.now(), "distance_gu": distance_px / GameParams.PX_PER_GU,
		"radius_gu": radius_px / GameParams.PX_PER_GU, "walls": walls, "heard": was_heard, "reason": reason,
	}


## Pure conversion from an internal event + acoustic verdict to the public observation.
static func perceive(kind: StringName, source: Vector2, acoustic: Dictionary, material: StringName, now: float,
		rng: RandomNumberGenerator, p: GameParams) -> Observation.HeardObservation:
	var obs := Observation.HeardObservation.new()
	obs.kind = kind
	obs.timestamp = now
	obs.is_nearby_presence = kind == &"footsteps"
	obs.intensity_band = &"loud" if kind == &"impact" or kind == &"glass" else (&"low" if kind == &"footsteps" or kind == &"foliage" else &"medium")
	obs.volume = acoustic.loudness
	obs.muffled = acoustic.muffled
	obs.surface = material
	obs.approximate_region = Acoustics.approximate_region(source, acoustic, rng, p)
	return obs


## Backwards-compatible helper for tests: an unoccluded verdict at 1/3 of the radius.
static func sanitize(kind: StringName, source: Vector2, now: float, rng: RandomNumberGenerator, p: GameParams) -> Observation.HeardObservation:
	var r := GameParams.gu(3.0)
	var ac := Acoustics.evaluate(r, source, source + Vector2(r / 3.0, 0), 0, false, 1.0, p)
	return perceive(kind, source, ac, &"", now, rng, p)
