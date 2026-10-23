extends CanvasLayer
## Normal HUD: inventory, stamina, context hint, preparation/test timer and the
## unidentified-footsteps signal. No minimap, no killer markers, no directions.
## Also hosts the pause menu and the result screen.

var session: Node

var _timer_label: Label
var _stamina_bar: ProgressBar
var _inventory_label: Label
var _health_label: Label
var _hint_label: Label
var _progress: ProgressBar
var _steps_label: Label
var _status_label: Label
var _pause_panel: PanelContainer
var _result_panel: PanelContainer
var _result_title: Label
var _result_text: Label
var _steps_left := 0.0


func setup(s: Node) -> void:
	session = s
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	session.survivor.inventory.changed.connect(_refresh_inventory)
	_refresh_inventory()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_timer_label = _label(root, Vector2(16, 12), 22)
	_steps_label = _label(root, Vector2(0, 12), 20)
	_steps_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_steps_label.position = Vector2(-80, 12)
	_steps_label.text = "• шаги рядом •"
	_steps_label.modulate = Color(1, 0.85, 0.6, 0)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(16, -120)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	_health_label = Label.new()
	bottom.add_child(_health_label)
	_inventory_label = Label.new()
	bottom.add_child(_inventory_label)
	var st := Label.new()
	st.text = "Выносливость"
	st.add_theme_font_size_override(&"font_size", 12)
	bottom.add_child(st)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(180, 12)
	_stamina_bar.max_value = 1.0
	_stamina_bar.show_percentage = false
	bottom.add_child(_stamina_bar)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	center.position = Vector2(-160, -80)
	center.custom_minimum_size = Vector2(320, 0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_status_label)
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_hint_label)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(320, 8)
	center.add_child(_progress)

	_pause_panel = _panel(root, "ПАУЗА", "Esc — продолжить")
	_add_buttons(_pause_panel.get_child(0))
	_pause_panel.visible = false

	_result_panel = _panel(root, "", "")
	var box: VBoxContainer = _result_panel.get_child(0)
	_result_title = box.get_child(0)
	_result_text = box.get_child(1)
	_add_buttons(box)
	_result_panel.visible = false


func _label(parent: Control, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override(&"font_size", size)
	parent.add_child(l)
	return l


func _panel(parent: Control, title: String, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(380, 180)
	p.position = Vector2(-190, -90)
	parent.add_child(p)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override(&"font_size", 30)
	box.add_child(t)
	var s := Label.new()
	s.text = text
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	return p


func _add_buttons(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var again := Button.new()
	again.text = "Повторить"
	again.pressed.connect(func(): session.restart())
	row.add_child(again)
	var quit := Button.new()
	quit.text = "Выйти"
	quit.pressed.connect(func(): session.quit_game())
	row.add_child(quit)


func _refresh_inventory() -> void:
	var inv: Inventory = session.survivor.inventory
	var parts: Array[String] = []
	for i in inv.slots.size():
		var name := "камень" if inv.slots[i] != null else "—"
		parts.append(("[%d: %s]" if i == inv.selected else " %d: %s ") % [i + 1, name])
	_inventory_label.text = "Инвентарь " + " ".join(parts)


func flash_footsteps() -> void:
	_steps_left = GameParams.current().hud_footsteps_hold


func is_footsteps_visible() -> bool:
	return _steps_left > 0.0


func set_pause_visible(v: bool) -> void:
	_pause_panel.visible = v


func set_debug_visible(_v: bool) -> void:
	pass


func show_result(escaped: bool) -> void:
	_pause_panel.visible = false
	_result_panel.visible = true
	if escaped:
		_result_title.text = "ESCAPED"
		_result_text.text = "Вы добрались до выхода."
	else:
		_result_title.text = "CAUGHT"
		_result_text.text = "Маньяк настиг вас."


func get_result_title() -> String:
	return _result_title.text if _result_panel.visible else ""


func _process(delta: float) -> void:
	if session == null:
		return
	if not get_tree().paused:
		_steps_left = maxf(0.0, _steps_left - delta)
	_steps_label.modulate.a = 1.0 if _steps_left > 0.0 else 0.0
	var sv: SurvivorController = session.survivor
	_stamina_bar.value = sv.stamina.value
	_health_label.text = "Здоровье: " + ["здоров", "ранен", "повален", "мёртв"][sv.health.state]
	_health_label.modulate = [Color.WHITE, Color(1, 0.6, 0.5), Color(1, 0.3, 0.3), Color(1, 0.2, 0.2)][sv.health.state]
	_stamina_bar.modulate = Color(1, 0.5, 0.4) if sv.stamina.is_exhausted() else Color.WHITE
	if session.phase == GameSession.Phase.PREPARE:
		_timer_label.text = "Подготовка: %d" % ceili(session.prepare_left)
	else:
		var t: float = session.active_time
		_timer_label.text = "Время: %02d:%02d" % [int(t) / 60, int(t) % 60]
	_hint_label.text = sv.get_focus_hint()
	var pr := sv.get_channel_progress()
	_progress.visible = pr >= 0.0
	_progress.value = maxf(pr, 0.0)
	var status := ""
	if sv.current_locker != null:
		status = "Вы в шкафу" + (" — выглядываете" if sv.current_locker.is_peeking() else "")
	elif session.phase == GameSession.Phase.PREPARE and session.exit_zone.contains_survivor():
		status = "Выход откроется после появления маньяка"
	_status_label.text = status
