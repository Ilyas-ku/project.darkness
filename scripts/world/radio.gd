extends Node2D
## Radio on the living-room table: E toggles it. While on, it is a continuous
## localizable sound source ("radio") for distraction. The killer may switch it
## off when it reaches it (KillerBrain, during INVESTIGATE_SOUND).

var is_on := false
var _timer := 0.0
var _phase := 0.0


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"radio")
	z_index = 5


func get_perception_points() -> PackedVector2Array:
	return PackedVector2Array([global_position])


func set_on(v: bool, actor: Node = null) -> void:
	is_on = v
	_timer = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_on:
		return
	_timer -= delta
	_phase += delta
	if _timer <= 0.0:
		_timer = GameParams.current().radio_interval
		SoundEventBus.emit(&"radio", global_position, GameParams.current().radio_radius, get_instance_id())
	queue_redraw()


# --- Interactable ------------------------------------------------------------

func get_interact_position() -> Vector2:
	return global_position


func can_interact(_actor: Node) -> bool:
	return true


func get_interact_duration(_actor: Node) -> float:
	return 0.3


func get_interact_hint(_actor: Node) -> String:
	return "E — выключить радио" if is_on else "E — включить радио"


func interact(actor: Node) -> void:
	set_on(not is_on, actor)


func _draw() -> void:
	draw_texture_rect(Art.tex("sprites/radio.png"), Rect2(-7.5, -5, 15, 10), false)
	if is_on:
		draw_rect(Rect2(1, -2.5, 5, 3), Color(1.0, 0.8, 0.4))
		var k := fmod(_phase, 1.0)
		draw_arc(Vector2.ZERO, 8 + k * 10, 0, TAU, 20, Color(0.9, 0.8, 0.4, 0.5 * (1.0 - k)), 1.0)
