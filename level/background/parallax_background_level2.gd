class_name LevelBackground2 extends LevelBackground

const LEVEL2_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/level2_parte1.png"),
	preload("res://level/background/level2_parte2.png"),
	preload("res://level/background/level2_parte3.png")
]


const CloudLayer = preload("res://level/background/moving_background_clouds.gd")
const AircraftLayer = preload("res://level/background/occasional_aircraft.gd")

var _clouds: CloudLayer
var _aircraft: AircraftLayer


func _ready() -> void:
	super._ready()
	_clouds = CloudLayer.new()
	_clouds.name = "MovingClouds"
	$Sky.add_child(_clouds)
	_aircraft = AircraftLayer.new()
	_aircraft.name = "OccasionalAircraft"
	_aircraft.sky_stages = [0, 1, 2]
	add_child(_aircraft)


func _process(delta: float) -> void:
	super._process(delta)
	_clouds.update_clouds(delta)
	_aircraft.update_aircraft(delta, _current_stage)


func _update_vertical_position() -> void:
	var overflow := maxf(0.0, _background_height - _last_viewport_size.y)
	var offset_y := -overflow * 0.5
	var camera := get_viewport().get_camera_2d()
	if camera and _current_stage < stage_vertical_motion.size():
		var start_y := stage_start_heights[_current_stage - 1] if _current_stage > 0 else 0.0
		offset_y -= (camera.get_screen_center_position().y - start_y) * camera.zoom.y * stage_vertical_motion[_current_stage]
	($Sky as ParallaxLayer).motion_offset.y = clampf(offset_y, -overflow, 0.0)


func _get_stage_textures() -> Array[Texture2D]:
	return LEVEL2_TEXTURES


func set_cave_mode(enabled: bool) -> void:
	set_stage(1 if enabled else 0)
