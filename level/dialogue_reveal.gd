extends Control
## Máscara que revela juntos el fondo, el retrato y el texto del diálogo.

var reveal_progress: float = 1.0:
	set(value):
		reveal_progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * reveal_progress, size.y)), Color.WHITE)
