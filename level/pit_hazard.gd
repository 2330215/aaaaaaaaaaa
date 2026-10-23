class_name PitHazard extends Area2D
## Hazard area for a pit that detaches camera so player falls into the abyss, shows PERDISTE, and resets level.

@export var respawn_position: Vector2 = Vector2(128, 448)

@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
@onready var game_over_panel: Control = $CanvasLayer/GameOverPanel

var _triggered := false


func _ready() -> void:
	add_to_group("pit_hazard")
	# Seguir corriendo aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 0)
		fade_rect.visible = false
	if game_over_panel:
		game_over_panel.visible = false


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	trigger(body)


func trigger(body: Node2D) -> void:
	if _triggered:
		return
	_triggered = true

	# Usar el nuevo sistema de vidas (respawn en posición del hazard)
	var player := body as Player
	if player:
		player.die_from_pit(respawn_position)
	_triggered = false


## Muestra el panel PERDISTE, fundido y recarga el nivel (Game Over total).
func show_game_over_and_reload() -> void:
	if _triggered:
		return
	_triggered = true

	get_tree().paused = true

	# Pausa música
	var music_node = get_node_or_null("/root/Music")
	if music_node and music_node.has_method("stop"):
		music_node.stream_paused = true

	# Mostrar panel PERDISTE
	if game_over_panel:
		game_over_panel.modulate.a = 0.0
		game_over_panel.visible = true
		var tween_ui := create_tween()
		tween_ui.tween_property(game_over_panel, "modulate:a", 1.0, 0.4)
		await tween_ui.finished

	await get_tree().create_timer(1.8, true).timeout

	# Fade to black
	if fade_rect:
		fade_rect.visible = true
		var tween_fade := create_tween()
		tween_fade.tween_property(fade_rect, "color:a", 1.0, 1.0)
		await tween_fade.finished

	# Ocultar panel
	if game_over_panel:
		game_over_panel.visible = false

	# Reanudar árbol antes de recargar
	get_tree().paused = false
	if music_node:
		music_node.stream_paused = false

	get_tree().reload_current_scene()
	_triggered = false
