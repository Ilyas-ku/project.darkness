class_name AudioDirector
extends Node
## SpatialAudioPlayer for the survivor (the only human listener).
## - Sounds the survivor HEARS come only from HearingSensor.heard (the single
##   audibility gate shared with the map markers): one positional voice per event
##   at the perceived approximate region (stereo pan follows the side of the map),
##   volume from the acoustic loudness, low-passed bus when heard through walls or
##   from inside a closet. Every actor's steps are separate voices, so two actors
##   give two overlapping rhythms.
## - The survivor's own actions play at the true spot (own knowledge).
## - Buses: Master, Ambient, Footsteps(+Muffled), SFX(+Muffled), UI; volumes from Settings.

const STREAMS := {
	&"step_grass": ["audio/step_grass_0.wav", "audio/step_grass_1.wav", "audio/step_grass_2.wav"],
	&"step_dirt": ["audio/step_dirt_0.wav", "audio/step_dirt_1.wav"],
	&"step_wood": ["audio/step_wood.wav", "audio/step_wood_1.wav"],
	&"foliage": ["audio/rustle_0.wav", "audio/rustle_1.wav", "audio/rustle_2.wav"],
	&"impact": ["audio/stone_impact.wav"],
	&"glass": ["audio/glass_break.wav"],
	&"door": ["audio/door_open.wav"],
	&"door_close": ["audio/door_close.wav"],
	&"window": ["audio/window_vault.wav"],
	&"gate": ["audio/gate_latch.wav"],
	&"gate_open": ["audio/gate_open.wav"],
	&"furniture": ["audio/furniture.wav"],
	&"hit": ["audio/attack_hit.wav"],
	&"wound": ["audio/wound_cry.wav"],
	&"down": ["audio/body_fall.wav"],
	&"swing": ["audio/attack_swing.wav"],
	&"throw": ["audio/throw_whoosh.wav"],
	&"locker": ["audio/locker.wav"],
	&"locker_close": ["audio/locker_close.wav"],
	&"radio": [],
}
## Base level per category (dB at full loudness).
const BASE_DB := {&"footsteps": 0.0, &"foliage": -3.0, &"impact": 0.0, &"glass": 0.0, &"door": -2.0,
	&"door_close": -2.0, &"window": -3.0, &"locker": -3.0, &"locker_close": -3.0, &"furniture": -4.0,
	&"gate": -6.0, &"hit": 0.0, &"swing": -3.0}

## Emitted for every started voice (debug / tests): key, world position, bus.
signal voice_played(key: StringName, pos: Vector2, bus: StringName)

const PAN_GAIN := 3.0

var session: Node
var voices_started := 0
var _rng := RandomNumberGenerator.new()
var _ambience: AudioStreamPlayer
var _radio_players := {}
## Recent step voices as {voice, t}; a voice counts against the limit for VOICE_LIFE s
## (robust even when a driver never reports "finished").
var _step_voices: Array = []
const VOICE_LIFE := 0.6


static func ensure_buses() -> void:
	var p := GameParams.current()
	for spec in [["Ambient", "Master"], ["Footsteps", "Master"], ["FootstepsMuffled", "Footsteps"],
			["SFX", "Master"], ["SFXMuffled", "SFX"], ["UI", "Master"]]:
		if AudioServer.get_bus_index(spec[0]) != -1:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, spec[0])
		AudioServer.set_bus_send(i, spec[1])
		if String(spec[0]).ends_with("Muffled"):
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = p.muffle_cutoff_hz
			AudioServer.add_bus_effect(i, lp)
			AudioServer.set_bus_volume_db(i, -2.0)
	# Limit peaks on the master bus.
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for e in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, e) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		AudioServer.add_bus_effect(master, AudioEffectHardLimiter.new())
	Settings.apply_volumes()


func setup(s: Node) -> void:
	session = s
	ensure_buses()
	var listener := AudioListener2D.new()
	listener.name = &"AudioListener2D"
	session.survivor.add_child(listener)
	listener.make_current()
	var bus := SoundEventBus.instance()
	if bus != null:
		bus.sound_emitted.connect(_on_world_sound)
	session.survivor.hearing.heard.connect(_on_heard)
	session.survivor.health.state_changed.connect(_on_survivor_health)
	session.exit_gate.opened.connect(func(): _voice(&"gate_open", session.exit_gate.global_position, 0.0, "SFX"))
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = _loop(Art.tex_audio("audio/night_ambience.wav"))
	_ambience.volume_db = -14.0
	_ambience.bus = &"Ambient"
	add_child(_ambience)
	_ambience.play()
	for r in get_tree().get_nodes_in_group(&"radio"):
		var p := AudioStreamPlayer2D.new()
		p.stream = _loop(Art.tex_audio("audio/radio_loop.wav"))
		p.volume_db = -6.0
		p.bus = &"SFX"
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
	var now := GameClock.now()
	_step_voices = _step_voices.filter(func(e): return is_instance_valid(e.voice) and now - e.t < VOICE_LIFE)


func _stream(key: StringName) -> AudioStream:
	var list: Array = STREAMS.get(key, [])
	if list.is_empty():
		return null
	return Art.tex_audio(list[_rng.randi_range(0, list.size() - 1)])


func _step_key(surface: StringName) -> StringName:
	match surface:
		&"wood":
			return &"step_wood"
		&"dirt":
			return &"step_dirt"
	return &"step_grass"


## Godot pans 2D voices by on-screen offset, which is small with the zoomed camera;
## widen the horizontal offset so a source on the left is clearly heard on the left.
func _pan_position(world: Vector2) -> Vector2:
	var me: Vector2 = session.survivor.global_position
	return me + Vector2((world.x - me.x) * PAN_GAIN, world.y - me.y)


## One positional voice. Distance attenuation is done by the acoustic model, so the
## player itself is flat (attenuation 0) and only pans.
func _voice(key: StringName, pos: Vector2, db: float, bus: String, pitch_jitter := 0.06) -> AudioStreamPlayer2D:
	var st := _stream(key)
	if st == null:
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = _rng.randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.attenuation = 0.0
	p.max_distance = 100000.0
	p.panning_strength = 1.0
	p.bus = StringName(bus)
	p.global_position = pos
	add_child(p)
	p.finished.connect(p.queue_free)
	# safety net: free the node even if the driver never reports "finished"
	var wr: WeakRef = weakref(p)
	get_tree().create_timer(4.0, false).timeout.connect(func():
		var n: Node = wr.get_ref()
		if n != null:
			n.queue_free())
	p.play()
	voices_started += 1
	voice_played.emit(key, pos, p.bus)
	return p


## Sounds made by the survivor itself (never routed through its own hearing).
func _on_world_sound(ev: SoundEventBus.SoundEvent) -> void:
	if ev.emitter_id != session.survivor.get_instance_id():
		return
	var muffled: bool = session.survivor.is_hidden_in_spot()
	var bus := "SFXMuffled" if muffled else "SFX"
	match ev.kind:
		&"footsteps":
			var db := -12.0 if ev.gait == &"careful" else (-4.0 if ev.gait == &"sprint" else -7.0)
			_voice(_step_key(ev.material), ev.source_world_position, db, "Footsteps")
		&"foliage":
			var db := -14.0 if ev.gait == &"careful" else (-5.0 if ev.gait == &"sprint" else -9.0)
			_voice(&"foliage", ev.source_world_position, db, "Footsteps")
		&"gate":
			pass  # the latch plays on channel start below
		_:
			_voice(ev.kind, ev.source_world_position, BASE_DB.get(ev.kind, -3.0), bus)
	if ev.kind == &"gate":
		_voice(&"gate", ev.source_world_position, -6.0, "SFX")


## Sounds heard from others: the same observation also drives the map marker.
func _on_heard(obs: Observation.HeardObservation) -> void:
	if obs.kind == &"radio":
		return  # the radio's own looped player is positional at the known radio
	var key: StringName = _step_key(obs.surface) if obs.kind == &"footsteps" else obs.kind
	var is_step := obs.kind == &"footsteps" or obs.kind == &"foliage"
	if is_step and _step_voices.size() >= GameParams.current().footstep_voice_limit:
		return
	# loudness 0..1 -> -14..0 dB on top of the category level (audible at the edge of range)
	var db: float = BASE_DB.get(obs.kind, -3.0) + lerpf(-14.0, 0.0, sqrt(obs.volume))
	var bus := ("Footsteps" if is_step else "SFX") + ("Muffled" if obs.muffled else "")
	var v := _voice(key, _pan_position(obs.region_center()), db, bus)
	var entry: Dictionary = session.survivor.hearing.debug_entry(obs)
	if not entry.is_empty():
		entry.audio_play_called = true
		entry.voice_active = v != null and v.playing
	if v != null and is_step:
		_step_voices.append({"voice": v, "t": GameClock.now()})


func _on_survivor_health(_old: int, new_state: int) -> void:
	var pos: Vector2 = session.survivor.global_position
	_voice(&"hit", pos, 0.0, "SFX")
	if new_state == HealthComponent.HState.WOUNDED:
		_voice(&"wound", pos, -4.0, "SFX")
	elif new_state == HealthComponent.HState.DOWNED:
		_voice(&"down", pos, -2.0, "SFX")
