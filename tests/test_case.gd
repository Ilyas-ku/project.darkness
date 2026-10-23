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


func before_each() -> void:
	pass


func after_each() -> void:
	pass
