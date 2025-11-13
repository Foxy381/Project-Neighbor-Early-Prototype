extends CharacterBody3D

# Настройки движения
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

# Настройки камеры
@export var camera_bob_frequency: float = 2.0
@export var camera_bob_amplitude: float = 0.08
@export var camera_pitch_limit: float = 89.0  # Ограничение поворота по вертикали (в градусах)
@export var camera_roll_limit: float = 5.0    # Ограничение наклона вбок (в градусах)
@export var camera_yaw_limit: float = 85.0    # Ограничение поворота головы вбок (в градусах)
@export var camera_smoothness: float = 10.0   # Плавность движения камеры
var camera_bob_time: float = 0.0

# Компоненты
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var hand_position: Node3D = $CameraPivot/Camera3D/HandPosition
@onready var raycast: RayCast3D = $CameraPivot/Camera3D/RayCast3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Инвентарь
var inventory: Array = [null, null, null, null]
var current_slot: int = 0
var held_object: Node3D = null

# Переменные движения
var current_speed: float = 0.0
var acceleration: float = 10.0
var deceleration: float = 15.0

# Переменные для анимаций
var is_moving: bool = false
var was_on_floor: bool = true
var current_animation: String = ""

# Названия анимаций - настраивайте здесь под ваши анимации
@export var anim_idle: String = "player_shadow_ao|neighbour_lowpoly_Anim_rig_idle_2"
@export var anim_walk: String = "player_shadow_ao|neighbour_lowpoly_Anim_rig_Walking"
@export var anim_run: String = "player_shadow_ao|neighbour_lowpoly_Anim_rig_RunCasual"
@export var anim_jump: String = "jump"

# Переменные для ограничений камеры
var original_camera_position: Vector3
var original_camera_rotation: Vector3
var target_camera_rotation: Vector3


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Добавляем игрока в группу для поиска ИИ
	add_to_group("player")
	
	# Сохраняем оригинальное положение и вращение камеры
	original_camera_position = camera.position
	original_camera_rotation = camera.rotation
	target_camera_rotation = camera.rotation
	
	# Настройка RayCast3D
	if raycast:
		raycast.enabled = true
		raycast.target_position = Vector3(0, 0, -3)
		raycast.collision_mask = 1
		raycast.collide_with_areas = true
		raycast.collide_with_bodies = true
	else:
		push_warning("RayCast3D не найден!")
	
	# Проверяем доступные анимации при старте
	check_available_animations()
	
	# Настраиваем анимации на зацикливание
	setup_loop_animations()
	
	# Инициализация начального слота
	switch_slot(0)
	print("Начальный слот: 1")


func check_available_animations():
	print("=== Доступные анимации ===")
	var animations = animation_player.get_animation_list()
	for anim in animations:
		print(" - " + anim)
	print("==========================")


func setup_loop_animations():
	# Настраиваем анимации на бесконечное повторение
	var animations_to_loop = [anim_idle, anim_walk, anim_run]
	
	for anim_name in animations_to_loop:
		if animation_player.has_animation(anim_name):
			var animation = animation_player.get_animation(anim_name)
			animation.loop_mode = Animation.LOOP_LINEAR
			print("Анимация '" + anim_name + "' настроена на зацикливание")


func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Поворот игрока по горизонтали
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Плавный поворот камеры по вертикали
		var vertical_rotation = -event.relative.y * mouse_sensitivity
		target_camera_rotation.x += vertical_rotation
		
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	# Обработка переключения слотов цифровыми клавишами
	if event.is_action_pressed("slot_1"):
		switch_slot(0)
	elif event.is_action_pressed("slot_2"):
		switch_slot(1)
	elif event.is_action_pressed("slot_3"):
		switch_slot(2)
	elif event.is_action_pressed("slot_4"):
		switch_slot(3)


func apply_camera_limits():
	# Конвертируем градусы в радианы для расчетов
	var pitch_limit_rad = deg_to_rad(camera_pitch_limit)
	var roll_limit_rad = deg_to_rad(camera_roll_limit)
	var yaw_limit_rad = deg_to_rad(camera_yaw_limit)
	
	# Ограничение по оси X (pitch - кивание) - вертикальное движение
	target_camera_rotation.x = clamp(target_camera_rotation.x, -pitch_limit_rad, pitch_limit_rad)
	
	# Ограничение по оси Y (yaw - поворот) - горизонтальное движение головы
	var current_yaw = target_camera_rotation.y - original_camera_rotation.y
	current_yaw = clamp(current_yaw, -yaw_limit_rad, yaw_limit_rad)
	target_camera_rotation.y = original_camera_rotation.y + current_yaw
	
	# Ограничение по оси Z (roll - крен) - наклон вбок
	var current_roll = target_camera_rotation.z - original_camera_rotation.z
	current_roll = clamp(current_roll, -roll_limit_rad, roll_limit_rad)
	target_camera_rotation.z = original_camera_rotation.z + current_roll


func smooth_camera_rotation(delta):
	# Плавное интерполирование вращения камеры
	var smooth_factor = camera_smoothness * delta
	camera.rotation.x = lerp(camera.rotation.x, target_camera_rotation.x, smooth_factor)
	camera.rotation.y = lerp(camera.rotation.y, target_camera_rotation.y, smooth_factor)
	camera.rotation.z = lerp(camera.rotation.z, target_camera_rotation.z, smooth_factor)


func _physics_process(delta):
	handle_movement(delta)
	handle_interactions()
	update_animations()
	
	# Применяем ограничения и плавное движение камеры
	apply_camera_limits()
	smooth_camera_rotation(delta)


func handle_movement(delta):
	# Получаем ввод с клавиатуры
	var input_dir = Vector2.ZERO
		
	if Input.is_action_pressed("2.1"):
		input_dir.y += 1
	if Input.is_action_pressed("2.2"):
		input_dir.y -= 1
	if Input.is_action_pressed("1.1"):
		input_dir.x -= 1
	if Input.is_action_pressed("1.2"):
		input_dir.x += 1
		
	# Нормализуем только если есть ввод
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		
	# Определяем целевую скорость
	var target_speed = 0.0
	var move_direction = Vector3.ZERO
		
	if input_dir != Vector2.ZERO:
		# Преобразуем 2D ввод в 3D направление относительно камеры
		var camera_forward = -camera.global_transform.basis.z
		var camera_right = camera.global_transform.basis.x
		
		camera_forward.y = 0
		camera_right.y = 0
		camera_forward = camera_forward.normalized()
		camera_right = camera_right.normalized()
		
		move_direction = (camera_forward * input_dir.y + camera_right * input_dir.x).normalized()
		
		# Определяем скорость (бег или ходьба)
		target_speed = run_speed if Input.is_action_pressed("sprint") else walk_speed
		
	# Плавное изменение скорости
	if input_dir != Vector2.ZERO:
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0, deceleration * delta)
		
	# Применяем движение
	if move_direction != Vector3.ZERO and current_speed > 0:
		velocity.x = move_direction.x * current_speed
		velocity.z = move_direction.z * current_speed
		
		# Плавная тряска камеры при движении
		camera_bob_time += delta * current_speed
		var bob_offset = sin(camera_bob_time * camera_bob_frequency) * camera_bob_amplitude
		
		# Применяем тряску только к вертикальной позиции
		camera.position.y = original_camera_position.y + bob_offset
		
		is_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)
		
		# Плавное сбрасывание тряски камеры при остановке
		camera_bob_time = 0.0
		camera.position.y = lerp(camera.position.y, original_camera_position.y, delta * 5.0)
		
		is_moving = false
		
	# Обработка прыжка и гравитации
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			# Небольшой плавный эффект при прыжке
			camera.position.y = lerp(camera.position.y, camera.position.y + 0.1, delta * 8.0)
		
		was_on_floor = true
	else:
		velocity.y -= 9.8 * delta
		was_on_floor = false
		
	# Применяем движение
	move_and_slide()


func handle_interactions():
	if Input.is_action_just_pressed("interact"):
		try_interact()
		
	if Input.is_action_just_pressed("drop_item"):
		drop_current_item()


func try_interact():
	if not raycast or not raycast.enabled:
		return
		
	# Обновляем RayCast
	raycast.force_raycast_update()
		
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		if collider and is_instance_valid(collider):
			if collider.has_method("pick_up"):
				pick_up_item(collider)
			elif collider.has_method("interact"):
				collider.interact(self)


func pick_up_item(item: Node3D):
	# Проверяем что предмет существует и валиден
	if not item or not is_instance_valid(item):
		push_error("Попытка подобрать несуществующий или невалидный предмет!")
		return
		
	var free_slot = get_free_slot()
	if free_slot != -1:
		print("Подбираем предмет в слот ", free_slot + 1)
		
		# Убираем физику у предмета
		if item is RigidBody3D:
			item.freeze = true
			item.collision_layer = 0
			item.collision_mask = 0
		
		# Перемещаем предмет в руку игрока
		if item.get_parent():
			item.get_parent().remove_child(item)
		
		hand_position.add_child(item)
		item.position = Vector3(0, 0, -0.8) # Перед игроком
		item.rotation = Vector3.ZERO
		item.scale = Vector3.ONE
		
		# Добавляем в инвентарь
		inventory[free_slot] = item
		
		# Автоматически переключаемся на слот с новым предметом
		switch_slot(free_slot)
		
		# Выводим информацию о состоянии инвентаря
		print_inventory_status()
	else:
		print("Инвентарь полон!")


func drop_current_item():
	if held_object and is_instance_valid(held_object):
		print("Выбрасываем предмет из слота ", current_slot + 1)
		
		# Восстанавливаем физику
		if held_object is RigidBody3D:
			held_object.freeze = false
			held_object.collision_layer = 1
			held_object.collision_mask = 1
			held_object.linear_velocity = Vector3.ZERO
			held_object.angular_velocity = Vector3.ZERO
		
		# Убираем из руки игрока
		hand_position.remove_child(held_object)
		
		# Добавляем на сцену
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(held_object)
		else:
			get_parent().add_child(held_object)
		
		# Бросаем предмет перед игроком
		var throw_direction = -camera.global_transform.basis.z
		var throw_position = camera.global_position + throw_direction * 1.5
		held_object.global_position = throw_position
		
		# Добавляем небольшой толчок вперед
		if held_object is RigidBody3D:
			var throw_force = throw_direction * 5.0
			held_object.apply_impulse(throw_force)
		
		# Очищаем слот инвентаря
		inventory[current_slot] = null
		held_object = null
		
		# Выводим информацию о состоянии инвентаря
		print_inventory_status()


func switch_slot(slot_index: int):
	if slot_index < 0 or slot_index >= 4:
		return
		
	# Если переключаемся на тот же слот - ничего не делаем
	if slot_index == current_slot:
		return
		
	print("Переключаем на слот ", slot_index + 1)
	
	# Скрываем текущий предмет
	if held_object and is_instance_valid(held_object):
		held_object.hide()
	
	# Обновляем текущий слот
	current_slot = slot_index
	held_object = inventory[slot_index]
	
	# Показываем новый предмет
	if held_object and is_instance_valid(held_object):
		held_object.show()
		# Убеждаемся, что предмет находится в правильной позиции
		held_object.position = Vector3(0, 0, -0.8)
		held_object.rotation = Vector3.ZERO
	
	# Выводим информацию о состоянии инвентаря
	print_inventory_status()


func get_free_slot() -> int:
	for i in range(4):
		if inventory[i] == null:
			return i
	return -1


func print_inventory_status():
	var status = "Состояние инвентаря: "
	for i in range(4):
		var item_status = "Пусто"
		if inventory[i] and is_instance_valid(inventory[i]):
			if inventory[i].has_method("get_item_name"):
				item_status = inventory[i].get_item_name()
			elif inventory[i].has_method("get_key_id"):
				item_status = "Ключ " + str(inventory[i].get_key_id())
			else:
				item_status = "Предмет"
		
		var selected = " [ВЫБРАН]" if i == current_slot else ""
		status += "Слот %d: %s%s | " % [i + 1, item_status, selected]
		
	print(status)


func update_animations():
	if not animation_player:
		return
	
	var new_animation = ""
	
	# Определяем какая анимация должна проигрываться
	if not is_on_floor():
		# В воздухе - анимация прыжка/падения
		new_animation = anim_jump
	elif is_moving:
		# Движение - анимация ходьбы/бега
		if Input.is_action_pressed("sprint"):
			new_animation = anim_run
		else:
			new_animation = anim_walk
	else:
		# Стояние на месте - анимация простоя
		new_animation = anim_idle
	
	# Проверяем доступность анимации
	if not animation_player.has_animation(new_animation):
		# Fallback: используем первую доступную анимацию подходящего типа
		var fallback_animation = get_fallback_animation(new_animation)
		if fallback_animation != "":
			new_animation = fallback_animation
		else:
			return  # Нет подходящих анимаций
	
	# Проигрываем анимацию только если она изменилась
	if new_animation != current_animation:
		animation_player.play(new_animation)
		current_animation = new_animation
		print("Проигрывается анимация: " + new_animation)


func get_fallback_animation(desired_anim: String) -> String:
	var available_animations = animation_player.get_animation_list()
	
	# Приоритеты fallback-анимаций
	if desired_anim == anim_jump:
		# Для прыжка пробуем найти любую анимацию с "jump" в названии
		for anim in available_animations:
			if "jump" in anim.to_lower():
				return anim
	elif desired_anim == anim_run:
		# Для бега ищем анимации с "run" в названии
		for anim in available_animations:
			if "run" in anim.to_lower():
				return anim
		# Если нет бега, используем ходьбу
		return anim_walk if animation_player.has_animation(anim_walk) else ""
	elif desired_anim == anim_walk:
		# Для ходьбы ищем анимации с "walk" в названии
		for anim in available_animations:
			if "walk" in anim.to_lower():
				return anim
	
	# Для idle используем первую доступную анимацию
	if desired_anim == anim_idle and available_animations.size() > 0:
		return available_animations[0]
	
	return ""


func face_neighbor(neighbor_position: Vector3):
	# Поворачиваем игрока к соседу
	var direction_to_neighbor = (neighbor_position - global_position).normalized()
		
	# Поворачиваем игрока в сторону соседа (только по оси Y)
	var target_rotation = atan2(direction_to_neighbor.x, direction_to_neighbor.z)
	rotation.y = target_rotation
		
	# Плавно поворачиваем камеру на 90 градусов для драматического эффекта
	var tween = create_tween()
	tween.tween_property(camera, "rotation_degrees:y", 90.0, 1.0).set_ease(Tween.EASE_OUT)
		
	print("Игрок поворачивается к соседу!")


func teleport_to_scene():
	# Телепортация на другую сцену (Game Over)
	var scene_path = "res://Levels/node_3d.tscn" # Укажите путь к вашей сцене Game Over
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		# Если сцены нет, просто перезагружаем теку
		pass
