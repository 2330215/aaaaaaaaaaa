extends Node2D

const LIMIT_LEFT = -128
const LIMIT_TOP = -200
const LIMIT_RIGHT = 3968
const LIMIT_BOTTOM = 5500

const COIN_SCENE = preload("res://level/coin.tscn")

@onready var tile_map_layer: TileMapLayer = $TileMapLayer

var _coin_spawn_timer: Timer


func _ready() -> void:
	_setup_camera()
	call_deferred("_spawn_random_coins", 45)
	
	# Create timer for periodic random coin spawns
	_coin_spawn_timer = Timer.new()
	_coin_spawn_timer.wait_time = 3.0
	_coin_spawn_timer.autostart = true
	_coin_spawn_timer.timeout.connect(_on_coin_spawn_timer_timeout)
	add_child(_coin_spawn_timer)


func _setup_camera() -> void:
	for child in get_children():
		if child is Player:
			var camera = child.get_node_or_null("Camera")
			if camera:
				camera.limit_left = LIMIT_LEFT
				camera.limit_top = LIMIT_TOP
				camera.limit_right = LIMIT_RIGHT
				camera.limit_bottom = LIMIT_BOTTOM


func _spawn_random_coins(count: int = 40) -> void:
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

	valid_surface_cells.shuffle()
	var spawn_count: int = mini(count, valid_surface_cells.size())
	for i in range(spawn_count):
		var cell: Vector2i = valid_surface_cells[i]
		_spawn_single_coin(cell)


func _spawn_single_coin(cell: Vector2i) -> void:
	var spawn_pos: Vector2 = tile_map_layer.map_to_local(cell) + Vector2(0, -32)
	var coin := COIN_SCENE.instantiate() as Area2D
	coin.global_position = spawn_pos
	add_child(coin)


func _on_coin_spawn_timer_timeout() -> void:
	if not tile_map_layer:
		return
	var used_cells := tile_map_layer.get_used_cells()
	if used_cells.is_empty():
		return
	var random_cell: Vector2i = used_cells.pick_random()
	var cell_above: Vector2i = random_cell + Vector2i(0, -1)
	if tile_map_layer.get_cell_source_id(cell_above) == -1:
		_spawn_single_coin(random_cell)


