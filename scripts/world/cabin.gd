extends StaticBody2D
## Two-room cabin with one door (south wall, east room) and a locker in the west
## room. Origin = top-left corner. Walls block movement and LOS; the inner wall
## has an open doorway.

const DOOR_SCENE := preload("res://scenes/world/door.tscn")
const LOCKER_SCENE := preload("res://scenes/world/locker.tscn")

@export var size_gu := Vector2(8, 6)
@export var wall_gu := 0.3
@export var inner_wall_x_gu := 4.0
@export var inner_gap_gu := Vector2(2.4, 3.6)   # y range of the inner doorway
@export var door_center_x_gu := 6.2
@export var door_width_gu := 1.2
@export var locker_pos_gu := Vector2(1.4, 0.65)

var _wall_rects: Array[Rect2] = []


func _ready() -> void:
	add_to_group(&"navigation_source")
	collision_layer = GameParams.L_WORLD
	collision_mask = 0
	var W := size_gu.x
	var H := size_gu.y
	var t := wall_gu
	var dl := door_center_x_gu - door_width_gu * 0.5
	var dr := door_center_x_gu + door_width_gu * 0.5
	var ix := inner_wall_x_gu - t * 0.5
	_wall(Rect2(0, 0, W, t))                            # north
	_wall(Rect2(0, 0, t, H))                            # west
	_wall(Rect2(W - t, 0, t, H))                        # east
	_wall(Rect2(0, H - t, dl, t))                       # south, left of door
	_wall(Rect2(dr, H - t, W - dr, t))                  # south, right of door
	_wall(Rect2(ix, t, t, inner_gap_gu.x - t))          # inner, above doorway
	_wall(Rect2(ix, inner_gap_gu.y, t, H - t - inner_gap_gu.y))  # inner, below
	var door := DOOR_SCENE.instantiate()
	door.width_gu = door_width_gu
	door.thickness_gu = t
	door.position = Vector2(door_center_x_gu, H - t * 0.5) * GameParams.PX_PER_GU
	add_child(door)
	var locker := LOCKER_SCENE.instantiate()
	locker.position = locker_pos_gu * GameParams.PX_PER_GU
	add_child(locker)


func _wall(r_gu: Rect2) -> void:
	var r := Rect2(r_gu.position * GameParams.PX_PER_GU, r_gu.size * GameParams.PX_PER_GU)
	_wall_rects.append(r)
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	cs.shape = s
	cs.position = r.get_center()
	add_child(cs)


func _draw() -> void:
	var s := size_gu * GameParams.PX_PER_GU
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.24, 0.2, 0.16))
	for r in _wall_rects:
		draw_rect(r, Color(0.55, 0.52, 0.48))
