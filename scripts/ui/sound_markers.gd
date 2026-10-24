class_name SoundMarkers
extends Node2D
## FootstepMapMarker layer: soft, short-lived, neutral blobs at the APPROXIMATE
## region of sounds the survivor actually heard. Driven by the same
## HearingSensor.heard observation as the audio voice (one audibility gate):
## no sound -> no marker. Close repeats merge into one blob; the blob fades in
## marker_fade seconds. No source silhouette, role, arrow or exact position.

var survivor: Node
var spawned := 0
var _markers: Array[Dictionary] = []   # {center, radius, born, kind, refresh}
var _t := 0.0


func setup(s: Node) -> void:
	survivor = s
	z_index = 56
	survivor.hearing.heard.connect(_on_heard)


func _on_heard(obs: Observation.HeardObservation) -> void:
	if not Settings.sound_markers or not obs.is_localizable():
		return
	var now := GameClock.now()
	var p := GameParams.current()
	var c: Vector2 = obs.region_center()
	var r: float = obs.region_radius()
	var merged := false
	for m in _markers:
		if m.kind == obs.kind and m.center.distance_to(c) <= GameParams.gu(p.marker_merge_distance) and now - m.refresh < p.marker_fade:
			m.center = m.center.lerp(c, 0.5)
			m.radius = lerpf(m.radius, r, 0.5)
			m.refresh = now
			merged = true
			break
	if not merged:
		_markers.append({"center": c, "radius": r, "born": now, "refresh": now, "kind": obs.kind})
	spawned += 1
	var entry: Dictionary = survivor.hearing.debug_entry(obs)
	if not entry.is_empty():
		entry.marker_spawned = true
	queue_redraw()


## Number of markers alive (optionally only of one kind).
func active_count(kind: StringName = &"") -> int:
	return _markers.filter(func(m): return kind == &"" or m.kind == kind).size()


func get_markers() -> Array[Dictionary]:
	return _markers


func _process(delta: float) -> void:
	_t += delta
	var now := GameClock.now()
	var fade := GameParams.current().marker_fade
	_markers = _markers.filter(func(m): return now - m.refresh < fade)
	queue_redraw()


func _draw() -> void:
	var now := GameClock.now()
	var fade := GameParams.current().marker_fade
	for m in _markers:
		var a := clampf(1.0 - (now - m.refresh) / fade, 0.0, 1.0)
		var col := Color(0.92, 0.9, 0.82) if m.kind == &"footsteps" or m.kind == &"foliage" else Color(1.0, 0.85, 0.6)
		# soft uncertainty disc made of concentric translucent rings
		for i in 6:
			var rr: float = m.radius * (1.0 - i * 0.15)
			draw_circle(m.center, rr, Color(col, 0.035 * a))
		var ph := fmod(_t * 1.3, 1.0)
		draw_arc(m.center, m.radius * (0.35 + 0.65 * ph), 0, TAU, 40, Color(col, 0.35 * a * (1.0 - ph)), 1.5)
