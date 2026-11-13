extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var player := preload("res://player/player.tscn").instantiate() as Player
	player.position = Vector2(-10000, -10000)
	add_child(player)
	player.set_physics_process(false)
	player.camera.make_current()
	var other := preload("res://player/player.tscn").instantiate() as Player
	other.position = Vector2(-20000, -20000)
	add_child(other)
	other.set_physics_process(false)
	other.camera.enabled = false
	var box := preload("res://level/dialogue_box.tscn").instantiate() as DialogueBox
	add_child(box)
	var npc_portrait := preload("res://enemy/portraits/tuniliana.png")
	var lines := [{"speaker": "Tuniliana", "text": "Hola."},
		{"speaker": "Jugador", "text": "Quiero recuperar las recetas."},
		{"speaker": "Tuniliana", "text": "Buena suerte."}]
	var portraits := ["robot", "aguacate", "limones", "globo", "elote", "cebolla"]
	for skin in range(6):
		player.set_skin(skin as Player.CharacterSkin)
		box.start_dialogue("Tuniliana", npc_portrait, lines)
		assert(box.portrait_rect.texture == npc_portrait and box.portrait_rect.visible)
		box._current_line_index = 1
		box._show_current_line()
		assert(box.portrait_rect.visible)
		assert(box.portrait_rect.texture.resource_path == "res://player/portraits/%s.png" % portraits[skin])
		box._current_line_index = 2
		box._show_current_line()
		assert(box.portrait_rect.texture == npc_portrait)
	# The player's actual form wins over the level's default and the active camera.
	GameState.current_level = 1
	other.set_skin(Player.CharacterSkin.GLOBO)
	box.start_dialogue("Tuniliana", npc_portrait, lines, other)
	box._current_line_index = 1
	box._show_current_line()
	assert(box.portrait_rect.texture.resource_path.ends_with("/globo.png"))
	other.set_skin(Player.CharacterSkin.AGUACATE)
	box._show_current_line()
	assert(box.portrait_rect.texture.resource_path.ends_with("/aguacate.png"))
	box.queue_free()
	await get_tree().process_frame
	# Exercise the NPC call path, not just the dialogue renderer.
	var npc := preload("res://enemy/npc_tuniliana.tscn").instantiate() as DialogueEnemy
	npc.position = Vector2(40000, 40000)
	npc.story_dialogue_id = ""
	npc.dialogue_lines = lines
	add_child(npc)
	npc._on_interaction_body_entered(other)
	for _frame in range(5):
		await get_tree().process_frame
	assert(npc._dialogue_box != null and npc._dialogue_box._active)
	npc._dialogue_box._current_line_index = 1
	npc._dialogue_box._show_current_line()
	assert(npc._dialogue_box.portrait_rect.texture.resource_path.ends_with("/aguacate.png"))
	npc._dialogue_box._finish_dialogue()
	await npc._dialogue_box.dialogue_finished
	assert(not get_tree().paused)
	print("PORTRAITS_TEST_PASS skins=6 npc_restore=OK camera_lookup=OK interacting_player=OK transformed_player=OK npc_integration=OK")
	get_tree().quit(0)
