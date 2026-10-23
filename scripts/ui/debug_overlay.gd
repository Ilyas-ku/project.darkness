extends Node2D
## F3 developer overlay: killer view sector, LOS rays to the survivor, FSM state,
## last seen position, investigated sound region, search area, navigation path,
## observation counters and transition reasons. Hidden by default.

var session: Node
var _label: Label
var _layer: CanvasLayer


func setup(s: Node) -> void:
	session = s
	z_index = 100
	visible = false
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 48)
	panel.modulate = Color(1, 1, 1, 0.85)
	_layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 12)
	panel.add_child(_label)
	visibility_changed.connect(func(): _layer.visible = visible)
	_layer.visible = false


func _process(_delta: float) -> void:
	if not visible or session == null:
		return
	queue_redraw()
	var lines: Array[String] = []
	lines.append("DEBUG (F3)   seed=%d   FPS=%d" % [session.seed_used, Engine.get_frames_per_second()])
	lines.append("phase=%s  prepare=%.1f  t=%.1f" % [GameSession.Phase.keys()[session.phase], session.prepare_left, session.active_time])
	var sv: SurvivorController = session.survivor
	lines.append("survivor mode=%s stamina=%.2f concealed=%s locker=%s" % [sv.movement_mode, sv.stamina.value, sv.is_concealed(), sv.current_locker != null])
	var k: KillerMotor = session.killer
	if k == null:
		lines.append("killer: absent (PREPARE)")
	else:
		var info: Dictionary = k.brain.get_debug_info()
		lines.append("FSM=%s (%.1fs)  visual=%s" % [info.state, info.state_time, info.has_visual])
		lines.append("last_seen=%s @%.1f" % [str((info.last_seen / GameParams.PX_PER_GU).snapped(Vector2(0.1, 0.1))) if info.has_last_seen else "-", info.last_seen_time])
		lines.append("observations=%d heard=%d ignored_sounds=%d" % [info.observations, info.heard, info.ignored_sounds])
		lines.append("transitions:")
		for l in info.log:
			lines.append("  " + l)
	_label.text = "\n".join(lines)


func _draw() -> void:
	if session == null:
		return
	var k: KillerMotor = session.killer
	if k == null:
		return
	var v: VisionSensor = k.vision
	var eye := v.get_eye_position()
	var r := v.effective_range_px()
	var half := deg_to_rad(v.fov_deg) * 0.5
	var a0 := k.facing.angle() - half
	var sector := PackedVector2Array([eye])
	for i in 25:
		sector.append(eye + Vector2.from_angle(a0 + 2.0 * half * i / 24.0) * r)
	draw_colored_polygon(sector, Color(1, 0.2, 0.2, 0.12))
	draw_polyline(sector + PackedVector2Array([eye]), Color(1, 0.3, 0.3, 0.6), 1.0)
	# LOS rays to the survivor silhouette points (debug only)
	for p in session.survivor.get_perception_points():
		var in_sector := VisionSensor.is_in_sector(eye, k.facing, v.fov_deg, r, p)
		var clear := v.has_line_of_sight(eye, p)
		var col := Color(0.2, 1, 0.2, 0.8) if in_sector and clear else (Color(1, 0.6, 0.1, 0.5) if clear else Color(0.6, 0.6, 0.6, 0.3))
		draw_line(eye, p, col, 1.0)
	var info: Dictionary = k.brain.get_debug_info()
	if info.has_last_seen:
		var ls: Vector2 = info.last_seen
		draw_circle(ls, 5, Color(1, 1, 0, 0.9))
		draw_string(ThemeDB.fallback_font, ls + Vector2(6, -6), "last seen", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 0))
	if info.investigate_region != null:
		draw_arc(info.investigate_region.center, info.investigate_region.radius, 0, TAU, 32, Color(0.3, 0.7, 1, 0.9), 1.5)
	if info.search_center != null:
		draw_arc(info.search_center, info.search_radius, 0, TAU, 32, Color(1, 0.5, 1, 0.8), 1.5)
	var path: PackedVector2Array = k.get_current_path()
	if path.size() >= 2:
		draw_polyline(path, Color(0.4, 1, 1, 0.8), 1.5)
