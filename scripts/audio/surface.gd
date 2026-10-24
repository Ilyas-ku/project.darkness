class_name Surface
extends RefCounted
## Ground material under a point: wood (house floor), dirt (paths), grass (forest).

static func at(node: Node, p: Vector2) -> StringName:
	var tree := node.get_tree()
	for c in tree.get_nodes_in_group(&"cabin"):
		if c.get_bounds().has_point(p):
			return &"wood"
	for b in tree.get_nodes_in_group(&"map_bounds"):
		if b.is_on_path(p):
			return &"dirt"
	return &"grass"
