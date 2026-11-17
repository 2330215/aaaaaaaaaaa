extends CanvasLayer
## Confirmación compartida entre los ajustes del inicio y los de pausa.

var _cancel_button: Button
var _delete_button: Button
var _error_label: Label
var _return_focus: Control
var _deleting: bool = false


static func open(owner_node: Node) -> CanvasLayer:
	var existing := owner_node.get_node_or_null("DeleteSaveDialog") as CanvasLayer
	if existing:
		return existing
	var dialog := load("res://gui/delete_save_dialog.gd").new() as CanvasLayer
	dialog.name = "DeleteSaveDialog"
	owner_node.add_child(dialog)
	return dialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 800
	_return_focus = get_viewport().gui_get_focus_owner()
	var surface := Control.new()
	surface.theme = preload("res://gui/theme.tres").duplicate()
	surface.theme.default_font = preload("res://gui/fonts/DejaVuSans.ttf")
	surface.theme.default_font_size = 16
	surface.theme.set_font("font", "Button", surface.theme.default_font)
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.88)
	surface.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	surface.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(500, get_viewport().get_visible_rect().size.x-32)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.09)
	style.border_color = Color(0.88, 0.43, 0.30)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.text = "¿Borrar la partida local?"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var warning := Label.new()
	warning.text = "Se perderá TODO el progreso: niveles desbloqueados, recetas y partida en curso.\n\nEl juego volverá al inicio con solo el nivel 1 disponible. Esta acción no se puede deshacer."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warning)
	var preferences := Label.new()
	preferences.text = "Los ajustes de audio y controles se conservarán."
	preferences.add_theme_font_size_override("font_size", 13)
	preferences.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(preferences)
	_error_label = Label.new()
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	_error_label.hide()
	box.add_child(_error_label)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_cancel_button = Button.new()
	_cancel_button.text = "Cancelar"
	_cancel_button.custom_minimum_size.y = 42
	_cancel_button.pressed.connect(queue_free)
	actions.add_child(_cancel_button)
	_delete_button = Button.new()
	_delete_button.text = "Borrar todo y reiniciar"
	_delete_button.custom_minimum_size.y = 42
	_delete_button.add_theme_color_override("font_color", Color(1, 0.58, 0.45))
	_delete_button.pressed.connect(_confirm_delete)
	actions.add_child(_delete_button)
	_cancel_button.grab_focus()


func _confirm_delete() -> void:
	if _deleting:
		return
	_deleting = true
	_cancel_button.disabled = true
	_delete_button.disabled = true
	var error := GameState.erase_save_and_restart()
	if error != OK:
		_deleting = false
		_cancel_button.disabled = false
		_delete_button.disabled = false
		_error_label.text = "No se pudo borrar la partida. Verifica que el juego pueda escribir en este dispositivo e inténtalo de nuevo."
		_error_label.show()
		_cancel_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_pause"):
		get_viewport().set_input_as_handled()
		if not _deleting:
			queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
