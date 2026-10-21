class_name VictoryScreen extends CanvasLayer
## Pantalla de nivel completado. Se pausa el juego, se muestran las
## estadísticas del nivel y se ofrecen las opciones SALIR / AVANZAR.

signal exit_requested()
signal advance_requested()

const FADE_DURATION := 0.35
const BLACK_SCREEN_HOLD := 2.0

@onready var panel: Control = $VictoryPanel
@onready var subtitle_label: Label = $VictoryPanel/CenterContainer/VBoxContainer/SubtitleLabel
@onready var stats_grid: GridContainer = $VictoryPanel/CenterContainer/VBoxContainer/StatsGrid
@onready var buttons: HBoxContainer = $VictoryPanel/CenterContainer/VBoxContainer/Buttons
@onready var exit_button: Button = $VictoryPanel/CenterContainer/VBoxContainer/Buttons/ExitButton
@onready var advance_button: Button = $VictoryPanel/CenterContainer/VBoxContainer/Buttons/AdvanceButton
@onready var black_overlay: ColorRect = $BlackOverlay

var _shown := false
var _advancing := false
var _row_labels: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	black_overlay.visible = false
	black_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	exit_button.pressed.connect(_on_exit_pressed)
	advance_button.pressed.connect(_on_advance_pressed)


func show_victory(stats: Dictionary, can_advance: bool) -> void:
	if _shown:
		return
	_shown = true

	panel.visible = true
	panel.modulate.a = 0.0
	subtitle_label.text = "NIVEL %d COMPLETADO" % int(stats.get("level_number", 1))
	_populate_stats(stats.get("rows", []))

	advance_button.text = "AVANZAR" if can_advance else "FIN DE LA DEMO"
	advance_button.disabled = not can_advance
	buttons.visible = false
	buttons.modulate.a = 0.0

	var fade_in := create_tween()
	fade_in.tween_property(panel, "modulate:a", 1.0, 0.35)
	await fade_in.finished

	await _reveal_stats()

	buttons.visible = true
	var buttons_tween := create_tween()
	buttons_tween.tween_property(buttons, "modulate:a", 1.0, 0.2)
	await buttons_tween.finished

	if can_advance:
		advance_button.grab_focus()
	else:
		exit_button.grab_focus()


func _populate_stats(rows: Array) -> void:
	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()
	_row_labels.clear()

	for row in rows:
		var row_data: Dictionary = row

		var label := Label.new()
		label.text = str(row_data.get("label", ""))
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.76, 0.88, 0.78))
		label.modulate.a = 0.0
		stats_grid.add_child(label)
		_row_labels.append(label)

		var value := Label.new()
		value.text = str(row_data.get("value", "0"))
		value.add_theme_font_size_override("font_size", 18)
		value.add_theme_color_override("font_color", Color(0.32, 1.0, 0.42))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(110, 0)
		value.modulate.a = 0.0
		stats_grid.add_child(value)
		_row_labels.append(value)


## Revela cada fila de estadísticas una tras otra.
func _reveal_stats() -> void:
	for i in range(0, _row_labels.size(), 2):
		var row_tween := create_tween()
		row_tween.set_parallel(true)
		row_tween.tween_property(_row_labels[i], "modulate:a", 1.0, 0.16)
		if i + 1 < _row_labels.size():
			row_tween.tween_property(_row_labels[i + 1], "modulate:a", 1.0, 0.16)
		await get_tree().create_timer(0.09, true).timeout


func _on_exit_pressed() -> void:
	if _advancing:
		return
	exit_requested.emit()


func _on_advance_pressed() -> void:
	if _advancing or advance_button.disabled:
		return
	_advancing = true

	exit_button.disabled = true
	advance_button.disabled = true

	# Pantalla negra de 2 segundos antes de cargar el siguiente nivel.
	black_overlay.visible = true
	black_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	var fade_out := create_tween()
	fade_out.tween_property(black_overlay, "color:a", 1.0, FADE_DURATION)
	await fade_out.finished

	await get_tree().create_timer(BLACK_SCREEN_HOLD, true).timeout
	advance_requested.emit()
