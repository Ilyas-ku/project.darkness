class_name SurvivorController
extends CharacterBody2D
## Player-controlled survivor: WASD movement, mouse look, sprint/careful gaits,
## contextual E interactions (timed; some must be held), stone throwing, locker
## hiding and peeking, window vaulting, wounds with blood traces.

signal hurt

const MODE_IDLE := &"idle"
const MODE_WALK := &"walk"
const MODE_SPRINT := &"sprint"
const MODE_CAREFUL := &"careful"
const BLOOD_SCENE := preload("res://scenes/world/blood_decal.tscn")

@onready var vision: VisionSensor = $VisionSensor
@onready var hearing: HearingSensor = $HearingSensor
@onready var inventory: Inventory = $Inventory
@onready var health: HealthComponent = $HealthComponent
@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D

var params: GameParams
var stamina: Stamina
var facing := Vector2.RIGHT
var movement_mode: StringName = MODE_IDLE
var input_enabled := true
var current_locker: Node = null
var focus: Node = null

var _shape: CollisionShape2D
var _bush_overlaps := 0
var _step_timer := 0.0
var _peek_hold := 0.0
var _blood_timer := 0.0
## Active timed interaction: {target, left, total, hold, from?, to?}
var _channel := {}
## Optional input override for automated tests:
## {move: Vector2, sprint: bool, careful: bool, aim: Vector2, peek: bool, interact_held: bool}
var scripted_input: Variant = null


func _ready() -> void:
	params = GameParams.current()
	stamina = Stamina.new(params)
	add_to_group(&"survivor_perceivable")
	add_to_group(&"survivor")
	collision_layer = GameParams.L_SURVIVOR
	collision_mask = GameParams.MOVE_MASK
	_shape = CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = GameParams.gu(params.survivor_radius)
	_shape.shape = c
	add_child(_shape)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	visual.radius_gu = params.survivor_radius
	_restore_vision()
	var map_px := params.map_size_px()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_px.x)
	camera.limit_bottom = int(map_px.y)
	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var z := vw / GameParams.gu(params.camera_view_width_gu)
	camera.zoom = Vector2(z, z)
	health.state_changed.connect(_on_health_changed)


# --- Perception interface (read by VisionSensor of others) -------------------

func get_perception_points() -> PackedVector2Array:
	if current_locker != null:
		if current_locker.is_peeking():
			return PackedVector2Array([current_locker.get_peek_origin()])
		return PackedVector2Array()
	var c := global_position
	var o := GameParams.gu(params.silhouette_offset)
	return PackedVector2Array([c, c + Vector2(o, 0), c - Vector2(o, 0), c + Vector2(0, o), c - Vector2(0, o)])


func is_concealed() -> bool:
	return current_locker == null and _bush_overlaps > 0


func is_peeking_from_hiding() -> bool:
	return current_locker != null


func is_downed() -> bool:
	return health.is_down()


func get_eye_position() -> Vector2:
	if current_locker != null:
		return current_locker.get_peek_origin()
	return global_position


func get_facing() -> Vector2:
	return facing


func get_movement_mode() -> StringName:
	return movement_mode


func bush_entered() -> void:
	_bush_overlaps += 1


func bush_exited() -> void:
	_bush_overlaps = maxi(0, _bush_overlaps - 1)


# --- Movement ----------------------------------------------------------------

static func speed_for_mode(mode: StringName, p: GameParams) -> float:
	match mode:
		MODE_SPRINT:
			return p.sprint_speed
		MODE_CAREFUL:
			return p.careful_speed
		MODE_WALK:
			return p.walk_speed
	return 0.0


## Normalized input: diagonal is never faster than straight movement.
static func compute_velocity(input: Vector2, mode: StringName, p: GameParams) -> Vector2:
	if input.length_squared() < 0.0001:
		return Vector2.ZERO
	return input.normalized() * GameParams.gu(speed_for_mode(mode, p))


static func footstep_radius(mode: StringName, p: GameParams) -> float:
	match mode:
		MODE_SPRINT:
			return p.footstep_radius_sprint
		MODE_CAREFUL:
			return p.footstep_radius_careful
	return p.footstep_radius_walk


static func footstep_interval(mode: StringName, p: GameParams) -> float:
	match mode:
		MODE_SPRINT:
			return p.footstep_interval_sprint
		MODE_CAREFUL:
			return p.footstep_interval_careful
	return p.footstep_interval_walk


func _read_input() -> Dictionary:
	if scripted_input != null:
		return scripted_input
	return {
		"move": Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"),
		"sprint": Input.is_action_pressed(&"sprint"),
		"careful": Input.is_action_pressed(&"careful"),
		"aim": get_global_mouse_position(),
		"peek": Input.is_action_pressed(&"peek"),
		"interact_held": Input.is_action_pressed(&"interact"),
	}


func _physics_process(delta: float) -> void:
	movement_mode = MODE_IDLE
	if not input_enabled or health.is_down():
		velocity = Vector2.ZERO
		stamina.update(delta, false)
		focus = null
		return
	var inp := _read_input()
	if current_locker == null and _channel.get("to") == null:
		var aim: Vector2 = inp.get("aim", global_position + facing)
		if aim.distance_squared_to(global_position) > 1.0:
			facing = (aim - global_position).normalized()
	if not _channel.is_empty():
		stamina.update(delta, false)
		_process_channel(delta, inp.get("interact_held", true))
		return
	if current_locker != null:
		stamina.update(delta, false)
		_process_peek(delta, inp.get("peek", false))
		focus = current_locker
		return
	var move: Vector2 = inp.get("move", Vector2.ZERO)
	var moving := move.length_squared() > 0.0001
	var careful: bool = inp.get("careful", false)
	var sprinting: bool = moving and inp.get("sprint", false) and not careful and stamina.can_sprint()
	if moving:
		movement_mode = MODE_CAREFUL if careful else (MODE_SPRINT if sprinting else MODE_WALK)
	stamina.update(delta, sprinting)
	velocity = compute_velocity(move, movement_mode, params)
	move_and_slide()
	if moving and get_real_velocity().length() > 1.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			SoundEventBus.emit(&"footsteps", global_position, footstep_radius(movement_mode, params), get_instance_id())
			_step_timer = footstep_interval(movement_mode, params)
		if health.state == HealthComponent.HState.WOUNDED:
			_blood_timer -= delta
			if _blood_timer <= 0.0:
				_drop_blood()
				_blood_timer = params.blood_interval
	else:
		movement_mode = MODE_IDLE
		_step_timer = 0.0
	focus = Interactable.find_best(self, inp.get("aim", global_position))


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or scripted_input != null or health.is_down():
		return
	if event.is_action_pressed(&"interact"):
		try_interact()
	elif event.is_action_pressed(&"throw"):
		try_throw(get_global_mouse_position())
	elif event.is_action_pressed(&"slot_1"):
		inventory.select(0)
	elif event.is_action_pressed(&"slot_2"):
		inventory.select(1)
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		inventory.select((inventory.selected + 1) % inventory.slots.size())


# --- Interactions ------------------------------------------------------------

func try_interact() -> bool:
	if not _channel.is_empty() or health.is_down():
		return false
	var target: Node = current_locker if current_locker != null else focus
	if target == null or not target.can_interact(self):
		return false
	if target.has_method(&"can_start") and not target.can_start(self):
		return false
	var d: float = target.get_interact_duration(self)
	_channel = {"target": target, "left": d, "total": d, "hold": target.has_method(&"requires_hold") and target.requires_hold()}
	if target.is_in_group(&"window"):
		var plan: Dictionary = target.plan_vault(self, GameParams.gu(params.survivor_radius))
		_channel["from"] = global_position
		_channel["to"] = plan.to
		_shape.set_deferred(&"disabled", true)
	if target.has_method(&"on_channel_started"):
		target.on_channel_started(self)
	if current_locker != null:
		current_locker.set_peeking(false)
		_peek_hold = 0.0
	return true


func _process_channel(delta: float, held: bool) -> void:
	velocity = Vector2.ZERO
	var target: Node = _channel.target
	if _channel.hold and not held:
		cancel_channel("released E")
		return
	_channel.left -= delta
	if _channel.has("to"):
		var k := 1.0 - clampf(_channel.left / _channel.total, 0.0, 1.0)
		global_position = _channel.from.lerp(_channel.to, k)
	if _channel.left > 0.0:
		return
	var ch := _channel
	_channel = {}
	if ch.has("to"):
		global_position = ch.to
		_shape.set_deferred(&"disabled", false)
		if is_instance_valid(target):
			target.on_vaulted(self)
		return
	if is_instance_valid(target) and target.can_interact(self):
		target.interact(self)


## Interrupts the current timed action (release, hit, ...). Progress is lost.
func cancel_channel(reason: String) -> void:
	if _channel.is_empty():
		return
	var ch := _channel
	_channel = {}
	if ch.has("to"):
		# An interrupted vault returns the survivor to the side it started from.
		global_position = ch.from
		_shape.set_deferred(&"disabled", false)
	if is_instance_valid(ch.target) and ch.target.has_method(&"on_channel_cancelled"):
		ch.target.on_channel_cancelled(self, reason)


func get_channel_target() -> Node:
	return _channel.get("target", null)


func get_channel_progress() -> float:
	if _channel.is_empty():
		return -1.0
	return 1.0 - _channel.left / maxf(_channel.total, 0.001)


func get_focus_hint() -> String:
	if not _channel.is_empty() or health.is_down():
		return ""
	var target: Node = current_locker if current_locker != null else focus
	if target == null or not is_instance_valid(target):
		return ""
	return target.get_interact_hint(self)


func start_vault(_window: Node) -> void:
	pass  # vaulting is handled as a channel with motion (see try_interact)


func try_throw(target_point: Vector2) -> bool:
	if current_locker != null or not _channel.is_empty() or not input_enabled or health.is_down():
		return false
	var item: Node = inventory.take_selected()
	if item == null:
		return false
	item.throw_from(global_position, target_point, get_instance_id())
	return true


# --- Health ------------------------------------------------------------------

func _on_health_changed(_old: int, new_state: int) -> void:
	cancel_channel("hit")
	hurt.emit()
	_drop_blood()
	_blood_timer = params.blood_interval
	if new_state == HealthComponent.HState.DOWNED or new_state == HealthComponent.HState.DEAD:
		velocity = Vector2.ZERO


func _drop_blood() -> void:
	var b: Node2D = BLOOD_SCENE.instantiate()
	b.position = global_position
	get_parent().add_child(b)


# --- Locker ------------------------------------------------------------------

func enter_locker(locker: Node) -> void:
	current_locker = locker
	global_position = locker.global_position
	_shape.set_deferred(&"disabled", true)
	visual.visible = false
	velocity = Vector2.ZERO
	facing = locker.get_facing()
	vision.enabled = false
	_peek_hold = 0.0


func exit_locker() -> void:
	if current_locker == null:
		return
	var locker := current_locker
	current_locker = null
	_channel = {}
	locker.set_peeking(false)
	global_position = locker.get_exit_position()
	_shape.set_deferred(&"disabled", false)
	visual.visible = true
	_restore_vision()


func _process_peek(delta: float, want_peek: bool) -> void:
	if want_peek:
		_peek_hold += delta
		if _peek_hold >= params.peek_transition and not current_locker.is_peeking():
			current_locker.set_peeking(true)
			vision.enabled = true
			vision.fov_deg = params.peek_fov_deg
			vision.base_range_gu = params.peek_range
	else:
		_peek_hold = 0.0
		if current_locker.is_peeking():
			current_locker.set_peeking(false)
			vision.enabled = false


func _restore_vision() -> void:
	vision.enabled = true
	vision.fov_deg = params.vision_fov_deg
	vision.base_range_gu = params.vision_range()
