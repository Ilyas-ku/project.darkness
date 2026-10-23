extends Node2D
## Character sprite: 7-frame top-down sheet (idle, 4 walk, special, downed),
## rotated towards the facing direction. Special frame = killer wind-up or
## survivor hurt. The parent provides get_facing() and optionally is_downed().

@export var sheet_path := "sprites/survivor_sheet.png"
@export var body_color := Color(0.35, 0.6, 1.0)
@export var radius_gu := 0.3
## Set true while an attack or a finisher is being telegraphed.
var telegraph := false

var _sprite: Sprite2D
var _walk := 0.0
var _last_pos := Vector2.INF
var _hurt := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = Art.tex(sheet_path)
	_sprite.hframes = 7
	_sprite.scale = Vector2(Art.SRC_SCALE, Art.SRC_SCALE)
	add_child(_sprite)


func flash_hurt() -> void:
	_hurt = 0.35


func _process(delta: float) -> void:
	var owner_node := get_parent() as Node2D
	var f: Vector2 = owner_node.get_facing() if owner_node.has_method(&"get_facing") else Vector2.RIGHT
	var pos := owner_node.global_position
	var moved := 0.0 if _last_pos == Vector2.INF else pos.distance_to(_last_pos)
	_last_pos = pos
	var downed: bool = owner_node.has_method(&"is_downed") and owner_node.is_downed()
	if downed:
		_sprite.frame = 6
	elif telegraph:
		_sprite.frame = 5
		_sprite.modulate = Color(1.0, 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.03), 0.6)
	elif _hurt > 0.0:
		_sprite.frame = 5
	elif moved > 0.2:
		_walk += moved / GameParams.gu(0.45)
		_sprite.frame = 1 + int(_walk) % 4
	else:
		_sprite.frame = 0
	if not telegraph:
		_sprite.modulate = Color(1, 0.55, 0.55) if _hurt > 0.0 else Color.WHITE
	_hurt = maxf(0.0, _hurt - delta)
	_sprite.rotation = f.angle()
