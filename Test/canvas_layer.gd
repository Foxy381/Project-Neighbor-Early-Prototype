extends CanvasLayer

var is_inventory_visible: bool = false
var inventory_items: Array = []
var selected_slot: int = -1

func _ready():
	# Создаем все элементы UI программно
	create_hud()
	create_inventory_panel()
	create_message_panel()
	
	# Скрываем инвентарь при старте
	get_node("InventoryPanel").visible = false
	get_node("MessagePanel").visible = false

func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
	
	if event.is_action_pressed("ui_cancel") and is_inventory_visible:
		toggle_inventory()

func create_hud():
	# Создаем основной HUD контейнер
	var hud = Control.new()
	hud.name = "HUD"
	hud.anchor_right = 1.0
	hud.anchor_bottom = 1.0
	hud.margin_left = 10
	hud.margin_top = 10
	add_child(hud)
	
	# Создаем контейнер для здоровья и выносливости
	var stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	hud.add_child(stats_container)
	
	# Создаем полоску здоровья
	var health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "Health: 100/100"
	stats_container.add_child(health_label)
	
	# Создаем полоску выносливости
	var stamina_label = Label.new()
	stamina_label.name = "StaminaLabel"
	stamina_label.text = "Stamina: 100/100"
	stats_container.add_child(stamina_label)
	
	# Создаем контейнер для слотов инвентаря HUD
	var inventory_hud = HBoxContainer.new()
	inventory_hud.name = "InventoryHUD"
	inventory_hud.margin_top = 100
	hud.add_child(inventory_hud)
	
	# Создаем 3 слота инвентаря для HUD
	for i in range(3):
		var slot_container = VBoxContainer.new()
		slot_container.name = "Slot" + str(i + 1)
		slot_container.margin_left = 5
		slot_container.margin_right = 5
		
		var slot_bg = ColorRect.new()
		slot_bg.name = "Background"
		slot_bg.color = Color(0.2, 0.2, 0.2, 0.7)
		slot_bg.custom_minimum_size = Vector2(50, 50)
		
		var slot_number = Label.new()
		slot_number.name = "SlotNumber"
		slot_number.text = str(i + 1)
		slot_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var item_label = Label.new()
		item_label.name = "ItemLabel"
		item_label.text = ""
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.add_theme_font_size_override("font_size", 10)
		
		slot_container.add_child(slot_bg)
		slot_container.add_child(slot_number)
		slot_container.add_child(item_label)
		inventory_hud.add_child(slot_container)
	
	# Создаем метку взаимодействия
	var interaction_label = Label.new()
	interaction_label.name = "InteractionLabel"
	interaction_label.text = ""
	interaction_label.margin_top = 200
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_size_override("font_size", 16)
	hud.add_child(interaction_label)

func create_inventory_panel():
	# Создаем панель инвентаря
	var inventory_panel = Panel.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.anchor_right = 1.0
	inventory_panel.anchor_bottom = 1.0
	inventory_panel.size = Vector2(400, 300)
	
	# Центрируем панель
	var viewport_size = get_viewport().get_visible_rect().size
	inventory_panel.position = Vector2(viewport_size.x / 2 - 200, viewport_size.y / 2 - 150)
	inventory_panel.visible = false
	add_child(inventory_panel)
	
	# Заголовок инвентаря
	var title = Label.new()
	title.name = "Title"
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.margin_top = 10
	title.margin_left = 10
	title.margin_right = 10
	inventory_panel.add_child(title)
	
	# Контейнер для слотов инвентаря
	var slots_container = GridContainer.new()
	slots_container.name = "SlotsContainer"
	slots_container.columns = 3
	slots_container.margin_top = 50
	slots_container.margin_left = 50
	slots_container.margin_right = 50
	slots_container.margin_bottom = 50
	inventory_panel.add_child(slots_container)
	
	# Создаем 3 слота инвентаря
	for i in range(3):
		var slot = TextureButton.new()
		slot.name = "InventorySlot" + str(i)
		slot.custom_minimum_size = Vector2(80, 80)
		slot.expand_mode = TextureButton.EXPAND_FIT_WIDTH_PROPORTIONAL
		
		# Подключаем сигналы для кнопок
		slot.pressed.connect(_on_inventory_slot_pressed.bind(i))
		
		var slot_label = Label.new()
		slot_label.name = "SlotLabel"
		slot_label.text = "Slot " + str(i + 1)
		slot_label.margin_top = 85
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var slot_container = VBoxContainer.new()
		slot_container.add_child(slot)
		slot_container.add_child(slot_label)
		slots_container.add_child(slot_container)

func create_message_panel():
	# Создаем панель для сообщений
	var message_panel = Panel.new()
	message_panel.name = "MessagePanel"
	message_panel.anchor_right = 1.0
	message_panel.anchor_bottom = 1.0
	
	# Центрируем панель сообщений
	var viewport_size = get_viewport().get_visible_rect().size
	message_panel.margin_left = viewport_size.x / 2 - 150
	message_panel.margin_top = viewport_size.y / 3
	message_panel.margin_right = viewport_size.x / 2 + 150
	message_panel.margin_bottom = viewport_size.y / 3 + 60
	message_panel.visible = false
	add_child(message_panel)
	
	var message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.text = ""
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.margin_left = 10
	message_label.margin_right = 10
	message_label.margin_top = 10
	message_label.margin_bottom = 10
	message_panel.add_child(message_label)

func toggle_inventory():
	is_inventory_visible = !is_inventory_visible
	get_node("InventoryPanel").visible = is_inventory_visible
	
	if is_inventory_visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		update_inventory_display()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func update_player_ui(data: Dictionary):
	# Обновление здоровья
	var health_label = get_node("HUD/StatsContainer/HealthLabel")
	var health = data.get("health", 100)
	var max_health = data.get("max_health", 100)
	health_label.text = "Health: " + str(health) + "/" + str(max_health)
	
	# Обновление выносливости
	var stamina_label = get_node("HUD/StatsContainer/StaminaLabel")
	var stamina = data.get("stamina", 100)
	var max_stamina = data.get("max_stamina", 100)
	stamina_label.text = "Stamina: " + str(int(stamina)) + "/" + str(int(max_stamina))
	
	# Обновление инвентаря HUD
	update_hud_inventory(data.get("inventory", []), data.get("selected_slot", -1))

func update_hud_inventory(items: Array, selected_slot: int):
	inventory_items = items
	
	for i in range(3):
		var slot_path = "HUD/InventoryHUD/Slot" + str(i + 1)
		if has_node(slot_path):
			var slot_container = get_node(slot_path)
			var background = slot_container.get_node("Background")
			var item_label = slot_container.get_node("ItemLabel")
			
			# Подсветка выбранного слота
			if i == selected_slot:
				background.color = Color(0.4, 0.4, 0.8, 0.9)
			else:
				background.color = Color(0.2, 0.2, 0.2, 0.7)
			
			# Отображение предмета
			if i < items.size() and items[i] != null:
				var item_name = get_item_name(items[i])
				item_label.text = item_name
			else:
				item_label.text = ""

func update_inventory_display():
	# Обновление отображения инвентаря при открытии
	for i in range(3):
		var slot_container = get_node("InventoryPanel/SlotsContainer").get_child(i)
		var slot = slot_container.get_child(0)  # TextureButton
		var slot_label = slot_container.get_child(1)  # Label
		
		if i < inventory_items.size() and inventory_items[i] != null:
			var item_name = get_item_name(inventory_items[i])
			slot_label.text = item_name
		else:
			slot_label.text = "Empty"

func get_item_name(item) -> String:
	if item is String:
		return item
	elif item != null and item.has_method("get_item_name"):
		return item.get_item_name()
	elif item != null and item.has_method("get_name"):
		return item.get_name()
	else:
		return "Item"

func show_interaction_text(text: String):
	var interaction_label = get_node("HUD/InteractionLabel")
	if interaction_label:
		interaction_label.text = "[E] " + text

func hide_interaction_text():
	var interaction_label = get_node("HUD/InteractionLabel")
	if interaction_label:
		interaction_label.text = ""

func show_message(message: String, duration: float = 3.0):
	var message_panel = get_node("MessagePanel")
	var message_label = message_panel.get_node("MessageLabel")
	
	if message_panel and message_label:
		message_label.text = message
		message_panel.visible = true
		
		# Таймер для скрытия сообщения
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(_on_message_timer_timeout)

func _on_message_timer_timeout():
	var message_panel = get_node("MessagePanel")
	if message_panel:
		message_panel.visible = false

func show_ai_status(status: String):
	show_message("Neighbor: " + status, 2.0)

func show_uv_code(code: String):
	show_message("UV Code Found: " + code, 5.0)

func show_night_message():
	show_message("NIGHT MODE - House layout changed!", 4.0)

func show_day_message():
	show_message("DAY MODE - House layout restored", 4.0)

# Обработчик для кнопок инвентаря
func _on_inventory_slot_pressed(slot_index: int):
	select_slot(slot_index)

func select_slot(slot_index: int):
	# Уведомляем игрока о выборе слота
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("select_inventory_slot"):
		player.select_inventory_slot(slot_index)
	
	# Закрываем инвентарь после выбора
	toggle_inventory()

# Обновление при изменении размера окна
func _notification(what):
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		# Пересчитываем позиции при изменении размера окна
		var viewport_size = get_viewport().get_visible_rect().size
		
		# Обновляем позицию инвентаря
		var inventory_panel = get_node("InventoryPanel")
		if inventory_panel:
			inventory_panel.position = Vector2(viewport_size.x / 2 - 200, viewport_size.y / 2 - 150)
		
		# Обновляем позицию сообщений
		var message_panel = get_node("MessagePanel")
		if message_panel:
			message_panel.margin_left = viewport_size.x / 2 - 150
			message_panel.margin_top = viewport_size.y / 3
			message_panel.margin_right = viewport_size.x / 2 + 150
			message_panel.margin_bottom = viewport_size.y / 3 + 60
