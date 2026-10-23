extends SceneTree
## Headless test runner:
##   godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
## Optional filter: -- --only=<substring of file name>

const DIRS := ["res://tests/unit", "res://tests/integration", "res://tests/smoke"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	var passed := 0
	var failed := 0
	for dir in DIRS:
		for file in _list(dir):
			if only != "" and not file.contains(only):
				continue
			var script: GDScript = load(file)
			if script == null or not script.can_instantiate():
				failed += 1
				print("FAIL ", file.get_file(), " (script failed to load)")
				continue
			for m in script.get_script_method_list():
				var name: String = m.name
				if not name.begins_with("test_"):
					continue
				var t: TestCase = script.new()
				t.tree = self
				GameParams.set_current(GameParams.new())
				await t.before_each()
				await t.call(name)
				await t.after_each()
				paused = false
				var label := "%s::%s" % [file.get_file(), name]
				if t.failures.is_empty():
					passed += 1
					print("PASS ", label)
				else:
					failed += 1
					print("FAIL ", label)
					for f in t.failures:
						print("     - ", f)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _list(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
	out.sort()
	return out
