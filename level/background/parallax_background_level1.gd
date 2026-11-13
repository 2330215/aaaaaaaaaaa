extends LevelBackground

@export var cave_preview_texture: Texture2D

const LEVEL1_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/nivel1_parte1.png"),
	preload("res://level/background/nivel1_parte1.png"),
	null
]
const CloudLayer = preload("res://level/background/moving_background_clouds.gd")

var _clouds: CloudLayer


func _ready() -> void:
	super._ready()
	_clouds = CloudLayer.new()
	_clouds.name = "MovingClouds"
	$Sky.add_child(_clouds)
	_clouds.visible = _current_stage < 2


func _process(delta: float) -> void:
	super._process(delta)
	_clouds.update_clouds(delta)


func _get_stage_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = LEVEL1_TEXTURES.duplicate()
	textures[2] = cave_preview_texture
	return textures


func set_stage(stage_index: int) -> void:
	super.set_stage(stage_index)
	if is_instance_valid(_clouds):
		_clouds.visible = _current_stage < 2
