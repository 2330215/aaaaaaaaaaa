extends CanvasLayer
## Un solo aparato por viewport, sin las copias del paralaje del paisaje.

@export var sky_stages: Array[int] = [0, 1]

const TEXTURES: Array[Texture2D] = [
	preload("res://level/background/avion.png"),
	preload("res://level/background/helicoptero.png")
]

var _sprite: Sprite2D
var _rng := RandomNumberGenerator.new()
var _remaining: float = 0.0
var _frame_time: float = 0.0
var _speed: float = 0.0
var _direction: float = 1.0
var _stage: int = -1
var _last_variant: int = -1


func _ready() -> void:
	layer = -99
	_rng.randomize()
	_sprite = Sprite2D.new()
	_sprite.hframes = 2
	_sprite.vframes = 2
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.hide()
	add_child(_sprite)


func update_aircraft(delta: float, stage: int) -> void:
	if stage != _stage:
		_stage = stage
		_sprite.hide()
		_remaining = _rng.randf_range(2.0, 4.0)
	if stage not in sky_stages:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if not _sprite.visible:
		_remaining -= delta
		if _remaining <= 0.0:
			_spawn(viewport_size)
		return
	_frame_time += delta
	_sprite.frame = int(_frame_time * 12.0) % 4
	_sprite.position.x += _direction * _speed * delta
	var half_width := _sprite.texture.get_width() * _sprite.scale.x / 4.0
	if (_direction > 0.0 and _sprite.position.x - half_width > viewport_size.x
			or _direction < 0.0 and _sprite.position.x + half_width < 0.0):
		_sprite.hide()
		_remaining = _rng.randf_range(6.0, 12.0)


func _spawn(viewport_size: Vector2) -> void:
	# Alternar modelos despues de la primera aparicion aleatoria.
	_last_variant = _rng.randi_range(0, 1) if _last_variant < 0 else 1 - _last_variant
	_sprite.texture = TEXTURES[_last_variant]
	_sprite.frame = 0
	_frame_time = 0.0
	var width := viewport_size.y * _rng.randf_range(0.22, 0.30)
	_sprite.scale = Vector2.ONE * width / (_sprite.texture.get_width() / 2.0)
	_direction = 1.0 if _rng.randf() > 0.5 else -1.0
	_sprite.flip_h = _direction < 0.0
	_sprite.position = Vector2(-width * 0.5 if _direction > 0.0 else viewport_size.x + width * 0.5,
		viewport_size.y * _rng.randf_range(0.12, 0.24))
	_speed = viewport_size.x * (0.16 if _last_variant == 0 else 0.11)
	_sprite.show()
