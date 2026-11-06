extends "res://level/level.gd"
## Destinos propios: el tercer escenario comienza encima del suelo de la fila 56.

const THIRD_STAGE_SPAWN := Vector2(96, 3536)


func get_stage_destinations() -> Array:
	return [
		{"pos": to_global(Vector2(128, 400)), "stage_index": 0, "cave": false, "sky": true, "label": "Inicio"},
		{"pos": to_global(Vector2(128, 2208)), "stage_index": 1, "cave": false, "sky": true, "label": "Escenario 2"},
		{"pos": to_global(THIRD_STAGE_SPAWN), "stage_index": 2, "cave": false, "sky": true, "label": "Escenario 3"}
	]


func _process(delta: float) -> void:
	super._process(delta)
	_setup_camera()


func _setup_camera() -> void:
	# El estadio del tercer escenario es más corto que los dos anteriores.
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player.get_world_2d() != get_world_2d():
			continue
		var height := to_local(player.global_position).y
		var bounds := Rect2(-4, -192, 3896, 1088)
		if height >= 2944.0:
			bounds = Rect2(-4, 2944, 2360, 1063)
		elif height >= 1792.0:
			bounds = Rect2(-4, 1792, 3896, 1088)
		var camera := player.camera
		var viewport_size := player.get_viewport_rect().size
		var zoom := maxf(0.7, maxf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y))
		camera.zoom = Vector2.ONE * zoom
		camera.position_smoothing_enabled = false
		camera.limit_smoothed = false
		camera.limit_left = roundi(to_global(bounds.position).x - camera.offset.x)
		camera.limit_top = roundi(to_global(bounds.position).y - camera.offset.y)
		camera.limit_right = roundi(to_global(bounds.end).x - camera.offset.x)
		camera.limit_bottom = roundi(to_global(bounds.end).y - camera.offset.y)
