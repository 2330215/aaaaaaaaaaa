class_name GameOverScreen extends CanvasLayer
## Pantalla de Game Over. Muestra "PERDISTE" con fade-in, congela el juego
## 2 segundos antes de que el juego reinicie el escenario.

@onready var panel: Control = $GameOverPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false


## Muestra la pantalla de Game Over y espera 2 segundos con el juego pausado.
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
