class_name DialogueEnemy extends CharacterBody2D
## NPC interactivo con diálogos RPG.
## - Al acercarse el jugador: se pausa y abre el diálogo automáticamente.
## - Tras la primera vez: se puede volver a ver tocando/haciendo click sobre el NPC.

@export var story_dialogue_id: String = ""
const STORY = preload("res://story/story_dialogues.gd")

@export var speaker_name: String = "ENEMIGO DEL NIVEL"
@export var dialogue_lines: Array = ["¡Hola! Bienvenid@ a este nivel."]
@export var portrait_texture: Texture2D

const DIALOGUE_BOX_SCENE := preload("res://level/dialogue_box.tscn")

@onready var prompt_label: Label       = $PromptLabel
@onready var sprite: Sprite2D          = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area2D  = $InteractionArea

var _player_in_range: CharacterBody2D = null
var _dialogue_box: DialogueBox         = null
var _first_time: bool                 = true   # controla el auto-trigger inicial
var _dialogue_pending := false


func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false
		prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)

	# Habilitar detección de tap / click sobre el sprite del NPC
	input_pickable = true
	input_event.connect(_on_body_input_event)
	_build_click_area()


func _build_click_area() -> void:
	# La colisión física está en los pies; el clic debe cubrir el sprite completo.
	var click_area := Area2D.new()
	click_area.name = "ClickArea"
	click_area.collision_layer = 2
	click_area.collision_mask = 0
	click_area.monitoring = false
	click_area.monitorable = false
	click_area.input_pickable = true
	click_area.transform = sprite.transform
	var bounds := sprite.get_rect()
	var rectangle := RectangleShape2D.new()
	rectangle.size = bounds.size
	var click_shape := CollisionShape2D.new()
	click_shape.shape = rectangle
	click_shape.position = bounds.get_center()
	click_area.add_child(click_shape)
	add_child(click_area)
	click_area.input_event.connect(_on_body_input_event)


func _on_body_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Tap en móvil o click en escritorio → abrir diálogo (siempre reutilizable)
	var is_tap   := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var is_click := event is InputEventMouseButton \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
		and (event as InputEventMouseButton).pressed
	if is_tap or is_click:
		if not is_instance_valid(_player_in_range) or get_tree().paused:
			return
		get_viewport().set_input_as_handled()
		_open_dialogue(true)


func _on_interaction_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	_player_in_range = body as CharacterBody2D
	if prompt_label:
		prompt_label.visible = true
	# Solo auto-abrir la primera vez que el jugador entra en rango
	if _first_time:
		_open_dialogue(true)


func _on_interaction_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		if prompt_label:
			prompt_label.visible = false


func _open_dialogue(require_in_range: bool = false) -> void:
	# No abrir si ya hay un diálogo activo
	if _dialogue_pending or (_dialogue_box and _dialogue_box._active):
		return
	_dialogue_pending = true
	if not await SceneFlow.wait_for_dialogue(self):
		_dialogue_pending = false
		return
	# A player may have left this NPC while the screen was transitioning.
	if require_in_range and (not is_instance_valid(_player_in_range) or _player_in_range._is_dead):
		SceneFlow.release_dialogue(self)
		_dialogue_pending = false
		return
	_dialogue_pending = false
	_first_time = false

	# Crear el DialogueBox si no existe
	if _dialogue_box == null:
		_dialogue_box = DIALOGUE_BOX_SCENE.instantiate()
		get_tree().current_scene.add_child(_dialogue_box)

	if _dialogue_box == null:
		SceneFlow.release_dialogue(self)
		return

	# Pausar el juego
	get_tree().paused = true

	# Reconectar señal (desconectar primero para no duplicar)
	if _dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_box.dialogue_finished.disconnect(_on_dialogue_finished)
	_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)

	var port_tex := portrait_texture
	if port_tex == null and sprite:
		port_tex = sprite.texture
	var lines: Array = STORY.lines(story_dialogue_id) if not story_dialogue_id.is_empty() else dialogue_lines
	_dialogue_box.start_dialogue(speaker_name, port_tex, lines)

	if prompt_label:
		prompt_label.visible = false


func _on_dialogue_finished() -> void:
	get_tree().paused = false
	SceneFlow.release_dialogue(self)
	RecipeCollection.complete_dialogue(story_dialogue_id)
	# Mostrar el prompt de nuevo si el jugador sigue cerca (indica que puede re-tocar)
	if prompt_label and _player_in_range:
		prompt_label.text = "Toca para volver a leer"
		prompt_label.visible = true
