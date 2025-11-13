# interactable_object.gd
extends StaticBody3D

@export var item_name: String = "Object"
@export var is_pickupable: bool = true

func interact(player):
	if is_pickupable:
		player.pickup_item(self)
	else:
		# Логика взаимодействия с непереносимыми объектами
		print("Взаимодействие с: ", item_name)

# Поместите объект в группу для обнаружения
func _ready():
	if is_pickupable:
		add_to_group("pickupable")
