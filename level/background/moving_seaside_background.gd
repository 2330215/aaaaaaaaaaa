extends Node2D
## Elementos del paisaje marino; comparten el paralaje y repeticion del fondo.

const CLOUD_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/nube_1.png"),
	preload("res://level/background/nube_2.png"),
	preload("res://level/background/nube_3.png"),
	preload("res://level/background/nube_4.png"),
	preload("res://level/background/nube_5.png"),
	preload("res://level/background/nubes/nube_01.png"),
	preload("res://level/background/nubes/nube_02.png"),
	preload("res://level/background/nubes/nube_03.png"),
	preload("res://level/background/nubes/nube_04.png"),
	preload("res://level/background/nubes/nube_05.png"),
	preload("res://level/background/nubes/nube_06.png"),
	preload("res://level/background/nubes/nube_07.png"),
	preload("res://level/background/nubes/nube_08.png"),
	preload("res://level/background/nubes/nube_09.png"),
	preload("res://level/background/nubes/nube_10.png"),
	preload("res://level/background/nubes/nube_11.png"),
	preload("res://level/background/nubes/nube_12.png"),
	preload("res://level/background/nubes/nube_13.png"),
	preload("res://level/background/nubes/nube_14.png"),
	preload("res://level/background/nubes/nube_15.png"),
	preload("res://level/background/nubes/nube_16.png"),
	preload("res://level/background/nubes/nube_17.png"),
	preload("res://level/background/nubes/nube_18.png"),
	preload("res://level/background/nubes/nube_19.png"),
	preload("res://level/background/nubes/nube_20.png"),
	preload("res://level/background/nubes/nube_21.png"),
	preload("res://level/background/nubes/nube_22.png"),
	preload("res://level/background/nubes/nube_23.png"),
	preload("res://level/background/nubes/nube_24.png"),
	preload("res://level/background/nubes/nube_25.png"),
	preload("res://level/background/nubes/nube_26.png"),
	preload("res://level/background/nubes/nube_27.png"),
	preload("res://level/background/nubes/nube_28.png"),
	preload("res://level/background/nubes/nube_29.png"),
	preload("res://level/background/nubes/nube_30.png"),
	preload("res://level/background/nubes/nube_31.png"),
	preload("res://level/background/nubes/nube_32.png"),
	preload("res://level/background/nubes/nube_33.png"),
	preload("res://level/background/nubes/nube_34.png"),
	preload("res://level/background/nubes/nube_35.png"),
	preload("res://level/background/nubes/nube_36.png"),
	preload("res://level/background/nubes/nube_37.png")
]

const WaveField = preload("res://level/background/animated_wave_field.gd")

var _repeat_width: float = 0.0
var _image_height: float = 0.0
var _elapsed: float = 0.0
var _clouds: Array[Sprite2D] = []
var _wave_field: WaveField


func configure(repeat_width: float, image_height: float) -> void:
	if is_equal_approx(_repeat_width, repeat_width) and is_equal_approx(_image_height, image_height):
		return
	_repeat_width = repeat_width
	_image_height = image_height
	for sprite in _clouds:
		sprite.queue_free()
	_clouds.clear()

	var tiles := maxi(1, ceili(repeat_width / (image_height * 3.0)))
	for index in range(tiles * 14):
		var cloud := Sprite2D.new()
		# Alternar las nubes originales con las nuevas, sin agrandar las pequenas.
		var variant := index / 2
		cloud.texture = CLOUD_TEXTURES[variant % 5 if index % 2 == 0 else 5 + variant % 37]
		var factor := image_height / 724.0
		if index % 2 == 0:
			factor = image_height * (0.055 + (index % 3) * 0.012) / cloud.texture.get_height()
		cloud.scale = Vector2.ONE * factor
		cloud.position = Vector2(repeat_width * (index + 0.5) / (tiles * 14), image_height * (0.08 + fposmod(index * 0.137, 0.43)))
		cloud.modulate.a = 0.8
		add_child(cloud)
		_clouds.append(cloud)
	if _wave_field == null:
		_wave_field = WaveField.new()
		add_child(_wave_field)
	_wave_field.position.y = image_height * 0.668
	_wave_field.configure(Vector2(repeat_width, image_height * 0.30), image_height / 724.0)



func animate(delta: float) -> void:
	if not visible or _repeat_width <= 0.0:
		return
	_elapsed += delta
	var factor := _image_height / 724.0
	for index in range(_clouds.size()):
		var cloud := _clouds[index]
		cloud.position.x = fposmod(cloud.position.x - (5.0 + index % 5 * 2.0) * factor * delta, _repeat_width)
	_wave_field.update_waves(delta)
