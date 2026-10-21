extends Node2D

const LIMIT_LEFT = -128
const LIMIT_TOP = -200
const LIMIT_RIGHT = 3968
const LIMIT_BOTTOM = 5500

@onready var tile_map_layer: TileMapLayer = $TileMapLayer


func _ready() -> void:
	_setup_camera()


func _setup_camera() -> void:
	for child in get_children():
		if child is Player:
			var camera = child.get_node_or_null("Camera")
			if camera:
				camera.limit_left = LIMIT_LEFT
				camera.limit_top = LIMIT_TOP
				camera.limit_right = LIMIT_RIGHT
				camera.limit_bottom = LIMIT_BOTTOM
