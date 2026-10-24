class_name DebugPresets
extends RefCounted
## Reproducible debug set-ups (spec 14.2). Select with `-- --preset=NAME` or the
## F2 debug menu. A preset survives restarts until "normal game" is chosen.

const TITLES := {
	&"TEST_HOUSE_PATROL": "Игрок в шкафу, маньяк патрулирует (seed 42)",
	&"TEST_COMBAT": "Маньяк и жертва на поляне",
	&"TEST_EXIT_INTERRUPT": "Удержание выхода, маньяк прерывает",
	&"TEST_STONE_LOOP": "Камень рядом: бросок и подбор",
	&"TEST_STEPS_CLOSET": "Игрок в шкафу, маньяк ходит по спальне и останавливается",
	&"TEST_STEPS_WALL": "DEBUG: Hearing Test — маньяк ходит за стеной",
	&"TEST_SOUND_OCCLUSION": "Шаги за входной дверью: дверь то открыта, то закрыта",
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
		&"TEST_STEPS_CLOSET":
			return "Вы в закрытом шкафу. Маньяк проходит по спальне, стоит 2 с у шкафа и уходит. Слушайте шаги (приглушённо) и смотрите на пятна."
		&"TEST_STEPS_WALL", &"TEST_FOOTSTEPS":
			return "Стойте в спальне. Маньяк ходит снаружи за северной стеной, останавливается и уходит."
		&"TEST_SOUND_OCCLUSION":
			return "Стойте у входной двери. Маньяк ходит снаружи; дверь каждые 4 с открывается/закрывается — сравните громкость и глухость."
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
		&"TEST_STEPS_CLOSET":
			var locker: Node = cabin.get_node("Locker")
			sv.global_position = locker.get_exit_position()
			locker.interact(sv)
			cabin.get_node("InnerDoor").set_open(true, null)
			_drive(s, g(9.2, 9.5), [[Vector2(9.2, 6.6), 0.0], [Vector2(7.6, 5.0), 0.0], [Vector2(4.2, 4.3), 2.0],
				[Vector2(7.6, 5.0), 0.0], [Vector2(9.2, 6.6), 0.0], [Vector2(9.2, 9.5), 2.0]])
			cabin.get_node("FrontDoor").set_open(true, null)
		&"TEST_STEPS_WALL", &"TEST_FOOTSTEPS":
			sv.global_position = g(5.0, 3.2)
			_drive(s, g(2.0, 1.0), [[Vector2(9.5, 1.0), 2.0], [Vector2(17.0, 1.0), 2.0], [Vector2(2.0, 1.0), 2.0]])
		&"TEST_SOUND_OCCLUSION":
			sv.global_position = g(9.2, 6.7)
			var drv := _drive(s, g(6.8, 9.2), [[Vector2(11.6, 9.2), 0.0], [Vector2(6.8, 9.2), 0.0]])
			drv.toggle_door = cabin.get_node("FrontDoor")
		&"TEST_WINDOW_NAV":
			sv.global_position = g(4.0, 4.6)
			s.spawn_killer_at(g(6.2, 5.0), Vector2.LEFT)
	s.set_debug(true)
	print("[preset] %s applied (seed 42)" % active)
	return true


## Spawns the killer with its brain off and drives it along a looping path.
static func _drive(s: GameSession, start: Vector2, waypoints: Array) -> PathDriver:
	s.spawn_killer_at(start, Vector2.RIGHT)
	s.killer.brain.set_physics_process(false)
	var d := PathDriver.new()
	d.actor = s.killer
	d.waypoints = waypoints
	s.add_child(d)
	return d


## Moves an actor along [[point_gu, stop_seconds], ...] in a loop; optionally toggles a door every 4 s.
class PathDriver extends Node:
	var actor: Node
	var waypoints: Array = []
	var toggle_door: Node = null
	var _i := 0
	var _wait := -1.0
	var _door_t := 0.0

	func _physics_process(delta: float) -> void:
		if actor == null or not is_instance_valid(actor) or waypoints.is_empty():
			return
		if toggle_door != null:
			_door_t += delta
			if _door_t >= 4.0:
				_door_t = 0.0
				toggle_door.set_open(not toggle_door.is_open(), null)
				print("[preset] door %s" % ("open" if toggle_door.is_open() else "closed"))
		var wp: Array = waypoints[_i]
		if _wait >= 0.0:
			actor.stop()
			_wait += delta
			if _wait >= wp[1]:
				_wait = -1.0
				_i = (_i + 1) % waypoints.size()
			return
		actor.move_to(wp[0] * GameParams.PX_PER_GU)
		if actor.has_arrived(0.2):
			if wp[1] > 0.0:
				print("[preset] actor at %s, stopping %.1f s" % [str(wp[0]), wp[1]])
				_wait = 0.0
			else:
				_i = (_i + 1) % waypoints.size()
