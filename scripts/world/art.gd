class_name Art
extends RefCounted
## Access to the generated art (assets/, see tools/gen_assets.py and ASSETS.md).
## Source art is 64 px per game unit and is drawn at scale 0.5.

const SRC_SCALE := 0.5

static var _cache := {}
static var _light: Texture2D


## Drops cached resources (called when a session ends, avoids leaks at exit).
static func clear_cache() -> void:
	_cache.clear()
	_light = null


static func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load("res://assets/" + path)
	return _cache[path]


static func tex_audio(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load("res://assets/" + path)
	return _cache[path]


## Adds a centred Sprite2D. If size_px is given, the sprite is scaled to that size.
static func sprite(parent: Node, path: String, z := 0, size_px := Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(path)
	s.z_index = z
	if size_px != Vector2.ZERO:
		s.scale = size_px / s.texture.get_size()
	else:
		s.scale = Vector2(SRC_SCALE, SRC_SCALE)
	parent.add_child(s)
	return s


## Soft radial texture for PointLight2D.
static func light_texture() -> Texture2D:
	if _light == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_light = t
	return _light


## Local light pool: an additive radial glow (cheap on every renderer; a
## PointLight2D in GL Compatibility re-draws everything it touches).
static func point_light(parent: Node, color: Color, radius_gu: float, energy: float) -> Sprite2D:
	var l := Sprite2D.new()
	l.texture = light_texture()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = mat
	l.modulate = Color(color.r * energy * 0.35, color.g * energy * 0.35, color.b * energy * 0.35, 1.0)
	l.scale = Vector2.ONE * GameParams.gu(radius_gu) * 2.0 / 256.0
	l.z_as_relative = false
	l.z_index = 30
	parent.add_child(l)
	return l


## Stable per-position variant index (same look on every run).
static func variant(pos: Vector2, count: int) -> int:
	return absi(int(pos.x * 7.0 + pos.y * 13.0)) % count
