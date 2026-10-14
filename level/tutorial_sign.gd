@tool
extends Node2D
## Cartel de tutorial dibujado por código.
## Aparece detrás del jugador (z_index = -2).
## @tool permite verlo directamente en el editor de Godot.
##
## Para añadir animación (GIF), agrega un AnimatedSprite2D como hijo
## con nombre "Anim". Se posicionará automáticamente sobre el texto.

@export_multiline var sign_text: String = "Texto del cartel"
@export var sign_width: float  = 380.0
@export var sign_height: float = 150.0
@export var font_size: int     = 15

## Imagen estática opcional (se muestra arriba del texto)
@export var image: Texture2D   = null
@export var image_size: Vector2 = Vector2(80, 80)

## Si hay un hijo AnimatedSprite2D llamado "Anim", se coloca
## en la zona superior del cartel automáticamente.
@export var anim_area_height: float = 120.0

const _BG_COLOR     := Color(0.28, 0.18, 0.08, 0.97)
const _BORDER_COLOR := Color(0.16, 0.09, 0.03, 1.00)
const _TRIM_COLOR   := Color(0.48, 0.33, 0.13, 1.00)
const _TEXT_COLOR   := Color(0.98, 0.92, 0.78, 1.00)
const _SHADOW_COLOR := Color(0.00, 0.00, 0.00, 0.38)


func _ready() -> void:
	z_index = -2
	_reposition_anim_child()


func _draw() -> void:
	var hw := sign_width  * 0.5
	var hh := sign_height * 0.5

	# Sombra
	draw_rect(Rect2(-hw + 6, -hh + 6, sign_width, sign_height), _SHADOW_COLOR)

	# Borde exterior
	draw_rect(Rect2(-hw, -hh, sign_width, sign_height), _BORDER_COLOR)
	# Fondo de madera
	draw_rect(Rect2(-hw + 4, -hh + 4, sign_width - 8, sign_height - 8), _BG_COLOR)

	# Ribete interior
	var pad := 9.0
	_draw_border_rect(-hw + pad, -hh + pad, sign_width - pad * 2.0, sign_height - pad * 2.0, _TRIM_COLOR, 1.5)

	# Clavos
	var nr := 3.5
	var no := 15.0
	var nc := Color(0.58, 0.52, 0.42, 1.0)
	draw_circle(Vector2(-hw + no, -hh + no), nr, nc)
	draw_circle(Vector2( hw - no, -hh + no), nr, nc)
	draw_circle(Vector2(-hw + no,  hh - no), nr, nc)
	draw_circle(Vector2( hw - no,  hh - no), nr, nc)

	# Calcular offset Y del texto según si hay imagen/anim
	var text_y := -hh + 18.0
	var has_anim := _has_anim_child()

	if has_anim:
		text_y = -hh + anim_area_height + 10.0
	elif image:
		var iy := -hh + 14.0
		draw_texture_rect(image, Rect2(-image_size.x * 0.5, iy, image_size.x, image_size.y), false)
		text_y = iy + image_size.y + 8.0

	# Texto
	var font := ThemeDB.fallback_font
	draw_multiline_string(
		font,
		Vector2(-hw + 18.0, text_y + font_size),
		sign_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		sign_width - 36.0,
		font_size,
		-1,
		_TEXT_COLOR
	)


func _has_anim_child() -> bool:
	return get_node_or_null("Anim") != null


func _reposition_anim_child() -> void:
	var anim := get_node_or_null("Anim")
	if anim and anim is Node2D:
		# Centrar verticalmente en la zona superior del cartel
		anim.position = Vector2(0.0, -sign_height * 0.5 + anim_area_height * 0.5)


func _draw_border_rect(x: float, y: float, w: float, h: float, color: Color, thickness: float) -> void:
	draw_line(Vector2(x,     y    ), Vector2(x + w, y    ), color, thickness)
	draw_line(Vector2(x + w, y    ), Vector2(x + w, y + h), color, thickness)
	draw_line(Vector2(x + w, y + h), Vector2(x,     y + h), color, thickness)
	draw_line(Vector2(x,     y + h), Vector2(x,     y    ), color, thickness)
