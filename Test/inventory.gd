extends Node

class_name InventorySystem

var items: Array[String] = []
var max_size: int = 8
var equipment_slots: Dictionary = {
	"weapon": null,
	"tool": null,
	"special": null
}

signal inventory_updated(items: Array)
signal item_added(item_id: String)
signal item_removed(item_id: String)
signal equipment_changed(slot: String, item_id: String)

func add_item(item_id: String) -> bool:
	if items.size() < max_size:
		items.append(item_id)
		inventory_updated.emit(items)
		item_added.emit(item_id)
		return true
	return false

func remove_item(item_id: String) -> bool:
	var index = items.find(item_id)
	if index != -1:
		items.remove_at(index)
		inventory_updated.emit(items)
		item_removed.emit(item_id)
		return true
	return false

func equip_item(slot: String, item_id: String) -> bool:
	if items.has(item_id):
		equipment_slots[slot] = item_id
		remove_item(item_id)
		equipment_changed.emit(slot, item_id)
		return true
	return false

func unequip_item(slot: String) -> bool:
	var item_id = equipment_slots[slot]
	if item_id and add_item(item_id):
		equipment_slots[slot] = null
		equipment_changed.emit(slot, "")
		return true
	return false
