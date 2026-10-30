class_name Player extends CharacterBody2D


signal coin_collected()
signal special_charge_changed(current: int, max_charge: int)
signal special_attack_ready(is_ready: bool)
signal skin_changed(skin_name: String)

const TEXTURE_ROBOT    = preload("res://player/robot.png")
const TEXTURE_AGUACATE = preload("res://player/aguacate.png")
const TEXTURE_LIMONES  = preload("res://player/limones.png")
const TEXTURE_GLOBO    = preload("res://player/globo.png")

enum CharacterSkin { ROBOT, AGUACATE, LIMONES, GLOBO }
var current_skin: CharacterSkin = CharacterSkin.ROBOT

## Modo globo: movimiento libre sin gravedad
var _balloon_mode: bool = false

const MAX_SPECIAL_CHARGE = 5
## Valores base de movimiento
const BASE_WALK_SPEED: float = 300.0
const BASE_JUMP_VELOCITY: float = -725.0
## Maximum speed at which the player can fall.
const TERMINAL_VELOCITY = 700

## Multiplicadores de trucos (modificados desde el menú de trucos)
var speed_mult: float = 1.0
var jump_mult: float = 1.0

## The player listens for input actions appended with this suffix.[br]
## Used to separate controls for multiple players in splitscreen.
@export var action_suffix := ""

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var special_charge := 0

@onready var platform_detector := $PlatformDetector as RayCast2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer
@onready var shoot_timer := $ShootAnimation as Timer
@onready var sprite := $Sprite2D as Sprite2D
@onready var jump_sound := $Jump as AudioStreamPlayer2D
@onready var gun = sprite.get_node(^"Gun") as Gun
@onready var camera := $Camera as Camera2D
@onready var invincibility_timer := $InvincibilityTimer as Timer
@onready var collision_shape := $CollisionShape2D as CollisionShape2D

var _double_jump_charged := false
## Estado de muerte: bloquea input y física
var _is_dead := false
## Estado de invencibilidad post-respawn
var _invincible := false
## Posición guardada para respawn en el mismo lugar
var _respawn_position: Vector2 = Vector2.ZERO
## escudo 
var shield_time_left: float = 0.0


func _ready() -> void:
	add_to_group("player")
	coin_collected.connect(_on_coin_collected_internal)
	_respawn_position = global_position
	invincibility_timer.timeout.connect(_on_invincibility_timeout)


func _on_coin_collected_internal() -> void:
	if special_charge < MAX_SPECIAL_CHARGE:
		special_charge += 1
		special_charge_changed.emit(special_charge, MAX_SPECIAL_CHARGE)
		if special_charge >= MAX_SPECIAL_CHARGE:
			special_attack_ready.emit(true)


## Llena la carga del ataque especial de golpe (monedas de recarga).
func recharge_special_attack() -> void:
	special_charge = MAX_SPECIAL_CHARGE
	special_charge_changed.emit(special_charge, MAX_SPECIAL_CHARGE)
	special_attack_ready.emit(true)


func _physics_process(delta: float) -> void:
	shield_time_left = maxf(0.0, shield_time_left - delta)
	# Bloquear todo si está muerto
	if _is_dead:
		# Solo aplicar gravedad para que el cuerpo caiga durante la animación
		velocity.y = minf(TERMINAL_VELOCITY, velocity.y + gravity * delta)
		move_and_slide()
		return

	# ── Modo globo: subir con Jump, bajar con move_down, horizontal normal ────
	if _balloon_mode:
		var bspeed := BASE_WALK_SPEED * speed_mult
		var dir_x  := Input.get_axis("move_left" + action_suffix, "move_right" + action_suffix)
		# Subir: botón de salto (hold). Bajar: move_down
		var going_up   := Input.is_action_pressed("jump"       + action_suffix)
		var going_down := Input.is_action_pressed("move_down"  + action_suffix)
		var dir_y: float = 0.0
		if going_up:
			dir_y = -1.0
		elif going_down:
			dir_y = 1.0
		velocity.x = move_toward(velocity.x, dir_x * bspeed, bspeed * 6.0 * delta)
		velocity.y = move_toward(velocity.y, dir_y * bspeed * 0.75, bspeed * 4.0 * delta)
		if not is_zero_approx(velocity.x):
			sprite.scale.x = sign(velocity.x)
		move_and_slide()
		# Daño por contacto (igual que modo normal)
		if not _invincible:
			for i in get_slide_collision_count():
				if get_slide_collision(i).get_collider() is Enemy:
					take_damage()
					return
		# Animación del globo según dirección vertical
		var anim: StringName
		if going_up:
			anim = &"balloon_rise"
		elif going_down:
			anim = &"balloon_fall"
		else:
			anim = &"balloon_idle"
		if anim != animation_player.current_animation:
			animation_player.play(anim)
		return
	# ─────────────────────────────────────────────────────────────────────────

	if is_on_floor():
		_double_jump_charged = true
	if Input.is_action_just_pressed("jump" + action_suffix):
		try_jump()
	elif Input.is_action_just_released("jump" + action_suffix) and velocity.y < 0.0:
		# The player let go of jump early, reduce vertical momentum.
		velocity.y *= 0.6
	# Fall.
	velocity.y = minf(TERMINAL_VELOCITY, velocity.y + gravity * delta)

	var walk_speed := BASE_WALK_SPEED * speed_mult
	var direction := Input.get_axis("move_left" + action_suffix, "move_right" + action_suffix) * walk_speed
	velocity.x = move_toward(velocity.x, direction, walk_speed * 6.0 * delta)

	if not is_zero_approx(velocity.x):
		if velocity.x > 0.0:
			sprite.scale.x = 1.0
		else:
			sprite.scale.x = -1.0

	floor_stop_on_slope = not platform_detector.is_colliding()
	move_and_slide()

	# Daño por contacto con enemigo (ignorar si es invencible)
	if not _invincible:
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_collider() is Enemy:
				take_damage()
				return

	var is_shooting := false
	if Input.is_action_just_pressed("special_attack" + action_suffix) or Input.is_action_just_pressed("special_attack"):
		if special_charge >= MAX_SPECIAL_CHARGE:
			special_charge = 0
			special_charge_changed.emit(special_charge, MAX_SPECIAL_CHARGE)
			special_attack_ready.emit(false)
			is_shooting = true
			gun.shoot_special(sprite.scale.x)
	elif Input.is_action_just_pressed("shoot" + action_suffix):
		is_shooting = gun.shoot(sprite.scale.x)

	var animation := get_new_animation(is_shooting)
	if animation != animation_player.current_animation and shoot_timer.is_stopped():
		if is_shooting:
			shoot_timer.start()
		animation_player.play(animation)


func get_new_animation(is_shooting := false) -> StringName:
	var animation_new: StringName
	if is_on_floor():
		if absf(velocity.x) > 0.1:
			animation_new = &"run"
		else:
			animation_new = &"idle"
	else:
		if velocity.y > 0.0:
			animation_new = &"falling"
		else:
			animation_new = &"jumping"
	if is_shooting:
		animation_new = animation_new + &"_weapon"
	return animation_new


## Llamado al recibir daño (enemigo o pit). Inicia la animación de muerte y respawn.
func take_damage() -> void:
	if _is_dead or _invincible or shield_time_left > 0.0:
		return

	_is_dead = true
	_respawn_position = global_position

	# La colisión se mantiene activa para que el cuerpo descanse en el suelo.
	# _is_dead=true ya impide que se reciba daño de enemigos en _physics_process.

	# Lanzar hacia arriba (efecto Metal Slug)
	velocity = Vector2(0, -500)

	# Detener animaciones previas y poner idle como base
	animation_player.stop()
	sprite.frame = 30  # frame idle estático

	# Animación programática de muerte con Tween
	var tween := create_tween()
	# Rotación + fade out en 0.9s
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation_degrees", 360.0 * sprite.scale.x, 0.85)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.85)
	await tween.finished

	# Decidir si quedan vidas o es Game Over
	var has_lives := GameState.lose_life()
	if has_lives:
		_do_respawn()
	else:
		_do_game_over()


func _do_respawn() -> void:
	# Resetear sprite
	sprite.rotation_degrees = 0.0
	sprite.modulate.a = 1.0

	# Teletransportar al punto de muerte
	global_position = _respawn_position
	velocity = Vector2.ZERO

	_is_dead = false

	# Parpadeo de invencibilidad (estilo Metal Slug)
	_invincible = true
	invincibility_timer.start(2.0)
	_play_blink()

	# Reanudar animación normal
	animation_player.play(&"idle")


func _play_blink() -> void:
	# Parpadea mientras dure la invencibilidad
	var blink_tween := create_tween().set_loops(10)
	blink_tween.tween_property(sprite, "modulate:a", 0.15, 0.1)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, 0.1)


func _on_invincibility_timeout() -> void:
	_invincible = false
	sprite.modulate.a = 1.0


func _do_game_over() -> void:
	# La señal GameState.game_over ya fue emitida en lose_life().
	# game.gd se encarga de mostrar la pantalla y congelar el juego.
	# Aquí no hacemos nada para evitar que el juego continúe o se recargue.
	pass

## Llamado por PitHazard cuando el jugador cae al vacío (pasa la posición de respawn).
func die_from_pit(respawn_pos: Vector2) -> void:
	if _is_dead:
		return
	_respawn_position = respawn_pos
	shield_time_left = 0.0
	take_damage()


## Compatibilidad con código anterior
func die() -> void:
	take_damage()


func try_jump() -> void:
	if is_on_floor():
		jump_sound.pitch_scale = 1.0
	elif _double_jump_charged:
		_double_jump_charged = false
		velocity.x *= 2.5
		jump_sound.pitch_scale = 1.5
	else:
		return
	velocity.y = BASE_JUMP_VELOCITY * jump_mult
	jump_sound.play()


func toggle_skin() -> void:
	if current_skin == CharacterSkin.ROBOT:
		set_skin(CharacterSkin.AGUACATE)
	else:
		set_skin(CharacterSkin.ROBOT)


## Cicla entre Limón y Globo.
func toggle_limon_skin() -> void:
	if current_skin == CharacterSkin.LIMONES:
		set_skin(CharacterSkin.GLOBO)
	else:
		set_skin(CharacterSkin.LIMONES)


func set_skin(new_skin: CharacterSkin) -> void:
	current_skin = new_skin
	# Activar / desactivar modo globo
	_balloon_mode = (current_skin == CharacterSkin.GLOBO)
	if _balloon_mode:
		velocity = Vector2.ZERO   # Detener caída al entrar en modo globo
	if sprite:
		match current_skin:
			CharacterSkin.ROBOT:
				sprite.texture = TEXTURE_ROBOT
				sprite.hframes  = 8
				sprite.vframes  = 8
			CharacterSkin.AGUACATE:
				sprite.texture = TEXTURE_AGUACATE
				sprite.hframes  = 8
				sprite.vframes  = 8
			CharacterSkin.LIMONES:
				sprite.texture = TEXTURE_LIMONES
				sprite.hframes  = 8
				sprite.vframes  = 8
				# Limón: usar animaciones de la librería reconfigurando frames
				_setup_limon_animations()
			CharacterSkin.GLOBO:
				sprite.texture = TEXTURE_GLOBO
				sprite.hframes  = 8
				sprite.vframes  = 6
				_setup_globo_animations()
	skin_changed.emit(get_skin_name())


## Reconfigura las animaciones existentes para que usen los frames del Limón.
## Limón 6×6 (36 frames total):
##   idle  → fila 0: frames 0-3 (4 frames de idle)
##   run   → fila 1: frames 6-11 (6 frames de carrera)
##   jumping → fila 4: frame 24
##   falling → fila 5: frame 30
func _setup_limon_animations() -> void:
	var lib := animation_player.get_animation_library(&"")
	if not lib:
		return
	_set_anim_frames(lib, &"idle",    [0, 1, 2, 3],           0.25, true)
	_set_anim_frames(lib, &"run",     [6, 7, 8, 9, 10, 11],   0.08, true)
	_set_anim_frames(lib, &"jumping", [24],                   0.25, false)
	_set_anim_frames(lib, &"falling", [30],                   0.25, false)
	_set_anim_frames(lib, &"idle_weapon",    [0, 1, 2, 3],           0.25, true)
	_set_anim_frames(lib, &"run_weapon",     [6, 7, 8, 9, 10, 11],   0.08, true)
	_set_anim_frames(lib, &"jumping_weapon", [24],                   0.25, false)
	_set_anim_frames(lib, &"falling_weapon", [30],                   0.25, false)


## Reconfigura las animaciones para el Globo aerostático.
## Globo 6×4 (24 frames total):
##   balloon_idle → fila 0: frames 0-5 (flotando)
##   balloon_rise → fila 1: frames 6-11 (subiendo con propulsor)
##   balloon_fall → fila 3: frames 18-23 (bajando)
##   idle / run   → alias de balloon_idle
func _setup_globo_animations() -> void:
	var lib := animation_player.get_animation_library(&"")
	if not lib:
		return
	# Asegurarse que existen las animaciones de globo
	_ensure_anim(lib, &"balloon_idle", [0, 1, 2, 3, 4, 5],     0.10, true)
	_ensure_anim(lib, &"balloon_rise", [6, 7, 8, 9, 10, 11],   0.08, true)
	_ensure_anim(lib, &"balloon_fall", [18, 19, 20, 21, 22, 23], 0.10, true)
	# Redirigir idle/run al idle del globo
	_set_anim_frames(lib, &"idle",    [0, 1, 2, 3, 4, 5],     0.10, true)
	_set_anim_frames(lib, &"run",     [0, 1, 2, 3, 4, 5],     0.10, true)
	_set_anim_frames(lib, &"jumping", [6, 7, 8, 9, 10, 11],   0.08, true)
	_set_anim_frames(lib, &"falling", [18, 19, 20, 21, 22, 23], 0.10, true)


## Sobrescribe los frames de una animación existente.
func _set_anim_frames(lib: AnimationLibrary, anim_name: StringName,
		frames: Array, fps_step: float, loop: bool) -> void:
	if not lib.has_animation(anim_name):
		return
	var anim := lib.get_animation(anim_name)
	# Buscar la pista de frame del Sprite2D
	var track := -1
	for i in anim.get_track_count():
		if anim.track_get_path(i) == NodePath("Sprite2D:frame"):
			track = i
			break
	if track == -1:
		return
	# Limpiar keyframes existentes
	while anim.track_get_key_count(track) > 0:
		anim.track_remove_key(track, 0)
	# Insertar nuevos keyframes
	for idx in frames.size():
		anim.track_insert_key(track, idx * fps_step, frames[idx])
	anim.length = frames.size() * fps_step
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


## Crea una animación nueva si no existe, o la sobreescribe.
func _ensure_anim(lib: AnimationLibrary, anim_name: StringName,
		frames: Array, fps_step: float, loop: bool) -> void:
	if not lib.has_animation(anim_name):
		var new_anim := Animation.new()
		new_anim.add_track(Animation.TYPE_VALUE)
		new_anim.track_set_path(0, NodePath("Sprite2D:frame"))
		new_anim.value_track_set_update_mode(0, Animation.UPDATE_DISCRETE)
		lib.add_animation(anim_name, new_anim)
	_set_anim_frames(lib, anim_name, frames, fps_step, loop)


func get_skin_name() -> String:
	match current_skin:
		CharacterSkin.ROBOT:
			return "Robot"
		CharacterSkin.AGUACATE:
			return "Aguacate"
		CharacterSkin.LIMONES:
			return "Limón"
		CharacterSkin.GLOBO:
			return "Globo 🎈"
		_:
			return "Robot"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			toggle_skin()

## escudo 
func activate_shield(duration: float = 5.0) -> void:
	shield_time_left = duration
