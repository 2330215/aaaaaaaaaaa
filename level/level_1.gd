extends "res://level/level.gd"
## La galeria inferior, las chimeneas y las cimas comparten el segundo escenario.

const CANYON_BOUNDS := Rect2(0, 1024, 3840, 1728)


func _setup_camera() -> void:
	super._setup_camera()
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player.get_world_2d() != get_world_2d():
			continue
		var height := to_local(player.global_position).y
		if height >= 1000.0 and height < 3000.0:
			_apply_camera_bounds(player.camera, CANYON_BOUNDS)
