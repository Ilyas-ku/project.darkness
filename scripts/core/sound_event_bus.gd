class_name SoundEventBus
extends Node
## World-side sound delivery. A SoundEvent knows the exact source position, emitter
## and surface for propagation / playback / debug; listeners never get those fields.
## For every listener the Acoustics verdict is computed ONCE and handed to its
## HearingSensor, which builds the sanitized Observation.HeardObservation
## (PerceivedSound) used by the speaker, the map marker and the AI alike.

signal sound_emitted(event: SoundEvent)

class SoundEvent:
	var id: int
	var kind: StringName
	var source_world_position: Vector2
	var radius_px: float
	var emitter_id: int
	var time: float
	var material: StringName = &""
	var speed := 0.0
	var gait: StringName = &""

static var _cached: SoundEventBus

var _listeners: Array = []
var _next_id := 1


func _enter_tree() -> void:
	add_to_group(&"sound_bus")
	_cached = self


func _exit_tree() -> void:
	if _cached == self:
		_cached = null


static func instance() -> SoundEventBus:
	if _cached != null and is_instance_valid(_cached):
		return _cached
	return null


func register_listener(sensor: Object) -> void:
	if not _listeners.has(sensor):
		_listeners.append(sensor)


func unregister_listener(sensor: Object) -> void:
	_listeners.erase(sensor)


## Emits a sound into the world. radius_gu is the base audibility radius in the open.
func emit_sound(kind: StringName, source: Vector2, radius_gu: float, emitter_id: int, extra: Dictionary = {}) -> SoundEvent:
	var ev := SoundEvent.new()
	ev.id = _next_id
	_next_id += 1
	ev.kind = kind
	ev.source_world_position = source
	ev.radius_px = GameParams.gu(radius_gu)
	ev.emitter_id = emitter_id
	ev.time = GameClock.now()
	ev.material = extra.get("material", &"")
	ev.speed = extra.get("speed", 0.0)
	ev.gait = extra.get("gait", &"")
	var p := GameParams.current()
	var space := get_viewport().world_2d.direct_space_state if is_inside_tree() else null
	for l in _listeners.duplicate():
		if not is_instance_valid(l):
			_listeners.erase(l)
			continue
		if l.get_listener_id() == emitter_id:
			continue
		var lp: Vector2 = l.get_listener_position()
		if source.distance_to(lp) > ev.radius_px * l.get_hearing_multiplier():
			l.receive_sound(ev, Acoustics.evaluate(ev.radius_px, source, lp, 0, l.is_listener_hidden(), l.get_hearing_multiplier(), p))
			continue
		var occ := Acoustics.count_occluders(space, source, lp, l.get_listener_exclude())
		l.receive_sound(ev, Acoustics.evaluate(ev.radius_px, source, lp, occ, l.is_listener_hidden(), l.get_hearing_multiplier(), p))
	sound_emitted.emit(ev)
	return ev


## Convenience used by emitters; silently does nothing without a bus (unit tests).
static func emit(kind: StringName, source: Vector2, radius_gu: float, emitter_id: int, extra: Dictionary = {}) -> void:
	var bus := instance()
	if bus != null:
		bus.emit_sound(kind, source, radius_gu, emitter_id, extra)
