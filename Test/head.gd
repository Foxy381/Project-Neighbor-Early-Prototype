# InventorySystem.gd
extends Node
class_name InventorySystem

signal inventory_updated
signal item_added(item)
signal item_removed(item)

var max_slots: int = 6
var items: Array[InventoryItem] = []

func add_item(item: InventoryItem) -> bool:
	if items.size() < max_slots:
		items.append(item)
		emit_signal("item_added", item)
		emit_signal("inventory_updated")
		return true
	return false

func remove_item(item: InventoryItem) -> bool:
	var index = items.find(item)
	if index != -1:
		items.remove_at(index)
		emit_signal("item_removed", item)
		emit_signal("inventory_updated")
		return true
	return false

func has_item(item_name: String) -> bool:
	for item in items:
		if item.item_name == item_name:
			return true
	return false

func get_item(item_name: String) -> InventoryItem:
	for item in items:
		if item.item_name == item_name:
			return item
	return null
