extends TestCase
## Integration: killer FSM driven only by sensors in a small arena.
## Arena: open ground, a wall at x=10 gu (y 9..15), killer at (5,12) facing right.

const KILLER_SCENE := preload("res://scenes/characters/killer.tscn")
const BOX_SCRIPT := preload("res://scripts/world/obstacle_box.gd")
const NAV_SCRIPT := preload("res://scripts/core/navigation_builder.gd")

var root: Node2D
var killer: KillerMotor
var target: Node2D


class DummyVictim extends Node2D:
	func _ready() -> void:
		add_to_group(&"survivor_perceivable")

	func get_perception_points() -> PackedVector2Array:
		return PackedVector2Array([global_position])

	func is_concealed() -> bool:
		return false


func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


func before_each() -> void:
	root = Node2D.new()
	root.add_child(GameClock.new())
	root.add_child(SoundEventBus.new())
	var wall := StaticBody2D.new()
	wall.set_script(BOX_SCRIPT)
	wall.size_gu = Vector2(1, 6)
	wall.position = g(10, 12)
	root.add_child(wall)
	for i in 2:
		var m := Marker2D.new()
		m.name = "P%d" % i
		m.position = g(3, 4 + i * 16)
		m.add_to_group(&"patrol_point")
		root.add_child(m)
	var nav := NavigationRegion2D.new()
	nav.set_script(NAV_SCRIPT)
	root.add_child(nav)
	target = DummyVictim.new()
	target.position = g(25, 2)   # far away, unseen
	root.add_child(target)
	tree.root.add_child(root)
	nav.build()
	killer = KILLER_SCENE.instantiate()
	killer.position = g(5, 12)
	root.add_child(killer)
	killer.facing = Vector2.RIGHT
	await physics_frames(3)
	killer.brain.activate()


func after_each() -> void:
	root.queue_free()
	await physics_frames(1)


func st() -> String:
	return killer.brain.state_name()


func test_seen_then_behind_wall_goes_last_seen() -> void:
	target.global_position = g(8, 12)
	await physics_frames(3)
	check_eq(st(), "CHASE", "victim in open LOS -> CHASE (AC-04)")
	var seen_pos: Vector2 = killer.brain.memory.last_seen_position
	check(seen_pos.distance_to(g(8, 12)) < 1.0, "last seen updated while visible")
	target.global_position = g(12, 12)   # hidden behind the wall
	await physics_frames(2)
	check(st() == "LAST_SEEN" or st() == "SEARCH", "LOS lost -> LAST_SEEN/SEARCH (got %s)" % st())
	for i in 20:
		target.global_position = g(12, 12 + i * 0.1)   # keeps moving while hidden
		await physics_frames(2)
	check(killer.brain.memory.last_seen_position.distance_to(g(8, 12)) < 1.0, "last seen not moved by hidden motion (AC-05)")
	check(killer.brain.memory.last_seen_position.distance_to(target.global_position) > GameParams.gu(3.0), "AI does not know hidden position")


func test_long_search_returns_to_patrol() -> void:
	target.global_position = g(8, 12)
	await physics_frames(3)
	target.global_position = g(25, 2)
	await seconds(1.0)
	var seen_search := false
	for i in 30:
		await seconds(1.0)
		if st() == "SEARCH":
			seen_search = true
		if st() == "PATROL":
			break
	check(seen_search, "went through SEARCH")
	check_eq(st(), "PATROL", "returns to PATROL after search without info (AC-06)")


func test_sound_does_not_break_visible_chase() -> void:
	target.global_position = g(8, 12)
	await physics_frames(3)
	check_eq(st(), "CHASE", "chasing")
	for i in 5:
		SoundEventBus.instance().emit_sound(&"impact", g(5, 18), 9.0, 0)
		await physics_frames(5)
		target.global_position = killer.global_position + killer.facing * GameParams.gu(2.5)
	check(st() == "CHASE" or st() == "ATTACK", "visible victim outranks impact sound (AC-10), got %s" % st())


func test_impact_triggers_investigate_region() -> void:
	await physics_frames(5)
	check_eq(st(), "PATROL", "patrolling")
	var src := g(7, 18)
	SoundEventBus.instance().emit_sound(&"impact", src, 9.0, 0)
	await physics_frames(2)
	check_eq(st(), "INVESTIGATE", "impact -> INVESTIGATE")
	var reg: Variant = killer.brain.investigate_region
	check(reg != null and reg.center.distance_to(src) <= reg.radius, "approximate region contains the impact point")


func test_footsteps_only_local_check() -> void:
	await physics_frames(5)
	var before := killer.global_position
	SoundEventBus.instance().emit_sound(&"footsteps", killer.global_position + g(1.5, 1.5), 3.0, 12345)
	await physics_frames(2)
	check_eq(st(), "SEARCH", "footsteps -> cautious local SEARCH")
	check(killer.brain.search_center.distance_to(before) < GameParams.gu(0.5), "search centred on the killer, not on the source")
	check(not killer.brain.memory.has_last_seen, "no position learned from footsteps")
