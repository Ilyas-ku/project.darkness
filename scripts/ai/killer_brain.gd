class_name KillerBrain
extends Node
## Killer decision making (FSM). Data flow:
##   WorldState -> VisionSensor/HearingSensor -> sanitized observations -> AIMemory -> KillerBrain -> KillerMotor
## The brain never references the survivor node or any list of true victim
## positions. World knowledge it uses is static: patrol points and locker places.

signal state_changed(from: int, to: int, reason: String)

const S := KillerStates.State

var state: int = S.PREPARE
var state_time := 0.0
var memory: AIMemory
var params: GameParams
var motor: Node
var vision: VisionSensor
var rng := RandomNumberGenerator.new()
var transition_log: Array[String] = []

var search_center := Vector2.ZERO
var search_radius_px := 0.0
var investigate_region: Variant = null
var investigate_point := Vector2.ZERO

var _patrol_points: Array[Vector2] = []
var _patrol_index := 0
var _wait_left := 0.0
var _look_base := Vector2.DOWN
var _look_t := 0.0
var _search_info_time := 0.0
var _search_point := Vector2.ZERO
var _search_point_valid := false
var _search_bias := Vector2.ZERO
var _search_locker: Node = null
var _footsteps_check_time := -INF
var _attack_left := 0.0
var _attack_done := false
var _attack_ready_time := 0.0


func _ready() -> void:
	params = GameParams.current()
	memory = AIMemory.new(params)
	motor = get_parent()
	vision = motor.get_node(^"VisionSensor")
	motor.get_node(^"HearingSensor").heard.connect(_on_heard)
	motor.locker_checked.connect(_on_locker_checked)
	var markers := get_tree().get_nodes_in_group(&"patrol_point")
	markers.sort_custom(func(a, b): return String(a.name) < String(b.name))
	for m in markers:
		_patrol_points.append(m.global_position)


## Called by GameSession when the killer has been spawned into the world.
func activate() -> void:
	if state != S.PREPARE:
		return
	var best := INF
	for i in _patrol_points.size():
		var d: float = motor.global_position.distance_to(_patrol_points[i])
		if d < best:
			best = d
			_patrol_index = i
	_change(S.PATROL, "spawned after preparation")


func state_name() -> String:
	return KillerStates.name_of(state)


func _change(to: int, reason: String) -> void:
	var from := state
	state = to
	state_time = 0.0
	_wait_left = 0.0
	var line := "%6.1fs %s -> %s: %s" % [GameClock.now(), KillerStates.name_of(from), KillerStates.name_of(to), reason]
	transition_log.append(line)
	if transition_log.size() > 8:
		transition_log.pop_front()
	state_changed.emit(from, to, reason)


func _on_heard(obs: Observation.HeardObservation) -> void:
	if state == S.PREPARE:
		return
	memory.ingest_heard(obs, GameClock.now())


func _on_locker_checked(_locker: Node, found: bool) -> void:
	if found:
		_search_info_time = GameClock.now()
		transition_log.append("%6.1fs locker opened: someone inside" % GameClock.now())


# --- Tick -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == S.PREPARE:
		return
	state_time += delta
	var now := GameClock.now()
	memory.ingest_vision(vision.scan_group(&"survivor_perceivable", delta), now)

	if state == S.ATTACK:
		_tick_attack(delta, now)
		return

	# 1. A visible victim outranks every sound.
	if memory.has_visual:
		memory.take_pending_sound()
		if state != S.CHASE:
			_change(S.CHASE, "victim visible")
		_tick_chase(now)
		return
	if state == S.CHASE:
		_change(S.LAST_SEEN, "LOS lost")

	# 2. A fresh localizable sound outranks patrol / last seen / search.
	if memory.has_pending_sound():
		var s := memory.take_pending_sound()
		if now - s.timestamp <= params.sound_fresh_window:
			_begin_investigate(s)

	# 3. Unlocalized footsteps only allow a cautious check around the killer's own position.
	if memory.footsteps_fresh(now, params.footsteps_fresh_window) and now - _footsteps_check_time >= params.sound_recheck_cooldown:
		if state == S.PATROL:
			_footsteps_check_time = now
			_begin_search(motor.global_position, params.footsteps_search_radius, "footsteps nearby: local check", false)
		elif state == S.SEARCH:
			_footsteps_check_time = now
			_search_info_time = now

	match state:
		S.PATROL:
			_tick_patrol(delta)
		S.LAST_SEEN:
			_tick_last_seen()
		S.INVESTIGATE:
			_tick_investigate(delta)
		S.SEARCH:
			_tick_search(delta, now)


func _tick_patrol(delta: float) -> void:
	if _patrol_points.is_empty():
		return
	if _wait_left > 0.0:
		_wait_left -= delta
		_sweep_look(delta)
		if _wait_left <= 0.0:
			_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		return
	motor.move_to(_patrol_points[_patrol_index])
	if motor.has_arrived() or motor.stuck:
		_start_wait(params.patrol_wait)


func _tick_chase(now: float) -> void:
	var target := memory.visible_position
	var dist: float = motor.global_position.distance_to(target)
	if motor.is_busy():
		return
	var locker := _locker_at(target, 0.4)
	if locker != null:
		# Victim seen peeking out of a locker: go and open it.
		motor.move_to(locker.get_search_position())
		if motor.global_position.distance_to(locker.get_search_position()) <= GameParams.gu(0.35):
			motor.start_open_locker(locker)
		return
	if dist <= GameParams.gu(params.attack_range) and now >= _attack_ready_time:
		_change(S.ATTACK, "victim in attack range")
		motor.stop()
		_attack_left = params.attack_telegraph
		_attack_done = false
		motor.visual.telegraph = true
		return
	motor.move_to(target)


func _tick_attack(delta: float, now: float) -> void:
	if _attack_done:
		return
	motor.stop()
	if memory.has_visual:
		motor.look_towards(memory.visible_position - motor.global_position)
	_attack_left -= delta
	if _attack_left > 0.0:
		return
	motor.visual.telegraph = false
	if motor.perform_attack():
		_attack_done = true
		transition_log.append("%6.1fs attack hit" % now)
		return
	_attack_ready_time = now + params.attack_cooldown
	if memory.has_visual:
		_change(S.CHASE, "attack missed, cooldown")
	else:
		_change(S.LAST_SEEN, "attack missed, LOS lost")


func _tick_last_seen() -> void:
	motor.move_to(memory.last_seen_position)
	if motor.has_arrived() or motor.stuck or state_time > params.last_seen_timeout:
		_search_bias = memory.last_seen_velocity
		_begin_search(memory.last_seen_position, params.search_radius, "reached last seen position", true)


func _tick_investigate(delta: float) -> void:
	if _wait_left > 0.0:
		_wait_left -= delta
		_sweep_look(delta)
		if _wait_left <= 0.0:
			investigate_region = null
			_change(S.PATROL, "no evidence at sound area")
		return
	if state_time > params.investigate_timeout:
		investigate_region = null
		_change(S.PATROL, "investigate timeout")
		return
	motor.move_to(investigate_point)
	if motor.has_arrived() or motor.stuck:
		_start_wait(params.investigate_look_time)


func _tick_search(delta: float, now: float) -> void:
	if now - _search_info_time >= params.search_duration:
		_change(S.PATROL, "search: %.0fs without new info" % params.search_duration)
		return
	if motor.is_busy():
		return
	if _search_locker != null:
		var sp: Vector2 = _search_locker.get_search_position()
		motor.move_to(sp)
		if motor.global_position.distance_to(sp) <= GameParams.gu(0.35):
			motor.start_open_locker(_search_locker)
			_search_locker = null
		elif motor.stuck or motor.has_arrived(0.2):
			_search_locker = null
		return
	if _wait_left > 0.0:
		_wait_left -= delta
		_sweep_look(delta)
		return
	if not _search_point_valid:
		_search_point = _pick_search_point()
		_search_point_valid = true
	motor.move_to(_search_point)
	if motor.has_arrived() or motor.stuck:
		_search_point_valid = false
		_start_wait(params.search_look_time)


# --- Helpers ----------------------------------------------------------------------

func _begin_investigate(s: Observation.HeardObservation) -> void:
	investigate_region = {"center": s.region_center(), "radius": s.region_radius()}
	var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, s.region_radius())
	investigate_point = _closest_nav_point(s.region_center() + off)
	_change(S.INVESTIGATE, "heard %s" % s.kind)


func _begin_search(center: Vector2, radius_gu: float, reason: String, from_last_seen: bool) -> void:
	search_center = center
	search_radius_px = GameParams.gu(radius_gu)
	_search_info_time = GameClock.now()
	_search_point_valid = false
	if not from_last_seen:
		_search_bias = Vector2.ZERO
	_search_locker = null
	var best := INF
	for l in get_tree().get_nodes_in_group(&"locker"):
		var d: float = l.get_peek_origin().distance_to(center)
		if d > search_radius_px + GameParams.gu(1.0):
			continue
		var forced := from_last_seen and d <= GameParams.gu(0.6)
		if (forced or rng.randf() < params.locker_check_chance) and d < best:
			best = d
			_search_locker = l
	_change(S.SEARCH, reason)


func _pick_search_point() -> Vector2:
	var me: Vector2 = motor.global_position
	for attempt in 10:
		var off: Vector2
		if attempt == 0 and _search_bias.length() > 1.0:
			off = _search_bias.normalized() * search_radius_px * 0.8
			_search_bias = Vector2.ZERO
		else:
			off = Vector2.from_angle(rng.randf() * TAU) * search_radius_px * sqrt(rng.randf())
		var p := _closest_nav_point(search_center + off)
		if p.distance_to(search_center) <= search_radius_px * 1.4 and p.distance_to(me) > GameParams.gu(0.8):
			return p
	return _closest_nav_point(search_center)


func _closest_nav_point(p: Vector2) -> Vector2:
	var map: RID = motor.agent.get_navigation_map()
	if not map.is_valid():
		return p
	return NavigationServer2D.map_get_closest_point(map, p)


func _locker_at(p: Vector2, tol_gu: float) -> Node:
	for l in get_tree().get_nodes_in_group(&"locker"):
		if l.get_peek_origin().distance_to(p) <= GameParams.gu(tol_gu):
			return l
	return null


func _start_wait(t: float) -> void:
	_wait_left = t
	_look_base = motor.facing
	_look_t = 0.0
	motor.stop()


func _sweep_look(delta: float) -> void:
	_look_t += delta
	motor.look_towards(_look_base.rotated(sin(_look_t * 2.6) * 1.3))


func get_debug_info() -> Dictionary:
	return {
		"state": state_name(),
		"state_time": state_time,
		"has_visual": memory.has_visual,
		"has_last_seen": memory.has_last_seen,
		"last_seen": memory.last_seen_position,
		"last_seen_time": memory.last_seen_time,
		"investigate_region": investigate_region,
		"search_center": search_center if state == S.SEARCH else null,
		"search_radius": search_radius_px,
		"observations": memory.observations_count,
		"heard": memory.heard_count,
		"ignored_sounds": memory.ignored_sounds_count,
		"log": transition_log,
	}
