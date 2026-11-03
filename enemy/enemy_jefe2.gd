class_name EnemyJefe2 extends Enemy

## Jefe 2: persigue al jugador y ataca con golpes laterales (puñetazo).
## Se activa cuando el jugador entra al escenario del jefe (coordenada Y).

@export var move_speed: float = 160.0
@export var min_distance: float = 180.0
@export var jump_force: float = -500.0
@export var jump_interval_min: float = 1.3
@export var jump_interval_max: float = 2.5

## Distancia a la que el jefe lanza el puñetazo
@export var punch_distance: float = 260.0
## Tiempo entre puñetazos
@export var punch_cooldown_min: float = 1.5
@export var punch_cooldown_max: float = 2.5

## Umbral Y a partir del cual el jefe se activa
@export var activation_y_threshold: float = 4800.0

const JAGUAR_TEX := preload("res://enemy/jaguar_frente_64x64.png")
const DIALOGUE_BOX_SCENE := preload("res://level/dialogue_box.tscn")

var _jump_timer: float = 1.5
var _punch_timer: float = 2.0
var _player: Node2D = null
var _double_jump_charged := false
var _was_ascending := false

var _health: int = 8
var _is_hurt: bool = false
var _is_punching: bool = false   # true mientras dura la animación del puñetazo
var _punch_hit_delivered: bool = false  # evita golpear varias veces por puñetazo
var _activated: bool = false
var _defeated: bool = false

## Nodo Area2D que funciona como hitbox del puñetazo (creado en _ready)
var _punch_hitbox: Area2D = null


func _ready() -> void:
	_reset_jump_timer()
	_reset_punch_timer()
	_player = _find_player()

	# Empezar invisible e inactivo
	sprite.modulate.a = 0.0
	set_process(true)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	# Crear hitbox de puñetazo dinámicamente
	_build_punch_hitbox()


func _build_punch_hitbox() -> void:
	_punch_hitbox = Area2D.new()
	_punch_hitbox.name = "PunchHitbox"
	_punch_hitbox.collision_layer = 0
	_punch_hitbox.collision_mask = 1   # máscara del jugador
	_punch_hitbox.monitoring = false   # se activa solo al golpear

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, 80)
	shape.shape = rect
	shape.position = Vector2(100, 0)  # a la derecha del jefe; se voltea con flip_h
	_punch_hitbox.add_child(shape)
	add_child(_punch_hitbox)

	_punch_hitbox.area_entered.connect(_on_punch_hit_area)
	_punch_hitbox.body_entered.connect(_on_punch_hit_body)


func _find_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		return nodes[0] as Node2D
	return null


func _reset_jump_timer() -> void:
	_jump_timer = randf_range(jump_interval_min, jump_interval_max)


func _reset_punch_timer() -> void:
	_punch_timer = randf_range(punch_cooldown_min, punch_cooldown_max)


# ── Activación ──────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _activated:
		return
	if not is_instance_valid(_player):
		_player = _find_player()
		return
	if _player.global_position.y >= activation_y_threshold:
		_activate()


func _activate() -> void:
	_activated = true
	set_process(false)
	set_physics_process(true)
	collision_layer = 2
	collision_mask = 24
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.6)
	tween.tween_callback(_show_boss_dialogue)


func _show_boss_dialogue() -> void:
	var dlg := DIALOGUE_BOX_SCENE.instantiate() as DialogueBox
	get_tree().current_scene.add_child(dlg)
	get_tree().paused = true
	dlg.dialogue_finished.connect(func() -> void:
		get_tree().paused = false
		await get_tree().process_frame
		dlg.queue_free()
	)
	dlg.start_dialogue("JEFE 2", JAGUAR_TEX, ["¡No pasarás de aquí!"])


# ── Física principal ─────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()

	# Orientar hacia el jugador cuando está en el suelo
	if is_on_floor() and is_instance_valid(_player):
		var diff := _player.global_position.x - global_position.x
		if abs(diff) > 8.0:
			facing_direction = sign(diff)

	# Gravedad
	velocity.y += gravity * delta

	if _state == State.WALKING:
		if not _is_punching:
			_handle_movement(delta)
		else:
			# Durante el puñetazo el jefe se detiene horizontalmente
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

		_handle_punch_logic(delta)

	move_and_slide()

	# Orientar sprite
	if velocity.x > 0.0:
		sprite.flip_h = false
		if _punch_hitbox:
			_punch_hitbox.scale.x = 1.0
	elif velocity.x < 0.0:
		sprite.flip_h = true
		if _punch_hitbox:
			_punch_hitbox.scale.x = -1.0
	elif is_instance_valid(_player):
		# Si está parado, orientar hacia el jugador
		var dir: float = signf(_player.global_position.x - global_position.x)
		sprite.flip_h = (dir < 0.0)
		if _punch_hitbox:
			_punch_hitbox.scale.x = dir if dir != 0.0 else 1.0

	# Animaciones
	var animation := get_new_animation()
	if animation != animation_player.current_animation:
		animation_player.play(animation)


func _handle_movement(delta: float) -> void:
	var too_close := false
	if is_instance_valid(_player):
		too_close = abs(_player.global_position.x - global_position.x) < min_distance
	velocity.x = 0.0 if too_close else move_speed * facing_direction

	if is_on_floor():
		_double_jump_charged = true
		_was_ascending = false

		_jump_timer -= delta
		if _jump_timer <= 0.0:
			velocity.y = jump_force
			_reset_jump_timer()

		# Detectar borde para saltar
		if facing_direction > 0.0 and floor_detector_right and not floor_detector_right.is_colliding():
			velocity.y = jump_force
			_reset_jump_timer()
		elif facing_direction < 0.0 and floor_detector_left and not floor_detector_left.is_colliding():
			velocity.y = jump_force
			_reset_jump_timer()
	else:
		if velocity.y < 0.0:
			_was_ascending = true
		elif _was_ascending and velocity.y >= 0.0 and _double_jump_charged:
			_double_jump_charged = false
			_was_ascending = false
			velocity.y = jump_force * 0.85

		if is_on_wall():
			facing_direction = -facing_direction
			velocity.x = move_speed * facing_direction


func _handle_punch_logic(delta: float) -> void:
	if _is_punching:
		return
	if not is_instance_valid(_player):
		return
	var dist := absf(_player.global_position.x - global_position.x)
	if dist <= punch_distance and is_on_floor():
		_punch_timer -= delta
		if _punch_timer <= 0.0:
			_do_punch()
			_reset_punch_timer()
	else:
		_reset_punch_timer()


func _do_punch() -> void:
	_is_punching = true
	_punch_hit_delivered = false

	# Animación de preparación (fila 4: frames 36-44) → luego golpe (fila 5: frames 45-53)
	animation_player.play(&"punch_windup")
	await animation_player.animation_finished

	if not is_instance_valid(self):
		return

	# Activar hitbox en el frame del golpe
	if _punch_hitbox:
		_punch_hitbox.monitoring = true

	animation_player.play(&"punch_hit")
	await animation_player.animation_finished

	if not is_instance_valid(self):
		return

	# Desactivar hitbox
	if _punch_hitbox:
		_punch_hitbox.monitoring = false

	_is_punching = false


# ── Callbacks de hitbox ──────────────────────────────────────────────────────

func _on_punch_hit_area(_area: Area2D) -> void:
	pass  # No se usa actualmente


func _on_punch_hit_body(body: Node2D) -> void:
	if _punch_hit_delivered:
		return
	if body.is_in_group("player"):
		_punch_hit_delivered = true
		# Llamar al método de daño del jugador
		if body.has_method("take_damage"):
			body.take_damage()
		elif body.has_method("hit"):
			body.hit()


# ── Daño al jefe ─────────────────────────────────────────────────────────────

func destroy() -> void:
	if _is_hurt or _defeated:
		return
	_health -= 1
	if _health <= 0:
		_defeated = true
		super.destroy()
		GameState.notify_boss_defeated()
		return
	_apply_hit_reaction()


func _apply_hit_reaction() -> void:
	_is_hurt = true
	var knockback_dir := -facing_direction
	if is_instance_valid(_player):
		knockback_dir = sign(global_position.x - _player.global_position.x)
	velocity.x = knockback_dir * 380.0
	velocity.y = -280.0
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color.RED, 0.06)
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.30)
	tween.tween_callback(func() -> void: _is_hurt = false)


# ── Animaciones ──────────────────────────────────────────────────────────────

func get_new_animation() -> StringName:
	if _state == State.WALKING:
		if _is_punching:
			# La animación de puñetazo se controla manualmente desde _do_punch
			return StringName(animation_player.current_animation)
		if not is_on_floor():
			if velocity.y < 0.0:
				return &"jump"
			else:
				return &"falling"
		else:
			if abs(velocity.x) > 5.0:
				return &"walk"
			else:
				return &"idle"
	else:
		return &"destroy"
