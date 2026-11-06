extends Node2D
## Lluvia repartida por la pantalla actual; deja huecos para esquivarla.
const SPRINKLE_SCRIPT = preload("res://enemy/donut_sprinkle.gd")
var duration: float = 2.5
var interval: float = 0.15
var fall_speed: float = 330.0
var hazard_group := ""
var _age := 0.0
var _timer := 0.0
var _column := -1

func _ready() -> void:
	add_to_group("donut_rain")
	if not hazard_group.is_empty():
		add_to_group(hazard_group)

func _physics_process(delta: float) -> void:
	_age += delta
	_timer -= delta
	if _age > duration:
		queue_free()
		return
	if _timer > 0.0:
		return
	_timer = maxf(0.06, interval)
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var next_column := randi_range(0, 7)
	if next_column == _column:
		next_column = (_column + 3) % 8
	_column = next_column
	var x := rect.position.x + rect.size.x * (float(_column) + 0.5) / 8.0
	var spawn := viewport.get_canvas_transform().affine_inverse() * Vector2(x, rect.position.y + 12.0)
	var sprinkle = SPRINKLE_SCRIPT.new()
	sprinkle.fall_speed = fall_speed
	sprinkle.hazard_group = hazard_group
	var colors := [Color("ff71b3"), Color("ffe17b"), Color("8df4ea"), Color("b293ff"), Color("fff2ce")]
	sprinkle.tint = colors[randi_range(0, colors.size()-1)]
	var parent := get_parent()
	sprinkle.position = parent.to_local(spawn) if parent is Node2D else spawn
	parent.add_child(sprinkle)
