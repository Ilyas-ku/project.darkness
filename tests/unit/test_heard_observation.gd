extends TestCase
## Unit: footstep observations serialize without position, direction, role or actor id;
## localizable events only give an approximate 2 gu region that contains the source.

const FORBIDDEN := ["position", "direction", "role", "actor", "emitter", "source", "distance"]


func test_footsteps_region_is_approximate_and_anonymous() -> void:
	var p := GameParams.current()
	var src := Vector2(123, 456)
	var exact_hits := 0
	for seed in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var obs := HearingSensor.sanitize(&"footsteps", src, 3.0, rng, p)
		check(obs.is_nearby_presence, "presence flag set")
		check(obs.is_localizable(), "0.3: footsteps carry an approximate region")
		var r := obs.region_radius()
		check(r >= GameParams.gu(p.sound_uncertainty_min) - 0.01 and r <= GameParams.gu(p.sound_uncertainty_max) + 0.01, "uncertainty 1.5..3 gu")
		check(obs.region_center().distance_to(src) <= r, "true source inside the region")
		if obs.region_center().is_equal_approx(src):
			exact_hits += 1
		var keys := obs.to_dict().keys()
		for k in keys:
			for f in FORBIDDEN:
				check(not String(k).to_lower().contains(f), "forbidden key '%s'" % k)
		for f in ["count", "is_killer", "id"]:
			check(not keys.has(f), "no '%s' in the observation" % f)
		for prop in obs.get_property_list():
			if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var n := String(prop.name).to_lower()
			for f in ["position", "direction", "role", "actor", "emitter", "count"]:
				check(not n.contains(f), "observation has no '%s' property (%s)" % [f, n])
	check(exact_hits == 0, "region centre never equals the exact source (%d)" % exact_hits)


func test_impact_region_contains_source() -> void:
	var rng := RandomNumberGenerator.new()
	var p := GameParams.current()
	for i in 50:
		rng.seed = i
		var src := Vector2(300, 200)
		var obs := HearingSensor.sanitize(&"impact", src, 1.0, rng, p)
		check(obs.is_localizable(), "impact is localizable")
		check(is_equal_approx(obs.region_radius(), GameParams.gu(2.0)), "region radius 2 gu")
		check(obs.region_center().distance_to(src) <= obs.region_radius(), "source inside region")
		check(not obs.to_dict().has("emitter_id"), "no emitter id")
