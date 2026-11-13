extends Node

var _unlock_events := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	RecipeCollection.save_path = "res://__collection_tests/progress.cfg"
	RecipeCollection.load_progress()
	RecipeCollection.unlocked.clear()
	RecipeCollection.notebook_owned = false
	RecipeCollection._notifications.clear()
	assert(RecipeCollection.save_progress() == OK)
	assert(RecipeCollection.recipes().size() == 7)
	RecipeCollection.recipe_unlocked.connect(func(_id: String) -> void: _unlock_events += 1)
	# The real dialogue completion callback grants ownership; opening it alone does not.
	var npc := preload("res://enemy/npc_tuniliana.tscn").instantiate() as DialogueEnemy
	npc.story_dialogue_id = "tuniliana"
	add_child(npc)
	npc._open_dialogue()
	for _frame in range(4):
		await get_tree().process_frame
	assert(get_tree().paused)
	assert(not RecipeCollection.is_unlocked("ensalada_desierto"))
	npc._dialogue_box._finish_dialogue()
	await npc._dialogue_box.dialogue_finished
	assert(not get_tree().paused)
	assert(RecipeCollection.is_unlocked("ensalada_desierto"))
	assert(_unlock_events == 1)
	assert(not RecipeCollection.complete_dialogue("tuniliana"))
	assert(_unlock_events == 1)
	RecipeCollection.load_progress()
	assert(RecipeCollection.notebook_owned and RecipeCollection.is_unlocked("ensalada_desierto"))
	assert(RecipeCollection.last_save_error == OK)
	# Normal play -> book -> normal play, and locked page secrecy.
	RecipeCollection.open_notebook(self)
	var book = RecipeCollection._notebook
	await get_tree().process_frame
	assert(get_tree().paused)
	assert(book._index.get_child_count() == 7)
	assert(book._progress.text == "1 de 7 recetas recuperadas")
	book.select_recipe("pescado_costa")
	assert(book._page.get_child(1).text == "Esta hoja aún falta")
	assert(book._page.get_node_or_null("DishIllustration") == null)
	book.select_recipe("ensalada_desierto")
	assert(book._page.get_child(1).text == "Ensalada del desierto")
	RecipeCollection.open_notebook(self, "pescado_costa")
	assert(RecipeCollection._notebook == book and book._selected_id == "pescado_costa")
	book.queue_free()
	await get_tree().process_frame
	assert(not get_tree().paused)
	# Already paused -> book -> still paused.
	get_tree().paused = true
	RecipeCollection.open_notebook(self)
	book = RecipeCollection._notebook
	book.queue_free()
	await get_tree().process_frame
	assert(get_tree().paused)
	get_tree().paused = false
	# Every recipe maps to the approved dialogue; repeat completion is idempotent.
	for entry: Dictionary in RecipeCollection.recipes():
		RecipeCollection.complete_dialogue(str(entry.dialogue))
	assert(RecipeCollection.unlocked.size() == 7)
	assert(_unlock_events == 7)
	RecipeCollection.open_notebook(self)
	book = RecipeCollection._notebook
	for entry: Dictionary in RecipeCollection.recipes():
		book.select_recipe(str(entry.id))
		var dish := book._page.get_node("DishIllustration") as TextureRect
		assert(dish.texture != null and dish.texture.get_width() > 0)
		assert(dish.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		assert(dish.texture.resource_path == str(entry.illustration))
	book.queue_free()
	await get_tree().process_frame
	assert(not RecipeCollection.complete_dialogue("mato_2"))
	assert(not RecipeCollection.unlock_recipe("nonexistent"))
	RecipeCollection.load_progress()
	assert(RecipeCollection.unlocked.size() == 7)
	# New state object simulates closing and reopening the game.
	var reloaded = load("res://story/recipe_collection.gd").new()
	reloaded.save_path = RecipeCollection.save_path
	add_child(reloaded)
	assert(reloaded.unlocked.size() == 7 and reloaded.notebook_owned)
	reloaded.queue_free()
	# Menu integration is present both on title and inherited pause scenes.
	var menu := preload("res://gui/start_screen.tscn").instantiate()
	add_child(menu)
	var found := false
	for button in menu._main.get_children():
		if button is Button and button.text == "Coleccionables":
			found = true
	assert(found)
	menu.queue_free()
	var pause := preload("res://gui/pause_menu_singleplayer.tscn").instantiate() as PauseMenu
	add_child(pause)
	assert(pause.main_options.get_node("CollectiblesButton").text == "Coleccionables")
	pause.queue_free()
	# Inspect the real animated toast while it is on-screen.
	await get_tree().create_timer(0.8, true).timeout
	assert(RecipeCollection._notification_running)
	var toasts := RecipeCollection.get_children()
	assert(not toasts.is_empty())
	assert(toasts[0] is CanvasLayer)
	assert(toasts[0].find_child("RecipeRewardIllustration", true, false) != null)
	print("COLLECTION_TEST_PASS recipes=7 illustrations=7 locked_art_hidden=OK reward_art=OK npc_award=OK persistence=OK no_duplicates=OK paused_restore=OK menus=2 animation=OK")
	get_tree().quit(0)
