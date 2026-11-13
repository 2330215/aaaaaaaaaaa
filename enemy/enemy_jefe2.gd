class_name EnemyJefe2 extends Enemy

## Jefe 2: persigue al jugador y ataca con golpes laterales (puñetazo).
## Se activa cuando el jugador entra al escenario del jefe (coordenada Y).

@export var move_speed: float = 240.0
@export var min_distance: float = 110.0
@export var jump_force: float = -620.0
@export var jump_interval_min: float = 2.0
@export var jump_interval_max: float = 3.0

## Distancia a la que el jefe lanza el puñetazo
@export var punch_distance: float = 320.0
@export var punch_speed: float = 680.0
## Tiempo entre puñetazos
@export var punch_cooldown_min: float = 0.08
@export var punch_cooldown_max: float = 0.18

## Umbral Y a partir del cual el jefe se activa
@export var activation_y_threshold: float = 4800.0

const BOSS_PORTRAIT := preload("res://enemy/portraits/enemy_jefe2.png")
const DIALOGUE_BOX_SCENE := preload("res://level/dialogue_box.tscn")

enum PunchPhase { NONE, WINDUP, LUNGE, RECOVERY }

const WINDUP_TIME := 0.30
const LUNGE_TIME := 0.34
const RECOVERY_TIME := 0.18

var _jump_timer: float = 1.5
var _punch_timer: float = 2.0
var _player: Node2D = null

var _health: int = 8
var _hit_stun_left: float = 0.0
var _is_hurt: bool = false
var _is_punching: bool = false   # true mientras dura la animación del puñetazo
var _punch_phase := PunchPhase.NONE
var _phase_time := 0.0
var _attack_direction := 1.0
var _sprite_rest_position := Vector2.ZERO
var _punch_hit_delivered: bool = false  # evita golpear varias veces por puñetazo
var _activated: bool = false
var _defeated: bool = false

## Nodo Area2D que funciona como hitbox del puñetazo (creado en _ready)
var _punch_hitbox: Area2D = null


func _ready() -> void:
	super._ready()
	_sprite_rest_position = sprite.position
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
	_fit_floor_detectors()


func _build_punch_hitbox() -> void:
	_punch_hitbox = Area2D.new()
	_punch_hitbox.name = "PunchHitbox"
	_punch_hitbox.collision_layer = 0
	_punch_hitbox.collision_mask = 1   # máscara del jugador
	_punch_hitbox.monitoring = false   # se activa solo al golpear

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 72)
	shape.shape = rect
	_punch_hitbox.add_child(shape)
	add_child(_punch_hitbox)

	_punch_hitbox.body_entered.connect(_on_punch_hit_body)
	_fit_punch_hitbox()


func _body_bounds() -> Rect2:
	var collider := $CollisionShape2D as CollisionShape2D
	return collider.transform * collider.shape.get_rect()


func _fit_floor_detectors() -> void:
	var bounds := _body_bounds()
	var margin := 12.0 / absf(global_scale.y)
	for detector in [floor_detector_left, floor_detector_right]:
		# Los rayos heredaban otra escala de 0.5 y terminaban dentro del cuerpo.
		detector.scale = Vector2.ONE
		detector.position.y = bounds.get_center().y
		detector.target_position = Vector2(0, bounds.size.y * 0.5 + margin)
	floor_detector_left.position.x = bounds.position.x - 6.0 / absf(global_scale.x)
	floor_detector_right.position.x = bounds.end.x + 6.0 / absf(global_scale.x)


func _fit_punch_hitbox() -> void:
	var bounds := _body_bounds()
	var collider := _punch_hitbox.get_child(0) as CollisionShape2D
	var rectangle := collider.shape as RectangleShape2D
	rectangle.size = Vector2(maxf(bounds.size.x * 0.65, 48.0 / absf(global_scale.x)), bounds.size.y * 0.9)
	collider.position = bounds.get_center() + Vector2(facing_direction * (bounds.size.x * 0.5 + rectangle.size.x * 0.5 - 8.0), 0)


func _target_bounds() -> Rect2:
	var collider := _player.get_node("CollisionShape2D") as CollisionShape2D
	return collider.global_transform * collider.shape.get_rect()


func _find_player() -> Node2D:
	var nearest: Player = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player._is_dead or player.get_world_2d() != get_world_2d():
			continue
		var distance := global_position.distance_squared_to(player.global_position)
		if distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	return nearest


func _reset_jump_timer() -> void:
	_jump_timer = randf_range(jump_interval_min, jump_interval_max)


func _reset_punch_timer() -> void:
	_punch_timer = randf_range(punch_cooldown_min, punch_cooldown_max)


# ── Activación ──────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _activated:
		return
	_player = _find_player()
	if not is_instance_valid(_player):
		return
	var level := get_parent() as Node2D
	var gateway := level.get_node_or_null("StageGateway2") as StageGateway
	if gateway and gateway._triggered:
		return
	if level.to_local(_player.global_position).y >= activation_y_threshold:
		_activate()


func _activate() -> void:
	_activated = true
	set_process(false)
	# Esperar al cierre del dialogo antes de comenzar el combate.
	set_physics_process(false)
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
		set_physics_process(true)
		await get_tree().process_frame
		dlg.queue_free()
	)
	dlg.start_dialogue("Boxeador", preload("res://enemy/portraits/enemy_jefe2.png"), preload("res://story/story_dialogues.gd").lines("boxeador"))


# ── Física principal ─────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	_hit_stun_left = maxf(0.0, _hit_stun_left - delta)
	_player = _find_player()
	_fit_floor_detectors()

	if _state == State.WALKING and not _is_punching and _hit_stun_left <= 0.0 and is_instance_valid(_player):
		var diff := _player.global_position.x - global_position.x
		if absf(diff) > 8.0:
			facing_direction = signf(diff)

	if _state == State.WALKING and _hit_stun_left <= 0.0:
		# El salto se prepara también mientras golpea, sin interrumpir el puñetazo.
		_jump_timer = maxf(0.0, _jump_timer - delta)

	velocity.y += gravity * delta
	if _state == State.WALKING:
		if _hit_stun_left > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		elif _is_punching:
			_update_punch(delta)
		else:
			_handle_movement(delta)
			# Un salto para interceptar tiene prioridad cuando termina el descanso.
			if velocity.y >= 0.0:
				_handle_punch_logic(delta)
	else:
		velocity.x = 0.0

	move_and_slide()
	if _punch_phase == PunchPhase.LUNGE and _punch_hitbox.monitoring:
		for body in _punch_hitbox.get_overlapping_bodies():
			_on_punch_hit_body(body)
	if _punch_phase == PunchPhase.LUNGE and is_on_wall():
		_begin_recovery()

	# La dirección queda fijada durante todo el golpe, incluso si el jugador lo esquiva.
	sprite.flip_h = facing_direction < 0.0
	_fit_punch_hitbox()

	# Animaciones
	var animation := get_new_animation()
	if animation != animation_player.current_animation:
		animation_player.play(animation)


func _handle_movement(_delta: float) -> void:
	var too_close := false
	if is_instance_valid(_player):
		too_close = abs(_player.global_position.x - global_position.x) < min_distance
	velocity.x = 0.0 if too_close else move_speed * facing_direction

	if is_on_floor():
		var detector := floor_detector_right if facing_direction > 0.0 else floor_detector_left
		detector.force_raycast_update()
		var at_edge := not detector.is_colliding()
		var needs_jump := _jump_timer <= 0.0 or at_edge or is_on_wall()
		if is_instance_valid(_player):
			var target := _target_bounds()
			var body: Rect2 = global_transform * _body_bounds()
			var nearby := absf(target.get_center().x - body.get_center().x) <= punch_distance
			needs_jump = needs_jump or (nearby and target.end.y < body.end.y - 48.0)
		if needs_jump and _jump_timer <= 0.0:
			velocity.y = jump_force
			velocity.x = move_speed * facing_direction
			_reset_jump_timer()
		elif at_edge:
			velocity.x = 0.0
	elif is_on_wall():
		velocity.x = 0.0


func _handle_punch_logic(delta: float) -> void:
	_punch_timer = maxf(0.0, _punch_timer - delta)
	if not is_instance_valid(_player):
		return
	var body: Rect2 = global_transform * _body_bounds()
	var target := _target_bounds()
	var gap_x := maxf(0.0, maxf(target.position.x - body.end.x, body.position.x - target.end.x))
	var overlaps_height := target.end.y >= body.position.y and target.position.y <= body.end.y
	# No cargar desde mas lejos de lo que realmente alcanza la embestida.
	var reach := minf(punch_distance, punch_speed * LUNGE_TIME * 0.7 + 40.0)
	if gap_x <= reach and overlaps_height and is_on_floor() and _punch_timer <= 0.0:
		_do_punch()


func _do_punch() -> void:
	_is_punching = true
	_punch_hit_delivered = false
	_attack_direction = facing_direction
	_punch_phase = PunchPhase.WINDUP
	_phase_time = 0.0
	velocity.x = 0.0
	animation_player.play(&"punch_windup", -1.0, 0.45 / WINDUP_TIME)


func _update_punch(delta: float) -> void:
	_phase_time += delta
	match _punch_phase:
		PunchPhase.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
			sprite.position.x = _sprite_rest_position.x - 8.0 * _attack_direction * minf(_phase_time / WINDUP_TIME, 1.0)
			if _phase_time >= WINDUP_TIME:
				_punch_phase = PunchPhase.LUNGE
				_phase_time = 0.0
				animation_player.play(&"punch_hit")
		PunchPhase.LUNGE:
			# El cuerpo avanza mediante la física; nunca se teletransporta a través de paredes.
			var detector := floor_detector_right if _attack_direction > 0.0 else floor_detector_left
			detector.force_raycast_update()
			if not is_on_floor() or not detector.is_colliding():
				_begin_recovery()
				return
			velocity.x = _attack_direction * punch_speed * lerpf(1.0, 0.55, minf(_phase_time / LUNGE_TIME, 1.0))
			sprite.position.x = lerpf(sprite.position.x, _sprite_rest_position.x + 18.0 * _attack_direction, minf(delta * 28.0, 1.0))
			sprite.rotation = -0.08 * _attack_direction
			# El daño solo coincide con la extensión del puño, no con la preparación.
			_punch_hitbox.set_deferred("monitoring", _phase_time >= 0.05 and _phase_time < 0.28)
			if _phase_time >= LUNGE_TIME:
				_begin_recovery()
		PunchPhase.RECOVERY:
			velocity.x = move_toward(velocity.x, 0.0, 2600.0 * delta)
			sprite.position = sprite.position.lerp(_sprite_rest_position, minf(delta * 18.0, 1.0))
			sprite.rotation = lerpf(sprite.rotation, 0.0, minf(delta * 18.0, 1.0))
			if _phase_time >= RECOVERY_TIME:
				_cancel_punch()
				_reset_punch_timer()


func _begin_recovery() -> void:
	_punch_phase = PunchPhase.RECOVERY
	_phase_time = 0.0
	velocity.x = 0.0
	_punch_hitbox.set_deferred("monitoring", false)
	animation_player.play(&"punch_recover", -1.0, 0.28 / RECOVERY_TIME)


func _cancel_punch() -> void:
	_is_punching = false
	_punch_phase = PunchPhase.NONE
	_punch_hitbox.set_deferred("monitoring", false)
	sprite.position = _sprite_rest_position
	sprite.rotation = 0.0


# ── Callbacks de hitbox ──────────────────────────────────────────────────────

func _on_punch_hit_body(body: Node2D) -> void:
	if _punch_hit_delivered or _punch_phase != PunchPhase.LUNGE or _state != State.WALKING:
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
		_cancel_punch()
		super.destroy()
		GameState.notify_boss_defeated()
		return
	_apply_hit_reaction()


func _apply_hit_reaction() -> void:
	_is_hurt = true
	# Un impacto no interrumpe un puñetazo ya preparado o en ejecución.
	if not _is_punching:
		_hit_stun_left = 0.10
		var knockback_dir := -facing_direction
		if is_instance_valid(_player):
			knockback_dir = signf(global_position.x - _player.global_position.x)
		velocity.x = knockback_dir * 90.0
		# Conservar la velocidad vertical: recibir daño ya no lo lanza al aire.
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color.RED, 0.06)
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.44)
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
