class_name Apple extends Area2D
## Manzana coleccionable: al tocarla el jugador gana +1 vida.
## Usa las mismas físicas y animación que la moneda (Coin).

@onready var animation_player := $AnimationPlayer as AnimationPlayer

var _collected := false


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not (body is Player):
		return
	_collected = true
	GameState.gain_life()
	animation_player.play(&"picked")
