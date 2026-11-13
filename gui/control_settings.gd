extends Node
## Distribución relativa al área visible; compartida por el juego y el editor.
signal changed

const PATH := "user://controls.cfg"
const IDS := ["Joystick", "TextureButtonJump", "TextureButtonAttack1", "TextureButtonAttack2"]
const TITLES := ["Movimiento", "Salto", "Disparo", "Especial"]
const SIZES := [Vector2(128, 128), Vector2(64, 64), Vector2(86, 86), Vector2(64, 64)]
const DEFAULTS := [Vector2(0.12, 0.81), Vector2(0.77, 0.86), Vector2(0.89, 0.69), Vector2(0.93, 0.88)]
var positions: Array[Vector2] = []
var opacity: float = 0.65

func _ready() -> void:
	positions.assign(DEFAULTS)
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		opacity = clampf(float(config.get_value("controls", "opacity", 0.65)), 0.2, 1.0)
		for index in range(IDS.size()):
			var value: Variant = config.get_value("controls", IDS[index], DEFAULTS[index])
			if value is Vector2:
				positions[index] = value.clamp(Vector2.ZERO, Vector2.ONE)

func control_rect(index: int, area: Vector2) -> Rect2:
	var extent: Vector2 = SIZES[index] * minf(1.0, minf(area.x / 800.0, area.y / 480.0))
	var origin := (positions[index] * area - extent * 0.5).clamp(Vector2(8, 8), (area - extent - Vector2(8, 8)).max(Vector2(8, 8)))
	return Rect2(origin, extent)

func update_position(index: int, value: Vector2) -> void:
	positions[index] = value.clamp(Vector2.ZERO, Vector2.ONE)
	changed.emit()

func update_opacity(value: float) -> void:
	opacity = clampf(value, 0.2, 1.0)
	changed.emit()

func reset() -> void:
	positions.assign(DEFAULTS)
	opacity = 0.65
	changed.emit()

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "opacity", opacity)
	for index in range(IDS.size()):
		config.set_value("controls", IDS[index], positions[index])
	var error := config.save(PATH)
	if error != OK:
		push_warning("No se pudieron guardar los controles: %s" % error_string(error))
