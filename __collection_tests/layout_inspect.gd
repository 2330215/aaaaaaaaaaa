extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var result: Dictionary = {}
	for number in range(1, 6):
		var path := "res://level/level.tscn" if number == 1 else "res://level/level_%d.tscn" % number
		var level := load(path).instantiate() as Node2D
		add_child(level)
		level.set_process(false)
		level.set_physics_process(false)
		var cells: Array = []
		for map: TileMapLayer in level.find_children("*", "TileMapLayer", true, false):
			if not map.collision_enabled:
				continue
			for cell in map.get_used_cells():
				var data := map.get_cell_tile_data(cell)
				if data == null:
					continue
				var solid := false
				for layer in range(map.tile_set.get_physics_layers_count()):
					if map.tile_set.get_physics_layer_collision_layer(layer) & 24:
						solid = solid or data.get_collision_polygons_count(layer) > 0
				if solid:
					var pos := map.to_global(map.map_to_local(cell))
					cells.append([pos.x, pos.y, map.tile_set.tile_size.x, str(map.get_path())])
		var statics: Array = []
		for collider: CollisionShape2D in level.find_children("*", "CollisionShape2D", true, false):
			var body := collider.get_parent() as StaticBody2D
			if body and body.collision_layer & 24 and collider.shape and not collider.disabled:
				var rect: Rect2 = collider.global_transform * collider.shape.get_rect()
				statics.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y, str(body.name)])
		var props: Array = []
		for sprite: Sprite2D in level.find_children("*", "Sprite2D", true, false):
			if sprite.texture and sprite.get_parent() == level:
				props.append([str(sprite.name), sprite.position.x, sprite.position.y, sprite.texture.resource_path])
		result[number] = {"cells": cells, "statics": statics, "props": props}
		await get_tree().physics_frame
		await get_tree().physics_frame
		var exploration := level.get_node("RecipeExploration")
		for route: Dictionary in exploration.routes:
			var point := level.to_global(Vector2(float(route.entry[0]), float(route.entry[1])))
			var ray := PhysicsRayQueryParameters2D.create(point - Vector2(0, 16), point + Vector2(0, 180), 24)
			var hit := level.get_world_2d().direct_space_state.intersect_ray(ray)
			print("ENTRY_SURFACE ", route.npc, " expected=", point, " actual=", hit.get("position", null))
		level.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open("res://__collection_tests/layout.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result))
	f.close()
	print("LAYOUT_EXTRACTED")
	get_tree().quit()
