extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var views := [[1, 1, Vector2(416, 2170), "Tuniliana"],
		[2, 0, Vector2(2256, 240), "MatoEscenario1"],
		[3, 1, Vector2(336, 2353), "Calivan"],
		[3, 1, Vector2(3000, 2260), "Narancio"],
		[4, 0, Vector2(2672, 280), "Pesado"],
		[5, 0, Vector2(1750, 310), "Papua"],
		[5, 1, Vector2(2960, 2320), "Manguel"]]
	for view: Array in views:
		var path := "res://level/level.tscn" if view[0] == 1 else "res://level/level_%d.tscn" % view[0]
		var level := load(path).instantiate() as Node2D
		add_child(level)
		level.set_process(false)
		level.set_physics_process(false)
		for node in level.find_children("*", "Node", true, false):
			if node is Enemy:
				node.set_process(false)
				node.set_physics_process(false)
			if node is Label and str(node.name) in ["HordeCounter", "VillageStatus"]:
				node.hide()
		var camera := Camera2D.new()
		camera.position = view[2]
		camera.zoom = Vector2(0.8, 0.8)
		level.add_child(camera)
		camera.make_current()
		for bg in get_tree().get_nodes_in_group("level_background"):
			bg.set_stage(view[1])
			if bg.has_method("align_to_stage"):
				bg.align_to_stage(view[1])
		await get_tree().create_timer(0.15, true).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://__collection_tests/exploration_%s.png" % view[3])
		level.queue_free()
		await get_tree().process_frame
	print("EXPLORATION_PREVIEWS_SAVED")
	get_tree().quit()
