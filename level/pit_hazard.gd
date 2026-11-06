class_name PitHazard extends Area2D
## Detecta caidas al vacio y busca suelo cercano para reaparecer.

@export var respawn_position: Vector2 = Vector2(128, 448)

@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
@onready var game_over_panel: Control = $CanvasLayer/GameOverPanel

var _triggered := false


func _ready() -> void:
	add_to_group("pit_hazard")
	# Seguir corriendo aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 0)
		fade_rect.visible = false
	if game_over_panel:
		game_over_panel.visible = false


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	trigger(body)


func trigger(body: Node2D) -> void:
	if _triggered:
		return
	_triggered = true

	# Elegir una superficie cercana con espacio para todo el jugador.
	var player := body as Player
	if player:
		player.die_from_pit(_find_solid_respawn(player))
	_triggered = false


func _find_solid_respawn(player: Player) -> Vector2:
	var nearest := (get_parent() as Node2D).to_global(respawn_position)
	var nearest_distance := INF
	var space := get_world_2d().direct_space_state
	var collider := player.collision_shape
	var body_bounds: Rect2 = collider.transform * collider.shape.get_rect()
	var clearance := PhysicsShapeQueryParameters2D.new()
	clearance.shape = collider.shape
	clearance.collision_mask = player.collision_mask
	clearance.exclude = [player.get_rid()]
	for node in get_parent().find_children("*", "TileMapLayer", true, false):
		var map := node as TileMapLayer
		if not map.collision_enabled:
			continue
		var half_tile := Vector2(map.tile_set.tile_size) * 0.5
		for cell in map.get_used_cells():
			var data := map.get_cell_tile_data(cell)
			if data == null:
				continue
			var solid := false
			for layer in range(map.tile_set.get_physics_layers_count()):
				if map.tile_set.get_physics_layer_collision_layer(layer) & player.collision_mask:
					solid = solid or data.get_collision_polygons_count(layer) > 0
			if not solid:
				continue
			var top := map.to_global(map.map_to_local(cell) - Vector2(0, half_tile.y))
			var ray := PhysicsRayQueryParameters2D.create(
				top - Vector2(0, 2), top + Vector2(0, half_tile.y * 2), player.collision_mask, [player.get_rid()])
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.collider != map or hit.normal.y > -0.7:
				continue
			var candidate: Vector2 = hit.position - Vector2(body_bounds.get_center().x, body_bounds.end.y + 2.0)
			var distance := candidate.distance_squared_to(player.global_position)
			if distance >= nearest_distance:
				continue
			clearance.transform = Transform2D(player.global_rotation, candidate) * collider.transform
			if not space.intersect_shape(clearance, 1).is_empty():
				continue
			nearest = candidate
			nearest_distance = distance
	return nearest


## Muestra el panel PERDISTE, fundido y recarga el nivel (Game Over total).
func show_game_over_and_reload() -> void:
	if _triggered:
		return
	_triggered = true

	get_tree().paused = true

	# Pausa música
	var music_node = get_node_or_null("/root/Music")
	if music_node and music_node.has_method("stop"):
		music_node.stream_paused = true

	# Mostrar panel PERDISTE
	if game_over_panel:
		game_over_panel.modulate.a = 0.0
		game_over_panel.visible = true
		var tween_ui := create_tween()
		tween_ui.tween_property(game_over_panel, "modulate:a", 1.0, 0.4)
		await tween_ui.finished

	await get_tree().create_timer(1.8, true).timeout

	# Fade to black
	if fade_rect:
		fade_rect.visible = true
		var tween_fade := create_tween()
		tween_fade.tween_property(fade_rect, "color:a", 1.0, 1.0)
		await tween_fade.finished

	# Ocultar panel
	if game_over_panel:
		game_over_panel.visible = false

	# Reanudar árbol antes de recargar
	get_tree().paused = false
	if music_node:
		music_node.stream_paused = false

	get_tree().reload_current_scene()
	_triggered = false
