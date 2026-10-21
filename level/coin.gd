class_name Coin extends Area2D
## Collectible that disappears when the player touches it.
## Con special_recharge = true, además llena la carga del ataque especial.

## Si es verdadero, esta moneda recarga el ataque especial al máximo.
@export var special_recharge: bool = false

@onready var animation_player := $AnimationPlayer as AnimationPlayer
@onready var sprite := $Sprite2D as Sprite2D
@onready var recharge_label := get_node_or_null(^"RechargeLabel") as Label

var _collected := false


func _ready() -> void:
	if special_recharge:
		sprite.self_modulate = Color(0.25, 0.9, 1.0, 1.0)
		sprite.scale *= 1.35
		if recharge_label:
			recharge_label.visible = true


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not (body is Player):
		return
	_collected = true
	GameState.record_coin()
	animation_player.play(&"picked")
	(body as Player).coin_collected.emit()
	if special_recharge:
		(body as Player).recharge_special_attack()
