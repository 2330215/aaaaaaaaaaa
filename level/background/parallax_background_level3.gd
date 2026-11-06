class_name LevelBackground3 extends LevelBackground

const LEVEL3_TEXTURES: Array[Texture2D] = [
	preload("res://level/rancho.png"),
	preload("res://level/background/level3_parte2.png"),
	preload("res://level/background/level3_parte3.png")
]


const CLOUD_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/nube_1.png"),
	preload("res://level/background/nube_2.png"),
	preload("res://level/background/nube_3.png"),
	preload("res://level/background/nube_4.png"),
	preload("res://level/background/nube_5.png")
]

var _clouds: Node2D
var _cloud_viewport_size := Vector2.ZERO


func _ready() -> void:
	super._ready()
	# Hijos directos del CanvasLayer: nubes en coordenadas de pantalla.
	_clouds = Node2D.new()
	_clouds.name = "MovingClouds"
	add_child(_clouds)
	for texture in CLOUD_TEXTURES:
		var cloud := Sprite2D.new()
		cloud.texture = texture
		_clouds.add_child(cloud)
	_layout_clouds()
	_clouds.visible = false


func _process(delta: float) -> void:
	super._process(delta)
	if _cloud_viewport_size != get_viewport().get_visible_rect().size:
		_layout_clouds()
	_clouds.visible = _current_stage == 2
	if not _clouds.visible:
		return
	for index in range(_clouds.get_child_count()):
		var cloud := _clouds.get_child(index) as Sprite2D
		var half_width := cloud.texture.get_width() * cloud.scale.x * 0.5
		cloud.position.x -= (12.0 + index * 4.0) * delta
		if cloud.position.x < -half_width:
			cloud.position.x = _cloud_viewport_size.x + half_width


func _layout_clouds() -> void:
	_cloud_viewport_size = get_viewport().get_visible_rect().size
	for index in range(_clouds.get_child_count()):
		var cloud := _clouds.get_child(index) as Sprite2D
		var factor := _cloud_viewport_size.y * (0.07 + index * 0.012) / cloud.texture.get_height()
		cloud.scale = Vector2.ONE * factor
		cloud.position = _cloud_viewport_size * Vector2((index + 0.5) / 5.0, 0.12 + index * 0.14)
		cloud.modulate.a = 0.65 + index * 0.06


func _update_vertical_position() -> void:
	# Cada zona tiene su propia imagen: reiniciar el paralaje al entrar.
	var overflow := maxf(0.0, _background_height - _last_viewport_size.y)
	var offset_y := -overflow * 0.5
	var camera := get_viewport().get_camera_2d()
	if camera and _current_stage < stage_vertical_motion.size():
		var start_y := stage_start_heights[_current_stage - 1] if _current_stage > 0 else 0.0
		offset_y -= (camera.get_screen_center_position().y - start_y) * camera.zoom.y * stage_vertical_motion[_current_stage]
	($Sky as ParallaxLayer).motion_offset.y = clampf(offset_y, -overflow, 0.0)


func _get_stage_textures() -> Array[Texture2D]:
	return LEVEL3_TEXTURES


func set_cave_mode(enabled: bool) -> void:
	set_stage(1 if enabled else 0)
