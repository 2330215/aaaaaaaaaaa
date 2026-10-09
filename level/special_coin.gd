class_name SpecialCoin extends Area2D
## Special coin that fades screen to black over 1s, pauses 1s, and teleports player.

@export var target_position: Vector2 = Vector2.ZERO
@export var target_stage_index: int = 0
@export var switch_to_cave: bool = false
@export var switch_to_sky: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var fade_rect: ColorRect = $CanvasLayer/ColorRect
@onready var pickup_sound: AudioStreamPlayer2D = $Pickup

var _triggered := false


func _ready() -> void:
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 0)
		fade_rect.visible = false


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not (body is Player):
		return
	_triggered = true
	set_deferred("monitoring", false)

	if pickup_sound and pickup_sound.stream:
		pickup_sound.play()

	# 1. Fade screen to black over 1 second
	if fade_rect:
		fade_rect.visible = true
		var tween := create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
		await tween.finished

	# 2. Non-automatic 1-second hold pause on black screen
	await get_tree().create_timer(1.0).timeout

	# 3. Switch background texture & align background to target stage while screen is 100% black
	var current_scene = get_tree().current_scene
	if current_scene:
		var bg = current_scene.find_child("ParallaxBackground", true, false)
		if bg:
			if bg.has_method("set_cave_mode"):
				if switch_to_cave:
					bg.set_cave_mode(true)
				elif switch_to_sky:
					bg.set_cave_mode(false)
			if bg.has_method("align_to_stage"):
				bg.align_to_stage(target_stage_index)

	# 4. Teleport player while screen is black
	body.global_position = target_position
	
	if body.get_parent():
		for sibling in body.get_parent().get_children():
			if sibling is Player and sibling != body:
				sibling.global_position = target_position + Vector2(25, 0)

	await get_tree().process_frame

	# 5. Fade back in from black over 1 second
	if fade_rect:
		var tween_in := create_tween()
		tween_in.tween_property(fade_rect, "color:a", 0.0, 1.0)
		await tween_in.finished
		fade_rect.visible = false

	queue_free()
