class_name GameParams
extends Resource
## Central gameplay configuration. Every number marked "MVP" in the spec lives here;
## gameplay scripts must read values from GameParams.current() instead of hardcoding them.
## Distances are in game units (gu), speeds in gu/s, times in seconds.

const PX_PER_GU := 32.0
const PARAMS_PATH := "res://config/game_params.tres"

# Physics layers (bit values).
const L_WORLD := 1        # trunks, walls, map bounds, shed
const L_DOOR := 2         # closed doors
const L_SURVIVOR := 4
const L_KILLER := 8
const L_FURNITURE := 16   # lockers
const L_BUSH := 32        # bush areas
const LOS_MASK := L_WORLD | L_DOOR | L_FURNITURE
const MOVE_MASK := L_WORLD | L_DOOR | L_FURNITURE

static var _current: GameParams

@export_group("World")
@export var map_size_gu := Vector2(30, 24)
@export var min_spawn_distance_gu := 10.0
## 0 = random seed every run. Can be overridden with `-- --seed=N`.
@export var rng_seed := 0
## Debug only: skip the 30 s preparation. Can be enabled with `-- --skip-prep`.
@export var skip_prepare := false
@export var prepare_time := 30.0

@export_group("Movement")
@export var walk_speed := 4.0
@export var sprint_speed := 5.2
@export var careful_speed := 2.2
@export var killer_speed := 4.6
@export var survivor_radius := 0.3
@export var killer_radius := 0.32
@export var killer_turn_rate_deg := 540.0
@export var camera_view_width_gu := 18.0

@export_group("Stamina")
@export var stamina_sprint_drain := 0.20     # fraction per second
@export var stamina_regen_delay := 2.0
@export var stamina_regen_rate := 0.10       # fraction per second
@export var stamina_sprint_restart := 0.20   # needed after full depletion

@export_group("Vision")
@export var vision_fov_deg := 110.0
@export var vision_range_night := 5.0
@export var vision_range_lit := 8.0
@export var night_mode := true
@export var silhouette_offset := 0.25
@export var bush_detect_distance := 2.0
@export var bush_detect_time := 0.6
@export var peek_fov_deg := 60.0
@export var peek_range := 4.0
@export var peek_transition := 0.25
@export var visibility_ray_count := 96
@export var los_edge_epsilon_px := 6.0

@export_group("Fog of war")
@export var fog_cell_size := 0.5
@export var fog_update_hz := 15.0
@export var fog_explored_alpha := 0.55

@export_group("Sound")
@export var footstep_radius_walk := 3.0
@export var footstep_radius_sprint := 4.5
@export var footstep_radius_careful := 1.3
@export var footstep_radius_killer := 3.0
@export var footstep_interval_walk := 0.4
@export var footstep_interval_sprint := 0.3
@export var footstep_interval_careful := 0.5
@export var footstep_interval_killer := 0.4
@export var impact_radius := 9.0
@export var door_open_radius := 5.0
@export var foliage_radius := 4.0
@export var foliage_cooldown := 0.8
@export var approx_region_radius := 2.0
## Max offset of the reported region centre from the true source, as a fraction of the radius.
@export var approx_region_offset_ratio := 0.75
@export var hud_footsteps_hold := 0.4

@export_group("AI")
@export var patrol_wait := 0.6
@export var arrive_distance := 0.4
@export var last_seen_timeout := 10.0
@export var investigate_look_time := 2.0
@export var investigate_timeout := 12.0
@export var search_duration := 12.0
@export var search_radius := 3.5
@export var search_look_time := 1.2
@export var footsteps_search_radius := 2.5
@export var footsteps_fresh_window := 0.5
@export var sound_fresh_window := 1.0
@export var sound_recheck_cooldown := 4.0
@export var sound_same_area_radius := 3.0
@export var locker_check_chance := 0.6
@export var repath_interval := 0.25
@export var stuck_time := 0.9

@export_group("Attack")
@export var attack_range := 0.65
@export var attack_telegraph := 0.35
@export var attack_cooldown := 1.2
@export var hits_to_down := 1

@export_group("Interaction")
@export var interact_range := 1.2
@export var stone_pickup_time := 0.4
@export var door_toggle_time := 0.3
@export var locker_enter_exit_time := 0.6
@export var stone_speed := 10.0
@export var stone_max_range := 7.0
@export var inventory_slots := 2


static func current() -> GameParams:
	if _current == null:
		if ResourceLoader.exists(PARAMS_PATH):
			_current = load(PARAMS_PATH) as GameParams
		if _current == null:
			_current = GameParams.new()
	return _current


static func set_current(p: GameParams) -> void:
	_current = p


static func gu(v: float) -> float:
	return v * PX_PER_GU


func vision_range() -> float:
	return vision_range_night if night_mode else vision_range_lit


func map_size_px() -> Vector2:
	return map_size_gu * PX_PER_GU
