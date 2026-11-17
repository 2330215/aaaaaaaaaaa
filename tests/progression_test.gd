extends Node
## Ejecutar con XDG_DATA_HOME apuntando a una carpeta temporal, nunca a la partida real.

const TEST_DIRECTORY := "/tmp/platformer_progression_regression"
var _menu: Control
var _pause: Control


func _ready() -> void:
	get_tree().create_timer(30.0, true).timeout.connect(func() -> void:
		push_error("PROGRESSION_TEST_TIMEOUT")
		get_tree().quit(1))
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIRECTORY)
	GameState.save_path = TEST_DIRECTORY + "/progress.cfg"
	RecipeCollection.save_path = TEST_DIRECTORY + "/recipes.cfg"
	assert(GameState.save_path.begins_with("/tmp/") and RecipeCollection.save_path.begins_with("/tmp/"))
	assert(GameState.erase_local_progress() == OK)
	GameState.load_progress()
	assert(GameState.is_level_unlocked(1))
	for level in range(2,6):
		assert(not GameState.is_level_unlocked(level))
	assert(not GameState.has_continue())
	assert(not GameState.start_level(GameState.SINGLEPLAYER_LEVELS[4]))
	assert(not GameState.start_level("res://unknown.tscn"))
	assert(not GameState._changing_scene)
	_menu = load("res://gui/start_screen.tscn").instantiate()
	add_child(_menu)
	_pause = load("res://gui/pause_menu_singleplayer.tscn").instantiate()
	add_child(_pause)
	assert(_menu._new_game_button.visible and not _menu._continue_button.visible)
	assert(not _menu._level_buttons[0].disabled)
	for index in range(1,5):
		assert(_menu._level_buttons[index].disabled)
		assert(_pause.main_options.get_node("Level%dButton" % (index+1)).disabled)
	_menu._start_selected_level(4)
	_pause.show()
	_pause._on_goto_level5_pressed()
	assert(not GameState._changing_scene)
	_pause.hide()
	print("PROGRESSION_FRESH_SAVE_AND_SELECTORS_OK")

	GameState.begin_level(1)
	GameState.remember_level(GameState.SINGLEPLAYER_LEVELS[0])
	assert(FileAccess.file_exists(GameState.save_path))
	assert(GameState.has_continue())
	GameState.notify_boss_defeated()
	assert(GameState.highest_completed_level == 1)
	assert(GameState.is_level_unlocked(2) and not GameState.is_level_unlocked(3))
	assert(GameState.last_played_scene == GameState.SINGLEPLAYER_LEVELS[1])
	assert(not _menu._level_buttons[1].disabled and _menu._level_buttons[2].disabled)
	assert(not _pause.main_options.get_node("Level2Button").disabled)
	GameState.notify_boss_defeated()
	assert(GameState.highest_completed_level == 1)
	var reloaded = load("res://game_state.gd").new()
	reloaded.save_path = GameState.save_path
	add_child(reloaded)
	assert(reloaded.highest_completed_level == 1 and reloaded.is_level_unlocked(2))
	assert(not reloaded.is_level_unlocked(3))
	assert(reloaded.last_played_scene == GameState.SINGLEPLAYER_LEVELS[1])
	reloaded.queue_free()
	# Un resultado fuera de orden no permite saltarse niveles.
	GameState.begin_level(4)
	GameState.notify_boss_defeated()
	assert(GameState.highest_completed_level == 1)
	for level in range(2,6):
		GameState.begin_level(level)
		GameState.notify_boss_defeated()
		assert(GameState.highest_completed_level == level)
		assert(GameState.is_level_unlocked(mini(5,level+1)))
	GameState.load_progress()
	assert(GameState.highest_completed_level == 5)
	print("PROGRESSION_BOSS_UNLOCK_PERSISTENCE_AND_ORDER_OK")

	# Migrar el formato anterior conserva el último nivel alcanzado, sin desbloquear el siguiente.
	var legacy := ConfigFile.new()
	legacy.set_value("progress", "last_scene", GameState.SINGLEPLAYER_LEVELS[2])
	assert(legacy.save(GameState.save_path) == OK)
	GameState.load_progress()
	assert(GameState.highest_completed_level == 2)
	assert(GameState.is_level_unlocked(3) and not GameState.is_level_unlocked(4))
	GameState.remember_level(GameState.SINGLEPLAYER_LEVELS[2])
	var migrated := ConfigFile.new()
	assert(migrated.load(GameState.save_path) == OK)
	assert(migrated.get_value("progress", "highest_completed") == 2)
	# El progreso es compartido por individual y pantalla dividida.
	GameState.highest_completed_level = 0
	GameState.begin_level(1)
	GameState.remember_level(GameState.SPLITSCREEN_LEVELS[0])
	GameState.notify_boss_defeated()
	assert(GameState.can_play_scene(GameState.SPLITSCREEN_LEVELS[1]))
	assert(GameState.last_played_scene == GameState.SPLITSCREEN_LEVELS[1])
	print("PROGRESSION_LEGACY_AND_SPLITSCREEN_OK")

	assert(RecipeCollection.unlock_recipe(str(RecipeCollection.recipes()[0].id)))
	await get_tree().process_frame
	var progress_bytes := FileAccess.get_file_as_bytes(GameState.save_path)
	var recipe_bytes := FileAccess.get_file_as_bytes(RecipeCollection.save_path)
	_menu._open_delete_save()
	var dialog = _menu.get_node("DeleteSaveDialog")
	assert(dialog._cancel_button.has_focus())
	dialog._cancel_button.pressed.emit()
	await get_tree().process_frame
	assert(FileAccess.get_file_as_bytes(GameState.save_path) == progress_bytes)
	assert(FileAccess.get_file_as_bytes(RecipeCollection.save_path) == recipe_bytes)
	assert(GameState.highest_completed_level == 1 and RecipeCollection.unlocked.size() == 1)
	# El borrado no se inicia en medio de otra transición.
	GameState._changing_scene = true
	assert(GameState.erase_local_progress() == ERR_BUSY)
	GameState._changing_scene = false
	assert(FileAccess.get_file_as_bytes(GameState.save_path) == progress_bytes)
	var suspended := Node.new()
	var suspended_ref: WeakRef = weakref(suspended)
	GameState._suspended_game = suspended
	GameState.used_special_coins["test"] = true
	GameState.lives = 8
	assert(GameState.erase_local_progress() == OK)
	assert(suspended_ref.get_ref() == null)
	assert(not FileAccess.file_exists(GameState.save_path))
	assert(not FileAccess.file_exists(RecipeCollection.save_path))
	assert(GameState.highest_completed_level == 0 and not GameState.has_continue())
	assert(GameState.used_special_coins.is_empty() and GameState.lives == 3)
	assert(RecipeCollection.unlocked.is_empty() and not RecipeCollection.notebook_owned)
	assert(_menu._level_buttons[1].disabled)
	GameState.load_progress()
	RecipeCollection.load_progress()
	assert(not GameState.is_level_unlocked(2) and RecipeCollection.unlocked.is_empty())
	print("PROGRESSION_CANCEL_AND_FULL_ERASURE_OK")

	# Confirmar la acción real de la UI también debe regresar al inicio y quitar la pausa.
	GameState.begin_level(1)
	GameState.remember_level(GameState.SINGLEPLAYER_LEVELS[0])
	GameState.notify_boss_defeated()
	get_tree().paused = true
	_pause._open_delete_save()
	dialog = _pause.get_node("DeleteSaveDialog")
	# Mantener este observador fuera de la escena que la acción va a sustituir.
	get_tree().current_scene = null
	dialog._confirm_delete()
	await get_tree().scene_changed
	assert(not get_tree().paused)
	assert(get_tree().current_scene.scene_file_path == GameState.TITLE_SCENE)
	assert(not GameState.has_continue() and not GameState.is_level_unlocked(2))
	assert(get_tree().current_scene._new_game_button.visible)
	assert(not FileAccess.file_exists(GameState.save_path))
	assert(not FileAccess.file_exists(RecipeCollection.save_path))
	print("PROGRESSION_CONFIRMED_ERASURE_RESTART_OK")
	await get_tree().create_timer(4.5, true).timeout
	assert(RecipeCollection.unlocked.is_empty() and not FileAccess.file_exists(RecipeCollection.save_path))
	_menu.queue_free()
	_pause.queue_free()
	await get_tree().process_frame
	await _check_real_scene_navigation()
	print("PROGRESSION_ALL_TESTS_PASSED")
	get_tree().quit()


func _check_real_scene_navigation() -> void:
	# Abrir una escena bloqueada directamente también devuelve al inicio.
	assert(get_tree().change_scene_to_file(GameState.SINGLEPLAYER_LEVELS[2]) == OK)
	await get_tree().scene_changed
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != GameState.TITLE_SCENE:
		await get_tree().scene_changed
	assert(GameState.highest_completed_level == 0 and not GameState.has_continue())
	assert(GameState.start_level(GameState.SINGLEPLAYER_LEVELS[0]))
	await get_tree().scene_changed
	assert(get_tree().current_scene.scene_file_path == GameState.SINGLEPLAYER_LEVELS[0])
	GameState.notify_boss_defeated()
	await get_tree().create_timer(1.7, true).timeout
	assert(get_tree().paused)
	get_tree().current_scene._on_victory_advance_requested()
	await get_tree().scene_changed
	assert(get_tree().current_scene.scene_file_path == GameState.SINGLEPLAYER_LEVELS[1])
	assert(GameState.highest_completed_level == 1)
	assert(GameState.start_level(GameState.SPLITSCREEN_LEVELS[1]))
	await get_tree().scene_changed
	var pause = get_tree().current_scene.get_node("InterfaceLayer/PauseMenu")
	pause.show()
	assert(pause.main_options.get_node("Level3Button").disabled)
	pause._on_goto_level1_pressed()
	await get_tree().scene_changed
	assert(get_tree().current_scene.scene_file_path == GameState.SPLITSCREEN_LEVELS[0])
	print("PROGRESSION_REAL_SCENE_GUARDS_VICTORY_AND_MODES_OK")
	pause = get_tree().current_scene.get_node("InterfaceLayer/PauseMenu")
	get_tree().paused = true
	pause.show()
	pause._open_delete_save()
	pause.get_node("DeleteSaveDialog")._confirm_delete()
	await get_tree().scene_changed
	assert(get_tree().current_scene.scene_file_path == GameState.TITLE_SCENE)
	assert(not get_tree().paused and not GameState.has_continue())
	assert(not GameState.is_level_unlocked(2))
	assert(not FileAccess.file_exists(GameState.save_path))
	print("PROGRESSION_ERASE_ACTIVE_SPLITSCREEN_OK")
