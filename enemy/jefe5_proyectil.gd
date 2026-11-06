## Proyectil buscador del Jefe. Persigue al jugador con un tween cúbico
## y crece mientras vuela. Al impactar o al expirar se destruye.
extends Area2D

@onready var animated_sprite_2d := $AnimatedSprite2D as AnimatedSprite2D

var speed: float = 450.0


func _ready() -> void:
	var nodes := get_tree().get_nodes_in_group("player")
	var player := nodes[0] as Node2D if nodes.size() > 0 else null
	if not is_instance_valid(player):
		queue_free()
		return

	var distance := position.distance_to(player.global_position)
	var duration := distance / speed

	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", player.global_position, duration) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", scale * 3.0, duration)
	tween.set_parallel(false)
	tween.tween_property(animated_sprite_2d, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		(body as Player).die()
		queue_free()
