extends Node2D
## Burbuja visual que sigue el tiempo real de proteccion del jugador.

@export var radius: float = 76.0

var _pulse_time: float = 0.0
var _time_left: float = 0.0


func _ready() -> void:
	name = "ShieldEffect"
	position = Vector2(0.0, -14.0)
	z_index = 5
	refresh()


func refresh() -> void:
	_time_left = get_parent().shield_time_left
	visible = _time_left > 0.0
	if visible:
		queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	refresh()


func _draw() -> void:
	var pulse := 1.0 + sin(_pulse_time * 4.0) * 0.025
	var r := radius * pulse
	# Parpadeo suave durante el ultimo segundo para avisar que se acaba.
	var opacity := 1.0
	if _time_left <= 1.0:
		opacity = 0.45 + (sin(_pulse_time * 18.0) + 1.0) * 0.275
	draw_circle(Vector2.ZERO, r, Color(0.12, 0.65, 1.0, 0.12 * opacity))
	draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 96, Color(0.1, 0.6, 1.0, 0.18 * opacity), 9.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.35, 0.9, 1.0, 0.85 * opacity), 2.5, true)
	draw_arc(Vector2.ZERO, r - 7.0, -2.8, -1.7, 24, Color(0.8, 0.98, 1.0, 0.8 * opacity), 3.0, true)
	draw_arc(Vector2.ZERO, r - 5.0, 0.35, 0.95, 16, Color(0.55, 0.9, 1.0, 0.45 * opacity), 2.0, true)
