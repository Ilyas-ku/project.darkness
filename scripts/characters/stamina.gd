class_name Stamina
extends RefCounted
## Sprint resource 0..1. Continuous sprint drains 20%/s; regen starts 2 s after the
## sprint stops at 10%/s. After hitting zero, sprint is locked until 20% is back.

var value := 1.0
var drain_rate := 0.2
var regen_rate := 0.1
var regen_delay := 2.0
var restart_threshold := 0.2

var _delay_left := 0.0
var _exhausted := false


func _init(p: GameParams = null) -> void:
	if p == null:
		p = GameParams.current()
	drain_rate = p.stamina_sprint_drain
	regen_rate = p.stamina_regen_rate
	regen_delay = p.stamina_regen_delay
	restart_threshold = p.stamina_sprint_restart


func can_sprint() -> bool:
	return value > 0.0 and not _exhausted


func is_exhausted() -> bool:
	return _exhausted


## sprinting = the character actually sprinted during this step.
func update(dt: float, sprinting: bool) -> void:
	if sprinting and can_sprint():
		value = maxf(0.0, value - drain_rate * dt)
		_delay_left = regen_delay
		if value <= 0.0:
			_exhausted = true
		return
	if _delay_left > 0.0:
		_delay_left -= dt
		if _delay_left > 0.0:
			return
		dt = -_delay_left
		_delay_left = 0.0
	value = minf(1.0, value + regen_rate * dt)
	if _exhausted and value >= restart_threshold - 0.00001:
		_exhausted = false
