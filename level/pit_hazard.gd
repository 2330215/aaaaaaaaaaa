class_name PitHazard extends Area2D
## Hazard area for a pit that detaches camera so player falls into the abyss, shows PERDISTE, and resets level.

@export var respawn_position: Vector2 = Vector2(128, 448)

@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
@onready var game_over_panel: Control = $CanvasLayer/GameOverPanel

var _triggered := false


func _ready() -> void:
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 0)
		fade_rect.visible = false
	if game_over_panel:
		game_over_panel.visible = false


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not (body is Player):
		return
	_triggered = true

	# 1. Detach camera so it stays fixed at top of pit while player falls into the abyss
	var camera: Camera2D = body.get_node_or_null("Camera")
	if camera:
		camera.top_level = true

	# 2. Pause background music
	var music_node = get_node_or_null("/root/Music")
	if music_node and music_node.has_method("stop"):
		music_node.stream_paused = true

	# 3. Show "PERDISTE" UI overlay
	if game_over_panel:
		game_over_panel.modulate.a = 0.0
		game_over_panel.visible = true
		var tween_ui := create_tween()
		tween_ui.tween_property(game_over_panel, "modulate:a", 1.0, 0.4)
		await tween_ui.finished

	# 4. Display "PERDISTE" screen for 1.8 seconds while player falls down
	await get_tree().create_timer(1.8).timeout

	# 5. Stop player physics movement before teleport
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO
		body.set_physics_process(false)

	# 6. Fade screen to black over 1 second
	if fade_rect:
		fade_rect.visible = true
		var tween_fade := create_tween()
		tween_fade.tween_property(fade_rect, "color:a", 1.0, 1.0)
		await tween_fade.finished

	# 7. Restore Sky background and align to Stage 1 while screen is 100% black
	var current_scene = get_tree().current_scene
	if current_scene:
		var bg = current_scene.find_child("ParallaxBackground", true, false)
		if bg:
			if bg.has_method("set_cave_mode"):
				bg.set_cave_mode(false)
			if bg.has_method("align_to_stage"):
				bg.align_to_stage(0)

	# Hide "PERDISTE" UI panel while screen is black
	if game_over_panel:
		game_over_panel.visible = false

	# 8. Reset player position & re-attach camera to player
	body.global_position = respawn_position
	if camera:
		camera.top_level = false
		camera.position = Vector2(0, -28)

	if body.get_parent():
		for sibling in body.get_parent().get_children():
			if sibling is Player and sibling != body:
				sibling.global_position = respawn_position + Vector2(30, 0)
				var sib_cam: Camera2D = sibling.get_node_or_null("Camera")
				if sib_cam:
					sib_cam.top_level = false
					sib_cam.position = Vector2(0, -28)

	await get_tree().process_frame

	# 9. Resume music and player physics
	if music_node:
		music_node.stream_paused = false
	if body is CharacterBody2D:
		body.set_physics_process(true)

	# 10. Fade back in from black over 1 second
	if fade_rect:
		var tween_in := create_tween()
		tween_in.tween_property(fade_rect, "color:a", 0.0, 1.0)
		await tween_in.finished
		fade_rect.visible = false

	_triggered = false
