extends Node2D
## Blood trace left by a wounded survivor. A dynamic object: drawn only while in
## the player's LOS; the killer may notice it only through its own VisionSensor.

var created_at := 0.0
var _seed := 0


func _ready() -> void:
	add_to_group(&"evidence")
	add_to_group(&"dynamic_object")
	created_at = GameClock.now()
	_seed = randi()
	z_index = 2


func get_perception_points() -> PackedVector2Array:
	return PackedVector2Array([global_position])


func _physics_process(_delta: float) -> void:
	if GameClock.now() - created_at > GameParams.current().blood_lifetime:
		queue_free()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	for i in 4:
		var p := Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5))
		draw_circle(p, rng.randf_range(1.5, 3.5), Color(0.45, 0.02, 0.03, 0.85))
