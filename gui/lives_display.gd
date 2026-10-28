extends CanvasLayer
## HUD de vidas estilo contador: icono - x - número de vidas.
## Se conecta a GameState.life_lost y GameState.life_gained para actualizarse.

@onready var lives_label := $Container/LivesLabel as Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	GameState.life_lost.connect(_on_lives_changed)
	GameState.life_gained.connect(_on_lives_changed)

	_refresh(GameState.lives)


func _on_lives_changed(lives_remaining: int) -> void:
	_refresh(lives_remaining)


func _refresh(lives_remaining: int) -> void:
	lives_label.text = "x%d" % lives_remaining
	# Pequeña animación de pulso al cambiar
	var tween := lives_label.create_tween()
	tween.tween_property(lives_label, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(lives_label, "scale", Vector2(1.0, 1.0), 0.12)
