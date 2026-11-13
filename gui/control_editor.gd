extends Control
## Vista previa a escala real con arrastre por ratón o pantalla táctil.
const PAD := preload("res://gui/mobile-controls-1/Sprites/Style E/Default/dpad.png")
const CIRCLE := preload("res://gui/mobile-controls-1/Sprites/Style E/Default/button_circle.png")
const ICONS := [
	preload("res://gui/mobile-controls-1/Sprites/Icons/Default/icon_jump.png"),
	preload("res://gui/mobile-controls-1/Sprites/Icons/Default/icon_crosshair.png"),
	preload("res://gui/mobile-controls-1/Sprites/Icons/Default/icon_arrow.png")
]
var _closing: bool = false
var _selected: int = 0
var _dragging: bool = false
var _finger: int = -1
var _grab_offset := Vector2.ZERO
var _panel: PanelContainer
var _alpha: HSlider
var _values: Array[Label] = []
var _preview: Array[TextureRect] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.065, 1.0)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in range(4):
		var image := TextureRect.new()
		image.texture = PAD if index == 0 else CIRCLE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)
		_preview.append(image)
		if index > 0:
			var icon := TextureRect.new()
			icon.texture = ICONS[index - 1]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			image.add_child(icon)
	var panel := PanelContainer.new()
	_panel = panel
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size.x = 340
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "CONTROLES · Vista previa"
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Arrastra cada control para colocarlo."
	box.add_child(hint)
	_alpha = _slider(box, "Transparencia", 0, 80)
	_alpha.value_changed.connect(func(value: float) -> void: ControlSettings.update_opacity(1.0 - value / 100.0))
	var actions := HBoxContainer.new()
	box.add_child(actions)
	for text: String in ["Restablecer", "Guardar y volver"]:
		var button := Button.new()
		button.text = text
		button.custom_minimum_size.y = 34
		actions.add_child(button)
		if text == "Restablecer":
			button.pressed.connect(ControlSettings.reset)
		else:
			button.pressed.connect(_close)
	ControlSettings.changed.connect(_sync)
	resized.connect(_sync)
	_sync()
	_alpha.grab_focus()

func _slider(parent: Node, text: String, minimum: float, maximum: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := Label.new()
	row.add_child(value)
	_values.append(value)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1
	slider.custom_minimum_size.y = 20
	parent.add_child(slider)
	return slider

func _input(event: InputEvent) -> void:
	if _closing:
		return
	# Resolver Volver antes de que el menú o la partida reciban la tecla.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_pause"):
		get_viewport().set_input_as_handled()
		_close()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not _dragging:
			_begin_drag(event.position, event.index)
		elif not event.pressed and _dragging and event.index == _finger:
			_end_drag()
	elif event is InputEventScreenDrag and _dragging and event.index == _finger:
		_drag_to(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.pressed and not _dragging:
			_begin_drag(event.position, -1)
		elif not event.pressed and _dragging and _finger == -1:
			_end_drag()
	elif event is InputEventMouseMotion and _dragging and _finger == -1:
		_drag_to(event.position)

func _begin_drag(point: Vector2, finger: int) -> void:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	if _panel.get_global_rect().has_point(get_global_transform() * local):
		return
	for index in range(_preview.size() - 1, -1, -1):
		if _preview[index].get_rect().has_point(local):
			_selected = index
			_dragging = true
			_finger = finger
			_grab_offset = local - _preview[index].get_rect().get_center()
			_sync()
			get_viewport().set_input_as_handled()
			return

func _drag_to(point: Vector2) -> void:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	var extent := _preview[_selected].size
	var center := (local - _grab_offset).clamp(extent * 0.5 + Vector2(8, 8), size - extent * 0.5 - Vector2(8, 8))
	ControlSettings.update_position(_selected, center / size)
	get_viewport().set_input_as_handled()

func _end_drag() -> void:
	_dragging = false
	_finger = -1
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_dragging = false
		_finger = -1

func _sync() -> void:
	if not is_instance_valid(_alpha):
		return
	_alpha.set_value_no_signal((1.0 - ControlSettings.opacity) * 100.0)
	_values[0].text = "%d%%" % roundi(_alpha.value)
	for index in range(_preview.size()):
		var rect := ControlSettings.control_rect(index, size)
		var image := _preview[index]
		image.position = rect.position
		image.size = rect.size
		image.modulate = Color(1.0, 0.85, 0.5, ControlSettings.opacity) if index == _selected else Color(1, 1, 1, ControlSettings.opacity)
		if index > 0:
			var icon := image.get_child(0) as TextureRect
			icon.position = rect.size * 0.28
			icon.size = rect.size * 0.44

func _close() -> void:
	if _closing:
		return
	_closing = true
	ControlSettings.save()
	queue_free()

static func open(parent: Node) -> void:
	if parent.has_node("ControlEditorLayer"):
		return
	var previous_focus := parent.get_viewport().gui_get_focus_owner()
	var previous_mode := parent.process_mode
	var menu := parent as Control
	var menu_was_visible := menu.visible if menu else false
	# La pantalla anterior queda oculta e inactiva mientras el editor está abierto.
	parent.process_mode = Node.PROCESS_MODE_DISABLED
	if menu:
		menu.hide()
	var layer := CanvasLayer.new()
	layer.name = "ControlEditorLayer"
	layer.layer = 150
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var editor := Control.new()
	editor.set_script(load("res://gui/control_editor.gd"))
	editor.tree_exited.connect(func() -> void:
		layer.queue_free()
		if not is_instance_valid(parent) or parent.is_queued_for_deletion() or not parent.is_inside_tree():
			return
		parent.process_mode = previous_mode
		if is_instance_valid(menu):
			menu.visible = menu_was_visible
		if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
			previous_focus.grab_focus()
	)
	layer.add_child(editor)
