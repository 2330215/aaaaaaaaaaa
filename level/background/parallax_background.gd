class_name LevelBackground extends ParallaxBackground

## Alturas donde comienzan la segunda y tercera zona del mapa.
@export var stage_start_heights: Array[float] = [1792.0, 3584.0]

const STAGE_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/Sky.webp"),
	preload("res://level/background/sky1.webp"),
	preload("res://level/background/cueva_1.webp")
]

var _current_stage: int = -1
var _last_viewport_size := Vector2.ZERO


func _ready() -> void:
	add_to_group("level_background")
	set_stage(0)


func _process(_delta: float) -> void:
	# Cada fondo sigue la camara de su viewport, incluso en pantalla dividida.
	var camera := get_viewport().get_camera_2d()
	if camera:
		var height := camera.global_position.y
		if camera.get_parent() is Player:
			height = (camera.get_parent() as Player).global_position.y
		set_stage(stage_for_height(height))
	if get_viewport().get_visible_rect().size != _last_viewport_size:
		_layout_sprites()


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
	var factor := maxf(_last_viewport_size.x / texture_size.x, _last_viewport_size.y / texture_size.y)
	var width := texture_size.x * factor
	var sky := $Sky as ParallaxLayer
	# El fondo permanece a la altura de la pantalla; no se desplaza fuera al bajar.
	scroll_offset.y = 0.0
	scroll_base_scale.y = 0.0
	sky.motion_scale.y = 0.0
	sky.motion_mirroring = Vector2(width, 0.0)
	var index := 0
	for child in sky.get_children():
		if child is Sprite2D:
			child.visible = true
			child.centered = false
			child.scale = Vector2.ONE * factor
			child.position = Vector2((index - 1) * width, 0.0)
			index += 1


func align_to_stage(stage_index: int) -> void:
	# Compatibilidad con las puertas y el menu de teletransporte.
	set_stage(stage_index)
