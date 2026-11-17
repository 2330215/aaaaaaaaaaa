extends Node2D
## Optional trails built with existing one-way platforms, away from the main path.
const ROUTES = preload("res://level/recipe_routes.json")
const PLATFORM = preload("res://level/platforms/forest_platform.tscn")
var routes: Array = []
var _marks: Array[Vector2] = []
var _hidden_authors: Array[WeakRef] = []


func build(level: Node2D) -> void:
	name = "RecipeExploration"
	var key := level.scene_file_path.get_file().get_basename()
	var config: Dictionary = ROUTES.data.get(key, {})
	if config.is_empty():
		return
	routes = config["routes"].duplicate(true)
	for route: Dictionary in routes:
		var npc := level.get_node_or_null(str(route["npc"])) as DialogueEnemy
		if npc == null:
			continue
		var entry: Array = route["entry"]
		_marks.append(Vector2(float(entry[0]), float(entry[1]) - 14.0))
		var shelf_index := 0
		for shelf: Array in route["platforms"]:
			var platform := PLATFORM.instantiate() as AnimatableBody2D
			platform.name = str(route["npc"]) + "_Trail_%d" % shelf_index
			# The existing platform's collision top is 21 px above its origin.
			platform.position = Vector2(float(shelf[0]) + 96.0, float(shelf[1]) + 21.0)
			add_child(platform)
			var artwork := platform.get_node("Sprite2D") as Sprite2D
			if key in ["level", "level_2"]:
				artwork.texture = preload("res://level/platforms/moving_platform.webp")
			elif key in ["level_4", "level_5"]:
				artwork.texture = preload("res://level/props/puente_selva.png")
				artwork.scale = Vector2(0.5, 0.5)
				artwork.position = Vector2(0, -35)
			if shelf_index == 0:
				_marks.append(Vector2(float(shelf[0]) + 96, float(shelf[1]) - 14))
			shelf_index += 1
		var standing: Array = route["standing"]
		var sprite_bounds: Rect2 = npc.sprite.transform * npc.sprite.get_rect()
		npc.position = Vector2(float(standing[0]), float(standing[1]) - sprite_bounds.end.y - 1.0)
		# Keep the character visible on reaching the nook, without interrupting
		# someone who is just walking below it on the main route.
		var shape_node := npc.interaction_area.get_node("CollisionShape2D") as CollisionShape2D
		shape_node.shape = shape_node.shape.duplicate()
		if shape_node.shape is CircleShape2D:
			(shape_node.shape as CircleShape2D).radius = 52.0
		npc.collision_layer = 0
		npc.collision_mask = 0
		npc.modulate.a = 0.0
		_hidden_authors.append(weakref(npc))
	queue_redraw()


func _process(_delta: float) -> void:
	for author_ref: WeakRef in _hidden_authors.duplicate():
		var npc := author_ref.get_ref() as Node2D
		if not is_instance_valid(npc):
			_hidden_authors.erase(author_ref)
			continue
		for player in get_tree().get_nodes_in_group("player"):
			if not (player is Player) or not player.is_inside_tree() or player.get_world_2d() != get_world_2d():
				continue
			var difference: Vector2 = player.global_position - npc.global_position
			if absf(difference.y) < 110.0 and difference.length() < 160.0:
				_hidden_authors.erase(author_ref)
				var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				reveal.tween_property(npc, "modulate:a", 1.0, 0.2)
				break


func _draw() -> void:
	# Tiny paper-shaped clues mark the start of an optional trail. They are
	# scenery, not rewards: the recipe still comes from talking to its author.
	for mark in _marks:
		draw_rect(Rect2(mark - Vector2(8, 11), Vector2(16, 22)), Color("634a31"))
		draw_rect(Rect2(mark - Vector2(6, 9), Vector2(12, 18)), Color("f1d89d"))
		draw_rect(Rect2(mark + Vector2(-3, -4), Vector2(6, 2)), Color("ae8050"))
		draw_rect(Rect2(mark + Vector2(-3, 1), Vector2(4, 2)), Color("ae8050"))
