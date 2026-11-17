extends LevelBackground

const LEVEL5_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/nivel5_1.png"),
	preload("res://level/background/nivel5_2.png"),
	preload("res://level/background/nivel5_3.png")
]


func _get_stage_textures() -> Array[Texture2D]:
	return LEVEL5_TEXTURES


const CloudLayer = preload("res://level/background/moving_background_clouds.gd")
const AircraftLayer = preload("res://level/background/occasional_aircraft.gd")
const LakeLayer = preload("res://level/background/moving_lake_background.gd")

var _clouds: CloudLayer
var _aircraft: AircraftLayer
var _lake: LakeLayer


func _ready() -> void:
	super._ready()
	_lake = LakeLayer.new()
	_lake.name = "MovingLakes"
	$Sky.add_child(_lake)
	_clouds = CloudLayer.new()
	_clouds.name = "MovingClouds"
	$Sky.add_child(_clouds)
	_aircraft = AircraftLayer.new()
	_aircraft.name = "OccasionalAirplane"
	_aircraft.airplane_only = true
	_aircraft.rarity = 3.0
	add_child(_aircraft)
	_sync_landscape()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_landscape()
	_lake.animate(delta)
	_clouds.update_clouds(delta)
	_aircraft.update_aircraft(delta, _current_stage)


func _sync_landscape() -> void:
	_clouds.visible = _current_stage == 0
	_lake.visible = _current_stage < 2
	if _lake.visible:
		_lake.configure(_current_stage, ($Sky as ParallaxLayer).motion_mirroring.x * 0.5, _background_height)
