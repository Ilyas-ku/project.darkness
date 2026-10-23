extends Area2D
## Noisy bush: passable, partial cover for whoever is inside. Normal walking or
## sprinting through it emits a "foliage" event (max once per 0.8 s per body);
## careful movement is silent.

@export var radius_gu := 1.0

var _last_noise := {}
var _sprite: Sprite2D
var _rustle := 0.0


func _ready() -> void:
	add_to_group(&"bush")
	collision_layer = GameParams.L_BUSH
	collision_mask = GameParams.L_SURVIVOR | GameParams.L_KILLER
	monitorable = false
	z_index = 7
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = GameParams.gu(radius_gu)
	cs.shape = c
	add_child(cs)
	_sprite = Art.sprite(self, "sprites/bush_%s.png" % ["a", "b"][Art.variant(global_position, 2)], 0,
		Vector2.ONE * GameParams.gu(radius_gu) * 2.15)
	_sprite.rotation = float(Art.variant(global_position, 628)) * 0.01
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(b: Node) -> void:
	if b.has_method(&"bush_entered"):
		b.bush_entered()


func _on_body_exited(b: Node) -> void:
	if b.has_method(&"bush_exited"):
		b.bush_exited()


func _physics_process(delta: float) -> void:
	var p := GameParams.current()
	var now := GameClock.now()
	var occupied := false
	for b in get_overlapping_bodies():
		if b.is_in_group(&"survivor"):
			occupied = true
		if not b.has_method(&"get_movement_mode"):
			continue
		var mode: StringName = b.get_movement_mode()
		if mode != &"walk" and mode != &"sprint":
			continue
		var id := b.get_instance_id()
		if now - _last_noise.get(id, -INF) < p.foliage_cooldown:
			continue
		_last_noise[id] = now
		_rustle = 0.4
		SoundEventBus.emit(&"foliage", b.global_position, p.foliage_radius, id)
	# The survivor inside sees through the leaves; others see a dense bush.
	_sprite.modulate.a = 0.55 if occupied else 1.0
	if _rustle > 0.0:
		_rustle -= delta
		_sprite.rotation += sin(_rustle * 40.0) * 0.004
