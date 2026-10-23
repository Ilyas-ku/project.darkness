class_name DebugPresets
extends RefCounted
## Reproducible debug set-ups (spec 14.2). Select with `-- --preset=NAME` or the
## F2 debug menu. A preset survives restarts until "normal game" is chosen.

const TITLES := {
	&"TEST_HOUSE_PATROL": "Игрок в шкафу, маньяк патрулирует (seed 42)",
	&"TEST_COMBAT": "Маньяк и жертва на поляне",
	&"TEST_EXIT_INTERRUPT": "Удержание выхода, маньяк прерывает",
	&"TEST_STONE_LOOP": "Камень рядом: бросок и подбор",
	&"TEST_FOOTSTEPS": "DEBUG: Hearing Test — маньяк ходит за стеной",
	&"TEST_WINDOW_NAV": "Погоня в спальне, уход через окно",
}

static var active: StringName = &""


static func g(x: float, y: float) -> Vector2:
	return Vector2(x, y) * GameParams.PX_PER_GU


static func instruction() -> String:
	match active:
		&"TEST_HOUSE_PATROL":
			return "Сидите в шкафу. Лог входов в дом / комнат / проверок шкафа — в консоли и F3."
		&"TEST_COMBAT":
			return "Стойте или убегайте. Счётчики атак и переходы здоровья — F3."
		&"TEST_EXIT_INTERRUPT":
			return "Удерживайте E у ворот. Удар маньяка обнулит прогресс."
		&"TEST_STONE_LOOP":
			return "E — поднять камень, ЛКМ — бросить. Повторите 10 раз."
		&"TEST_FOOTSTEPS":
			return "Стойте в спальне. Маньяк ходит снаружи за северной стеной, останавливается и уходит."
		&"TEST_WINDOW_NAV":
			return "Удерживайте E у окна (запад спальни) и уходите. Маньяк выберет окно или обход."
	return ""


## Applied by GameSession at the end of _ready. Returns true if a preset was applied.
static func apply(s: GameSession) -> bool:
	if active == &"":
		return false
	var p := GameParams.current()
	s.seed_used = 42
	s.rng.seed = 42
	var sv: SurvivorController = s.survivor
	var cabin: Node = s.get_tree().get_first_node_in_group(&"cabin")
	match active:
		&"TEST_HOUSE_PATROL":
			var locker: Node = cabin.get_node("Locker")
			sv.global_position = locker.get_exit_position()
			locker.interact(sv)
			s.prepare_left = 0.0
		&"TEST_COMBAT":
			sv.global_position = g(15, 13)
			s.spawn_killer_at(g(11.5, 13), Vector2.RIGHT)
		&"TEST_EXIT_INTERRUPT":
			sv.global_position = s.exit_gate.get_interact_position() + g(-0.3, 0)
			s.spawn_killer_at(g(20, 19.25), Vector2.RIGHT)
		&"TEST_STONE_LOOP":
			sv.global_position = g(15, 13)
			var stone: Node2D = s.get_tree().get_nodes_in_group(&"stone")[1]
			stone.global_position = g(15.8, 13)
			s.prepare_left = 600.0
		&"TEST_FOOTSTEPS":
			sv.global_position = g(5.0, 3.2)
			s.spawn_killer_at(g(2.0, 1.0), Vector2.RIGHT)
			s.killer.brain.set_physics_process(false)
			var driver := HearingTestDriver.new()
			driver.killer = s.killer
			s.add_child(driver)
		&"TEST_WINDOW_NAV":
			sv.global_position = g(4.0, 4.6)
			s.spawn_killer_at(g(6.2, 5.0), Vector2.LEFT)
	s.set_debug(true)
	print("[preset] %s applied (seed 42)" % active)
	return true


## Moves the killer on a fixed loop outside the bedroom's north wall:
## walk east (audible), stop 2 s, walk far east (out of range), stop, come back.
class HearingTestDriver extends Node:
	var killer: Node
	var _waypoints := [Vector2(9.5, 1.0), Vector2(9.5, 1.0), Vector2(17.0, 1.0), Vector2(17.0, 1.0), Vector2(2.0, 1.0), Vector2(2.0, 1.0)]
	var _i := 0
	var _wait := 0.0

	func _physics_process(delta: float) -> void:
		if killer == null or not is_instance_valid(killer):
			return
		var wp: Vector2 = _waypoints[_i] * GameParams.PX_PER_GU
		if _i % 2 == 1:
			killer.stop()
			_wait += delta
			if _wait >= 2.0:
				_wait = 0.0
				_i = (_i + 1) % _waypoints.size()
			return
		killer.move_to(wp)
		if killer.has_arrived(0.2):
			print("[hearing-test] killer at %s, stopping 2 s" % str(_waypoints[_i]))
			_i = (_i + 1) % _waypoints.size()
