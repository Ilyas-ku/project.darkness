class_name AudioDirector
extends Node
## Plays sounds without leaking hidden information:
## - the survivor's own actions: positional at the true spot (own knowledge);
## - sounds the survivor HEARS: localizable ones at the approximate region
##   centre from the sanitized observation; footsteps of others are a neutral,
##   non-positional, fixed-volume step (no direction, no distance);
## - combat: the survivor's own hits; ambience loop.

const STREAMS := {
	&"step": ["audio/step_grass_0.wav", "audio/step_grass_1.wav", "audio/step_grass_2.wav"],
	&"impact": ["audio/stone_impact.wav"],
	&"glass": ["audio/glass_break.wav"],
	&"door": ["audio/door_creak.wav"],
	&"window": ["audio/window_vault.wav"],
	&"gate": ["audio/gate_open.wav"],
	&"furniture": ["audio/furniture.wav"],
	&"foliage": ["audio/step_grass_2.wav"],
	&"hit": ["audio/attack_hit.wav"],
	&"swing": ["audio/attack_swing.wav"],
	&"locker": ["audio/locker.wav"],
}

var session: Node
var _rng := RandomNumberGenerator.new()
var _ambience: AudioStreamPlayer
var _radio_players := {}


func setup(s: Node) -> void:
	session = s
	var bus := SoundEventBus.instance()
	if bus != null:
		bus.sound_emitted.connect(_on_world_sound)
	session.survivor.hearing.heard.connect(_on_heard)
	session.survivor.health.state_changed.connect(func(_o, _n): _play2d(&"hit", session.survivor.global_position, -2.0))
	session.exit_gate.opened.connect(func(): _play2d(&"gate", session.exit_gate.global_position, 0.0))
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = _loop(Art.tex_audio("audio/night_ambience.wav"))
	_ambience.volume_db = -14.0
	add_child(_ambience)
	_ambience.play()
	for r in get_tree().get_nodes_in_group(&"radio"):
		var p := AudioStreamPlayer2D.new()
		p.stream = _loop(Art.tex_audio("audio/radio_loop.wav"))
		p.volume_db = -6.0
		p.max_distance = GameParams.gu(GameParams.current().radio_radius)
		r.add_child(p)
		_radio_players[r] = p


func _exit_tree() -> void:
	for c in get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer2D:
			c.stop()
			c.stream = null


func _loop(st: AudioStream) -> AudioStream:
	if st is AudioStreamWAV:
		var w := (st as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = w.data.size() / 2
		return w
	return st


func _process(_delta: float) -> void:
	for r in _radio_players:
		if not is_instance_valid(r):
			continue
		var p: AudioStreamPlayer2D = _radio_players[r]
		if r.is_on and not p.playing:
			p.play()
		elif not r.is_on and p.playing:
			p.stop()


func _stream(kind: StringName) -> AudioStream:
	var list: Array = STREAMS.get(kind, [])
	if list.is_empty():
		return null
	return Art.tex_audio(list[_rng.randi_range(0, list.size() - 1)])


func _play2d(kind: StringName, pos: Vector2, db: float) -> void:
	var st := _stream(kind)
	if st == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = _rng.randf_range(0.92, 1.08)
	p.max_distance = GameParams.gu(14.0)
	p.global_position = pos
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _play_flat(kind: StringName, db: float) -> void:
	var st := _stream(kind)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = _rng.randf_range(0.9, 1.05)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Sounds made by the survivor itself.
func _on_world_sound(ev: SoundEventBus.SoundEvent) -> void:
	if ev.emitter_id != session.survivor.get_instance_id():
		return
	var kind := ev.kind
	if kind == &"footsteps":
		_play2d(&"step", ev.source_world_position, -16.0 if session.survivor.movement_mode == &"careful" else -9.0)
	elif kind != &"gate":
		_play2d(kind, ev.source_world_position, -3.0)


## Sounds heard from others (already sanitized).
func _on_heard(obs: Observation.HeardObservation) -> void:
	if obs.kind == &"footsteps":
		_play_flat(&"step", -15.0)
	elif obs.kind == &"radio":
		pass  # the radio player itself is positional at the known radio
	elif obs.is_localizable():
		_play2d(obs.kind, obs.region_center(), -4.0)
