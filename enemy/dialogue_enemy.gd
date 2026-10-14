class_name DialogueEnemy extends CharacterBody2D
## NPC interactivo con diálogos RPG.
## - Al acercarse el jugador: se pausa y abre el diálogo automáticamente.
## - Tras la primera vez: se puede volver a ver tocando/haciendo click sobre el NPC.

@export var speaker_name: String = "ENEMIGO DEL NIVEL"
@export var dialogue_lines: Array = ["¡Hola! Bienvenid@ a este nivel."]
@export var portrait_texture: Texture2D

@onready var prompt_label: Label       = $PromptLabel
@onready var sprite: Sprite2D          = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area2D  = $InteractionArea

var _player_in_range: CharacterBody2D = null
var _dialogue_box: Node               = null
var _first_time: bool                 = true   # controla el auto-trigger inicial


func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

	# Habilitar detección de tap / click sobre el sprite del NPC
	input_pickable = true
	input_event.connect(_on_body_input_event)


func _on_body_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Tap en móvil o click en escritorio → abrir diálogo (siempre reutilizable)
	var is_tap   := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var is_click := event is InputEventMouseButton \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
		and (event as InputEventMouseButton).pressed
	if is_tap or is_click:
		if _player_in_range == null:
			return
		_open_dialogue()


func _on_interaction_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	_player_in_range = body as CharacterBody2D
	if prompt_label:
		prompt_label.visible = true
	# Solo auto-abrir la primera vez que el jugador entra en rango
	if _first_time:
		_first_time = false
		_open_dialogue()


func _on_interaction_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		if prompt_label:
			prompt_label.visible = false


func _open_dialogue() -> void:
	# No abrir si ya hay un diálogo activo
	if _dialogue_box and _dialogue_box.get("_active") == true:
		return

	# Crear el DialogueBox si no existe
	if _dialogue_box == null:
		var scene = load("res://level/dialogue_box.tscn")
		if scene:
			_dialogue_box = scene.instantiate()
			get_tree().current_scene.add_child(_dialogue_box)

	if not (_dialogue_box and _dialogue_box.has_method("start_dialogue")):
		return

	# Pausar el juego
	get_tree().paused = true

	# Reconectar señal (desconectar primero para no duplicar)
	if _dialogue_box.has_signal("dialogue_finished"):
		if _dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
			_dialogue_box.dialogue_finished.disconnect(_on_dialogue_finished)
		_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)

	var port_tex := portrait_texture
	if port_tex == null and sprite:
		port_tex = sprite.texture
	_dialogue_box.start_dialogue(speaker_name, port_tex, dialogue_lines)

	if prompt_label:
		prompt_label.visible = false


func _on_dialogue_finished() -> void:
	get_tree().paused = false
	# Mostrar el prompt de nuevo si el jugador sigue cerca (indica que puede re-tocar)
	if prompt_label and _player_in_range:
		prompt_label.text = "Toca para volver a leer"
		prompt_label.visible = true
