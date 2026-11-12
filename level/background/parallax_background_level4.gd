extends LevelBackground

const LEVEL4_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/nivel4_1.png"),
	preload("res://level/background/nivel4_2.png"),
	preload("res://level/background/nivel4_3.png")
]


const SeasideLayer = preload("res://level/background/moving_seaside_background.gd")
const AircraftLayer = preload("res://level/background/occasional_aircraft.gd")

var _seaside: SeasideLayer
var _aircraft: AircraftLayer


func _ready() -> void:
	super._ready()
	_seaside = SeasideLayer.new()
	_seaside.name = "MovingSeaside"
	$Sky.add_child(_seaside)
	_sync_seaside()
	_aircraft = AircraftLayer.new()
	_aircraft.name = "OccasionalAircraft"
	add_child(_aircraft)


func _process(delta: float) -> void:
	super._process(delta)
	_sync_seaside()
	_seaside.animate(delta)
	_aircraft.update_aircraft(delta, _current_stage)


func _sync_seaside() -> void:
	_seaside.visible = _current_stage < 2
	if _seaside.visible:
		_seaside.configure(($Sky as ParallaxLayer).motion_mirroring.x, _background_height)


func _get_stage_textures() -> Array[Texture2D]:
	return LEVEL4_TEXTURES
