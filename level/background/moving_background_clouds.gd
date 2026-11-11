extends Node2D
## Nubes que comparten el paralaje y la repetición de su ParallaxLayer padre.

const CLOUD_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/nube_1.png"),
	preload("res://level/background/nube_2.png"),
	preload("res://level/background/nube_3.png"),
	preload("res://level/background/nube_4.png"),
	preload("res://level/background/nube_5.png")
]

var _cloud_viewport_size := Vector2.ZERO
var _cloud_repeat_width: float = 0.0


func _ready() -> void:
	_layout_clouds()


func update_clouds(delta: float) -> void:
	if (_cloud_viewport_size != get_viewport().get_visible_rect().size
			or not is_equal_approx(_cloud_repeat_width, (get_parent() as ParallaxLayer).motion_mirroring.x)):
		_layout_clouds()
	if not visible:
		return
	for index in range(get_child_count()):
		var cloud := get_child(index) as Sprite2D
		var speed := 8.0 + (index % CLOUD_TEXTURES.size()) * 3.0
		cloud.position.x = fposmod(cloud.position.x - speed * delta, _cloud_repeat_width)


func _layout_clouds() -> void:
	_cloud_viewport_size = get_viewport().get_visible_rect().size
	_cloud_repeat_width = maxf((get_parent() as ParallaxLayer).motion_mirroring.x, 1.0)
	# Distribuir las nubes por todo el tramo que repite el fondo evita huecos
	# al recorrer el mapa y mantiene una densidad similar en cada viewport.
	var count := maxi(CLOUD_TEXTURES.size(), ceili(
		_cloud_repeat_width / maxf(_cloud_viewport_size.x, 1.0)
	) * CLOUD_TEXTURES.size())
	while get_child_count() > count:
		var cloud := get_child(get_child_count() - 1)
		remove_child(cloud)
		cloud.queue_free()
	while get_child_count() < count:
		var cloud := Sprite2D.new()
		cloud.texture = CLOUD_TEXTURES[get_child_count() % CLOUD_TEXTURES.size()]
		add_child(cloud)
	for index in range(get_child_count()):
		var cloud := get_child(index) as Sprite2D
		var variant := index % CLOUD_TEXTURES.size()
		var factor := _cloud_viewport_size.y * (0.045 + variant * 0.008) / cloud.texture.get_height()
		cloud.scale = Vector2.ONE * factor
		cloud.position = Vector2(
			_cloud_repeat_width * (index + 0.5) / count,
			_cloud_viewport_size.y * (0.08 + variant * 0.045)
		)
		cloud.modulate.a = 0.75 + variant * 0.04
