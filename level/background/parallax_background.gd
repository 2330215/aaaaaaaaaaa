class_name LevelBackground extends ParallaxBackground

## Alturas donde comienzan la segunda y tercera zona del mapa.
@export var stage_start_heights: Array[float] = [1792.0, 3584.0]

## Desplazamiento vertical por escenario, en pixeles: positivo baja, negativo sube.
@export var stage_vertical_offsets: Array[float] = []
## Intensidad del movimiento vertical por escenario; 0 mantiene el fondo fijo.
@export var stage_vertical_motion: Array[float] = []
## Margen de imagen para desplazar el fondo sin descubrir sus bordes.
@export_range(1.0, 2.0, 0.05) var vertical_overscan: float = 1.0
## Alternar copias reflejadas une los bordes de las imagenes del nivel 1.
@export var mirror_horizontal_tiles: bool = false

const STAGE_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/Sky.webp"),
	preload("res://level/background/Sky.webp"),
	preload("res://level/background/cueva_1.webp")
]

var _current_stage: int = -1
var _last_viewport_size := Vector2.ZERO
var _background_height: float = 0.0


func _ready() -> void:
	add_to_group("level_background")
	set_stage(0)


func _process(_delta: float) -> void:
	# La camara actualiza scroll_offset; descartar siempre su componente vertical.
	scroll_offset.y = 0.0
	# Cada fondo sigue la camara de su viewport, incluso en pantalla dividida.
	var camera := get_viewport().get_camera_2d()
	if camera:
		var height := camera.global_position.y
		if camera.get_parent() is Player:
			height = (camera.get_parent() as Player).global_position.y
		set_stage(stage_for_height(height))
	if get_viewport().get_visible_rect().size != _last_viewport_size:
		_layout_sprites()
	_update_vertical_position()


func stage_for_height(height: float) -> int:
	var stage := 0
	for start_height in stage_start_heights:
		if height >= start_height:
			stage += 1
	return mini(stage, _get_stage_textures().size() - 1)


func _get_stage_textures() -> Array[Texture2D]:
	return STAGE_TEXTURES


func set_stage(stage_index: int) -> void:
	var textures := _get_stage_textures()
	stage_index = clampi(stage_index, 0, textures.size() - 1)
	if stage_index == _current_stage:
		return
	_current_stage = stage_index
	for child in $Sky.get_children():
		if child is Sprite2D:
			child.texture = textures[stage_index]
	for layer_name in ["Mountains1", "Mountains2"]:
		var mountains := get_node_or_null(NodePath(layer_name))
		if mountains:
			mountains.visible = stage_index != 2
	_layout_sprites()


func _layout_sprites() -> void:
	_last_viewport_size = get_viewport().get_visible_rect().size
	var texture := _get_stage_textures()[_current_stage]
	var texture_size := texture.get_size()
	var factor := maxf(_last_viewport_size.x / texture_size.x, _last_viewport_size.y * vertical_overscan / texture_size.y)
	_background_height = texture_size.y * factor
	var width := texture_size.x * factor
	var sky := $Sky as ParallaxLayer
	# El fondo permanece a la altura de la pantalla; no se desplaza fuera al bajar.
	scroll_offset.y = 0.0
	scroll_base_scale.y = 0.0
	sky.motion_scale.y = 0.0
	sky.motion_mirroring = Vector2(width * 2.0 if mirror_horizontal_tiles else width, 0.0)
	var index := 0
	for child in sky.get_children():
		if child is Sprite2D:
			if mirror_horizontal_tiles and index >= 2:
				child.visible = false
				continue
			child.visible = true
			child.centered = false
			child.scale = Vector2.ONE * factor
			child.position = Vector2((index - 1) * width, 0.0)
			if mirror_horizontal_tiles:
				child.position.x = 0.0 if index == 0 else width * 2.0
				child.scale.x = factor if index == 0 else -factor
			index += 1
	_update_vertical_position()


func _update_vertical_position() -> void:
	var overflow := maxf(0.0, _background_height - _last_viewport_size.y)
	var vertical_offset := -overflow * 0.5
	if _current_stage < stage_vertical_offsets.size():
		vertical_offset += stage_vertical_offsets[_current_stage]
	var camera := get_viewport().get_camera_2d()
	if camera and _current_stage < stage_vertical_motion.size():
		var stage_start := 0.0
		# Los dos escenarios de cielo comparten tambien el encuadre vertical.
		if _current_stage > 0 and _current_stage - 1 < stage_start_heights.size() and not (mirror_horizontal_tiles and _current_stage == 1):
			stage_start = stage_start_heights[_current_stage - 1]
		vertical_offset -= (camera.get_screen_center_position().y - stage_start) * camera.zoom.y * stage_vertical_motion[_current_stage]
	# Limitar el recorrido al margen disponible: nunca mostrar espacio vacio.
	($Sky as ParallaxLayer).motion_offset.y = clampf(vertical_offset, -overflow, 0.0)


func align_to_stage(stage_index: int) -> void:
	# Compatibilidad con las puertas y el menu de teletransporte.
	set_stage(stage_index)
