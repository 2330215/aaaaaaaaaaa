extends Node2D

const LIMIT_LEFT = -128
const LIMIT_TOP = -200
const LIMIT_RIGHT = 3968
const LIMIT_BOTTOM = 5500

@export_group("Camara del jefe")
@export var boss_camera_enabled: bool = false
## Altura del mapa a partir de la cual se usan los limites de la arena.
@export var boss_camera_start_y: float = 4608.0
## Posicion: borde izquierdo/superior. Size: ancho/alto visibles de la arena.
@export var boss_camera_bounds: Rect2 = Rect2(-64, 4608, 2240, 896)

var _camera_offsets: Dictionary = {}

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
				if boss_camera_enabled and to_local(child.global_position).y >= boss_camera_start_y:
					if not _camera_offsets.has(camera):
						_camera_offsets[camera] = camera.offset
					camera.offset = Vector2.ZERO
					bounds = boss_camera_bounds
				elif _camera_offsets.has(camera):
					camera.offset = _camera_offsets[camera]
					_camera_offsets.erase(camera)
				# Los limites de Camera2D son globales y su offset se aplica despues.
				var top_left := to_global(bounds.position) - camera.offset
				var bottom_right := to_global(bounds.end) - camera.offset
				camera.limit_left = roundi(top_left.x)
				camera.limit_top = roundi(top_left.y)
				camera.limit_right = roundi(bottom_right.x)
				camera.limit_bottom = roundi(bottom_right.y)
