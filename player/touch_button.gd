# touch_button.gd
class_name TouchButton
extends TextureButton

## Nombre de la acción del InputMap a simular (ej: "jump", "shoot", "move_left").
@export var action := ""

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_button_down() -> void:
	if action != "":
		Input.action_press(action)

func _on_button_up() -> void:
	if action != "":
		Input.action_release(action)

func _notification(what: int) -> void:
	# Si el botón se oculta/destruye mientras está pulsado, soltamos la acción
	# para que el personaje no se quede caminando o disparando solo.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_on_button_up()
