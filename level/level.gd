extends Node2D

const LIMIT_LEFT = -128
const LIMIT_TOP = -200
const LIMIT_RIGHT = 3968
const LIMIT_BOTTOM = 5500

const COIN_SCENE = preload("res://level/coin.tscn")

@onready var tile_map_layer: TileMapLayer = $TileMapLayer


func _ready() -> void:
	_setup_camera()
	call_deferred("_spawn_predefined_coins")


func _setup_camera() -> void:
	for child in get_children():
		if child is Player:
			var camera = child.get_node_or_null("Camera")
			if camera:
				camera.limit_left = LIMIT_LEFT
				camera.limit_top = LIMIT_TOP
				camera.limit_right = LIMIT_RIGHT
				camera.limit_bottom = LIMIT_BOTTOM


func _spawn_predefined_coins() -> void:
	if not tile_map_layer:
		return
	var used_cells := tile_map_layer.get_used_cells()
	if used_cells.is_empty():
		return

	var valid_surface_cells: Array[Vector2i] = []
	for cell in used_cells:
		var cell_above := cell + Vector2i(0, -1)
		if tile_map_layer.get_cell_source_id(cell_above) == -1:
			valid_surface_cells.append(cell)

	if valid_surface_cells.is_empty():
		valid_surface_cells = used_cells

	# Sort cells deterministically to keep positions fixed and predictable
	valid_surface_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)

	# Place coins at predefined regular steps along the surface
	for i in range(0, valid_surface_cells.size(), 3):
		var cell: Vector2i = valid_surface_cells[i]
		_spawn_single_coin(cell)


func _spawn_single_coin(cell: Vector2i) -> void:
	# Vector2(0, -96) places the coins higher up above the platform
	var spawn_pos: Vector2 = tile_map_layer.map_to_local(cell) + Vector2(0, -96)
	var coin := COIN_SCENE.instantiate() as Area2D
	coin.global_position = spawn_pos
	add_child(coin)



