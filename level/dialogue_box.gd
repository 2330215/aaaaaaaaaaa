class_name DialogueBox extends CanvasLayer
## RPG-style Dialogue Box (Celeste / Hotline Miami style) with typewriter text effect.

signal dialogue_finished()

enum TransitionEffect { FADE, WIPE }

@export var transition_effect: TransitionEffect = TransitionEffect.WIPE
## Cero elige automáticamente el entorno del nivel actual.
@export_range(0, 5) var environment_level: int = 0

const WIPE_IN_DURATION: float = 0.45
const WIPE_OUT_DURATION: float = 0.35
const FADE_IN_DURATION: float = 0.4
const FADE_OUT_DURATION: float = 0.3

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
var _transition_tween: Tween
var _is_opening: bool = false
var _is_closing: bool = false


func _ready() -> void:
	# Seguir procesando input aunque el juego esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	if panel:
		panel.visible = false
		panel.modulate.a = 0.0


func start_dialogue(speaker_name: String, portrait_tex: Texture2D, lines: Array) -> void:
	if lines.is_empty():
		return

	_apply_environment_theme()
	_lines.clear()
	for line_item in lines:
		_lines.append(str(line_item))

	if _transition_tween:
		_transition_tween.kill()
	if _type_tween:
		_type_tween.kill()
	_current_line_index = 0
	_active = true
	_is_typing = false
	_is_opening = true
	_is_closing = false

	if name_label:
		name_label.text = speaker_name
	if portrait_rect:
		portrait_rect.texture = portrait_tex
		portrait_rect.visible = portrait_tex != null

	# Preparar el contenido antes de mostrarlo para evitar destellos del diálogo anterior.
	_show_current_line()
	panel.modulate.a = 1.0 if transition_effect == TransitionEffect.WIPE else 0.0
	panel.set("reveal_progress", 0.0 if transition_effect == TransitionEffect.WIPE else 1.0)
	panel.visible = true
	_transition_tween = _transition_to(true)
	_transition_tween.finished.connect(_on_transition_in_finished)


func _apply_environment_theme() -> void:
	var level: int = environment_level if environment_level > 0 else GameState.current_level
	var palette: Dictionary = DialogueTheme.palette(level)
	($Panel/Border as ColorRect).color = palette["border"]
	$Panel/Background.apply_environment(level, palette)
	# Recursos independientes para que dos diálogos no compartan cambios de estilo.
	name_label.label_settings = _label_style(palette["font"], 20, palette["accent"])
	text_label.label_settings = _label_style(DialogueTheme.BODY_FONT, 17, palette["text"])
	prompt_label.label_settings = _label_style(DialogueTheme.BODY_FONT, 12, palette["muted"])


func _label_style(font: Font, font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = font_size
	settings.font_color = color
	return settings


func _transition_to(entering: bool) -> Tween:
	var target: float = 1.0 if entering else 0.0
	if transition_effect == TransitionEffect.FADE:
		return _fade_to(target, FADE_IN_DURATION if entering else FADE_OUT_DURATION)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(panel, "reveal_progress", target, WIPE_IN_DURATION if entering else WIPE_OUT_DURATION)
	return tween


func _fade_to(alpha: float, duration: float) -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(panel, "modulate:a", alpha, duration)
	return tween


func _on_transition_in_finished() -> void:
	_is_opening = false


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	# Solo avanza con click izquierdo (escritorio) o tap (móvil)
	var is_click := event is InputEventMouseButton \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
		and (event as InputEventMouseButton).pressed
	var is_tap := event is InputEventScreenTouch \
		and (event as InputEventScreenTouch).pressed

	if not (is_click or is_tap):
		return

	get_viewport().set_input_as_handled()
	if _is_opening or _is_closing:
		return
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
	if not _active or _is_closing:
		return
	_is_closing = true
	_is_opening = false
	_is_typing = false
	if _type_tween:
		_type_tween.kill()
	if _transition_tween:
		_transition_tween.kill()
	_transition_tween = _transition_to(false)
	_transition_tween.finished.connect(_on_transition_out_finished)


func _on_transition_out_finished() -> void:
	panel.visible = false
	_active = false
	_is_closing = false
	dialogue_finished.emit()
