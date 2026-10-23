class_name SoundEventBus
extends Node
## World-side sound propagation. A SoundEvent knows the exact source position and
## emitter for physics/debug purposes; listeners never see it directly. Each
## HearingSensor converts it into a sanitized Observation.HeardObservation.

signal sound_emitted(event: SoundEvent)

class SoundEvent:
	var id: int
	var kind: StringName
	var source_world_position: Vector2
	var radius_px: float
	var emitter_id: int
	var time: float

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


## Emits a sound into the world. radius_gu is the audibility radius (MVP table).
func emit_sound(kind: StringName, source: Vector2, radius_gu: float, emitter_id: int) -> SoundEvent:
	var ev := SoundEvent.new()
	ev.id = _next_id
	_next_id += 1
	ev.kind = kind
	ev.source_world_position = source
	ev.radius_px = GameParams.gu(radius_gu)
	ev.emitter_id = emitter_id
	ev.time = GameClock.now()
	for l in _listeners.duplicate():
		if not is_instance_valid(l):
			_listeners.erase(l)
			continue
		if l.get_listener_id() == emitter_id:
			continue
		var r: float = ev.radius_px * l.get_hearing_multiplier()
		if l.get_listener_position().distance_to(source) <= r:
			l.receive_sound(ev)
	sound_emitted.emit(ev)
	return ev


## Convenience used by emitters; silently does nothing without a bus (unit tests).
static func emit(kind: StringName, source: Vector2, radius_gu: float, emitter_id: int) -> void:
	var bus := instance()
	if bus != null:
		bus.emit_sound(kind, source, radius_gu, emitter_id)
