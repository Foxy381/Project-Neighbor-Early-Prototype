extends Area3D

@onready var window = get_parent()

func _ready():
	# Настраиваем большую область вокруг окна для обнаружения всех столкновений
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body):
	if window and window.has_method("_on_body_entered_break_area"):
		window._on_body_entered_break_area(body)

func _on_area_entered(area):
	if window and window.has_method("_on_area_entered_break_area"):
		window._on_area_entered_break_area(area)
