extends NavigationRegion2D
## Bakes the killer's navigation polygon at runtime from static colliders in the
## "navigation_source" group (trunks, walls, shed, lockers, map bounds).
## Doors are excluded: the killer opens closed doors in its way.


func _enter_tree() -> void:
	add_to_group(&"nav_builder")


func build() -> void:
	var p := GameParams.current()
	var poly := NavigationPolygon.new()
	poly.agent_radius = GameParams.gu(p.killer_radius + 0.08)
	poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	poly.parsed_collision_mask = GameParams.NAV_MASK
	poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	poly.source_geometry_group_name = &"navigation_source"
	var m := p.map_size_px()
	poly.add_outline(PackedVector2Array([Vector2.ZERO, Vector2(m.x, 0), m, Vector2(0, m.y)]))
	navigation_polygon = poly
	bake_navigation_polygon(false)
