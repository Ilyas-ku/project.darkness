extends StaticBody2D
## Impassable map border and the ground layer: tiled forest floor, the central
## clearing, dirt paths and scattered details. Placed at the origin; the playable
## map is Rect2(0, 0, map_size). Also the source of the navigation outline.

const THICK_GU := 2.0
const DETAILS := ["sprites/detail_fern.png", "sprites/detail_rocks.png", "sprites/detail_stump.png",
	"sprites/detail_branch.png", "sprites/detail_tuft.png"]

## Dirt paths as polylines in gu.
@export var paths_gu: Array = []
@export var clearing_gu := Vector3(15, 13, 3.4)   # x, y, radius

var _ground: Texture2D


func _ready() -> void:
	add_to_group(&"navigation_source")
	add_to_group(&"map_bounds")
	collision_layer = GameParams.L_WORLD
	collision_mask = 0
	z_index = -10
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ground = Art.tex("textures/ground_grass.png")
	var m := GameParams.current().map_size_px()
	var t := GameParams.gu(THICK_GU)
	_add_rect(Rect2(-t, -t, m.x + 2 * t, t))
	_add_rect(Rect2(-t, m.y, m.x + 2 * t, t))
	_add_rect(Rect2(-t, 0, t, m.y))
	_add_rect(Rect2(m.x, 0, t, m.y))
	var cl := Art.sprite(self, "textures/clearing.png", 1, Vector2.ONE * GameParams.gu(clearing_gu.z) * 2.2)
	cl.position = Vector2(clearing_gu.x, clearing_gu.y) * GameParams.PX_PER_GU
	for p in paths_gu:
		var line := Line2D.new()
		var pts := PackedVector2Array()
		for q in p:
			pts.append(q * GameParams.PX_PER_GU)
		line.points = pts
		line.width = GameParams.gu(1.4)
		line.texture = Art.tex("textures/ground_path.png")
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
		line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.z_index = 2
		add_child(line)
	_scatter_details.call_deferred()
	_tree_line()


## True if p (world px) is on a dirt path.
func is_on_path(p: Vector2) -> bool:
	var half := GameParams.gu(0.65)
	for path in paths_gu:
		for i in range(path.size() - 1):
			var a: Vector2 = path[i] * GameParams.PX_PER_GU
			var b: Vector2 = path[i + 1] * GameParams.PX_PER_GU
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= half:
				return true
	return false


func _add_rect(r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	cs.shape = s
	cs.position = r.get_center()
	add_child(cs)


## Decorative details; kept out of the house and the shed.
func _scatter_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var m := GameParams.current().map_size_px()
	var blocked: Array[Rect2] = []
	for c in get_tree().get_nodes_in_group(&"cabin"):
		blocked.append(c.get_bounds().grow(GameParams.gu(0.3)))
	for o in get_tree().get_nodes_in_group(&"obstacle_box"):
		blocked.append(o.get_bounds().grow(GameParams.gu(0.3)))
	var placed := 0
	while placed < 70:
		var p := Vector2(rng.randf_range(0.5, m.x / GameParams.PX_PER_GU - 0.5), rng.randf_range(0.5, m.y / GameParams.PX_PER_GU - 0.5)) * GameParams.PX_PER_GU
		if blocked.any(func(r): return r.has_point(p)):
			continue
		var s := Art.sprite(self, DETAILS[rng.randi_range(0, DETAILS.size() - 1)], 3)
		s.position = p
		s.rotation = rng.randf() * TAU
		s.modulate = Color(1, 1, 1, rng.randf_range(0.7, 1.0))
		placed += 1


## Dense trees just outside the playable area read as an impassable forest wall.
func _tree_line() -> void:
	var m := GameParams.current().map_size_px()
	var step := GameParams.gu(1.6)
	var i := 0
	var pts: Array[Vector2] = []
	var x := -step * 0.5
	while x < m.x + step:
		pts.append(Vector2(x, -GameParams.gu(1.5)))
		pts.append(Vector2(x + step * 0.5, m.y + GameParams.gu(1.5)))
		x += step
	var y := 0.0
	while y < m.y + step:
		pts.append(Vector2(-GameParams.gu(1.5), y))
		pts.append(Vector2(m.x + GameParams.gu(1.5), y + step * 0.5))
		y += step
	var variants := ["sprites/canopy_pine_a.png", "sprites/canopy_pine_b.png"]
	for p in pts:
		var s := Art.sprite(self, variants[i % 2], 20, Vector2.ONE * GameParams.gu(2.6))
		s.position = p
		s.rotation = float(i) * 1.7
		i += 1


func _draw() -> void:
	var m := GameParams.current().map_size_px()
	var t := GameParams.gu(THICK_GU)
	draw_rect(Rect2(-t, -t, m.x + 2 * t, m.y + 2 * t), Color(0.04, 0.06, 0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(Art.SRC_SCALE, Art.SRC_SCALE))
	draw_texture_rect(_ground, Rect2(Vector2.ZERO, m / Art.SRC_SCALE), true)
