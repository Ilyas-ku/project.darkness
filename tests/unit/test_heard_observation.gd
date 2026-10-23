extends TestCase
## Unit: footstep observations serialize without position, direction, role or actor id;
## localizable events only give an approximate 2 gu region that contains the source.

const FORBIDDEN := ["position", "direction", "role", "actor", "emitter", "source", "distance"]


func test_footsteps_have_no_positional_data() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var obs := HearingSensor.sanitize(&"footsteps", Vector2(123, 456), 3.0, rng, GameParams.current())
	var d := obs.to_dict()
	check(obs.is_nearby_presence, "presence flag set")
	check(obs.approximate_region == null, "no region for footsteps")
	check_eq(d.keys().size(), 4, "only kind/timestamp/presence/intensity keys")
	for k in d.keys():
		for f in FORBIDDEN:
			check(not String(k).to_lower().contains(f), "forbidden key '%s'" % k)
	var s := var_to_str(d)
	check(not s.contains("123") and not s.contains("456"), "serialized footsteps leak no coordinates")
	for p in obs.get_property_list():
		var n := String(p.name).to_lower()
		for f in ["position", "direction", "role", "actor", "emitter"]:
			check(not n.contains(f), "observation has no '%s' property (%s)" % [f, n])


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
