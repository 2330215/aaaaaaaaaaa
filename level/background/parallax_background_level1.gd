extends LevelBackground

const LEVEL1_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/nivel1_parte1.png"),
	preload("res://level/background/nivel1_parte1.png"),
	preload("res://level/background/cueva_1.webp")
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
var _cloud_repeat_width: float = 0.0


func _ready() -> void:
	super._ready()
	# Comparte el movimiento de cámara, encuadre vertical y repetición del cielo.
	_clouds = Node2D.new()
	_clouds.name = "MovingClouds"
	$Sky.add_child(_clouds)
	_layout_clouds()
	_clouds.visible = _current_stage < 2


func _process(delta: float) -> void:
	super._process(delta)
	if (_cloud_viewport_size != get_viewport().get_visible_rect().size
			or not is_equal_approx(_cloud_repeat_width, $Sky.motion_mirroring.x)):
		_layout_clouds()
	if not _clouds.visible:
		return
	for index in range(_clouds.get_child_count()):
		var cloud := _clouds.get_child(index) as Sprite2D
		var speed := 8.0 + (index % CLOUD_TEXTURES.size()) * 3.0
		cloud.position.x = fposmod(cloud.position.x - speed * delta, _cloud_repeat_width)


func _get_stage_textures() -> Array[Texture2D]:
	return LEVEL1_TEXTURES


func set_stage(stage_index: int) -> void:
	super.set_stage(stage_index)
	if is_instance_valid(_clouds):
		_clouds.visible = _current_stage < 2


func _layout_clouds() -> void:
	_cloud_viewport_size = get_viewport().get_visible_rect().size
	_cloud_repeat_width = maxf($Sky.motion_mirroring.x, 1.0)
	# Distribuir las nubes por todo el tramo que repite el fondo evita huecos
	# al recorrer el mapa y mantiene una densidad similar en cada viewport.
	var count := maxi(CLOUD_TEXTURES.size(), ceili(
		_cloud_repeat_width / maxf(_cloud_viewport_size.x, 1.0)
	) * CLOUD_TEXTURES.size())
	while _clouds.get_child_count() > count:
		var cloud := _clouds.get_child(_clouds.get_child_count() - 1)
		_clouds.remove_child(cloud)
		cloud.queue_free()
	while _clouds.get_child_count() < count:
		var cloud := Sprite2D.new()
		cloud.texture = CLOUD_TEXTURES[_clouds.get_child_count() % CLOUD_TEXTURES.size()]
		_clouds.add_child(cloud)
	for index in range(_clouds.get_child_count()):
		var cloud := _clouds.get_child(index) as Sprite2D
		var variant := index % CLOUD_TEXTURES.size()
		var factor := _cloud_viewport_size.y * (0.045 + variant * 0.008) / cloud.texture.get_height()
		cloud.scale = Vector2.ONE * factor
		cloud.position = Vector2(
			_cloud_repeat_width * (index + 0.5) / count,
			_cloud_viewport_size.y * (0.08 + variant * 0.045)
		)
		cloud.modulate.a = 0.75 + variant * 0.04
