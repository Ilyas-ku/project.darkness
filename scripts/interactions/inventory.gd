class_name Inventory
extends Node
## Two-slot inventory (MVP: only stones are carried).

signal changed

var slots: Array = []
var selected := 0


func _ready() -> void:
	slots.resize(GameParams.current().inventory_slots)


func has_space() -> bool:
	return slots.has(null)


func add(item: Node) -> bool:
	var i := slots.find(null)
	if i < 0:
		return false
	slots[i] = item
	if slots[selected] == null:
		selected = i
	changed.emit()
	return true


func select(i: int) -> void:
	if i >= 0 and i < slots.size():
		selected = i
		changed.emit()


func take_selected() -> Node:
	var item: Node = slots[selected]
	if item == null:
		var i := slots.find_custom(func(s): return s != null)
		if i < 0:
			return null
		selected = i
		item = slots[i]
	slots[selected] = null
	changed.emit()
	return item


func count() -> int:
	return slots.filter(func(s): return s != null).size()
