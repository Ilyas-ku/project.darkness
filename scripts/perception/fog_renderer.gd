class_name FogRenderer
extends Node2D
## Draws the fog of war over the world:
##   black = UNEXPLORED, dimmed = EXPLORED (static geometry only),
##   clear = inside the current visibility polygon (VISIBLE).
## The visibility polygon is rasterized in a SubViewport (precise LOS edges);
## the explored memory is a low-res texture sampled with linear filtering.

const SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D visible_mask : filter_linear;
uniform float explored_alpha = 0.62;
void fragment() {
	float explored = texture(TEXTURE, UV).r;
	float vis = texture(visible_mask, UV).r;
	float a = mix(1.0, explored_alpha, explored);
	a = mix(a, 0.0, vis);
	COLOR = vec4(0.0, 0.0, 0.015, a);
}
"""

var memory: ExplorationMemory

var _img: Image
var _tex: ImageTexture
var _viewport: SubViewport
var _mask: _MaskDraw


func setup(map_px: Vector2, cell_px: float, explored_alpha: float) -> void:
	z_index = 50
	memory = ExplorationMemory.new(map_px, cell_px)
	_img = Image.create(memory.cols, memory.rows, false, Image.FORMAT_L8)
	_img.fill(Color.BLACK)
	_tex = ImageTexture.create_from_image(_img)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(map_px)
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = map_px
	_viewport.add_child(bg)
	_mask = _MaskDraw.new()
	_viewport.add_child(_mask)
	add_child(_viewport)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = _tex
	sprite.scale = Vector2(cell_px, cell_px)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sh := Shader.new()
	sh.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter(&"visible_mask", _viewport.get_texture())
	mat.set_shader_parameter(&"explored_alpha", explored_alpha)
	sprite.material = mat
	add_child(sprite)


func set_visible_polygon(poly: PackedVector2Array) -> void:
	_mask.poly = poly
	_mask.queue_redraw()


func refresh_texture() -> void:
	memory.write_image(_img)
	_tex.update(_img)


class _MaskDraw extends Node2D:
	var poly := PackedVector2Array()

	func _draw() -> void:
		if poly.size() < 3:
			return
		var eye := poly[0]
		for i in range(1, poly.size() - 1):
			draw_colored_polygon(PackedVector2Array([eye, poly[i], poly[i + 1]]), Color.WHITE)
