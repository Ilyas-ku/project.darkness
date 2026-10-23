class_name FocusHighlight
extends Node2D
## Soft pulsing ring around the object the E key would act on.

var survivor: Node
var _t := 0.0


func _ready() -> void:
	z_index = 45


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if survivor == null or survivor.current_locker != null or not survivor.input_enabled or survivor.get_channel_target() != null:
		return
	var f: Node = survivor.focus
	if f == null or not is_instance_valid(f):
		return
	var p: Vector2 = f.get_interact_position()
	var r := 9.0 + sin(_t * 5.0) * 1.5
	draw_arc(p, r, 0, TAU, 32, Color(1.0, 0.9, 0.6, 0.75), 1.5)
	draw_arc(p, r + 3, 0, TAU, 32, Color(1.0, 0.9, 0.6, 0.25), 1.0)
