extends CanvasLayer
## Un solo aparato por viewport, sin las copias del paralaje del paisaje.

@export var sky_stages: Array[int] = [0, 1]
@export var airplane_only: bool = false
## Multiplica la espera entre apariciones; un valor mayor implica menos trafico.
@export_range(0.1, 10.0, 0.1) var rarity: float = 1.0
@export var appearance_delay := Vector2(10.0, 24.0)
## Ancho relativo a la altura del viewport; todos los aparatos son pequeños.
@export var size_range := Vector2(0.035, 0.14)
@export var color_palette: Array[Color] = [
	Color("ef3545"), Color("2785f5"), Color("28ce78"),
	Color("ad4aee"), Color("ff812b"), Color("eeeeee")
]
@export_range(0.0, 6.0, 0.1) var distant_blur: float = 2.5

# El muestreo queda dentro del fotograma actual del atlas 2x2.
const DISTANCE_SHADER := """
shader_type canvas_item;
uniform float blur_radius = 0.0;
uniform vec4 paint_color : source_color = vec4(1.0);
varying vec4 aircraft_color;
void vertex() {
	aircraft_color = COLOR;
}
void fragment() {
	vec2 frame_min = floor(UV * 2.0) * 0.5 + TEXTURE_PIXEL_SIZE * 0.5;
	vec2 frame_max = frame_min + vec2(0.5) - TEXTURE_PIXEL_SIZE;
	vec4 result = vec4(0.0);
	float weight_sum = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			float weight = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
			vec2 offset = vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * blur_radius;
			vec4 sample_color = texture(TEXTURE, clamp(UV + offset, frame_min, frame_max));
			result += vec4(sample_color.rgb * sample_color.a, sample_color.a) * weight;
			weight_sum += weight;
		}
	}
	result /= weight_sum;
	result.rgb /= max(result.a, 0.0001);
	float luminance = dot(result.rgb, vec3(0.299, 0.587, 0.114));
	vec3 paint = paint_color.rgb * luminance * 1.35;
	result.rgb = mix(result.rgb, paint, 0.9);
	COLOR = aircraft_color * result;
}
"""

const TEXTURES: Array[Texture2D] = [
	preload("res://level/background/avion.png"),
	preload("res://level/background/helicoptero.png")
]

var _distance_material: ShaderMaterial
var _sprite: Sprite2D
var _rng := RandomNumberGenerator.new()
var _remaining: float = 0.0
var _frame_time: float = 0.0
var _speed: float = 0.0
var _direction: float = 1.0
var _stage: int = -1
var _last_variant: int = -1
var _last_color: int = -1
var _small_variant: bool = false


func _ready() -> void:
	layer = -99
	_rng.randomize()
	_sprite = Sprite2D.new()
	_sprite.hframes = 2
	_sprite.vframes = 2
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = DISTANCE_SHADER
	_distance_material = ShaderMaterial.new()
	_distance_material.shader = shader
	_sprite.material = _distance_material
	_sprite.hide()
	add_child(_sprite)


func update_aircraft(delta: float, stage: int) -> void:
	if stage != _stage:
		_stage = stage
		_sprite.hide()
		_remaining = _next_delay()
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
		_remaining = _next_delay()


func _spawn(viewport_size: Vector2) -> void:
	# Alternar modelos despues de la primera aparicion aleatoria.
	_last_variant = 0 if airplane_only else (_rng.randi_range(0, 1) if _last_variant < 0 else 1 - _last_variant)
	_sprite.texture = TEXTURES[_last_variant]
	_sprite.frame = 0
	_frame_time = 0.0
	var minimum := maxf(0.01, minf(size_range.x, size_range.y))
	var maximum := maxf(minimum, maxf(size_range.x, size_range.y))
	_small_variant = not _small_variant
	var relative_width := _rng.randf_range(minimum, lerpf(minimum, maximum, 0.35)) if _small_variant else _rng.randf_range(lerpf(minimum, maximum, 0.65), maximum)
	var width := viewport_size.y * relative_width
	_sprite.scale = Vector2.ONE * width / (_sprite.texture.get_width() / 2.0)
	var distance := 1.0 - smoothstep(minimum, maximum, relative_width)
	_distance_material.set_shader_parameter("blur_radius", distant_blur * distance / maxf(_sprite.scale.x, 0.001))
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if distance > 0.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	var color := Color.WHITE
	if not color_palette.is_empty():
		var index := _rng.randi_range(0, color_palette.size() - 1)
		if color_palette.size() > 1 and index == _last_color:
			index = (index + _rng.randi_range(1, color_palette.size() - 1)) % color_palette.size()
		_last_color = index
		color = color_palette[index]
	_distance_material.set_shader_parameter("paint_color", color)
	_direction = 1.0 if _rng.randf() > 0.5 else -1.0
	_sprite.flip_h = _direction < 0.0
	_sprite.position = Vector2(-width * 0.5 if _direction > 0.0 else viewport_size.x + width * 0.5,
		viewport_size.y * _rng.randf_range(0.12, 0.24))
	_speed = viewport_size.x * (0.16 if _last_variant == 0 else 0.11) * lerpf(0.45, 1.0, 1.0 - distance)
	_sprite.show()


func _next_delay() -> float:
	var minimum := maxf(0.1, minf(appearance_delay.x, appearance_delay.y))
	var maximum := maxf(minimum, maxf(appearance_delay.x, appearance_delay.y))
	return _rng.randf_range(minimum, maximum) * maxf(rarity, 0.1)
