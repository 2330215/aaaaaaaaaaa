class_name DialogueEnemy extends CharacterBody2D
## Interactive NPC / Enemy that displays RPG-style dynamic dialogues when player approaches.

@export var speaker_name: String = "ENEMIGO DEL NIVEL"
@export var dialogue_lines: Array = ["¡Hola! Bienvenid@ a este nivel."]
@export var portrait_texture: Texture2D

@onready var prompt_label: Label = $PromptLabel
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area2D = $InteractionArea

var _player_in_range: CharacterBody2D = null
var _dialogue_box: Node = null


func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null:
		return

	if event.is_action_pressed(&"shoot") or event.is_action_pressed(&"jump") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_open_dialogue()


func _open_dialogue() -> void:
	if _dialogue_box == null:
		var scene = load("res://level/dialogue_box.tscn")
		if scene:
			_dialogue_box = scene.instantiate()
			get_tree().current_scene.add_child(_dialogue_box)

	if _dialogue_box and _dialogue_box.has_method("start_dialogue"):
		var port_tex = portrait_texture
		if port_tex == null and sprite:
			port_tex = sprite.texture
		_dialogue_box.start_dialogue(speaker_name, port_tex, dialogue_lines)


func _on_interaction_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = body as CharacterBody2D
		if prompt_label:
			prompt_label.visible = true


func _on_interaction_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		if prompt_label:
			prompt_label.visible = false
