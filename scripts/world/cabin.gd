extends StaticBody2D
## Two-room cabin (origin = top-left corner):
##   west = bedroom (locker, bed), east = living room (table, chairs, crate, radio, bottle).
## Front door in the south wall of the east room, inner door between the rooms,
## a vaultable window in the west wall of the bedroom (the "other side").

const DOOR_SCENE := preload("res://scenes/world/door.tscn")
const LOCKER_SCENE := preload("res://scenes/world/locker.tscn")
const WINDOW_SCENE := preload("res://scenes/world/window.tscn")
const FURNITURE_SCENE := preload("res://scenes/world/furniture.tscn")
const RADIO_SCENE := preload("res://scenes/items/radio.tscn")
const BOTTLE_SCENE := preload("res://scenes/items/bottle.tscn")

## Furniture: [node name, kind, display name, local centre gu, size gu, tall, movable]
const FURNITURE := [
	["Bed", &"bed", "кровать", Vector2(3.0, 1.35), Vector2(1.2, 2.0), false, false],
	["Table", &"table", "стол", Vector2(6.0, 1.6), Vector2(1.6, 1.0), false, false],
	["ChairA", &"chair", "стул", Vector2(4.85, 1.6), Vector2(0.5, 0.5), false, true],
	["ChairB", &"chair", "стул", Vector2(7.2, 1.6), Vector2(0.5, 0.5), false, true],
	["Crate", &"crate", "ящик", Vector2(4.9, 4.7), Vector2(0.8, 0.8), true, true],
]

@export var size_gu := Vector2(8, 6)
@export var wall_gu := 0.3
@export var inner_wall_x_gu := 4.0
@export var inner_door_y_gu := 3.0
@export var door_center_x_gu := 6.2
@export var opening_gu := 1.2
@export var window_y_gu := 3.0
@export var locker_pos_gu := Vector2(1.2, 0.65)

var _wall_rects: Array[Rect2] = []
var _wall_tex: Texture2D


func _ready() -> void:
	add_to_group(&"navigation_source")
	add_to_group(&"cabin")
	collision_layer = GameParams.L_WORLD
	collision_mask = 0
	z_index = 6
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_wall_tex = Art.tex("textures/wall_logs.png")
	_build_interior_art()
	var W := size_gu.x
	var H := size_gu.y
	var t := wall_gu
	var o := opening_gu * 0.5
	var dl := door_center_x_gu - o
	var dr := door_center_x_gu + o
	var ix := inner_wall_x_gu - t * 0.5
	_wall(Rect2(0, 0, W, t))                                         # north
	_wall(Rect2(0, 0, t, window_y_gu - o))                           # west, above window
	_wall(Rect2(0, window_y_gu + o, t, H - window_y_gu - o))         # west, below window
	_wall(Rect2(W - t, 0, t, H))                                     # east
	_wall(Rect2(0, H - t, dl, t))                                    # south, left of door
	_wall(Rect2(dr, H - t, W - dr, t))                               # south, right of door
	_wall(Rect2(ix, t, t, inner_door_y_gu - o - t))                  # inner, above door
	_wall(Rect2(ix, inner_door_y_gu + o, t, H - t - inner_door_y_gu - o))  # inner, below door
	_add(DOOR_SCENE, Vector2(door_center_x_gu, H - t * 0.5), 0.0, &"FrontDoor")
	_add(DOOR_SCENE, Vector2(inner_wall_x_gu, inner_door_y_gu), PI * 0.5, &"InnerDoor")
	_add(WINDOW_SCENE, Vector2(t * 0.5, window_y_gu), PI * 0.5, &"Window")
	_add(LOCKER_SCENE, locker_pos_gu, 0.0, &"Locker")
	for f in FURNITURE:
		var n: Node2D = FURNITURE_SCENE.instantiate()
		n.name = f[0]
		n.kind = f[1]
		n.display_name = f[2]
		n.position = f[3] * GameParams.PX_PER_GU
		n.size_gu = f[4]
		n.tall = f[5]
		n.movable = f[6]
		add_child(n)
	_add(RADIO_SCENE, Vector2(6.3, 1.55), 0.0, &"Radio")
	_add(BOTTLE_SCENE, Vector2(7.2, 5.0), 0.0, &"Bottle")


func _add(scene: PackedScene, pos_gu: Vector2, rot: float, node_name: StringName) -> Node2D:
	var n: Node2D = scene.instantiate()
	n.name = node_name
	if "width_gu" in n:
		n.width_gu = opening_gu
	if "thickness_gu" in n:
		n.thickness_gu = wall_gu
	n.position = pos_gu * GameParams.PX_PER_GU
	n.rotation = rot
	add_child(n)
	return n


func _wall(r_gu: Rect2) -> void:
	var r := Rect2(r_gu.position * GameParams.PX_PER_GU, r_gu.size * GameParams.PX_PER_GU)
	_wall_rects.append(r)
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	cs.shape = s
	cs.position = r.get_center()
	add_child(cs)


## Floors (two tones for the two rooms), a rug, an oil lamp with warm light.
func _build_interior_art() -> void:
	var floor_node := _Floor.new()
	floor_node.cabin = self
	floor_node.z_as_relative = false
	floor_node.z_index = -6
	floor_node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(floor_node)
	var rug := Art.sprite(self, "sprites/rug.png", 0, Vector2(2.0, 1.4) * GameParams.PX_PER_GU)
	rug.z_as_relative = false
	rug.z_index = -5
	rug.position = Vector2(2.1, 4.1) * GameParams.PX_PER_GU
	var lamp := Art.sprite(self, "sprites/lamp.png", 0)
	lamp.z_as_relative = false
	lamp.z_index = 5
	lamp.position = Vector2(5.55, 1.45) * GameParams.PX_PER_GU
	var light := Art.point_light(self, Color(1.0, 0.72, 0.42), 3.2, 1.1)
	light.position = lamp.position


func get_wall_rects() -> Array[Rect2]:
	return _wall_rects


## Room rectangles in world px (for "seen in the same room" decisions).
func get_room_rects() -> Array[Rect2]:
	var g := GameParams.PX_PER_GU
	var ix := inner_wall_x_gu
	return [
		Rect2(global_position, Vector2(ix, size_gu.y) * g),
		Rect2(global_position + Vector2(ix, 0) * g, Vector2(size_gu.x - ix, size_gu.y) * g),
	]


func get_bounds() -> Rect2:
	return Rect2(global_position, size_gu * GameParams.PX_PER_GU)


func _draw() -> void:
	var sh := Vector2(GameParams.gu(0.12), GameParams.gu(0.16))
	for r in _wall_rects:  # cold drop shadow
		draw_rect(Rect2(r.position + sh, r.size), Color(0.0, 0.02, 0.05, 0.45))
	for r in _wall_rects:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(Art.SRC_SCALE, Art.SRC_SCALE))
		draw_texture_rect(_wall_tex, Rect2(r.position / Art.SRC_SCALE, r.size / Art.SRC_SCALE), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(r, Color(0.16, 0.11, 0.07), false, 1.5)
		draw_line(r.position, r.position + Vector2(r.size.x, 0), Color(0.75, 0.66, 0.52, 0.5), 1.0)


class _Floor extends Node2D:
	var cabin: Node

	func _draw() -> void:
		var tex := Art.tex("textures/floor_wood.png")
		var g := GameParams.PX_PER_GU
		var sz: Vector2 = cabin.size_gu
		var ix: float = cabin.inner_wall_x_gu
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(Art.SRC_SCALE, Art.SRC_SCALE))
		draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(ix, sz.y) * g / Art.SRC_SCALE), true, Color(0.85, 0.8, 0.85))
		draw_texture_rect(tex, Rect2(Vector2(ix, 0) * g / Art.SRC_SCALE, Vector2(sz.x - ix, sz.y) * g / Art.SRC_SCALE), true, Color(1.0, 0.95, 0.88))
