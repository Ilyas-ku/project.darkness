extends CanvasLayer
## Normal HUD: health, stamina, two inventory slots, context hint with a key cap,
## preparation/hunt timer, exit progress and a neutral footsteps pulse (no
## direction, no count, no role). Also hosts the pause menu, the result screen,
## the F2 debug-preset menu and the damage vignette.

signal footsteps_indicator_changed(shown: bool)

const PANEL_BG := Color(0.05, 0.07, 0.08, 0.78)
const ACCENT := Color(0.93, 0.82, 0.55)
const TEXT := Color(0.88, 0.9, 0.86)

var session: Node

var _timer_label: Label
var _stamina_bar: ProgressBar
var _health_pips: Array[Panel] = []
var _health_label: Label
var _slots: Array[Panel] = []
var _slot_icons: Array[TextureRect] = []
var _hint_panel: PanelContainer
var _hint_key: Label
var _hint_label: Label
var _progress_panel: PanelContainer
var _progress_label: Label
var _progress: ProgressBar
var _status_label: Label
var _instruction: Label
var _vignette: ColorRect
var _pause_panel: PanelContainer
var _result_panel: PanelContainer
var _result_title: Label
var _result_text: Label
var _debug_menu: PanelContainer
var _steps_shown := false
var _hurt := 0.0


func setup(s: Node) -> void:
	session = s
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	session.survivor.inventory.changed.connect(_refresh_inventory)
	session.survivor.hurt.connect(func(): _hurt = 1.0)
	_refresh_inventory()


# --- construction -------------------------------------------------------------

static func _style(bg: Color, border: Color = Color(1, 1, 1, 0.08), radius := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	return sb


## Anchors c to a point of the screen (ax, ay in 0..1) with a pixel offset; the
## control grows away from the screen edge it is attached to.
static func _anchor(c: Control, ax: float, ay: float, ox: float, oy: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = Control.GROW_DIRECTION_END if ax < 0.25 else (Control.GROW_DIRECTION_BEGIN if ax > 0.75 else Control.GROW_DIRECTION_BOTH)
	c.grow_vertical = Control.GROW_DIRECTION_END if ay < 0.25 else (Control.GROW_DIRECTION_BEGIN if ay > 0.75 else Control.GROW_DIRECTION_BOTH)


func _panel_container(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", _style(PANEL_BG))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _label(parent: Node, text := "", size := 16, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override(&"shadow_offset_y", 1)
	parent.add_child(l)
	return l


func _icon(parent: Node, path: String, size := 22, tint := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.tex(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = tint
	parent.add_child(t)
	return t


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(0.45, 0.0, 0.02, smoothstep(0.35, 0.75, d) * strength);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_vignette.material = mat
	root.add_child(_vignette)

	# top centre: timer
	var top := _panel_container(root)
	_anchor(top, 0.5, 0.0, 0, 10)
	top.custom_minimum_size = Vector2(180, 0)
	_timer_label = _label(top, "", 18, ACCENT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_instruction = _label(root, "", 13, Color(0.75, 0.86, 1.0))
	_anchor(_instruction, 0.0, 0.0, 16, 58)
	_instruction.custom_minimum_size = Vector2(640, 0)
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD

	# bottom left: health + stamina
	var vitals := _panel_container(root)
	_anchor(vitals, 0.0, 1.0, 14, -14)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 6)
	vitals.add_child(vbox)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override(&"separation", 6)
	vbox.add_child(hrow)
	_icon(hrow, "ui/icon_heart.png", 20, Color(0.9, 0.35, 0.35))
	for i in 3:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(26, 10)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hrow.add_child(pip)
		_health_pips.append(pip)
	_health_label = _label(hrow, "", 13)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override(&"separation", 6)
	vbox.add_child(srow)
	_icon(srow, "ui/icon_stamina.png", 20, Color(0.65, 0.85, 1.0))
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(170, 10)
	_stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stamina_bar.max_value = 1.0
	_stamina_bar.show_percentage = false
	_stamina_bar.add_theme_stylebox_override(&"background", _style(Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.1), 4))
	_stamina_bar.add_theme_stylebox_override(&"fill", _style(Color(0.55, 0.78, 0.95), Color(0, 0, 0, 0), 4))
	srow.add_child(_stamina_bar)

	# bottom right: two inventory slots
	var inv := HBoxContainer.new()
	_anchor(inv, 1.0, 1.0, -14, -14)
	inv.add_theme_constant_override(&"separation", 8)
	inv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inv)
	for i in 2:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(62, 62)
		inv.add_child(slot)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(11, 9)
		icon.size = Vector2(40, 40)
		slot.add_child(icon)
		var n := _label(slot, str(i + 1), 11, Color(1, 1, 1, 0.6))
		n.position = Vector2(5, 2)
		_slots.append(slot)
		_slot_icons.append(icon)

	# bottom centre: footsteps pulse, status, progress, hint
	var center := VBoxContainer.new()
	_anchor(center, 0.5, 1.0, 0, -14)
	center.custom_minimum_size = Vector2(360, 0)
	center.alignment = BoxContainer.ALIGNMENT_END
	center.add_theme_constant_override(&"separation", 6)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_status_label = _label(center, "", 14, Color(0.8, 0.85, 0.95))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_panel = _panel_container(center)
	var pv := VBoxContainer.new()
	_progress_panel.add_child(pv)
	var prow := HBoxContainer.new()
	pv.add_child(prow)
	_icon(prow, "ui/icon_gate.png", 18, ACCENT)
	_progress_label = _label(prow, "", 14, ACCENT)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(320, 10)
	_progress.add_theme_stylebox_override(&"background", _style(Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.1), 4))
	_progress.add_theme_stylebox_override(&"fill", _style(ACCENT, Color(0, 0, 0, 0), 4))
	pv.add_child(_progress)
	_hint_panel = _panel_container(center)
	var hrow2 := HBoxContainer.new()
	hrow2.alignment = BoxContainer.ALIGNMENT_CENTER
	hrow2.add_theme_constant_override(&"separation", 8)
	_hint_panel.add_child(hrow2)
	var key := PanelContainer.new()
	key.add_theme_stylebox_override(&"panel", _style(Color(0.9, 0.88, 0.8), Color(0, 0, 0, 0.3), 4))
	hrow2.add_child(key)
	_hint_key = _label(key, "E", 14, Color(0.1, 0.1, 0.1))
	_hint_label = _label(hrow2, "", 15)

	_build_debug_menu(root)
	_pause_panel = _modal(root, "ПАУЗА", "Esc — продолжить · F2 — debug-пресеты", true)
	_build_settings(_pause_panel.get_child(0))
	_pause_panel.visible = false
	_result_panel = _modal(root, "", "", true)
	var box: VBoxContainer = _result_panel.get_child(0)
	_result_title = box.get_child(0)
	_result_text = box.get_child(1)
	_result_panel.visible = false


func _modal(parent: Control, title: String, text: String, buttons: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", _style(Color(0.04, 0.05, 0.06, 0.92), Color(ACCENT, 0.4), 10))
	p.custom_minimum_size = Vector2(420, 200)
	_anchor(p, 0.5, 0.5, 0, 0)
	parent.add_child(p)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 12)
	p.add_child(box)
	var t := _label(box, title, 34, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := _label(box, text, 16)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if buttons:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", 16)
		box.add_child(row)
		var again := Button.new()
		again.text = "  Повторить (R)  "
		again.pressed.connect(func(): session.restart())
		row.add_child(again)
		var quit := Button.new()
		quit.text = "  Выйти  "
		quit.pressed.connect(func(): session.quit_game())
		row.add_child(quit)
	return p


func _build_debug_menu(root: Control) -> void:
	_debug_menu = PanelContainer.new()
	_debug_menu.add_theme_stylebox_override(&"panel", _style(Color(0.04, 0.05, 0.06, 0.94), Color(0.5, 0.7, 1.0, 0.4), 10))
	_debug_menu.custom_minimum_size = Vector2(500, 0)
	_anchor(_debug_menu, 0.5, 0.5, 0, 0)
	_debug_menu.visible = false
	root.add_child(_debug_menu)
	var box := VBoxContainer.new()
	_debug_menu.add_child(box)
	var t := _label(box, "DEBUG-ПРЕСЕТЫ (F2)", 18, Color(0.7, 0.85, 1.0))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for id in DebugPresets.TITLES:
		var b := Button.new()
		b.text = "%s — %s" % [id, DebugPresets.TITLES[id]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			DebugPresets.active = id
			session.restart())
		box.add_child(b)
	var normal := Button.new()
	normal.text = "Обычная игра"
	normal.pressed.connect(func():
		DebugPresets.active = &""
		session.restart())
	box.add_child(normal)


# --- API used by GameSession / tests ---------------------------------------------

func toggle_debug_menu() -> void:
	_debug_menu.visible = not _debug_menu.visible
	get_tree().paused = _debug_menu.visible or session.is_finished()


func set_instruction(text: String) -> void:
	_instruction.text = ("[%s] " % DebugPresets.active + text) if text != "" else ""


## Footsteps are shown on the map (SoundMarkers); kept for logs and tests.
func flash_footsteps() -> void:
	pass


func is_footsteps_visible() -> bool:
	return session.sound_markers.active_count(&"footsteps") > 0


## Volume sliders per bus and the sound-marker accessibility toggle.
func _build_settings(box: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 12)
	box.add_child(grid)
	var names := {"Master": "Общая громкость", "Footsteps": "Шаги и шорох", "SFX": "Звуки событий", "Ambient": "Фон"}
	for b in names:
		_label(grid, names[b], 13)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(180, 18)
		sl.value = Settings.volumes[b]
		sl.value_changed.connect(func(v): Settings.set_volume(b, v))
		grid.add_child(sl)
	var cb := CheckBox.new()
	cb.text = "Звуковые метки на карте"
	cb.button_pressed = Settings.sound_markers
	cb.toggled.connect(func(on):
		Settings.sound_markers = on
		Settings.save())
	box.add_child(cb)


func set_pause_visible(v: bool) -> void:
	_pause_panel.visible = v


func set_debug_visible(_v: bool) -> void:
	pass


func show_result(escaped: bool) -> void:
	_pause_panel.visible = false
	_result_panel.visible = true
	if escaped:
		_result_title.text = "ESCAPED"
		_result_text.text = "Ворота открыты. Вы выбрались из леса."
	else:
		_result_title.text = "CAUGHT"
		_result_title.add_theme_color_override(&"font_color", Color(0.9, 0.3, 0.3))
		_result_text.text = "Маньяк настиг вас."


func get_result_title() -> String:
	return _result_title.text if _result_panel.visible else ""


func _refresh_inventory() -> void:
	var inv: Inventory = session.survivor.inventory
	for i in _slots.size():
		var item: Node = inv.slots[i] if i < inv.slots.size() else null
		var path := ""
		if item != null:
			path = "sprites/bottle.png" if item.breaks_on_impact else "sprites/stone.png"
		_slot_icons[i].texture = Art.tex(path) if path != "" else null
		var sel := i == inv.selected
		_slots[i].add_theme_stylebox_override(&"panel", _style(PANEL_BG, ACCENT if sel else Color(1, 1, 1, 0.12), 8))


# --- per frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	if session == null:
		return
	var p := GameParams.current()
	if not get_tree().paused:
		_hurt = maxf(0.0, _hurt - delta * 1.5)
	var shown := is_footsteps_visible()
	if shown != _steps_shown:
		_steps_shown = shown
		footsteps_indicator_changed.emit(shown)
	var sv: SurvivorController = session.survivor
	var hs: int = sv.health.state
	_vignette.material.set_shader_parameter(&"strength", clampf(_hurt + (0.35 if hs == HealthComponent.HState.WOUNDED else 0.0) + (0.7 if hs >= HealthComponent.HState.DOWNED else 0.0), 0.0, 1.0))
	for i in 3:
		var alive := 2 - mini(hs, 2)
		var col := Color(0.85, 0.3, 0.3) if i < alive else Color(1, 1, 1, 0.12)
		_health_pips[i].add_theme_stylebox_override(&"panel", _style(col, Color(0, 0, 0, 0.4), 3))
	_health_pips[2].visible = false
	_health_label.text = ["здоров", "ранен", "повален", "мёртв"][hs]
	_stamina_bar.value = sv.stamina.value
	_stamina_bar.modulate = Color(1, 0.55, 0.45) if sv.stamina.is_exhausted() else Color.WHITE
	if session.phase == GameSession.Phase.PREPARE:
		_timer_label.text = "ПОДГОТОВКА  %d" % ceili(session.prepare_left)
	else:
		var t: float = session.active_time
		_timer_label.text = "ОХОТА  %02d:%02d" % [int(t) / 60, int(t) % 60]
	var hint := sv.get_focus_hint()
	_hint_panel.visible = hint != ""
	_hint_label.text = hint.trim_prefix("E — ").trim_prefix("Удерживайте E — ")
	_hint_key.text = "удерж. E" if hint.begins_with("Удерживайте") else "E"
	var pr := sv.get_channel_progress()
	_progress_panel.visible = pr >= 0.0
	if pr >= 0.0:
		_progress.value = pr
		var target: Node = sv.get_channel_target()
		var total: float = p.exit_hold_time if target == session.exit_gate else 0.0
		_progress_label.text = "Открытие выхода  %.1f / %.0f с" % [pr * total, total] if total > 0.0 else "Действие…"
	var status := ""
	if sv.current_locker != null:
		status = "Вы в шкафу" + (" — выглядываете" if sv.current_locker.is_peeking() else " · ПКМ — выглянуть")
	elif hs == HealthComponent.HState.DOWNED:
		status = "Вы повалены"
	_status_label.text = status
