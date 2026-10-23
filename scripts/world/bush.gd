extends Area2D
## Noisy bush: passable, partial cover for whoever is inside. Normal walking or
## sprinting through it emits a "foliage" event (max once per 0.8 s per body);
## careful movement is silent.

@export var radius_gu := 1.0

var _last_noise := {}


func _ready() -> void:
	add_to_group(&"bush")
	collision_layer = GameParams.L_BUSH
	collision_mask = GameParams.L_SURVIVOR | GameParams.L_KILLER
	monitorable = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = GameParams.gu(radius_gu)
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(b: Node) -> void:
	if b.has_method(&"bush_entered"):
		b.bush_entered()


func _on_body_exited(b: Node) -> void:
	if b.has_method(&"bush_exited"):
		b.bush_exited()


func _physics_process(_delta: float) -> void:
	var p := GameParams.current()
	var now := GameClock.now()
	for b in get_overlapping_bodies():
		if not b.has_method(&"get_movement_mode"):
			continue
		var mode: StringName = b.get_movement_mode()
		if mode != &"walk" and mode != &"sprint":
			continue
		var id := b.get_instance_id()
		if now - _last_noise.get(id, -INF) < p.foliage_cooldown:
			continue
		_last_noise[id] = now
		SoundEventBus.emit(&"foliage", b.global_position, p.foliage_radius, id)


func _draw() -> void:
	var r := GameParams.gu(radius_gu)
	draw_circle(Vector2.ZERO, r, Color(0.14, 0.32, 0.12, 0.9))
	for i in 6:
		var a := TAU * i / 6.0
		draw_circle(Vector2.from_angle(a) * r * 0.55, r * 0.42, Color(0.18, 0.4, 0.15, 0.8))
