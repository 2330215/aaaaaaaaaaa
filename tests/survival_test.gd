extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	RecipeCollection.save_path = ProjectSettings.globalize_path("res://../tmp/survival_test_recipes.cfg")
	RecipeCollection.unlocked.clear()
	GameState.lives = 2
	GameState.current_level = 3
	GameState._shots_fired = 17
	GameState._level_timer_running = false
	var last_scene := GameState.last_played_scene
	var completed := GameState.highest_completed_level
	var arena := preload("res://survival/survival.tscn").instantiate()
	check(arena.get_node("Level/Suelo").get_used_cells().size() == 50, "Ground saved in scene before ready")
	var platform: TileMapLayer = arena.get_node("Level/Plataforma1")
	platform.position.x += 24
	arena.get_node("Level/Player").position.x += 20
	add_child(arena)
	check(platform.position.x == 124, "Edited platform position preserved")
	check(arena._respawn_position.x == 820, "Respawn follows edited player position")
	check(arena.get_node("Level").find_children("Spawn*", "Marker2D", true, false).size() == 7, "Editable enemy spawn markers")
	arena.set_process(false)
	await get_tree().process_frame
	check(arena.get_node("Level").find_children("Plataforma*", "TileMapLayer", false, false).size() == 6, "Six editable platforms expected")
	var terrain_count := 0
	for child in arena.get_node("Level").get_children():
		if child is TileMapLayer:
			terrain_count += 1
			check(child.tile_set == preload("res://level/tileset.tres"), "Original level one tiles")
	check(terrain_count == 7, "Ground and six tile platforms")
	check(arena.controls._player == arena.player, "Mobile controls must find player")
	arena.toggle_pause()
	var countdown: float = arena.countdown
	arena._process(20)
	check(arena.countdown == countdown, "Pause must stop waves")
	arena.toggle_pause()
	for target_wave in range(1, 11):
		arena._process(5)
		check(arena.wave == target_wave, "Wave sequence")
		var spawned := 0
		while not arena.intermission and not arena.finished:
			arena._process(2)
			for enemy in arena.enemies:
				if is_instance_valid(enemy) and enemy._state != Enemy.State.DEAD:
					spawned += 1
					check(enemy.hit_points == 3 and enemy.chase_speed == 160.0 and enemy.patrol_speed == 100.0, "Original enemy parameters")
					check(enemy.position.distance_to(arena.player.position) > 350, "Safe spawn distance")
					while enemy._state != Enemy.State.DEAD:
						enemy.destroy()
		check(spawned == 3 + target_wave * 2, "Wave population")
		if target_wave < 10:
			check(not RecipeCollection.is_unlocked(arena.REWARD), "No early reward")
	check(arena.finished, "Victory after tenth wave")
	check(RecipeCollection.is_unlocked(arena.REWARD), "Victory recipe unlocked")
	check(RecipeCollection.last_save_error == OK, "Recipe persists")
	RecipeCollection.load_progress()
	check(RecipeCollection.is_unlocked(arena.REWARD), "Reward survives reload")
	RecipeCollection.open_notebook(arena, arena.REWARD)
	check(RecipeCollection._notebook.layer > 120, "Notebook visible above victory")
	RecipeCollection._notebook.free()
	arena.free()
	get_tree().paused = false
	check(GameState.lives == 2 and GameState.current_level == 3 and GameState._shots_fired == 17, "Campaign restored")
	check(GameState.last_played_scene == last_scene and GameState.highest_completed_level == completed, "Campaign progress untouched")
	RecipeCollection.unlocked.clear()
	arena = preload("res://survival/survival.tscn").instantiate()
	add_child(arena)
	arena.set_process(false)
	arena.wave = 4
	GameState.lives = 1
	GameState.lose_life()
	check(arena.finished and get_tree().paused, "Defeat stops match")
	check(not RecipeCollection.is_unlocked(arena.REWARD), "Defeat grants no reward")
	arena.free()
	get_tree().paused = false
	print("SURVIVAL_TEST failures=", failures)
	get_tree().quit(failures)
