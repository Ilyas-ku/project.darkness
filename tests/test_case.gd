class_name TestCase
extends RefCounted
## Minimal test base (no external plugins). Methods named test_* are run by
## tests/run_tests.gd; they may be coroutines (await frames via `tree`).

var tree: SceneTree
var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		failures.append("%s (got %s, expected %s)" % [msg, str(a), str(b)])


func physics_frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Advances simulated time (seconds) at the fixed physics rate.
func seconds(t: float) -> void:
	await physics_frames(int(ceil(t * Engine.physics_ticks_per_second)))


## Navigation maps sync asynchronously; wait until the scene's navigation is usable.
func wait_navigation(region: NavigationRegion2D) -> void:
	var map: RID = region.get_navigation_map()
	for i in 120:
		if NavigationServer2D.map_get_iteration_id(map) > 0 and not NavigationServer2D.map_get_path(map, Vector2(300, 300), Vector2(400, 420), true).is_empty():
			break
		await tree.physics_frame
	await physics_frames(5)


func before_each() -> void:
	pass


func after_each() -> void:
	pass
