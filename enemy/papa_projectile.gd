extends RigidBody2D

@export var speed: float = 450.0

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	gravity_scale = 0.0
	linear_velocity = direction.normalized() * speed
	rotation = direction.angle()

	await get_tree().create_timer(3.0).timeout
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		body.die()
		queue_free()
