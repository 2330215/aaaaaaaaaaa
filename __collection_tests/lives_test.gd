extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	GameState.begin_level(1)
	var hud := preload("res://gui/lives_display.tscn").instantiate()
	add_child(hud)
	assert(hud.lives_label.text == "x3")
	assert(GameState.lose_life())
	assert(hud.lives_label.text == "x2")
	assert(GameState.lose_life())
	assert(hud.lives_label.text == "x1")
	assert(not GameState.lose_life())
	assert(hud.lives_label.text == "x0")
	hud.queue_free()
	await get_tree().process_frame
	# Reproduce the scene reload order: the new HUD sees 0 before the
	# parent Game._ready calls begin_level. Both split-screen HUDs must reset.
	for level_number in range(1, 6):
		GameState.lives = 0
		var first := preload("res://gui/lives_display.tscn").instantiate()
		var second := preload("res://gui/lives_display.tscn").instantiate()
		add_child(first)
		add_child(second)
		assert(first.lives_label.text == "x0")
		GameState.begin_level(level_number)
		assert(GameState.lives == GameState.MAX_LIVES)
		assert(first.lives_label.text == "x3" and second.lives_label.text == "x3")
		GameState.gain_life()
		assert(first.lives_label.text == "x4" and second.lives_label.text == "x4")
		assert(GameState.lose_life())
		assert(first.lives_label.text == "x3" and second.lives_label.text == "x3")
		first.queue_free()
		second.queue_free()
		await get_tree().process_frame
	print("LIVES_TEST_PASS death_countdown=3_2_1_0 reload_reset=3 levels=5 split_huds=OK gain_loss=OK")
	get_tree().quit(0)
