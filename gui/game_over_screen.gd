class_name GameOverScreen extends CanvasLayer
## Pantalla de Game Over. Muestra "PERDISTE" con fade-in, congela el juego
## 2 segundos y luego reinicia el nivel desde el principio.

@onready var panel: Control = $GameOverPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false


## Muestra la pantalla de Game Over, pausa 2 s y reinicia el nivel.
func show_game_over() -> void:
	panel.visible = true
	panel.modulate.a = 0.0

	# Fade-in del panel (process_mode=ALWAYS: sigue corriendo aunque el árbol esté pausado)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.5)
	await tween.finished

	# Congelar todo el juego
	get_tree().paused = true

	# Esperar 2 segundos; el argumento `true` hace que el timer ignore la pausa
	await get_tree().create_timer(2.0, true).timeout

	# Descongelar, limpiar estado persistente y recargar el nivel desde cero
	get_tree().paused = false
	GameState.used_special_coins.clear()
	get_tree().reload_current_scene()
