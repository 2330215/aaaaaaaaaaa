@tool
extends Node2D
## Fachada construida con fragmentos del atlas urbano; la cornisa es transitable.

@export var building_size := Vector2(704, 640):
	set(value):
		building_size = value.max(Vector2(64, 64))
		queue_redraw()
		if is_inside_tree():
			_update_roof()
@export_enum("Amarillo", "Naranja", "Crema", "Rojo") var facade_style: int = 0:
	set(value):
		facade_style = clampi(value, 0, 3)
		queue_redraw()
@export var storefront: bool = true:
	set(value):
		storefront = value
		queue_redraw()

const ATLAS: Texture2D = preload("res://level/tiles_level2_tileset_64x64.png")
const WALL_REGIONS: Array[Rect2] = [
	Rect2(8, 342, 22, 18), Rect2(264, 349, 14, 10),
	Rect2(520, 343, 18, 20), Rect2(716, 345, 24, 18)
]
const SHOP_REGIONS: Array[Rect2] = [
	Rect2(0, 320, 256, 128), Rect2(256, 320, 256, 128),
	Rect2(512, 320, 192, 128), Rect2(704, 320, 128, 128)
]
const WINDOW_REGION := Rect2(198, 343, 18, 24)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_update_roof()


func _update_roof() -> void:
	var body := get_node_or_null("Roof") as StaticBody2D
	if body == null:
		body = StaticBody2D.new()
		body.name = "Roof"
		body.collision_layer = 16
		body.collision_mask = 0
		add_child(body)
		var collider := CollisionShape2D.new()
		collider.name = "CollisionShape2D"
		collider.one_way_collision = true
		collider.one_way_collision_margin = 8.0
		body.add_child(collider)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(building_size.x, 12)
	var collider := body.get_node("CollisionShape2D") as CollisionShape2D
	collider.shape = shape
	collider.position = Vector2(building_size.x * 0.5, -building_size.y + 6)


func _draw() -> void:
	var width := building_size.x
	var height := building_size.y
	var region := WALL_REGIONS[facade_style]
	# Repetir estuco, nunca los tiles de asfalto, en los pisos superiores.
	var y := -height
	while y < 0:
		var x := 0.0
		while x < width:
			draw_texture_rect_region(ATLAS, Rect2(x, y, minf(64, width-x), minf(64, -y)), region)
			x += 64
		y += 64
	# Ventanas y cornisas organizadas por plantas, dejando el frente comercial abajo.
	y = -height + 40
	while y < (-176.0 if storefront else -48.0):
		var x := 48.0
		while x < width - 40:
			draw_rect(Rect2(x-4, y-4, 40, 50), Color(0.12, 0.13, 0.16, 0.38))
			draw_texture_rect_region(ATLAS, Rect2(x, y, 32, 42), WINDOW_REGION)
			draw_line(Vector2(x-6, y+44), Vector2(x+38, y+44), Color(0.82, 0.67, 0.42), 4)
			x += 128
		draw_line(Vector2(0, y+82), Vector2(width, y+82), Color(0.22, 0.15, 0.11, 0.24), 5)
		y += 128
	if storefront:
		var shop := SHOP_REGIONS[facade_style]
		var x := 0.0
		while x < width:
			var part := minf(shop.size.x, width-x)
			var source := Rect2(shop.position, Vector2(part, shop.size.y))
			draw_texture_rect_region(ATLAS, Rect2(x, -128, part, 128), source)
			x += part
	# Remate de azotea tomado de la cornisa de la misma fachada.
	var roof_source := Rect2(SHOP_REGIONS[facade_style].position, Vector2(64, 14))
	var x := 0.0
	while x < width:
		var part := minf(64, width-x)
		draw_texture_rect_region(ATLAS, Rect2(x, -height, part, 14), Rect2(roof_source.position, Vector2(part, 14)))
		x += part
	draw_rect(Rect2(0, -height+14, width, 5), Color(0.17, 0.12, 0.12, 0.55))
	draw_line(Vector2(3, -height+19), Vector2(3, 0), Color(0.95, 0.85, 0.62, 0.55), 6)
	draw_line(Vector2(width-3, -height+19), Vector2(width-3, 0), Color(0.15, 0.12, 0.14, 0.36), 6)
