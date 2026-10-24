extends Area2D
## Dense bush: passable, visual cover for whoever is inside (VisionSensor applies
## the movement-based visibility multipliers). Rustle events come from the moving
## actor's FootstepEmitter; the bush only animates in sync with them.

@export var radius_gu := 1.0

var _sprite: Sprite2D
var _rustle := 0.0


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
	var tex := "sprites/bush_%s.png" % ["a", "b"][Art.variant(global_position, 2)]
	var size := Vector2.ONE * GameParams.gu(radius_gu) * 2.0   # drawing == cover zone == collider
	# base layer under the characters, dense top foliage over them
	var base := Art.sprite(self, tex, 0, size)
	base.z_as_relative = false
	base.z_index = 3
	base.modulate = Color(0.55, 0.62, 0.55)
	base.rotation = float(Art.variant(global_position, 628)) * 0.01
	_sprite = Art.sprite(self, tex, 0, size * 0.96)
	_sprite.z_as_relative = false
	_sprite.z_index = 8
	_sprite.rotation = base.rotation + 0.7
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(b: Node) -> void:
	if b.has_method(&"bush_entered"):
		b.bush_entered()


func _on_body_exited(b: Node) -> void:
	if b.has_method(&"bush_exited"):
		b.bush_exited()


func contains_point(p: Vector2) -> bool:
	return global_position.distance_to(p) <= GameParams.gu(radius_gu)


## Leaves move only on a real rustle event (synchronised with the sound).
func shake(mode: StringName) -> void:
	_rustle = {&"careful": 0.25, &"walk": 0.4, &"sprint": 0.55}.get(mode, 0.4)


## The top foliage thins out over the player's own character and over a character
## the player actually sees, so leaves never hide what the logic says is visible.
var reveal := false


func _physics_process(delta: float) -> void:
	var occupied := false
	for b in get_overlapping_bodies():
		if b.is_in_group(&"survivor"):
			occupied = true
	_sprite.modulate.a = 0.5 if occupied or reveal else 0.92
	if _rustle > 0.0:
		_rustle -= delta
		_sprite.rotation += sin(_rustle * 40.0) * 0.004
