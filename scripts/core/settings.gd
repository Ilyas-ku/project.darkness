class_name Settings
extends RefCounted
## Player settings (persisted in user://settings.cfg): bus volumes (linear 0..1)
## and the accessibility toggle for sound markers on the map (on by default).

const PATH := "user://settings.cfg"
const BUSES := ["Master", "Ambient", "Footsteps", "SFX", "UI"]

static var volumes := {"Master": 1.0, "Ambient": 0.8, "Footsteps": 1.0, "SFX": 1.0, "UI": 1.0}
static var sound_markers := true
static var _loaded := false


static func load_once() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for b in BUSES:
		volumes[b] = float(cf.get_value("audio", b, volumes[b]))
	sound_markers = bool(cf.get_value("accessibility", "sound_markers", true))


static func save() -> void:
	var cf := ConfigFile.new()
	for b in BUSES:
		cf.set_value("audio", b, volumes[b])
	cf.set_value("accessibility", "sound_markers", sound_markers)
	cf.save(PATH)


static func apply_volumes() -> void:
	load_once()
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i != -1:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumes[b], 0.0001)))


static func set_volume(bus: String, v: float) -> void:
	volumes[bus] = clampf(v, 0.0, 1.0)
	apply_volumes()
	save()
