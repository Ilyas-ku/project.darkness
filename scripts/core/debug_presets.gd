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
	&"TEST_STEPS_TWO_RUNNERS": "Два служебных бегуна за спиной: бег и шаг, один останавливается",
	&"TEST_SOUND_EVENTS": "Последовательность звуков: дверь, шкаф, окно, камень, бутылка, удар, выход",
	&"TEST_DOOR_SPRINT": "Бег сквозь входную дверь: E на бегу",
	&"TEST_CHASE_BREAK_LOS": "Погоня у группы деревьев: разорвите контакт",
	&"TEST_BUSH_STATIC": "Жертва неподвижно в кусте, маньяк ходит мимо",
	&"TEST_BUSH_WALK_RUN": "Жертва у куста, маньяк смотрит: пройдите куст крадучись, шагом, бегом",
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
		&"TEST_STEPS_TWO_RUNNERS":
			return "Стойте, смотрите на юг. За спиной один бегун бежит, второй идёт; через 8 с идущий останавливается. Слышны два наложенных ритма, потом один."
		&"TEST_SOUND_EVENTS":
			return "Стойте в гостиной. Каждые 1.5 с звучит событие: дверь откр./закр., шкаф, окно, камень, бутылка, удар, задвижка выхода."
		&"TEST_DOOR_SPRINT":
			return "Бегите (Shift) к закрытой двери дома и нажмите E на бегу: дверь откроется за 0.2 с, вы не остановитесь. Повторное нажатие закроет."
		&"TEST_CHASE_BREAK_LOS":
			return "Маньяк уже видит вас. Уведите его за стволы на поляне/в кусты или через дом с окном, чтобы разорвать линию зрения."
		&"TEST_BUSH_STATIC":
			return "Стойте в кусте не двигаясь. Маньяк проходит в 2–3 ед. и не видит вас; подойдя вплотную — заметит. F3 показывает сектор."
		&"TEST_BUSH_WALK_RUN":
			return "Маньяк стоит и смотрит на куст. Пройдите куст с Ctrl, шагом и с Shift: шорох громче, маскировка слабее."
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
		&"TEST_STEPS_TWO_RUNNERS":
			sv.global_position = g(15.0, 13.0)
			s.prepare_left = 600.0
			spawn_runner(s, &"sprint", [g(13.4, 9.8), g(18.4, 9.8)], -1.0, g(13.4, 9.8))
			spawn_runner(s, &"walk", [g(17.6, 11.0), g(13.6, 11.0)], 8.0, g(17.6, 11.0))
		&"TEST_SOUND_EVENTS":
			sv.global_position = g(5.4, 4.6)
			s.prepare_left = 600.0
			var ev := SoundEventsDriver.new()
			ev.session = s
			s.add_child(ev)
		&"TEST_DOOR_SPRINT":
			sv.global_position = g(9.2, 12.0)
			s.prepare_left = 600.0
		&"TEST_CHASE_BREAK_LOS":
			sv.global_position = g(14.0, 13.0)
			s.spawn_killer_at(g(11.0, 13.0), Vector2.RIGHT)
		&"TEST_BUSH_STATIC":
			sv.global_position = g(6.5, 15.0)
			_drive(s, g(3.0, 12.6), [[Vector2(10.0, 12.6), 1.0], [Vector2(3.0, 12.6), 1.0], [Vector2(6.5, 13.9), 2.0]])
		&"TEST_BUSH_WALK_RUN":
			sv.global_position = g(4.6, 15.0)
			s.spawn_killer_at(g(6.5, 11.6), Vector2.DOWN)
			s.killer.brain.set_physics_process(false)
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


## Debug-only scripted runner (independent footstep source, no combat AI).
static func spawn_runner(s: GameSession, gait: StringName, points: Array, stop_after: float, at: Vector2) -> TestRunner:
	var r: TestRunner = load("res://scenes/debug/test_runner.tscn").instantiate()
	r.name = "Runner_%s" % gait
	r.gait = gait
	for p in points:
		r.waypoints.append(p)
	r.stop_after = stop_after
	r.position = at
	s.actors.add_child(r)
	return r


## Plays the situational events one after another near the survivor.
class SoundEventsDriver extends Node:
	var session: Node
	var _t := 0.0
	var _i := 0

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t < 1.5:
			return
		_t = 0.0
		var cabin: Node = session.get_tree().get_first_node_in_group(&"cabin")
		var g := GameParams.PX_PER_GU
		var names := ["door open", "door close", "locker", "window", "stone", "bottle", "hit", "exit latch"]
		print("[preset] sound event: %s" % names[_i % names.size()])
		match _i % names.size():
			0:
				cabin.get_node("InnerDoor").set_open(true, null)
			1:
				cabin.get_node("InnerDoor").set_open(false, null)
			2:
				SoundEventBus.emit(&"locker", cabin.get_node("Locker").global_position, 3.0, 0)
			3:
				cabin.get_node("Window").on_vaulted(self)
			4:
				var st: Node2D = session.get_tree().get_nodes_in_group(&"stone")[0]
				st.state = Throwable.State.HELD
				st.throw_from(Vector2(5.9, 5.3) * g, Vector2(5.9, 8.0) * g, 0)
			5:
				SoundEventBus.emit(&"glass", Vector2(8.6, 6.4) * g, 11.0, 0)
			6:
				if session.survivor.health.can_be_hit():
					session.survivor.health.take_hit(self)
			7:
				# the latch is normally the survivor's own action at the gate
				SoundEventBus.emit(&"gate", session.exit_gate.global_position, 2.0, session.survivor.get_instance_id())
		_i += 1


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
