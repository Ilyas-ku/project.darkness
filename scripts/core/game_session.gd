class_name GameSession
extends Node2D
## Match flow for ForestTest_01:
##   PREPARE (30 s, killer absent from the world) -> ACTIVE (killer spawned at a
##   safe map-edge point, exit active) -> ESCAPED | CAUGHT. Also pause, restart,
##   debug toggle, seeding and command-line overrides.

enum Phase { PREPARE, ACTIVE, ESCAPED, CAUGHT }

const KILLER_SCENE := preload("res://scenes/characters/killer.tscn")

@onready var actors: Node2D = $World/Actors
@onready var survivor: SurvivorController = $World/Actors/Survivor
@onready var nav_region: NavigationRegion2D = $World/NavRegion
@onready var exit_gate: StaticBody2D = $World/ExitGate
@onready var fog: FogRenderer = $FogRenderer
@onready var perception: PlayerPerceptionView = $PerceptionView
@onready var hud: CanvasLayer = $HUD
@onready var debug_overlay: Node2D = $DebugOverlay

var params: GameParams
var phase := Phase.PREPARE
var prepare_left := 30.0
var active_time := 0.0
var killer: KillerMotor = null
var rng := RandomNumberGenerator.new()
var seed_used := 0
var debug_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure_actions()
	params = GameParams.current()
	_apply_cmdline()
	seed_used = params.rng_seed if params.rng_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0) % 1000000
	rng.seed = seed_used
	survivor.hearing.rng.seed = seed_used + 11
	_place_survivor()
	nav_region.build()
	fog.setup(params.map_size_px(), GameParams.gu(params.fog_cell_size), params.fog_explored_alpha)
	perception.setup(survivor, fog)
	exit_gate.opened.connect(_on_exit_opened)
	survivor.health.died.connect(_on_survivor_died)
	survivor.hearing.heard.connect(_on_survivor_heard)
	hud.setup(self)
	debug_overlay.setup(self)
	set_debug(debug_enabled)
	prepare_left = 0.0 if params.skip_prepare else params.prepare_time
	print("[session] seed=%d prepare=%.1fs" % [seed_used, prepare_left])


func _apply_cmdline() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			params.rng_seed = int(a.get_slice("=", 1))
		elif a == "--skip-prep":
			params.skip_prepare = true
		elif a == "--debug":
			debug_enabled = true


func _place_survivor() -> void:
	var spawns := get_tree().get_nodes_in_group(&"survivor_spawn")
	if spawns.is_empty():
		return
	spawns.sort_custom(func(a, b): return String(a.name) < String(b.name))
	survivor.global_position = spawns[rng.randi_range(0, spawns.size() - 1)].global_position


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	match phase:
		Phase.PREPARE:
			prepare_left -= delta
			if prepare_left <= 0.0:
				prepare_left = 0.0
				spawn_killer()
		Phase.ACTIVE:
			active_time += delta


## Picks a map-edge spawn at least min_spawn_distance from the survivor and
## outside the survivor's line of sight; falls back to the farthest point.
func choose_killer_spawn() -> Vector2:
	var pts: Array[Vector2] = []
	for m in get_tree().get_nodes_in_group(&"killer_spawn"):
		pts.append(m.global_position)
	if pts.is_empty():
		return Vector2.ZERO
	var min_d := GameParams.gu(params.min_spawn_distance_gu)
	var ok: Array[Vector2] = []
	var farthest := pts[0]
	for p in pts:
		var d := p.distance_to(survivor.global_position)
		if d > farthest.distance_to(survivor.global_position):
			farthest = p
		if d >= min_d and not survivor.vision.can_see_point(p):
			ok.append(p)
	if ok.is_empty():
		return farthest
	return ok[rng.randi_range(0, ok.size() - 1)]


func spawn_killer() -> void:
	if killer != null:
		return
	killer = KILLER_SCENE.instantiate()
	var p := choose_killer_spawn()
	killer.position = p
	actors.add_child(killer)
	killer.facing = (params.map_size_px() * 0.5 - p).normalized()
	killer.brain.rng.seed = seed_used + 7
	killer.hearing.rng.seed = seed_used + 13
	killer.brain.activate()
	phase = Phase.ACTIVE
	print("[session] killer spawned at %s (gu)" % str(p / GameParams.PX_PER_GU))


func _on_exit_opened() -> void:
	if is_finished():
		return
	phase = Phase.ESCAPED
	survivor.input_enabled = false
	# short gate animation before the result screen
	await get_tree().create_timer(0.6).timeout
	_finish(Phase.ESCAPED)


func _on_survivor_died() -> void:
	if phase == Phase.ACTIVE:
		_finish(Phase.CAUGHT)


func _on_survivor_heard(obs: Observation.HeardObservation) -> void:
	# Footstep indicator only for someone else's movement outside direct LOS.
	if obs.kind == &"footsteps" and not perception.killer_perceived:
		hud.flash_footsteps()


func _finish(result: Phase) -> void:
	phase = result
	survivor.input_enabled = false
	print("[session] result=%s time=%.1fs" % [Phase.keys()[result], active_time])
	hud.show_result(result == Phase.ESCAPED)
	get_tree().paused = true


func is_finished() -> bool:
	return phase == Phase.ESCAPED or phase == Phase.CAUGHT


func toggle_pause() -> void:
	if is_finished():
		return
	get_tree().paused = not get_tree().paused
	hud.set_pause_visible(get_tree().paused)


func set_debug(v: bool) -> void:
	debug_enabled = v
	debug_overlay.visible = v
	perception.debug_reveal = v
	hud.set_debug_visible(v)


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func quit_game() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle_pause()
	elif event.is_action_pressed(&"debug_toggle"):
		set_debug(not debug_enabled)
	elif event.is_action_pressed(&"restart") and (debug_enabled or is_finished()):
		restart()
