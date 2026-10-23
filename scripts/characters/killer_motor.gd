class_name KillerMotor
extends CharacterBody2D
## Physical body of the killer: NavigationAgent2D path following, turning,
## footsteps, opening closed doors in its way, opening lockers and the melee hit.
## Has no knowledge of the survivor; decisions come from KillerBrain.

signal locker_checked(locker: Node, found: bool)

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var vision: VisionSensor = $VisionSensor
@onready var hearing: HearingSensor = $HearingSensor
@onready var brain: Node = $KillerBrain
@onready var visual: Node2D = $Visual

var params: GameParams
var facing := Vector2.DOWN
var movement_mode: StringName = &"idle"
var stuck := false

var _target := Vector2.ZERO
var _has_target := false
var _repath_left := 0.0
var _look_dir := Vector2.ZERO
## Timed action: {kind: StringName, left: float, object: Node}
var _action := {}
var _step_timer := 0.0
var _stuck_timer := 0.0
var _bush_overlaps := 0


func _ready() -> void:
	params = GameParams.current()
	add_to_group(&"killer_perceivable")
	add_to_group(&"killer")
	collision_layer = GameParams.L_KILLER
	collision_mask = GameParams.MOVE_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = GameParams.gu(params.killer_radius)
	cs.shape = c
	add_child(cs)
	agent.path_desired_distance = GameParams.gu(0.3)
	agent.target_desired_distance = GameParams.gu(params.arrive_distance * 0.75)
	agent.radius = GameParams.gu(params.killer_radius)
	agent.avoidance_enabled = false
	visual.radius_gu = params.killer_radius
	visual.body_color = Color(0.85, 0.15, 0.12)


# --- Perception interface (for the survivor's VisionSensor) --------------------

func get_perception_points() -> PackedVector2Array:
	var c := global_position
	var o := GameParams.gu(params.silhouette_offset)
	return PackedVector2Array([c, c + Vector2(o, 0), c - Vector2(o, 0), c + Vector2(0, o), c - Vector2(0, o)])


func is_concealed() -> bool:
	return _bush_overlaps > 0


func bush_entered() -> void:
	_bush_overlaps += 1


func bush_exited() -> void:
	_bush_overlaps = maxi(0, _bush_overlaps - 1)


func get_eye_position() -> Vector2:
	return global_position


func get_facing() -> Vector2:
	return facing


func get_movement_mode() -> StringName:
	return movement_mode


# --- Commands from the brain ----------------------------------------------------

func move_to(p: Vector2) -> void:
	if _has_target:
		var d := p.distance_to(_target)
		if d < 2.0:
			return
		if _repath_left > 0.0 and d < GameParams.gu(0.5):
			return
	_target = p
	_has_target = true
	_repath_left = params.repath_interval
	_stuck_timer = 0.0
	stuck = false
	agent.target_position = p


func stop() -> void:
	_has_target = false
	velocity = Vector2.ZERO


func has_arrived(tolerance_gu: float = -1.0) -> bool:
	if not _has_target:
		return true
	if tolerance_gu < 0.0:
		tolerance_gu = params.arrive_distance
	return global_position.distance_to(_target) <= GameParams.gu(tolerance_gu) or agent.is_navigation_finished()


func look_towards(dir: Vector2) -> void:
	_look_dir = dir.normalized()


func is_busy() -> bool:
	return not _action.is_empty()


func start_open_locker(locker: Node) -> void:
	stop()
	look_towards(locker.global_position - global_position)
	_action = {"kind": &"locker", "left": params.locker_enter_exit_time, "object": locker}


func get_current_path() -> PackedVector2Array:
	return agent.get_current_navigation_path() if _has_target else PackedVector2Array()


## Melee hit: true if a body with a HealthComponent within attack range and in LOS was hit.
func perform_attack() -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = GameParams.gu(params.attack_range + 0.05)
	q.shape = c
	q.transform = Transform2D(0.0, global_position)
	q.collision_mask = GameParams.L_SURVIVOR
	for r in get_world_2d().direct_space_state.intersect_shape(q, 4):
		var body: Node2D = r.collider
		if body.global_position.distance_to(global_position) > GameParams.gu(params.attack_range):
			continue
		if not vision.has_line_of_sight(global_position, body.global_position):
			continue
		var h := body.get_node_or_null(^"HealthComponent")
		if h != null and h.take_hit(self):
			return true
	return false


# --- Simulation -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	movement_mode = &"idle"
	_repath_left -= delta
	if not _action.is_empty():
		velocity = Vector2.ZERO
		_turn_towards(_look_dir, delta)
		_action.left -= delta
		if _action.left <= 0.0:
			_finish_action()
		return
	var moved := false
	if _has_target and not agent.is_navigation_finished():
		var next := agent.get_next_path_position()
		var to := next - global_position
		if to.length() > 0.5:
			var dir := to.normalized()
			var door := _closed_door_ahead(dir)
			if door != null:
				_look_dir = dir
				_action = {"kind": &"door", "left": params.door_toggle_time, "object": door}
				velocity = Vector2.ZERO
				return
			var before := global_position
			velocity = dir * GameParams.gu(params.killer_speed)
			move_and_slide()
			_turn_towards(dir, delta)
			moved = true
			movement_mode = &"walk"
			if before.distance_to(global_position) < GameParams.gu(params.killer_speed) * delta * 0.25:
				_stuck_timer += delta
				if _stuck_timer >= params.stuck_time:
					stuck = true
			else:
				_stuck_timer = 0.0
	if not moved:
		velocity = Vector2.ZERO
		if _look_dir != Vector2.ZERO:
			_turn_towards(_look_dir, delta)
	if moved:
		_step_timer -= delta
		if _step_timer <= 0.0:
			SoundEventBus.emit(&"footsteps", global_position, params.footstep_radius_killer, get_instance_id())
			_step_timer = params.footstep_interval_killer
	else:
		_step_timer = 0.0


func _turn_towards(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		return
	var max_step := deg_to_rad(params.killer_turn_rate_deg) * delta
	var a := clampf(facing.angle_to(dir), -max_step, max_step)
	facing = facing.rotated(a).normalized()


func _closed_door_ahead(dir: Vector2) -> Node:
	var reach := GameParams.gu(params.killer_radius + 0.45)
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * reach, GameParams.L_DOOR)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var d: Node = hit.collider
	if d.has_method(&"is_open") and not d.is_open():
		return d
	return null


func _finish_action() -> void:
	var a := _action
	_action = {}
	if not is_instance_valid(a.object):
		return
	match a.kind:
		&"door":
			a.object.set_open(true, self)
		&"locker":
			var found: bool = a.object.killer_open(self)
			locker_checked.emit(a.object, found)
