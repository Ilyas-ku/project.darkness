class_name ExplorationMemory
extends RefCounted
## Player's map memory on a grid (memory only, not gameplay collision).
## UNEXPLORED: never seen (black). EXPLORED: seen before, only static geometry is
## drawn (dimmed). VISIBLE: currently in direct view, dynamic objects allowed.

enum CellState { UNEXPLORED = 0, EXPLORED = 1, VISIBLE = 2 }

var cell_px: float
var cols: int
var rows: int
var cells := PackedByteArray()
var _last_polygon := PackedVector2Array()


func _init(map_size_px: Vector2, cell_size_px: float) -> void:
	cell_px = cell_size_px
	cols = int(ceil(map_size_px.x / cell_px))
	rows = int(ceil(map_size_px.y / cell_px))
	cells.resize(cols * rows)
	cells.fill(CellState.UNEXPLORED)


## Rendering contract: dynamic objects (characters, stones, blood, door state)
## are drawn only in VISIBLE cells; static geometry in EXPLORED or VISIBLE.
static func is_renderable(is_dynamic: bool, state: int) -> bool:
	if is_dynamic:
		return state == CellState.VISIBLE
	return state != CellState.UNEXPLORED


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / cell_px)), int(floor(p.y / cell_px)))


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func get_state(c: Vector2i) -> int:
	return cells[c.y * cols + c.x] if in_bounds(c) else CellState.UNEXPLORED


func get_state_at(p: Vector2) -> int:
	return get_state(cell_of(p))


func set_visible_cell(c: Vector2i) -> void:
	if in_bounds(c):
		cells[c.y * cols + c.x] = CellState.VISIBLE


## VISIBLE -> EXPLORED, then marks the cells covered by the current view polygon.
## Returns false (and leaves memory untouched) if the view geometry did not change.
func update_from_polygon(poly: PackedVector2Array) -> bool:
	if poly == _last_polygon:
		return false
	_last_polygon = poly
	for i in cells.size():
		if cells[i] == CellState.VISIBLE:
			cells[i] = CellState.EXPLORED
	if poly.size() < 3:
		return true
	var bb := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bb = bb.expand(p)
	var c0 := cell_of(bb.position)
	var c1 := cell_of(bb.end)
	for y in range(maxi(c0.y, 0), mini(c1.y, rows - 1) + 1):
		for x in range(maxi(c0.x, 0), mini(c1.x, cols - 1) + 1):
			var center := Vector2((x + 0.5) * cell_px, (y + 0.5) * cell_px)
			if Geometry2D.is_point_in_polygon(center, poly):
				cells[y * cols + x] = CellState.VISIBLE
	# Ray end points lie just inside wall faces; make those faces remembered too.
	for i in range(1, poly.size()):
		set_visible_cell(cell_of(poly[i]))
	return true


## Writes the memory to an L8 image: 0 = unexplored, 255 = explored or visible.
func write_image(img: Image) -> void:
	for y in rows:
		for x in cols:
			var v := 0.0 if cells[y * cols + x] == CellState.UNEXPLORED else 1.0
			img.set_pixel(x, y, Color(v, v, v))
