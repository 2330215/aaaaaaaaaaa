class_name ShieldPickup extends Area2D

@export var shield_duration: float = 5.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _collected := false


func _on_body_entered(body: Node2D) -> void:
	if _collected or not (body is Player):
		return

	_collected = true
	set_deferred("monitoring", false)

	(body as Player).activate_shield(shield_duration)
	animation_player.play(&"picked")
