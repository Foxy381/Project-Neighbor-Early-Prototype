extends StaticBody3D

@export var window_id = "default"
@export var is_breakable = true
@export var break_force = 5.0
@export var break_on_any_contact = false  # Разбиваться при любом контакте

# Эффекты разбития
@export var break_particles_scene: PackedScene
@export var glass_shards_scene: PackedScene

# Ссылки на узлы
@onready var mesh_instance = $MeshInstance3D
@onready var break_area = $BreakArea

# Состояние окна
var is_broken = false
var original_position
var original_rotation

# Материалы для смены при разрушении
var intact_material: StandardMaterial3D
var broken_material: StandardMaterial3D

func _ready():
	add_to_group("windows")
	original_position = position
	original_rotation = rotation
	
	# Настройка материалов
	setup_materials()
	
	# Подключаем сигналы
	if break_area:
		break_area.body_entered.connect(_on_body_entered_break_area)
		break_area.area_entered.connect(_on_area_entered_break_area)

func setup_materials():
	# Создаем базовые материалы
	intact_material = StandardMaterial3D.new()
	intact_material.albedo_color = Color(0.8, 0.9, 1.0, 0.8)  # Стеклянный цвет
	intact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	intact_material.metallic = 0.3
	intact_material.roughness = 0.1
	
	broken_material = StandardMaterial3D.new()
	broken_material.albedo_color = Color(0.5, 0.5, 0.5, 0.3)  # Серый разбитый
	broken_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	broken_material.roughness = 0.8
	
	if mesh_instance:
		mesh_instance.material_override = intact_material

func break_window():
	if is_broken:
		return
	
	is_broken = true
	print("🪟 Окно разбито: ", window_id)
	
	# Визуальные эффекты разрушения
	apply_break_effects()
	
	# Отключаем столкновения для основного тела
	collision_layer = 0
	collision_mask = 0

func apply_break_effects():
	# Меняем материал на разбитый
	if mesh_instance:
		mesh_instance.material_override = broken_material
	
	# Создаем эффект трещин
	create_crack_effect()
	
	# Создаем частицы разбитого стекла
	create_break_particles()
	
	# Создаем осколки стекла
	create_glass_shards()
	
	# Случайное смещение и вращение для эффекта разрушения
	var break_offset = Vector3(
		randf_range(-0.05, 0.05),
		randf_range(-0.15, -0.05),
		randf_range(-0.05, 0.05)
	)
	
	var break_rotation = Vector3(
		randf_range(-10, 10),
		randf_range(-20, 20),
		randf_range(-10, 10)
	)
	
	position = original_position + break_offset
	rotation_degrees = original_rotation + break_rotation

func create_crack_effect():
	# Создаем нод для эффекта трещин
	var crack_node = Node3D.new()
	crack_node.name = "CrackEffect"
	add_child(crack_node)
	
	# Создаем несколько плоскостей для трещин
	for i in range(3):
		var crack_mesh = MeshInstance3D.new()
		var plane_mesh = PlaneMesh.new()
		plane_mesh.size = Vector2(0.3, 0.3)
		
		var crack_material = StandardMaterial3D.new()
		crack_material.albedo_color = Color(0.2, 0.2, 0.2, 0.6)
		crack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		crack_mesh.mesh = plane_mesh
		crack_mesh.material_override = crack_material
		
		# Случайное позиционирование трещин
		crack_mesh.position = Vector3(
			randf_range(-0.5, 0.5),
			randf_range(-0.5, 0.5),
			0.01  # Немного перед окном
		)
		crack_mesh.rotation_degrees = Vector3(
			0,
			0,
			randf_range(0, 360)
		)
		
		crack_node.add_child(crack_mesh)

func create_break_particles():
	# Создаем систему частиц для эффекта разбития
	var particles = GPUParticles3D.new()
	particles.name = "BreakParticles"
	
	# Настройка частиц
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(1.0, 1.0, 0.1)
	particle_material.gravity = Vector3(0, -9.8, 0)
	particle_material.initial_velocity_min = 2.0
	particle_material.initial_velocity_max = 8.0
	particle_material.angle_min = 0.0
	particle_material.angle_max = 360.0
	particle_material.scale_min = 0.05
	particle_material.scale_max = 0.2
	particle_material.color = Color(0.9, 0.9, 1.0, 0.8)
	
	particles.process_material = particle_material
	particles.amount = 30
	particles.explosiveness = 0.9
	particles.one_shot = true
	
	add_child(particles)
	particles.emitting = true
	
	# Автоматическое удаление после завершения
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if particles and is_instance_valid(particles):
			particles.queue_free()
	)

func create_glass_shards():
	# Создаем несколько осколков стекла
	for i in range(8):
		var shard = MeshInstance3D.new()
		var shard_mesh = BoxMesh.new()
		shard_mesh.size = Vector3(
			randf_range(0.05, 0.15),
			randf_range(0.05, 0.15),
			0.02
		)
		
		var shard_material = StandardMaterial3D.new()
		shard_material.albedo_color = Color(
			randf_range(0.7, 0.9),
			randf_range(0.8, 1.0),
			randf_range(0.9, 1.0),
			randf_range(0.4, 0.7)
		)
		shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shard_material.metallic = randf_range(0.2, 0.5)
		shard_material.roughness = randf_range(0.1, 0.4)
		
		shard.mesh = shard_mesh
		shard.material_override = shard_material
		
		# Случайное позиционирование осколков
		shard.position = Vector3(
			randf_range(-0.8, 0.8),
			randf_range(-0.8, 0.8),
			0
		)
		shard.rotation_degrees = Vector3(
			randf_range(0, 360),
			randf_range(0, 360),
			randf_range(0, 360)
		)
		
		add_child(shard)

# Основная функция обработки столкновений
func _on_body_entered_break_area(body):
	if is_broken or not is_breakable:
		return
	
	# Обрабатываем разные типы тел
	if body is RigidBody3D:
		handle_rigidbody_collision(body)
	elif body is CharacterBody3D:
		handle_character_collision(body)
	elif break_on_any_contact:
		# Разбиваемся при любом контакте
		print("💥 Окно разбито контактом с: ", body.name)
		break_window()

func _on_area_entered_break_area(area):
	if is_broken or not is_breakable:
		return
	
	# Обработка Area3D (например, от других объектов)
	if area.get_parent() is RigidBody3D:
		var parent_body = area.get_parent() as RigidBody3D
		handle_rigidbody_collision(parent_body)
	elif break_on_any_contact:
		print("💥 Окно разбито контактом с Area: ", area.name)
		break_window()

# Прямые столкновения с StaticBody3D
func _on_body_entered(body):
	if is_broken or not is_breakable:
		return
	
	print("🔵 Прямое столкновение с: ", body.name)
	
	if body is RigidBody3D:
		handle_rigidbody_collision(body)
	elif body is CharacterBody3D:
		handle_character_collision(body)
	elif break_on_any_contact:
		print("💥 Окно разбито прямым контактом с: ", body.name)
		break_window()

# Обработка RigidBody3D
func handle_rigidbody_collision(body: RigidBody3D):
	var impact_force = body.linear_velocity.length()
	
	print("🎯 Столкновение с объектом: ", body.name, " Скорость: ", impact_force)
	
	# Проверяем силу удара
	if impact_force >= break_force:
		print("💥 Окно разбито предметом: ", body.name, " с силой: ", impact_force)
		break_window()
		
		# Добавляем физическую реакцию
		var reflection_dir = -body.linear_velocity.normalized()
		body.linear_velocity = reflection_dir * impact_force * 0.3
		
		# Добавляем случайное вращение
		body.angular_velocity = Vector3(
			randf_range(-2, 2),
			randf_range(-2, 2),
			randf_range(-2, 2)
		)
	elif break_on_any_contact:
		# Разбиваемся при любом контакте с объектом
		print("💥 Окно разбито контактом с объектом: ", body.name)
		break_window()

# Обработка CharacterBody3D (игрок, NPC)
func handle_character_collision(body: CharacterBody3D):
	var velocity = body.velocity.length()
	
	print("👤 Столкновение с персонажем: ", body.name, " Скорость: ", velocity)
	
	# Проверяем скорость персонажа
	if velocity >= break_force * 0.7:  # Персонажам нужно меньше скорости
		print("💥 Окно разбито персонажем: ", body.name, " со скоростью: ", velocity)
		break_window()
	elif break_on_any_contact:
		# Разбиваемся при любом контакте с персонажем
		print("💥 Окно разбито контактом с персонажем: ", body.name)
		break_window()

# Метод для принудительного разбития
func force_break():
	if not is_broken and is_breakable:
		break_window()

# Метод для восстановления окна
func repair_window():
	if not is_broken:
		return
	
	is_broken = false
	position = original_position
	rotation = original_rotation
	
	# Восстанавливаем столкновения
	collision_layer = 1
	collision_mask = 1
	
	# Восстанавливаем материал
	if mesh_instance:
		mesh_instance.material_override = intact_material
	
	# Удаляем эффекты разбития
	cleanup_break_effects()
	
	print("🔧 Окно починено: ", window_id)

func cleanup_break_effects():
	# Удаляем все эффекты разбития
	var crack_effect = get_node_or_null("CrackEffect")
	if crack_effect:
		crack_effect.queue_free()
	
	var particles = get_node_or_null("BreakParticles")
	if particles:
		particles.queue_free()
	
	# Удаляем осколки
	for child in get_children():
		if child is MeshInstance3D and child != mesh_instance:
			child.queue_free()

# Получить информацию о состоянии окна
func get_window_info() -> Dictionary:
	return {
		"id": window_id,
		"is_broken": is_broken,
		"is_breakable": is_breakable,
		"break_force": break_force,
		"break_on_any_contact": break_on_any_contact
	}

# Включить/выключить режим "разбиваться при любом контакте"
func set_break_on_any_contact(enabled: bool):
	break_on_any_contact = enabled
	print("🔧 Режим 'разбиваться при любом контакте': ", enabled)
