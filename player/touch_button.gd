class_name TouchButton
extends TextureButton

## Cada botón reserva su propio dedo, independiente del clic usado por los menús.
@export var action: String = ""
var _finger: int = -1
var _action_held: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	visibility_changed.connect(_release)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled or get_tree().paused:
		_release()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and _inside(event.position):
			_finger = event.index
			_on_button_down()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _finger:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _finger:
		if _inside(event.position):
			_on_button_down()
		else:
			_on_button_up()
		get_viewport().set_input_as_handled()

func _inside(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(get_global_transform_with_canvas().affine_inverse() * point)

func _process(_delta: float) -> void:
	if disabled or get_tree().paused:
		_release()

func _on_button_down() -> void:
	if action != "" and not _action_held:
		_action_held = true
		Input.action_press(action)

func _on_button_up() -> void:
	if _action_held:
		_action_held = false
		Input.action_release(action)

func _release() -> void:
	_finger = -1
	_on_button_up()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PAUSED:
		_release()
