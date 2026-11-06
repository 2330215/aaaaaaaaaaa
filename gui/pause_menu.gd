class_name PauseMenu extends Control


@export var fade_in_duration := 0.3
@export var fade_out_duration := 0.2

@onready var center_cont := $ColorRect/CenterContainer as CenterContainer
@onready var resume_button := center_cont.get_node(^"VBoxContainer/ResumeButton") as Button
@onready var coins_counter := $ColorRect/CoinsCounter as CoinsCounter

## Escenas disponibles en el selector de niveles.
const SCENE_SP_L1 := "res://game_singleplayer.tscn"
const SCENE_SP_L2 := "res://game_singleplayer_level2.tscn"
const SCENE_SP_L3 := "res://game_singleplayer_level3.tscn"
const SCENE_SP_L4 := "res://game_singleplayer_level4.tscn"
const SCENE_SS_L1 := "res://game_splitscreen.tscn"
const SCENE_SS_L2 := "res://game_splitscreen_level2.tscn"


func _ready() -> void:
	hide()


func close() -> void:
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


func open() -> void:
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


func _on_singleplayer_button_pressed() -> void:
	if visible:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://game_singleplayer.tscn")


func _on_splitscreen_button_pressed() -> void:
	if visible:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://game_splitscreen.tscn")


func _on_quit_button_pressed() -> void:
	if visible:
		get_tree().quit()


func _on_goto_level1_pressed() -> void:
	if not visible:
		return
	get_tree().paused = false
	var scene := get_tree().current_scene
	var is_split := scene != null and scene.name.to_lower().contains("splitscreen")
	get_tree().change_scene_to_file(SCENE_SS_L1 if is_split else SCENE_SP_L1)


func _on_goto_level2_pressed() -> void:
	if not visible:
		return
	get_tree().paused = false
	var scene := get_tree().current_scene
	var is_split := scene != null and scene.name.to_lower().contains("splitscreen")
	get_tree().change_scene_to_file(SCENE_SS_L2 if is_split else SCENE_SP_L2)


func _on_goto_level3_pressed() -> void:
	if not visible:
		return
	get_tree().paused = false
	var scene := get_tree().current_scene
	var is_split := scene != null and scene.name.to_lower().contains("splitscreen")
	get_tree().change_scene_to_file(SCENE_SP_L3)


func _on_goto_level4_pressed() -> void:
	if not visible:
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_SP_L4)
