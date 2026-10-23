class_name InputSetup
extends RefCounted
## Registers the prototype's input actions at runtime so the project works
## from a clean checkout without editing the InputMap by hand.


static func ensure_actions() -> void:
	_key(&"move_up", KEY_W)
	_key(&"move_down", KEY_S)
	_key(&"move_left", KEY_A)
	_key(&"move_right", KEY_D)
	_key(&"sprint", KEY_SHIFT)
	_key(&"careful", KEY_CTRL)
	_key(&"interact", KEY_E)
	_mouse(&"throw", MOUSE_BUTTON_LEFT)
	_mouse(&"peek", MOUSE_BUTTON_RIGHT)
	_key(&"slot_1", KEY_1)
	_key(&"slot_2", KEY_2)
	_key(&"debug_toggle", KEY_F3)
	_key(&"debug_menu", KEY_F2)
	_key(&"pause", KEY_ESCAPE)
	_key(&"restart", KEY_R)


static func _key(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


static func _mouse(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
