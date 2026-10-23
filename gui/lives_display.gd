extends CanvasLayer
## HUD de vidas estilo Metal Slug: muestra 3 corazones en la esquina superior derecha.
## Se conecta a GameState.life_lost para actualizar visualmente.

@onready var hearts: Array[Label] = []

const HEART_FULL  := "❤"
const HEART_EMPTY := "🖤"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Recoger los 3 Labels de corazón por nombre
	for i in range(1, 4):
		var heart := find_child("Heart%d" % i, true, false) as Label
		if heart:
			hearts.append(heart)

	# Conectar señal de GameState
	GameState.life_lost.connect(_on_life_lost)

	# Dibujar estado inicial
	_refresh(GameState.lives)


func _on_life_lost(lives_remaining: int) -> void:
	_refresh(lives_remaining)


func _refresh(lives_remaining: int) -> void:
	for i in hearts.size():
		var heart := hearts[i]
		if i < lives_remaining:
			# Corazón lleno: rojo vivo
			heart.modulate = Color(1.0, 0.25, 0.35, 1.0)
		else:
			# Corazón perdido: animación rápida de "romperse" y se vuelve gris
			var tween := heart.create_tween()
			tween.tween_property(heart, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.05)
			tween.tween_property(heart, "modulate", Color(0.3, 0.3, 0.3, 0.5), 0.2)
