extends Enemy
## Pizza combate en tierra: patrulla, salta y alterna proyectiles y golpes al suelo.

@export var ground_speed: float = 150.0
@export var ground_patrol_distance: float = 280.0
@export var jump_speed: float = 560.0
@export var jump_interval: float = 3.0
@export var attack_interval: float = 2
@export var max_health: int = 8
@export var slam_jump_speed: float = 500.0
@export var slam_gravity: float = 1800.0
@export var bread_duration: float = 2.5
@export var bread_height: float = 140.0
const BREAD_SCENE = preload("res://enemy/bread_barrier.tscn")
var _slamming := false
var _next_slam := false
var _slam_elapsed := 0.0
var _impact_wait := -1.0
var _bread_target_x := 0.0
@onready var projectile_spawn: Marker2D = $proyectil

const PROJECTILE_SCENE = preload("res://enemy/jefe3_proyectil.tscn")

var _active := false
var _attacking := false
var _shot_fired := false
var _attack_timer := 1.0
var _ground_origin_x: float
var _patrol_direction: float = -1.0
var _jump_timer: float = 1.8
var _health: int
var _hurt_timer := 0.0


func _ready() -> void:
	_ground_origin_x = global_position.x
	floor_snap_length = 8.0
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	_health = max_health
	animation_player.animation_finished.connect(_on_animation_finished)
	# Estas animaciones heredadas tenian cuadros de otra hoja de sprites.
	var library := animation_player.get_animation_library(&"").duplicate(true) as AnimationLibrary
	animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", library)
	for anim_name in library.get_animation_list():
		var anim := library.get_animation(anim_name)
		for track in anim.get_track_count():
			if anim.track_get_path(track) == NodePath("Sprite2D:frame"):
				for key in anim.track_get_key_count(track):
					var frame := int(anim.track_get_key_value(track, key))
					anim.track_set_key_value(track, key, clampi(frame, 0, sprite.hframes * sprite.vframes - 1))
	var slam := library.get_animation(&"attack2")
	slam.loop_mode = Animation.LOOP_NONE
	slam.length = 1.0
	var attack := library.get_animation(&"attack" )
	attack.loop_mode = Animation.LOOP_NONE
	attack.length = 0.8
	animation_player.play(&"idle")


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		velocity = Vector2.ZERO
		return
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	var viewport := get_viewport()
	if not viewport.get_camera_2d():
		return
	var canvas := viewport.get_canvas_transform()
	var screen := viewport.get_visible_rect()
	if not _active:
		# Esperar a que el jugador llegue al jefe, sin traerlo desde otros pisos.
		if not screen.grow(80.0).has_point(canvas * global_position):
			return
		_active = true
	var player := _find_player_in_view()
	if player:
		sprite.flip_h = player.global_position.x < global_position.x

	if _slamming:
		_update_slam(delta)
		return

	_jump_timer = maxf(0.0, _jump_timer - delta)
	if global_position.x <= _ground_origin_x - ground_patrol_distance:
		_patrol_direction = 1.0
	elif global_position.x >= _ground_origin_x + ground_patrol_distance:
		_patrol_direction = -1.0
	elif is_on_wall():
		_patrol_direction = signf(get_wall_normal().x)
	velocity.x = 0.0 if _attacking else _patrol_direction * ground_speed
	if not _attacking and is_on_floor() and _jump_timer <= 0.0:
		velocity.y = -jump_speed
		_jump_timer = maxf(0.5, jump_interval)
	velocity.y += gravity * delta
	move_and_slide()
	if _attacking:
		if not _shot_fired and animation_player.current_animation_position >= 0.4:
			_shot_fired = true
			_fire_attack()
	else:
		_attack_timer -= delta
		if player and is_on_floor() and _attack_timer <= 0.0:
			attack()
		else:
			var animation: StringName = &"walk" if not is_zero_approx(velocity.x) else &"idle"
			if animation_player.current_animation != animation:
				animation_player.play(animation)


func _find_player_in_view() -> Player:
	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()
	if camera and camera.get_parent() is Player:
		return camera.get_parent() as Player
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.get_viewport() == viewport:
			return node
	return null


func attack() -> void:
	if _attacking or _state == State.DEAD:
		return
	if _next_slam:
		_next_slam = false
		_start_slam()
		return
	_next_slam = true
	_attacking = true
	_shot_fired = false
	velocity = Vector2.ZERO
	animation_player.play(&"attack")


func _fire_attack() -> void:
	if _state == State.DEAD or not _find_player_in_view():
		return
	var projectile := PROJECTILE_SCENE.instantiate() as Area2D
	var spawn := projectile_spawn.global_position
	var parent := get_parent()
	projectile.position = parent.to_local(spawn) if parent is Node2D else spawn
	parent.add_child(projectile)


func _on_animation_finished(animation: StringName) -> void:
	if animation == &"attack":
		_attacking = false
		_attack_timer = maxf(0.1, attack_interval)


func destroy() -> void:
	if _state == State.DEAD or _hurt_timer > 0.0:
		return
	_health -= 1
	if _health <= 0:
		_attacking = false
		super.destroy()
		_slamming = false
		animation_player.play(&"destroy")
		GameState.notify_boss_defeated()
	else:
		_hurt_timer = 0.3
		sprite.self_modulate = Color(1.0, 0.35, 0.35)
		create_tween().tween_property(sprite, "self_modulate", Color.WHITE, 0.25)


func _start_slam() -> void:
	_slamming = true
	_attacking = true
	_slam_elapsed = 0.0
	_impact_wait = -1.0
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	var player := _find_player_in_view()
	_bread_target_x = player.global_position.x if player else global_position.x - 160.0
	velocity = Vector2(0.0, -slam_jump_speed)
	animation_player.play(&"attack2")
	# El cuerpo salta de verdad; los cuadros de la animacion esperan al impacto.
	animation_player.pause()
	animation_player.seek(0.0, true)


func _update_slam(delta: float) -> void:
	_slam_elapsed += delta
	if _impact_wait >= 0.0:
		_impact_wait -= delta
		if _impact_wait <= 0.0:
			_finish_slam()
		return
	velocity.y += slam_gravity * delta
	velocity.x = 0.0
	var falling := velocity.y > 0.0
	move_and_slide()
	if falling and is_on_floor():
		velocity = Vector2.ZERO
		animation_player.play(&"attack2")
		animation_player.seek(0.6, true)
		_spawn_bread()
		_impact_wait = 0.5
	elif _slam_elapsed > 0.25:
		animation_player.seek(minf(0.5, _slam_elapsed * 0.5), true)
	# Cancelar con seguridad si el salto se hizo sobre un pozo.
	if _slam_elapsed > 3.0 and _impact_wait < 0.0:
		_finish_slam()


func _finish_slam() -> void:
	_slamming = false
	_attacking = false
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	velocity = Vector2.ZERO
	_attack_timer = maxf(0.1, attack_interval)
	animation_player.play(&"idle")


func _spawn_bread() -> void:
	# Buscar suelo real bajo el lugar del jugador elegido al iniciar el salto.
	var feet: Rect2 = $CollisionShape2D.global_transform * $CollisionShape2D.shape.get_rect()
	var start := Vector2(_bread_target_x, feet.end.y - 240.0)
	var query := PhysicsRayQueryParameters2D.create(start, start + Vector2(0, 650.0), 24, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var bread := BREAD_SCENE.instantiate() as Area2D
	bread.active_time = bread_duration
	bread.bread_height = bread_height
	var parent := get_parent()
	bread.position = parent.to_local(hit.position) if parent is Node2D else hit.position
	parent.add_child(bread)