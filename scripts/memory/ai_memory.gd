class_name AIMemory
extends RefCounted
## Killer's memory. Fed ONLY by sanitized observations from VisionSensor and
## HearingSensor; never by the survivor's true position. When LOS is lost,
## last_seen_position stays where the victim was last actually observed.

var has_visual := false
var visible_position := Vector2.ZERO
var visible_downed := false
var visible_peeking := false
var has_last_seen := false
var last_seen_position := Vector2.ZERO
var last_seen_time := -INF
## Velocity estimated from two consecutive actual observations (not hidden motion).
var last_seen_velocity := Vector2.ZERO

var footsteps_heard_time := -INF
var observations_count := 0
var heard_count := 0
var ignored_sounds_count := 0

var sound_recheck_cooldown := 4.0
var same_area_radius_px := 96.0

## Area id -> time of last completed visit; hiding spot id -> time of last check.
var area_last_visit := {}
var hiding_last_check := {}
var seen_evidence := {}

var _pending_sound: Observation.HeardObservation = null
var _recent_sounds: Array = []   # [{kind, center, time}]


func _init(p: GameParams = null) -> void:
	if p == null:
		p = GameParams.current()
	sound_recheck_cooldown = p.sound_recheck_cooldown
	same_area_radius_px = GameParams.gu(p.sound_same_area_radius)


func ingest_vision(obs: Observation.ObservedVictim, now: float) -> void:
	if obs == null:
		has_visual = false
		return
	if has_visual and obs.seen_at > last_seen_time:
		last_seen_velocity = (obs.last_seen_position - last_seen_position) / (obs.seen_at - last_seen_time)
	elif not has_visual:
		last_seen_velocity = Vector2.ZERO
	has_visual = true
	visible_downed = obs.is_downed
	visible_peeking = obs.is_peeking
	visible_position = obs.last_seen_position
	last_seen_position = obs.last_seen_position
	last_seen_time = obs.seen_at
	has_last_seen = true
	observations_count += 1


## Returns true if the observation was accepted as new information.
func ingest_heard(h: Observation.HeardObservation, now: float) -> bool:
	heard_count += 1
	if h.kind == &"footsteps":
		footsteps_heard_time = now
	if not h.is_localizable():
		return true
	if h.kind == &"throw":
		return false   # a throw whoosh is the thrower's own sound; the impact is the lure
	_recent_sounds = _recent_sounds.filter(func(r): return now - r.time < sound_recheck_cooldown)
	for r in _recent_sounds:
		if r.kind == h.kind and r.center.distance_to(h.region_center()) <= same_area_radius_px:
			ignored_sounds_count += 1
			return false
	_recent_sounds.append({"kind": h.kind, "center": h.region_center(), "time": now})
	_pending_sound = h
	return true


func has_pending_sound() -> bool:
	return _pending_sound != null


func take_pending_sound() -> Observation.HeardObservation:
	var s := _pending_sound
	_pending_sound = null
	return s


func footsteps_fresh(now: float, window: float) -> bool:
	return now - footsteps_heard_time <= window
