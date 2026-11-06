extends "res://level/level.gd"
## Tres tramos cortos de playa; Pizza se activa solo en el ultimo.

const STAGE_WIDTH: float = 1664.0
const CAMERA_OFFSET := Vector2(0, -90)
const FLOOR_HEIGHTS: Array[float] = [448.0, 2496.0, 4288.0]
const PLAYER_SPAWNS: Array[Vector2] = [Vector2(128, 400), Vector2(128, 2448), Vector2(128, 4240)]


func _process(_delta: float) -> void:
	_setup_camera()
	var in_boss_stage := false
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.get_world_2d() == get_world_2d():
			in_boss_stage = in_boss_stage or to_local(node.global_position).y >= 3584.0
	var boss := get_node_or_null("PizzaBoss") as Enemy
	if boss and boss._state != Enemy.State.DEAD:
		boss.visible = in_boss_stage
		boss.process_mode = Node.PROCESS_MODE_INHERIT if in_boss_stage else Node.PROCESS_MODE_DISABLED
		boss.collision_layer = 2 if in_boss_stage else 0


func _setup_camera() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player.get_world_2d() != get_world_2d():
			continue
		var height := to_local(player.global_position).y
		var stage := 2 if height >= 3584.0 else (1 if height >= 1792.0 else 0)
		var bounds := Rect2(0, FLOOR_HEIGHTS[stage] - 640.0, STAGE_WIDTH, 960)
		var viewport_size := player.get_viewport_rect().size
		var zoom := maxf(0.7, maxf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y))
		player.camera.zoom = Vector2.ONE * zoom
		player.camera.offset = CAMERA_OFFSET
		player.camera.limit_left = roundi(to_global(bounds.position).x - player.camera.offset.x)
		player.camera.limit_top = roundi(to_global(bounds.position).y - player.camera.offset.y)
		player.camera.limit_right = roundi(to_global(bounds.end).x - player.camera.offset.x)
		player.camera.limit_bottom = roundi(to_global(bounds.end).y - player.camera.offset.y)


func get_stage_destinations() -> Array:
	return [
		{"pos": to_global(PLAYER_SPAWNS[0]), "stage_index": 0, "cave": false, "sky": true, "label": "Inicio"},
		{"pos": to_global(PLAYER_SPAWNS[1]), "stage_index": 1, "cave": false, "sky": true, "label": "Escenario 2"},
		{"pos": to_global(PLAYER_SPAWNS[2]), "stage_index": 2, "cave": false, "sky": true, "label": "Jefe Pizza"}
	]
