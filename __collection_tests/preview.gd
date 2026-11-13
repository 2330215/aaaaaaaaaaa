extends Node

func _ready() -> void:
	RecipeCollection.save_path = "res://__collection_tests/preview.cfg"
	RecipeCollection.unlocked = {"ensalada_desierto": true, "tacos_mercado": true, "guiso_montana": true}
	RecipeCollection.notebook_owned = true
	_run.call_deferred()

func _run() -> void:
	RecipeCollection.open_notebook(self, "ensalada_desierto")
	await get_tree().create_timer(0.5, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://__collection_tests/notebook_preview.png")
	RecipeCollection._notebook.select_recipe("pescado_costa")
	await get_tree().create_timer(0.2, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://__collection_tests/locked_preview.png")
	RecipeCollection._notebook.queue_free()
	await get_tree().process_frame
	var toast = load("res://gui/recipe_toast.gd").new()
	add_child(toast)
	toast.present("tacos_mercado")
	await get_tree().create_timer(0.9, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://__collection_tests/toast_preview.png")
	toast.queue_free()
	var menu := preload("res://gui/start_screen.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(0.8, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://__collection_tests/menu_preview.png")
	menu.queue_free()
	await get_tree().process_frame
	var pause := preload("res://gui/pause_menu_singleplayer.tscn").instantiate() as PauseMenu
	add_child(pause)
	get_tree().paused = true
	pause.open()
	await get_tree().create_timer(0.5, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://__collection_tests/pause_preview.png")
	print("COLLECTION_PREVIEWS_SAVED")
	get_tree().quit()
