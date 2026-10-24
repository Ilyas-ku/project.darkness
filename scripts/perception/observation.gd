class_name Observation
extends RefCounted
## Sanitized perception records. These are the ONLY data the AI layer receives
## about the victim. Footstep observations carry no position, direction,
## role or actor id by construction.


## Produced by VisionSensor when the victim is actually seen this tick.
class ObservedVictim:
	var last_seen_position: Vector2
	var seen_at: float
	## Visible posture (lying on the ground) — observable, not hidden state.
	var is_downed := false
	## Seen as a face in a hiding-spot slit (observable).
	var is_peeking := false

	func _init(pos: Vector2 = Vector2.ZERO, t: float = 0.0, downed: bool = false, peeking: bool = false) -> void:
		last_seen_position = pos
		seen_at = t
		is_downed = downed
		is_peeking = peeking


## Produced by HearingSensor (the PerceivedSound of the spec).
## approximate_region = {"center": Vector2, "radius": float} in world px: a coarse,
## offset circle that contains the true source. No source id, role, exact position
## or source count ever appears here.
class HeardObservation:
	var kind: StringName
	var timestamp: float
	var is_nearby_presence: bool
	var intensity_band: StringName
	var approximate_region: Variant = null
	## 0..1 perceived loudness after distance and occlusion.
	var volume := 0.0
	## Heard through walls / from inside a closet (low-passed playback).
	var muffled := false
	## Character of the sound (wood / dirt / grass / leaves) — not who made it.
	var surface: StringName = &""

	func is_localizable() -> bool:
		return approximate_region != null

	func region_center() -> Vector2:
		return approximate_region["center"] if approximate_region != null else Vector2.ZERO

	func region_radius() -> float:
		return approximate_region["radius"] if approximate_region != null else 0.0

	func to_dict() -> Dictionary:
		var d := {
			"kind": kind,
			"timestamp": timestamp,
			"is_nearby_presence": is_nearby_presence,
			"intensity_band": intensity_band,
			"volume": volume,
			"muffled": muffled,
			"surface": surface,
		}
		if approximate_region != null:
			d["approximate_region"] = {"center": region_center(), "radius": region_radius()}
		return d


## Static traces actually seen in the world (blood).
class WorldEvidence:
	var kind: StringName
	var observed_at: Vector2
	var seen_at: float

	func _init(k: StringName = &"", pos: Vector2 = Vector2.ZERO, t: float = 0.0) -> void:
		kind = k
		observed_at = pos
		seen_at = t
