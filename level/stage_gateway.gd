class_name StageGateway extends Area2D
## Pasillo de transición entre escenarios.
## El jugador camina hacia la derecha y entra en el pasillo;
## al cruzar la zona de detección se produce un fade negro,
## teletransporte y fade de vuelta — igual que el SpecialCoin.
## Es reutilizable: nunca desaparece.

@export var target_position: Vector2 = Vector2.ZERO
@export var target_stage_index: int = 0
@export var switch_to_cave: bool = false
@export var switch_to_sky: bool = false

@onready var fade_rect: ColorRect = $CanvasLayer/ColorRect

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
	GameState.record_special_coin()
	set_deferred("monitoring", false)

	# 1. Fade a negro
	if fade_rect:
		fade_rect.visible = true
		var tween := create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
		await tween.finished

	# 2. Pausa un segundo con pantalla negra
	await get_tree().create_timer(1.0).timeout

	# 3. Cambiar fondo mientras la pantalla está negra
	var backgrounds := get_tree().get_nodes_in_group("level_background")
	for bg in backgrounds:
		if bg.has_method("set_stage"):
			bg.set_stage(target_stage_index)
		if bg.has_method("align_to_stage"):
			bg.align_to_stage(target_stage_index)

	# 4. Teletransportar al jugador (y al compañero en splitscreen)
	body.global_position = target_position
	if body.get_parent():
		for sibling in body.get_parent().get_children():
			if sibling is Player and sibling != body:
				sibling.global_position = target_position + Vector2(25, 0)

	await get_tree().process_frame

	# 5. Fade de vuelta
	if fade_rect:
		var tween_in := create_tween()
		tween_in.tween_property(fade_rect, "color:a", 0.0, 1.0)
		await tween_in.finished
		fade_rect.visible = false

	# 6. Rearmar: el pasillo siempre puede usarse de nuevo
	set_deferred("monitoring", true)
	_triggered = false
