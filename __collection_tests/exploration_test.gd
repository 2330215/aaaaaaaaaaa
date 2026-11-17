extends Node

var _player: Player
var _driving := false
var _target_x := 0.0
var _done := false
var _jumps := 0

func _ready() -> void:
	RecipeCollection.save_path = "res://__collection_tests/exploration_rewards.cfg"
	RecipeCollection.load_progress()
	_watchdog()
	_run.call_deferred()

func _watchdog() -> void:
	await get_tree().create_timer(90.0, true).timeout
	if not _done:
		push_error("EXPLORATION_TEST_TIMEOUT")
		get_tree().quit(1)

func _physics_process(delta: float) -> void:
	if not _driving or not is_instance_valid(_player) or get_tree().paused:
		return
	var distance := _target_x - _player.global_position.x
	_player.velocity.x = clampf(distance * 12.0, -Player.BASE_WALK_SPEED, Player.BASE_WALK_SPEED)
	_player.velocity.y += float(_player.gravity) * delta
	_player.move_and_slide()

func _feet() -> float:
	var rect: Rect2 = _player.collision_shape.global_transform * _player.collision_shape.shape.get_rect()
	return rect.end.y

func _run() -> void:
	for number in range(1, 6):
		var path := "res://level/level.tscn" if number == 1 else "res://level/level_%d.tscn" % number
		var level := load(path).instantiate() as Node2D
		add_child(level)
		level.set_process(false)
		level.set_physics_process(false)
		for node in level.find_children("*", "Node", true, false):
			if node is Enemy:
				node.collision_layer = 0
				node.collision_mask = 0
				node.process_mode = Node.PROCESS_MODE_DISABLED
			if node is Area2D:
				node.monitoring = false
		var exploration := level.get_node("RecipeExploration")
		assert(not exploration.routes.is_empty())
		for route: Dictionary in exploration.routes:
			assert(level.get_node(str(route.npc)).modulate.a == 0.0)
		_player = preload("res://player/player.tscn").instantiate() as Player
		level.add_child(_player)
		_player.set_physics_process(false)
		for route: Dictionary in exploration.routes:
			var entry: Array = route["entry"]
			var body_rect: Rect2 = _player.collision_shape.transform * _player.collision_shape.shape.get_rect()
			_player.global_position = level.to_global(Vector2(float(entry[0]), float(entry[1]))) - Vector2(0, body_rect.end.y + 0.5)
			_player.velocity = Vector2.ZERO
			_target_x = _player.global_position.x
			_driving = true
			for _frame in range(30):
				await get_tree().physics_frame
			if not _player.is_on_floor():
				print("ENTRY_DEBUG ", route["npc"], " pos=", _player.global_position, " feet=", _feet(), " mask=", _player.collision_mask)
			assert(_player.is_on_floor(), "Entry must be on the existing route: " + str(route["npc"]))
			var previous_left := 0.0
			var previous_right := 0.0
			var has_previous := false
			for shelf: Array in route["platforms"]:
				var shelf_origin := level.to_global(Vector2(float(shelf[0]), float(shelf[1])))
				var left := shelf_origin.x
				var top := shelf_origin.y
				var right := left + float(shelf[2]) * 64.0
				# Walk to the departure edge, as a player would, before jumping.
				if has_previous:
					_target_x = previous_right - 28 if left >= previous_right else previous_left + 28
					if left < previous_right and right > previous_left:
						_target_x = clampf((left + right) * 0.5, previous_left + 28, previous_right - 28)
					for _frame in range(90):
						await get_tree().physics_frame
						if absf(_player.global_position.x - _target_x) < 3:
							break
				_target_x = clampf(_player.global_position.x, left + 32, right - 32)
				_player.velocity.y = Player.BASE_JUMP_VELOCITY
				var landed := false
				var minimum_feet := _feet()
				for frame in range(130):
					await get_tree().physics_frame
					minimum_feet = minf(minimum_feet, _feet())
					if frame > 5 and _player.is_on_floor() and absf(_feet() - top) < 3.0 and _player.global_position.x > left + 8 and _player.global_position.x < right - 8:
						landed = true
						break
				if not landed:
					for platform in exploration.get_children():
						if platform is AnimatableBody2D:
							print("PLATFORM_DEBUG ", platform.name, " pos=", platform.global_position, " layer=", platform.collision_layer, " shape=", platform.get_node("CollisionShape2D").global_position, " server=", PhysicsServer2D.body_get_state(platform.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM))
					var query := PhysicsRayQueryParameters2D.create(Vector2(_target_x, top - 100), Vector2(_target_x, top + 200), 30, [_player.get_rid()])
					print("JUMP_DEBUG min_feet=", minimum_feet, " gravity=", _player.gravity, " ray=", _player.get_world_2d().direct_space_state.intersect_ray(query))
					push_error("UNREACHABLE_ROUTE %s shelf=%s player=%s feet=%s" % [route["npc"], shelf, _player.global_position, _feet()])
					_done = true
					get_tree().quit(1)
					return
				_jumps += 1
				previous_left = left
				previous_right = right
				has_previous = true
			var npc := level.get_node(str(route["npc"])) as DialogueEnemy
			var standing: Array = route["standing"]
			var standing_point := level.to_global(Vector2(float(standing[0]), float(standing[1])))
			_target_x = standing_point.x
			for _frame in range(60):
				await get_tree().physics_frame
				if absf(_player.global_position.x - _target_x) < 3:
					break
			_driving = false
			assert(_player.is_on_floor())
			assert(absf(_feet() - standing_point.y) < 3.0)
			assert(npc.position.distance_to(_player.position) < 80)
			var bounds: Rect2 = npc.sprite.global_transform * npc.sprite.get_rect()
			assert(absf(bounds.end.y - standing_point.y) < 2.0)
			assert((npc.interaction_area.get_node("CollisionShape2D").shape as CircleShape2D).radius == 52.0)
			npc._on_interaction_body_entered(_player)
			for _frame in range(6):
				await get_tree().process_frame
			assert(npc._dialogue_box != null and npc._dialogue_box._active)
			npc._dialogue_box._finish_dialogue()
			await npc._dialogue_box.dialogue_finished
			assert(RecipeCollection.is_unlocked(str(route["recipe"])))
			assert(npc.modulate.a > 0.99)
			print("ROUTE_REACHED ", route["npc"], " feet=", standing)
		level.queue_free()
		await get_tree().process_frame
	_done = true
	print("EXPLORATION_TEST_PASS hidden_npcs=7 normal_jumps=%d terrain_collisions=OK standing=OK nearby_reveal=OK dialogue_rewards=OK" % _jumps)
	get_tree().quit(0)
