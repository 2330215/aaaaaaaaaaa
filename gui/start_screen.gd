extends Control

const BACKGROUNDS: Array[PackedScene] = [
	preload("res://level/background/parallax_background.tscn"),
	preload("res://level/background/parallax_background2.tscn"),
	preload("res://level/background/parallax_background3.tscn"),
	preload("res://level/background/parallax_background4.tscn"),
	preload("res://level/background/parallax_background5.tscn")
]
const FADE_DURATION: float = 0.65
const MIN_BACKGROUND_SECONDS: float = 5.0
const MAX_BACKGROUND_SECONDS: float = 10.0

var _background: LevelBackground
var _background_index: int = -1
var _background_order: Array[Vector2i] = []
var _background_timer: Timer
var _background_fade: ColorRect
var _backdrop_label: Label
var _main: VBoxContainer
var _levels: VBoxContainer
var _options: VBoxContainer
var _continue_button: Button
var _level_buttons: Array[Button] = []
var _music_slider: HSlider
var _effects_slider: HSlider
var _music_value: Label
var _effects_value: Label
var _fullscreen: CheckButton
var _transitioning: bool = false


func _ready() -> void:
	get_tree().paused = false
	Music.stream_paused = false
	_build_interface()
	for level in range(BACKGROUNDS.size()):
		for stage in range(3):
			# Los dos primeros escenarios del nivel 1 comparten la misma imagen.
			if level == 0 and stage == 1:
				continue
			_background_order.append(Vector2i(level, stage))
	_show_next_background()
	_background_timer = Timer.new()
	_background_timer.one_shot = true
	_background_timer.timeout.connect(_cycle_background)
	add_child(_background_timer)
	_background_fade.color.a = 1.0
	var fade := create_tween()
	fade.tween_property(_background_fade, "color:a", 0.0, FADE_DURATION)
	fade.tween_callback(_schedule_background)
	_show_panel(_main)


func _process(delta: float) -> void:
	if is_instance_valid(_background):
		_background.scroll_offset.x += delta * 12.0


func _show_next_background() -> void:
	if is_instance_valid(_background):
		remove_child(_background)
		_background.queue_free()
	_background_index = (_background_index + 1) % _background_order.size()
	var entry := _background_order[_background_index]
	_background = BACKGROUNDS[entry.x].instantiate() as LevelBackground
	if entry == Vector2i(0, 2):
		_background.set("cave_preview_texture", preload("res://level/cueva.png"))
	add_child(_background)
	_background.set_stage(entry.y)
	_backdrop_label.text = "NIVEL %d  /  ESCENARIO %d" % [entry.x + 1, entry.y + 1]


func _schedule_background() -> void:
	_background_timer.start(randf_range(MIN_BACKGROUND_SECONDS, MAX_BACKGROUND_SECONDS))


func _cycle_background() -> void:
	var fade := create_tween()
	fade.tween_property(_background_fade, "color:a", 1.0, FADE_DURATION)
	fade.tween_callback(_show_next_background)
	fade.tween_interval(0.15)
	fade.tween_property(_background_fade, "color:a", 0.0, FADE_DURATION)
	fade.tween_callback(_schedule_background)


func _build_interface() -> void:
	theme = preload("res://gui/theme.tres").duplicate()
	theme.default_font = preload("res://gui/fonts/DejaVuSans.ttf")
	theme.default_font_size = 17
	theme.set_font("font", "Button", theme.default_font)
	# El fundido cubre únicamente el paisaje; el menú sigue disponible.
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = -90
	add_child(fade_layer)
	_background_fade = ColorRect.new()
	_background_fade.color = Color.BLACK
	_background_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_background_fade)
	_background_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.05, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.075, 0.92)
	style.border_color = Color(0.63, 0.77, 0.86, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := _label("PLATFORMER 2D", 27)
	title.add_theme_color_override("font_color", Color(0.93, 0.8, 0.44))
	content.add_child(title)
	content.add_child(HSeparator.new())

	_main = _box(content)
	_continue_button = _button(_main, "Continuar", _on_continue)
	_continue_button.disabled = not GameState.has_continue()
	_continue_button.tooltip_text = "Reanuda la partida actual o abre el último nivel jugado."
	_button(_main, "Elegir nivel", _open_levels)
	_button(_main, "Opciones", _open_options)
	_button(_main, "Salir del juego", _quit_game)

	_levels = _box(content)
	_levels.add_child(_label("SELECCIÓN DE NIVEL", 17))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_levels.add_child(grid)
	for index in range(5):
		var button := _button(grid, "Nivel %d" % (index + 1), _start_selected_level.bind(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_level_buttons.append(button)
	_button(_levels, "Volver", _show_panel.bind(_main))

	_options = _box(content)
	_options.add_child(_label("OPCIONES", 17))
	_music_slider = _volume_control(_options, "Música", true)
	_effects_slider = _volume_control(_options, "Efectos de sonido", false)
	_fullscreen = CheckButton.new()
	_fullscreen.text = "Pantalla completa"
	_fullscreen.toggled.connect(_set_fullscreen)
	_options.add_child(_fullscreen)
	_button(_options, "Volver", _close_options)

	_backdrop_label = _label("", 12)
	_backdrop_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_backdrop_label.add_theme_constant_override("outline_size", 4)
	_backdrop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop_label)
	_backdrop_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_backdrop_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_backdrop_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_backdrop_label.position -= Vector2(20, 18)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _box(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	parent.add_child(box)
	return box


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 39
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _volume_control(parent: Node, text: String, music: bool) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(text, 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(label)
	var value := _label("100%", 15)
	row.add_child(value)
	if music:
		_music_value = value
	else:
		_effects_value = value
	var slider := HSlider.new()
	slider.custom_minimum_size.y = 28
	slider.max_value = 100
	slider.step = 1
	slider.value_changed.connect(_on_volume_changed.bind(music))
	parent.add_child(slider)
	return slider


func _show_panel(panel: VBoxContainer) -> void:
	for box: VBoxContainer in [_main, _levels, _options]:
		box.visible = box == panel
	for child in panel.get_children():
		if child is BaseButton and not child.disabled:
			child.grab_focus()
			break


func _open_levels() -> void:
	_show_panel(_levels)
	_level_buttons[0].grab_focus()


func _start_selected_level(index: int) -> void:
	if _transitioning:
		return
	_transitioning = true
	GameState.start_level(GameState.SINGLEPLAYER_LEVELS[index])


func _on_continue() -> void:
	if _transitioning:
		return
	_transitioning = true
	GameState.continue_game()


func _open_options() -> void:
	_music_slider.set_value_no_signal(AudioSettings.music_volume * 100.0)
	_effects_slider.set_value_no_signal(AudioSettings.effects_volume * 100.0)
	_music_value.text = "%d%%" % roundi(_music_slider.value)
	_effects_value.text = "%d%%" % roundi(_effects_slider.value)
	_fullscreen.set_pressed_no_signal(DisplayServer.window_get_mode() in [
		DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	])
	_show_panel(_options)
	_music_slider.grab_focus()


func _on_volume_changed(value: float, music: bool) -> void:
	if music:
		AudioSettings.set_music_volume(value / 100.0)
		_music_value.text = "%d%%" % roundi(value)
	else:
		AudioSettings.set_effects_volume(value / 100.0)
		_effects_value.text = "%d%%" % roundi(value)


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_fullscreen.set_pressed_no_signal(enabled)


func _close_options() -> void:
	AudioSettings.save_settings()
	_show_panel(_main)


func _quit_game() -> void:
	AudioSettings.save_settings()
	Music.quit_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_pause") or event.is_action_pressed("ui_cancel"):
		_close_options()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fullscreen"):
		_set_fullscreen(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED)
		get_viewport().set_input_as_handled()
