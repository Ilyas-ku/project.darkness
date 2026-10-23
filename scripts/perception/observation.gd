class_name Observation
extends RefCounted
## Sanitized perception records. These are the ONLY data the AI layer receives
## about the victim. Footstep observations carry no position, direction,
## role or actor id by construction.


## Produced by VisionSensor when the victim is actually seen this tick.
class ObservedVictim:
	var last_seen_position: Vector2
	var seen_at: float

	func _init(pos: Vector2 = Vector2.ZERO, t: float = 0.0) -> void:
		last_seen_position = pos
		seen_at = t


## Produced by HearingSensor.
## approximate_region is null for footsteps, otherwise {"center": Vector2, "radius": float}
## in world px; the true source lies somewhere inside the circle.
class HeardObservation:
	var kind: StringName
	var timestamp: float
	var is_nearby_presence: bool
	var intensity_band: StringName
	var approximate_region: Variant = null

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
		}
		if approximate_region != null:
			d["approximate_region"] = {"center": region_center(), "radius": region_radius()}
		return d


## Static traces found in the world (blood, etc.). Not produced in the first prototype.
class WorldEvidence:
	var kind: StringName
	var observed_at: Vector2
	var seen_at: float
