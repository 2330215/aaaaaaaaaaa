class_name Coin extends Area2D
## Collectible that disappears when the player touches it.


@onready var animation_player := $AnimationPlayer as AnimationPlayer


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	animation_player.play(&"picked")
	(body as Player).coin_collected.emit()
