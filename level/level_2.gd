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
		var bounds := Rect2(-12, -192, 3840, 1088)
		if height >= 2944.0:
			bounds = Rect2(-12, 2944, 2304, 1063)
		elif height >= 1792.0:
			bounds = Rect2(-12, 1792, 3840, 1088)
		var camera := player.camera
		camera.offset = Vector2(0, -90)
		camera.position_smoothing_enabled = false
		camera.limit_smoothed = false
		_apply_camera_bounds(camera, bounds)
