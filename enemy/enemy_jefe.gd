class_name EnemyJefe extends Enemy

## Enemigo Jefe que persigue al jugador, salta constantemente y lanza proyectiles buscadores.

@export var move_speed: float = 150.0
@export var min_distance: float = 120.0  # distancia mínima al jugador
@export var jump_force: float = -520.0
@export var jump_interval_min: float = 1.2
@export var jump_interval_max: float = 2.2

## Disparo de proyectiles
@export var shoot_interval_min: float = 2
@export var shoot_interval_max: float = 2

const SEEKER_SCENE := preload("res://enemy/jefe_seeker.tscn")

var _jump_timer: float = 1.5
var _shoot_timer: float = 2.5
var _player: Node2D = null
var _double_jump_charged := false
var _was_ascending := false

var _health: int = 2
var _is_hurt: bool = false  # invencibilidad temporal entre golpes


func _ready() -> void:
	_reset_jump_timer()
	_reset_shoot_timer()
	_player = _find_player()


func _find_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		return nodes[0] as Node2D
	return null


func _reset_jump_timer() -> void:
	_jump_timer = randf_range(jump_interval_min, jump_interval_max)


func _reset_shoot_timer() -> void:
	_shoot_timer = randf_range(shoot_interval_min, shoot_interval_max)


func _physics_process(delta: float) -> void:
	# Actualizar referencia al jugador si cambia (splitscreen, respawn, etc.)
	if not is_instance_valid(_player):
		_player = _find_player()

	# Perseguir al jugador: solo corregir dirección cuando está en el suelo.
	# Al ir rápido y saltar se desvía del jugador (overshoot natural).
	if is_on_floor() and is_instance_valid(_player):
		var diff := _player.global_position.x - global_position.x
		if abs(diff) > 8.0:
			facing_direction = sign(diff)

	# Aplicar gravedad
	velocity.y += gravity * delta

	if _state == State.WALKING:
		# Caminar hacia el jugador solo si está suficientemente lejos
		var too_close := false
		if is_instance_valid(_player):
			too_close = abs(_player.global_position.x - global_position.x) < min_distance
		velocity.x = 0.0 if too_close else move_speed * facing_direction

		if is_on_floor():
			# Al tocar suelo se recarga el salto doble
			_double_jump_charged = true
			_was_ascending = false

			# Temporizador de salto
			_jump_timer -= delta
			if _jump_timer <= 0.0:
				velocity.y = jump_force
				_reset_jump_timer()

			# Detección de bordes: si hay vacío al frente, forzar salto
			if facing_direction > 0.0 and floor_detector_right and not floor_detector_right.is_colliding():
				velocity.y = jump_force
				_reset_jump_timer()
			elif facing_direction < 0.0 and floor_detector_left and not floor_detector_left.is_colliding():
				velocity.y = jump_force
				_reset_jump_timer()
		else:
			# Salto doble: se dispara cuando empieza a caer tras el primer salto
			if velocity.y < 0.0:
				_was_ascending = true
			elif _was_ascending and velocity.y >= 0.0 and _double_jump_charged:
				_double_jump_charged = false
				_was_ascending = false
				velocity.y = jump_force * 0.85

		# Cambiar de dirección al chocar con una pared
		if is_on_wall():
			facing_direction = -facing_direction
			velocity.x = move_speed * facing_direction

		# Contador de disparo
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_seeker()
			_reset_shoot_timer()

	move_and_slide()

	# Orientación del sprite
	if velocity.x > 0.0:
		sprite.flip_h = false
	elif velocity.x < 0.0:
		sprite.flip_h = true

	# Animaciones
	var animation := get_new_animation()
	if animation != animation_player.current_animation:
		animation_player.play(animation)


func destroy() -> void:
	if _is_hurt:
		return
	_health -= 1
	if _health <= 0:
		# Muerte real: delegar al padre
		super.destroy()
		return
	_apply_hit_reaction()


func _apply_hit_reaction() -> void:
	_is_hurt = true

	# Knockback: salto pequeño hacia atrás (alejándose del jugador)
	var knockback_dir := -facing_direction
	if is_instance_valid(_player):
		knockback_dir = sign(global_position.x - _player.global_position.x)
	velocity.x = knockback_dir * 380.0
	velocity.y = -300.0

	# Flash rojo: sprite se vuelve rojo y vuelve a blanco
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color.RED, 0.06)
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.30)
	tween.tween_callback(func() -> void: _is_hurt = false)


func _shoot_seeker() -> void:
	if not is_instance_valid(_player):
		return
	if not SEEKER_SCENE:
		return
	var seeker = SEEKER_SCENE.instantiate()
	# Spawnear en la posición del jefe, al nivel del mundo para que se mueva libre
	seeker.global_position = global_position + Vector2(facing_direction * 20.0, -20.0)
	get_tree().current_scene.add_child(seeker)


func get_new_animation() -> StringName:
	var animation_new: StringName
	if _state == State.WALKING:
		if not is_on_floor():
			if velocity.y < 0.0:
				animation_new = &"jump"
			else:
				if animation_player.has_animation(&"falling"):
					animation_new = &"falling"
				else:
					animation_new = &"jump"
		else:
			if abs(velocity.x) > 5.0:
				animation_new = &"walk"
			else:
				animation_new = &"idle"
	else:
		animation_new = &"destroy"
	return animation_new
