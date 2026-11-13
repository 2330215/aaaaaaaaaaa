extends Node

var _done := false
var _player: Player

func _ready() -> void:
	RecipeCollection.save_path = "res://__collection_tests/transition_rewards.cfg"
	_watchdog()
	_run.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(45.0, true, false, true).timeout
	if not _done:
		push_error("TRANSITION_TEST_TIMEOUT")
		get_tree().quit(1)

func _npc(id: String = "tuniliana") -> DialogueEnemy:
	var npc := preload("res://enemy/npc_tuniliana.tscn").instantiate() as DialogueEnemy
	npc.position = Vector2(40000, 40000)
	npc.story_dialogue_id = id
	add_child(npc)
	return npc

func _active_boxes() -> Array[DialogueBox]:
	var boxes: Array[DialogueBox] = []
	for node in find_children("*", "DialogueBox", true, false):
		if node._active:
			boxes.append(node as DialogueBox)
	return boxes

func _wait_box() -> DialogueBox:
	while _active_boxes().is_empty():
		await get_tree().process_frame
	return _active_boxes()[0]

func _close(box: DialogueBox) -> void:
	box._finish_dialogue()
	await box.dialogue_finished
	await get_tree().process_frame

func _run() -> void:
	Engine.time_scale = 4.0
	_player = preload("res://player/player.tscn").instantiate() as Player
	_player.position = Vector2(2000, 1000)
	add_child(_player)
	_player.set_physics_process(false)
	_player.collision_layer = 0
	_player.collision_mask = 0
	# Real initial-level fade: dialogue must not pause it.
	var game := Game.new()
	var layer := CanvasLayer.new()
	layer.name = "InterfaceLayer"
	var pause := preload("res://gui/pause_menu_singleplayer.tscn").instantiate()
	pause.name = "PauseMenu"
	layer.add_child(pause)
	game.add_child(layer)
	add_child(game)
	var npc := _npc()
	npc._open_dialogue()
	await get_tree().create_timer(0.2, true).timeout
	assert(SceneFlow.is_transitioning() and not get_tree().paused)
	assert(_active_boxes().is_empty())
	var box: DialogueBox = await _wait_box()
	assert(not SceneFlow.is_transitioning())
	assert(get_tree().paused)
	await _close(box)
	npc.queue_free()
	game.queue_free()
	await get_tree().process_frame
	# Real reusable gateway and old special-coin portal, including black hold.
	for resource_path in ["res://level/stage_gateway.tscn", "res://level/special_coin.tscn"]:
		var portal = load(resource_path).instantiate()
		portal.position = Vector2(-10000, -10000)
		portal.target_position = Vector2(2000, 1000)
		add_child(portal)
		npc = _npc()
		portal._on_body_entered(_player)
		npc._open_dialogue()
		await get_tree().create_timer(1.3, true).timeout
		assert(portal.fade_rect.visible and portal.fade_rect.color.a > 0.95)
		assert(not get_tree().paused and _active_boxes().is_empty())
		box = await _wait_box()
		assert(not portal.fade_rect.visible and portal.fade_rect.color.a < 0.01)
		assert(not portal._triggered and not SceneFlow.is_transitioning())
		await _close(box)
		portal.queue_free()
		npc.queue_free()
		await get_tree().process_frame
	# Leaving the source NPC during a transition must not consume first encounter.
	var controls := preload("res://touch_controls.tscn").instantiate()
	add_child(controls)
	npc = _npc()
	controls._on_stage_pressed()
	npc._open_dialogue()
	await get_tree().create_timer(0.4, true).timeout
	assert(controls._fade_rect.visible and not get_tree().paused)
	assert(_active_boxes().is_empty())
	box = await _wait_box()
	assert(not controls._fade_rect.visible and not controls._teleporting)
	await _close(box)
	controls.queue_free()
	npc.queue_free()
	await get_tree().process_frame
	# Leaving the source NPC during a transition must not consume first encounter.
	var token := SceneFlow.begin_transition(self)
	npc = _npc()
	npc._on_interaction_body_entered(_player)
	npc._on_interaction_body_exited(_player)
	SceneFlow.end_transition(token)
	await get_tree().create_timer(0.3, true).timeout
	assert(_active_boxes().is_empty() and npc._first_time and not npc._dialogue_pending)
	npc._on_interaction_body_entered(_player)
	box = await _wait_box()
	assert(not npc._first_time)
	await _close(box)
	npc.queue_free()
	await get_tree().process_frame
	# Simultaneous NPC arrivals must serialize, rather than opening hidden boxes.
	token = SceneFlow.begin_transition(self)
	var first := _npc()
	var second := _npc("maizano")
	first._open_dialogue()
	second._open_dialogue()
	SceneFlow.end_transition(token)
	box = await _wait_box()
	assert(_active_boxes().size() == 1)
	await _close(box)
	box = await _wait_box()
	assert(_active_boxes().size() == 1)
	await _close(box)
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	# Every boss entry point must wait, including the shared Pizza/Dona runner.
	for number in range(1, 6):
		token = SceneFlow.begin_transition(self)
		var owner_node: Node
		if number <= 2:
			var path := "res://enemy/enemy_jefe.tscn" if number == 1 else "res://enemy/enemy_jefe2.tscn"
			owner_node = load(path).instantiate()
			add_child(owner_node)
			owner_node.set_process(false)
			owner_node._activate()
		else:
			owner_node = load("res://level/level_%d.tscn" % number).instantiate()
			add_child(owner_node)
			owner_node.set_process(false)
			owner_node.set_physics_process(false)
			if number == 3:
				owner_node._start_air_intro()
			else:
				owner_node._play_story_intro()
		await get_tree().create_timer(0.9, true).timeout
		assert(not get_tree().paused and _active_boxes().is_empty())
		if number <= 2:
			assert(not owner_node.is_physics_processing())
		SceneFlow.end_transition(token)
		box = await _wait_box()
		assert(not SceneFlow.is_transitioning())
		await _close(box)
		if number <= 2:
			assert(owner_node.is_physics_processing())
		elif number >= 4:
			assert(owner_node._story_intro_done)
		owner_node.queue_free()
		await get_tree().process_frame
	# A disappeared level cannot leave a permanent transition lock.
	var abandoned := Node.new()
	add_child(abandoned)
	SceneFlow.begin_transition(abandoned)
	abandoned.queue_free()
	await get_tree().process_frame
	assert(not SceneFlow.is_transitioning())
	assert(not SceneFlow.has_active_dialogue())
	# The ending deliberately runs while victory is already paused.
	get_tree().paused = true
	preload("res://story/story_dialogues.gd").play(self, "epilogo", "Nopalio", null, true)
	box = await _wait_box()
	await _close(box)
	assert(get_tree().paused and not SceneFlow.has_active_dialogue())
	get_tree().paused = false
	_done = true
	print("TRANSITIONS_TEST_PASS initial_fade=OK gateway=OK special_coin=OK touch_teleport=OK cancelled_npc=OK serialized_npcs=OK bosses=5 abandoned_lock=OK paused_ending=OK")
	get_tree().quit(0)
