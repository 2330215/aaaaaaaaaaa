extends Control
## Control táctil con un dedo reservado; los demás quedan libres para disparar.
const BASE := preload("res://gui/joy.png")
const KNOB := preload("res://gui/joy2.png")
const ACTIONS := [&"move_left", &"move_right", &"jump", &"move_down"]
var _finger: int = -1
var _mouse_drag := false
var _direction := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(release)

func _draw() -> void:
	draw_texture_rect(BASE, Rect2(Vector2.ZERO, size), false)
	var knob_size := size * 0.45
	draw_texture_rect(KNOB, Rect2(size * 0.5 + _direction * size.x * 0.28 - knob_size * 0.5, knob_size), false)

func _process(_delta: float) -> void:
	if get_tree().paused and (_finger != -1 or _mouse_drag):
		release()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and _inside(event.position):
			_finger = event.index
			_update_direction(event.position)
		elif not event.pressed and event.index == _finger:
			release()
	elif event is InputEventScreenDrag and event.index == _finger:
		_update_direction(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _inside(event.position) and _finger == -1:
			_mouse_drag = true
			_update_direction(event.position)
		elif not event.pressed and _mouse_drag:
			release()
	elif event is InputEventMouseMotion and _mouse_drag:
		_update_direction(event.position)

func _inside(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(get_global_transform_with_canvas().affine_inverse() * point)

func _update_direction(point: Vector2) -> void:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	_direction = ((local - size * 0.5) / (size.x * 0.35)).limit_length()
	if _direction.length() < 0.18:
		_direction = Vector2.ZERO
	var strengths := [-_direction.x, _direction.x, -_direction.y, _direction.y]
	for index in range(ACTIONS.size()):
		if strengths[index] > 0.0:
			Input.action_press(ACTIONS[index], strengths[index])
		else:
			Input.action_release(ACTIONS[index])
	queue_redraw()

func release() -> void:
	if _finger == -1 and not _mouse_drag and _direction == Vector2.ZERO:
		return
	_finger = -1
	_mouse_drag = false
	_direction = Vector2.ZERO
	for action in ACTIONS:
		Input.action_release(action)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		release()
