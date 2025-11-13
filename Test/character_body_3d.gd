extends CharacterBody3D

# Настройки камеры и движения
@export var mouse_sensitivity = 0.002
@export var walk_speed = 5.0
@export var run_speed = 8.0
@export var jump_velocity = 4.5
@export var throw_force = 15.0

# Настройки положения предмета перед игроком
@export var hand_position_offset = Vector3(0.5, -0.3, -1.0)

# Ссылки на узлы
@onready var camera = $Head/Camera3D
@onready var interaction_ray = $Head/Camera3D/InteractionRay
@onready var hand_position = $Head/Camera3D/HandPosition

# Переменные состояния
var current_held_object: RigidBody3D = null
var is_running = false
var current_speed = 0.0
var lean_angle = 0.0
var target_lean = 0.0

# Инвентарь как в Hello Neighbor Pre-Alpha
var inventory: Array = [null, null, null, null, null]  # 5 слотов
var current_slot = 0  # Текущий выбранный слот
var max_inventory_size = 5

# Настройки наклона
const LEAN_ANGLE = 35.5
const LEAN_SPEED = 8.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	current_speed = walk_speed
	setup_hand_position()
	print("=== СИСТЕМА HELLO NEIGHBOR PRE-ALPHA ЗАГРУЖЕНА ===")

func setup_hand_position():
	hand_position.position = hand_position_offset

func _input(event):
	# Управление камерой мышью
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)
	
	# Выбор слотов инвентаря (1-5)
	if Input.is_action_just_pressed("slot_1"):
		switch_to_slot(0)
	elif Input.is_action_just_pressed("slot_2"):
		switch_to_slot(1)
	elif Input.is_action_just_pressed("slot_3"):
		switch_to_slot(2)
	elif Input.is_action_just_pressed("slot_4"):
		switch_to_slot(3)

	
	# Взаимодействие с предметами
	if Input.is_action_just_pressed("3.3_interact"):
		if current_held_object:
			# Если уже держим предмет - добавляем в инвентарь
			add_object_to_inventory(current_held_object)
		else:
			# Если нет - пробуем взять предмет
			try_pickup_object()
	
	# Бросок предмета
	if Input.is_action_just_pressed("throw"):
		if current_held_object:
			throw_current_object()
	
	# Выброс предмета из инвентаря
	if Input.is_action_just_pressed("drop_item"):
		drop_from_current_slot()
	
	# Наклоны (Z и C)
	if Input.is_action_just_pressed("lean_1"):
		target_lean = deg_to_rad(LEAN_ANGLE)
	elif Input.is_action_just_pressed("lean_2"):
		target_lean = deg_to_rad(-LEAN_ANGLE)
	elif Input.is_action_just_released("lean_1") or Input.is_action_just_released("lean_2"):
		target_lean = 0.0
	
	# Бег
	if Input.is_action_just_pressed("sprint"):
		is_running = true
		current_speed = run_speed
	if Input.is_action_just_released("sprint"):
		is_running = false
		current_speed = walk_speed
	
	# Выход из захвата мыши
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	handle_movement(delta)
	handle_leaning(delta)

func handle_movement(delta):
	var input_dir = Input.get_vector("1.1", "1.2", "2.1", "2.2")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()

func handle_leaning(delta):
	lean_angle = lerp(lean_angle, target_lean, LEAN_SPEED * delta)
	camera.rotation.z = lean_angle

func try_pickup_object():
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		
		if collider is RigidBody3D and collider.is_in_group("pickable"):
			pickup_object_directly(collider)
		elif collider.has_method("on_interact"):
			collider.on_interact(self)

func pickup_object_directly(obj: RigidBody3D):
	# Находим свободный слот автоматически
	var free_slot = find_free_slot()
	
	if free_slot != -1:
		# Показываем объект в руке и добавляем в найденный слот
		show_object_in_hand(obj)
		add_object_to_slot(obj, free_slot)
		switch_to_slot(free_slot)
		print("Подобран объект: '", obj.name, "' -> Слот ", free_slot + 1)
	else:
		print("Инвентарь полон! Нельзя подобрать: ", obj.name)

func show_object_in_hand(obj: RigidBody3D):
	current_held_object = obj
	
	# Сохраняем оригинальные свойства
	obj.set_meta("original_parent", obj.get_parent())
	obj.set_meta("original_collision_layer", obj.collision_layer)
	obj.set_meta("original_collision_mask", obj.collision_mask)
	obj.set_meta("original_gravity", obj.gravity_scale)
	
	# Перемещаем объект в руку
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	hand_position.add_child(obj)
	obj.position = Vector3.ZERO
	obj.rotation = Vector3.ZERO
	
	# Отключаем физику - объект не будет двигаться при движении камеры
	obj.collision_layer = 0
	obj.collision_mask = 0
	obj.gravity_scale = 0
	obj.freeze = true
	obj.linear_velocity = Vector3.ZERO
	obj.angular_velocity = Vector3.ZERO

func find_free_slot() -> int:
	# Ищем первый свободный слот (например, если слоты 1 и 3 заняты, вернет слот 2)
	for i in range(max_inventory_size):
		if inventory[i] == null:
			return i
	return -1  # Все слоты заняты

func add_object_to_inventory(obj: RigidBody3D):
	var free_slot = find_free_slot()
	if free_slot != -1:
		add_object_to_slot(obj, free_slot)
		switch_to_slot(free_slot)
		print("Объект добавлен в слот ", free_slot + 1)
	else:
		print("Инвентарь полон!")

func add_object_to_slot(obj: RigidBody3D, slot_index: int):
	# Прячем текущий объект из руки
	hide_object_from_hand()
	
	# Сохраняем в инвентарь
	inventory[slot_index] = {
		"object": obj,
		"name": obj.name,
		"slot": slot_index
	}

func switch_to_slot(slot_index: int):
	if slot_index < 0 or slot_index >= max_inventory_size:
		return
	
	# Сначала убираем текущий объект из руки
	hide_object_from_hand()
	
	# Меняем текущий слот
	current_slot = slot_index
	
	# Показываем объект из нового слота (если он есть)
	if inventory[slot_index] != null:
		var item_data = inventory[slot_index]
		var obj = item_data["object"]
		show_object_in_hand(obj)
		print("Активирован слот ", slot_index + 1, ": '", obj.name, "'")
	else:
		print("Слот ", slot_index + 1, " пуст")

func hide_object_from_hand():
	if current_held_object:
		# Убираем объект из руки, но оставляем в инвентаре
		hand_position.remove_child(current_held_object)
		
		# Возвращаем объект в мир (но прячем его)
		return_object_to_world(current_held_object)
		current_held_object.global_position = Vector3(0, -100, 0)  # Прячем под карту
		
		current_held_object = null

func throw_current_object():
	if current_held_object:
		var obj = current_held_object
		var obj_name = obj.name
		
		# Убираем из инвентаря
		remove_object_from_all_slots(obj)
		
		# Возвращаем физику
		restore_object_physics(obj)
		
		# Перемещаем обратно в мир
		hand_position.remove_child(obj)
		return_object_to_world(obj)
		
		# Применяем силу броска
		apply_throw_force(obj)
		
		current_held_object = null
		print("Бросок объекта: '", obj_name, "'")

func drop_from_current_slot():
	if inventory[current_slot] != null:
		var item_data = inventory[current_slot]
		var obj = item_data["object"]
		var obj_name = obj.name
		
		# Убираем из инвентаря
		inventory[current_slot] = null
		
		# Возвращаем физику
		restore_object_physics(obj)
		
		# Убираем из руки если это текущий объект
		if current_held_object == obj:
			hand_position.remove_child(obj)
			current_held_object = null
		
		# Возвращаем в мир
		return_object_to_world(obj)
		
		# Помещаем перед игроком
		obj.global_position = global_position + (-camera.global_transform.basis.z * 1.0) + Vector3(0, -0.5, 0)
		obj.linear_velocity = Vector3(0, -2, 0)
		
		print("Выброшен из слота ", current_slot + 1, ": '", obj_name, "'")

func remove_object_from_all_slots(obj: RigidBody3D):
	for i in range(max_inventory_size):
		if inventory[i] != null and inventory[i]["object"] == obj:
			inventory[i] = null
			print("Объект '", obj.name, "' удален из слота ", i + 1)

func restore_object_physics(obj: RigidBody3D):
	if obj.has_meta("original_collision_layer"):
		obj.collision_layer = obj.get_meta("original_collision_layer")
	if obj.has_meta("original_collision_mask"):
		obj.collision_mask = obj.get_meta("original_collision_mask")
	if obj.has_meta("original_gravity"):
		obj.gravity_scale = obj.get_meta("original_gravity")
	obj.freeze = false

func return_object_to_world(obj: RigidBody3D):
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	
	var original_parent = obj.get_meta("original_parent", null)
	if original_parent and is_instance_valid(original_parent):
		original_parent.add_child(obj)
	else:
		# Создаем Objects нод если его нет
		var objects_node = get_node_or_null("/root/Main/Objects")
		if not objects_node:
			objects_node = Node3D.new()
			objects_node.name = "Objects"
			var main_node = get_node_or_null("/root/Main")
			if main_node:
				main_node.add_child(objects_node)
			else:
				get_tree().current_scene.add_child(objects_node)
		objects_node.add_child(obj)

func apply_throw_force(obj: RigidBody3D):
	obj.global_transform.origin = hand_position.global_transform.origin
	var throw_direction = -camera.global_transform.basis.z
	obj.linear_velocity = throw_direction * throw_force
	obj.angular_velocity = Vector3.ZERO  # Предметы не крутятся

func has_item(item_name: String) -> bool:
	for item in inventory:
		if item != null and item["name"] == item_name:
			return true
	return false

func remove_item(item_name: String) -> bool:
	for i in range(max_inventory_size):
		if inventory[i] != null and inventory[i]["name"] == item_name:
			inventory[i] = null
			
			# Если удаляемый предмет был в руке, убираем его
			if current_held_object and current_held_object.name == item_name:
				hide_object_from_hand()
			
			print("Удален предмет: '", item_name, "' из слота ", i + 1)
			return true
	return false

func get_inventory_size() -> int:
	var count = 0
	for item in inventory:
		if item != null:
			count += 1
	return count

# Проверка системы на ошибки
func check_system_errors():
	print("=== ПРОВЕРКА СИСТЕМЫ НА ОШИБКИ ===")
	
	# Проверка узлов
	if not camera:
		print("❌ ОШИБКА: Камера не найдена")
	else:
		print("✅ Камера: OK")
	
	if not interaction_ray:
		print("❌ ОШИБКА: InteractionRay не найден")
	else:
		print("✅ InteractionRay: OK")
	
	if not hand_position:
		print("❌ ОШИБКА: HandPosition не найден")
	else:
		print("✅ HandPosition: OK")
	
	# Проверка инвентаря
	print("📦 Инвентарь: ", get_inventory_size(), "/", max_inventory_size, " слотов занято")
	print("🎯 Текущий слот: ", current_slot + 1)
	print("✋ Объект в руке: ", "'" + current_held_object.name + "'" if current_held_object else "нет")
	
	# Показываем содержимое слотов
	for i in range(max_inventory_size):
		var slot_info = "Слот " + str(i + 1) + ": "
		if inventory[i] != null:
			slot_info += "'" + inventory[i]["name"] + "'"
		else:
			slot_info += "пусто"
		print(slot_info)
	
	print("=== ПРОВЕРКА ЗАВЕРШЕНА ===")

# Автопроверка при запуске
func _enter_tree():
	call_deferred("check_system_errors")
