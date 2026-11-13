extends Node2D

const LIMIT_LEFT = 0
const LIMIT_TOP = -200
const LIMIT_RIGHT = 3840
const LIMIT_BOTTOM = 5500

@export_group("Camara del jefe")
@export var boss_camera_enabled: bool = false
## Altura del mapa a partir de la cual se usan los limites de la arena.
@export var boss_camera_start_y: float = 4608.0
## Posicion: borde izquierdo/superior. Size: ancho/alto visibles de la arena.
@export var boss_camera_bounds: Rect2 = Rect2(0, 4608, 2112, 896)

## Desplazamiento del encuadre; negativo muestra mas cielo.
@export var camera_offset := Vector2(0, 50)

const CAMERA_EDGE_INSET: float = 8.0

@onready var tile_map_layer: TileMapLayer = $TileMapLayer


func _ready() -> void:
	_setup_camera.call_deferred()


func _process(_delta: float) -> void:
	if boss_camera_enabled:
		_setup_camera()


func _setup_camera() -> void:
	for child in get_tree().get_nodes_in_group("player"):
		if child is Player and child.get_world_2d() == get_world_2d():
			var camera := child.get_node_or_null("Camera") as Camera2D
			if camera:
				var bounds := Rect2(
					Vector2(LIMIT_LEFT, LIMIT_TOP),
					Vector2(LIMIT_RIGHT - LIMIT_LEFT, LIMIT_BOTTOM - LIMIT_TOP)
				)
				camera.offset = camera_offset
				if boss_camera_enabled and to_local(child.global_position).y >= boss_camera_start_y:
					bounds = boss_camera_bounds
				_apply_camera_bounds(camera, bounds)


func _apply_camera_bounds(camera: Camera2D, bounds: Rect2) -> void:
	# Excluir los muros laterales y dejar margen para el redondeo de pixeles.
	bounds.position.x += CAMERA_EDGE_INSET
	bounds.size.x -= CAMERA_EDGE_INSET * 2.0
	var viewport := camera.custom_viewport as Viewport
	if viewport == null:
		viewport = camera.get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	var zoom := maxf(0.7, maxf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y))
	camera.zoom = Vector2.ONE * zoom
	# El offset se aplica despues de los limites en Camera2D.
	var top_left := to_global(bounds.position) - camera.offset
	var bottom_right := to_global(bounds.end) - camera.offset
	camera.limit_left = ceili(top_left.x)
	camera.limit_top = ceili(top_left.y)
	camera.limit_right = floori(bottom_right.x)
	camera.limit_bottom = floori(bottom_right.y)
