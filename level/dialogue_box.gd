class_name DialogueBox extends CanvasLayer
## RPG-style Dialogue Box (Celeste / Hotline Miami style) with typewriter text effect.

signal dialogue_finished()

@onready var panel: Control = $Panel
@onready var portrait_rect: TextureRect = $Panel/HBox/Portrait
@onready var name_label: Label = $Panel/HBox/VBox/NameLabel
@onready var text_label: Label = $Panel/HBox/VBox/TextLabel
@onready var prompt_label: Label = $Panel/HBox/VBox/PromptLabel

var _lines: Array[String] = []
var _current_line_index := 0
var _is_typing := false
var _active := false
var _type_tween: Tween


func _ready() -> void:
	if panel:
		panel.visible = false


func start_dialogue(speaker_name: String, portrait_tex: Texture2D, lines: Array) -> void:
	if lines.is_empty():
		return

	_lines.clear()
	for line_item in lines:
		_lines.append(str(line_item))

	_current_line_index = 0
	_active = true

	if name_label:
		name_label.text = speaker_name
	if portrait_rect and portrait_tex:
		portrait_rect.texture = portrait_tex

	if panel:
		panel.visible = true
		panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.25)

	_show_current_line()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed(&"shoot") or event.is_action_pressed(&"jump") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if _is_typing:
			# Skip typewriter animation, reveal full line
			if _type_tween:
				_type_tween.kill()
			_is_typing = false
			text_label.visible_characters = -1
		else:
			# Advance to next line or finish
			_current_line_index += 1
			if _current_line_index < _lines.size():
				_show_current_line()
			else:
				_finish_dialogue()


func _show_current_line() -> void:
	if _current_line_index >= _lines.size():
		_finish_dialogue()
		return

	_is_typing = true
	var line_text := _lines[_current_line_index]
	text_label.text = line_text
	text_label.visible_characters = 0

	if _type_tween:
		_type_tween.kill()

	_type_tween = create_tween()
	var duration := line_text.length() * 0.03
	_type_tween.tween_property(text_label, "visible_characters", line_text.length(), duration)
	_type_tween.finished.connect(func(): _is_typing = false)


func _finish_dialogue() -> void:
	_active = false
	if panel:
		var tween := create_tween()
		tween.tween_property(panel, "modulate:a", 0.0, 0.2)
		await tween.finished
		panel.visible = false

	dialogue_finished.emit()
