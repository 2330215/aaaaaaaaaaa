class_name LevelBackground3 extends LevelBackground

const LEVEL3_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/nivel3_parte1.png"),
	preload("res://level/background/level3_parte2.png"),
	preload("res://level/background/level3_parte3.png")
]


const CloudLayer = preload("res://level/background/moving_background_clouds.gd")

var _clouds: CloudLayer


func _ready() -> void:
	super._ready()
	_clouds = CloudLayer.new()
	_clouds.name = "MovingClouds"
	$Sky.add_child(_clouds)


func _process(delta: float) -> void:
	super._process(delta)
	_clouds.update_clouds(delta)


func _layout_sprites() -> void:
	var default_overscan := vertical_overscan
	# Mostrar mas paisaje en el primer escenario sin descubrir los bordes.
	if _current_stage == 0:
		vertical_overscan = 1.08
	super._layout_sprites()
	vertical_overscan = default_overscan


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
