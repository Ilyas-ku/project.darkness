class_name Acoustics
extends RefCounted
## AcousticPropagation: one audibility verdict per (listener, event) pair.
## Distance, walls / closed doors between source and listener (each one shrinks the
## audible radius by wall_sound_attenuation — attenuates, never mutes) and the
## listener's own hiding spot (closet_sound_attenuation). Sight (LOS) is NOT required.
## The same verdict drives the speaker, the map marker and the AI.

const MAX_OCCLUDERS := 4


## Counts distinct sound occluders (walls, closed doors, tall furniture) on the segment.
static func count_occluders(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, exclude: Array[RID]) -> int:
	if space == null:
		return 0
	var ex: Array[RID] = exclude.duplicate()
	var n := 0
	for i in MAX_OCCLUDERS:
		var q := PhysicsRayQueryParameters2D.create(from, to, GameParams.LOS_MASK, ex)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		n += 1
		ex.append(hit.rid)
	return n


## Returns {audible, distance_px, radius_px, effective_radius_px, occluders, hidden, muffled, loudness, reason}.
static func evaluate(base_radius_px: float, source: Vector2, listener: Vector2, occluders: int, listener_hidden: bool,
		hearing_multiplier: float, p: GameParams) -> Dictionary:
	var att := pow(p.wall_sound_attenuation, occluders)
	if listener_hidden:
		att *= p.closet_sound_attenuation
	var eff := base_radius_px * hearing_multiplier * att
	var d := source.distance_to(listener)
	var audible := d <= eff
	var reason := "audible"
	if not audible:
		reason = "out of range (%.1f > %.1f gu%s)" % [d / GameParams.PX_PER_GU, eff / GameParams.PX_PER_GU,
			", %d wall(s)" % occluders if occluders > 0 else ""]
	return {
		"audible": audible, "distance_px": d, "radius_px": base_radius_px, "effective_radius_px": eff,
		"occluders": occluders, "hidden": listener_hidden, "muffled": occluders > 0 or listener_hidden,
		"loudness": clampf(1.0 - d / maxf(eff, 1.0), 0.0, 1.0) if audible else 0.0, "reason": reason,
	}


## Approximate region: uncertainty grows with distance and occlusion; the centre is
## offset and snapped to a coarse grid, so it never equals the source exactly every
## time, yet the true source always lies inside the circle.
static func approximate_region(source: Vector2, acoustic: Dictionary, rng: RandomNumberGenerator, p: GameParams) -> Dictionary:
	var k := clampf(acoustic.distance_px / maxf(acoustic.effective_radius_px, 1.0) + 0.3 * acoustic.occluders, 0.0, 1.0)
	var r := GameParams.gu(lerpf(p.sound_uncertainty_min, p.sound_uncertainty_max, k))
	var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, r * 0.4)
	var q := GameParams.gu(p.sound_region_quantum)
	var c := ((source + off) / q).floor() * q + Vector2(q, q) * 0.5
	# keep the source inside the circle (quantization can push it out at small radii)
	if c.distance_to(source) > r * 0.9:
		c = source + (c - source).limit_length(r * 0.9)
	return {"center": c, "radius": r}
