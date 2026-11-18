class_name PauseMenu extends Control


@export var fade_in_duration := 0.3
@export var fade_out_duration := 0.2

@onready var center_cont := $ColorRect/CenterContainer as CenterContainer
@onready var resume_button := center_cont.get_node(^"VBoxContainer/ResumeButton") as Button
@onready var coins_counter := $ColorRect/CoinsCounter as CoinsCounter


var _categories: VBoxContainer

@onready var main_options: VBoxContainer = center_cont.get_node("VBoxContainer")
@onready var settings_panel: PanelContainer = center_cont.get_node("AudioSettings")
@onready var settings_content: VBoxContainer = settings_panel.get_node("Margin/Content")
@onready var music_slider: HSlider = settings_content.get_node("MusicSlider")
@onready var effects_slider: HSlider = settings_content.get_node("EffectsSlider")
@onready var music_value: Label = settings_content.get_node("MusicRow/Value")
@onready var effects_value: Label = settings_content.get_node("EffectsRow/Value")


func _ready() -> void:
	hide()
	_categories = VBoxContainer.new()
	center_cont.add_child(_categories)
	_categories.hide()
	for text: String in ["Audio", "Controles", "Borrar partida local", "Volver"]:
		var button := Button.new()
		button.text = text
		button.custom_minimum_size = Vector2(260, 39)
		_categories.add_child(button)
		match text:
			"Audio": button.pressed.connect(_open_audio)
			"Controles": button.pressed.connect(func() -> void: preload("res://gui/control_editor.gd").open(self))
			"Borrar partida local": button.pressed.connect(_open_delete_save)
			"Volver": button.pressed.connect(_show_main_options)
	_categories.add_child(ControlSettings.create_cheats_button())
	_categories.move_child(_categories.get_child(-1), 2)
	ControlSettings.cheats_changed.connect(_refresh_level_buttons)
	# Colocar Ajustes junto a Reanudar también en las escenas heredadas.
	main_options.move_child(main_options.get_node("SettingsButton"), 3)
	var collection_button := Button.new()
	collection_button.name = "CollectiblesButton"
	collection_button.text = "Coleccionables"
	collection_button.custom_minimum_size.y = 34
	collection_button.pressed.connect(_open_collectibles)
	main_options.add_child(collection_button)
	main_options.move_child(collection_button, main_options.get_node("SettingsButton").get_index() + 1)
	music_slider.value_changed.connect(_on_music_volume_changed)
	effects_slider.value_changed.connect(_on_effects_volume_changed)
	settings_content.get_node("BackButton").pressed.connect(_on_settings_button_pressed)
	GameState.progress_changed.connect(_refresh_level_buttons)
	_refresh_level_buttons()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()


func _update_responsive_layout() -> void:
	if not is_node_ready():
		return
	# Usar el área lógica: Godot ya aplica el escalado de la ventana.
	var ui_scale := minf(size.x / 800.0, size.y / 480.0)
	var button_width := minf(size.x * 0.8, 306.0 * ui_scale)
	for box: VBoxContainer in [main_options, _categories]:
		var button_count := 0
		var heading_count := 0
		for child in box.get_children():
			if child is Control and child.visible:
				if child is Button:
					button_count += 1
				elif child is Label or child is HSeparator:
					heading_count += 1
		var gap := 8.0 * ui_scale
		var available_height := size.y * 0.86 - heading_count * 32.0 * ui_scale
		var button_height := minf(43.0 * ui_scale, (available_height - gap * (button_count + heading_count)) / maxi(button_count, 1))
		var font_size := maxi(1, roundi(minf(23.0 * ui_scale, button_height * 0.65)))
		box.add_theme_constant_override("separation", roundi(gap))
		for child in box.get_children():
			if child is Button:
				child.custom_minimum_size = Vector2(button_width, button_height)
				child.size_flags_horizontal = Control.SIZE_FILL
				child.add_theme_font_size_override("font_size", font_size)
			elif child is Label:
				child.add_theme_font_size_override("font_size", font_size)
	settings_panel.custom_minimum_size.x = minf(size.x * 0.9, 420.0 * ui_scale)
	settings_panel.add_theme_font_size_override("font_size", maxi(1, roundi(22.0 * ui_scale)))


func close() -> void:
	AudioSettings.save_settings()
	var tween := create_tween()
	get_tree().paused = false
	tween.tween_property(
		self,
		^"modulate:a",
		0.0,
		fade_out_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		center_cont,
		^"anchor_bottom",
		0.5,
		fade_out_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(hide)


func _open_collectibles() -> void:
	AudioSettings.save_settings()
	hide()
	# La libreta mantiene su propia pausa y al cerrarse reanuda la partida.
	get_tree().paused = false
	RecipeCollection.open_notebook(get_parent())


func open() -> void:
	_refresh_level_buttons()
	_show_main_options()
	show()
	resume_button.grab_focus()

	modulate.a = 0.0
	center_cont.anchor_bottom = 0.5
	var tween := create_tween()
	tween.tween_property(
		self,
		^"modulate:a",
		1.0,
		fade_in_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
		center_cont,
		^"anchor_bottom",
		1.0,
		fade_out_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_coin_collected() -> void:
	coins_counter.collect_coin()


func _on_resume_button_pressed() -> void:
	close()


func _on_quit_button_pressed() -> void:
	if visible:
		GameState.return_to_title()


func _refresh_level_buttons() -> void:
	for node_name: String in ["HSeparatorLevels", "LevelLabel"]:
		var heading := main_options.get_node_or_null(node_name) as Control
		if heading:
			heading.visible = ControlSettings.cheats_enabled
	for number in range(1,6):
		var button := main_options.get_node_or_null("Level%dButton" % number) as Button
		if button == null:
			continue
		button.visible = ControlSettings.cheats_enabled
		var unlocked := GameState.is_level_unlocked(number)
		button.disabled = not unlocked
		button.text = "Nivel %d" % number if unlocked else "Nivel %d · Bloqueado" % number
		button.tooltip_text = "" if unlocked else "Completa el nivel %d para desbloquearlo." % (number-1)
	_update_responsive_layout()


func _go_to_level(number: int) -> void:
	if not ControlSettings.cheats_enabled or not visible or not GameState.is_level_unlocked(number):
		return
	GameState.start_level(GameState.SINGLEPLAYER_LEVELS[number - 1])


func _on_goto_level1_pressed() -> void:
	_go_to_level(1)


func _on_goto_level2_pressed() -> void:
	_go_to_level(2)


func _on_goto_level3_pressed() -> void:
	_go_to_level(3)


func _on_goto_level4_pressed() -> void:
	_go_to_level(4)


func _on_goto_level5_pressed() -> void:
	_go_to_level(5)


func _open_delete_save() -> void:
	preload("res://gui/delete_save_dialog.gd").open(self)


func _on_settings_button_pressed() -> void:
	AudioSettings.save_settings()
	main_options.hide()
	settings_panel.hide()
	_categories.show()
	(_categories.get_child(0) as Button).grab_focus()


func _open_audio() -> void:
	_categories.hide()
	music_slider.set_value_no_signal(AudioSettings.music_volume * 100.0)
	effects_slider.set_value_no_signal(AudioSettings.effects_volume * 100.0)
	_update_volume_labels()
	main_options.hide()
	settings_panel.show()
	music_slider.grab_focus()


func _show_main_options() -> void:
	_categories.hide()
	if settings_panel.visible:
		AudioSettings.save_settings()
	settings_panel.hide()
	main_options.show()
	if visible:
		main_options.get_node("SettingsButton").grab_focus()


func _on_music_volume_changed(value: float) -> void:
	AudioSettings.set_music_volume(value / 100.0)
	_update_volume_labels()


func _on_effects_volume_changed(value: float) -> void:
	AudioSettings.set_effects_volume(value / 100.0)
	_update_volume_labels()


func _update_volume_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value)
	effects_value.text = "%d%%" % roundi(effects_slider.value)
