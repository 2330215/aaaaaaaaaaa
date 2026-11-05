extends Enemy
## Jefe volador: ocupa la mitad derecha de la vista de la camara.

@export var flight_speed: float = 150.0
@export var flight_change_interval: float = 1.5
@export var screen_margin: float = 16.0
@export var attack_interval: float = 2
@export var max_health: int = 8
@onready var projectile_spawn: Marker2D = $proyectil

const PROJECTILE_SCENE = preload("res://enemy/jefe3_proyectil.tscn")

var _active := false
var _attacking := false
var _shot_fired := false
var _attack_timer := 1.0
var _flight_timer := 0.0
var _destination_ratio := Vector2(0.6, 0.4)
var _health: int
var _hurt_timer := 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
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
	var attack := library.get_animation(&"attack")
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
	_clamp_to_screen()
	var player := _find_player_in_view()
	if player:
		sprite.flip_h = player.global_position.x < global_position.x

	if _attacking:
		velocity = Vector2.ZERO
		if not _shot_fired and animation_player.current_animation_position >= 0.4:
			_shot_fired = true
			_fire_attack()
	else:
		_flight_timer -= delta
		if _flight_timer <= 0.0:
			_destination_ratio = Vector2(randf_range(0.1, 0.9), randf_range(0.1, 0.9))
			_flight_timer = maxf(0.1, flight_change_interval)
		var limits := _screen_limits()
		var destination := canvas.affine_inverse() * (limits.position + limits.size * _destination_ratio)
		var offset := destination - global_position
		velocity = offset.normalized() * minf(flight_speed, offset.length() / maxf(delta, 0.001))
		move_and_slide()
		_attack_timer -= delta
		if player and _attack_timer <= 0.0:
			attack()
		elif animation_player.current_animation != &"idle":
			animation_player.play(&"idle")
	_clamp_to_screen()


func _process(_delta: float) -> void:
	# Mantener el limite tambien al desplazar o cambiar el zoom de la camara.
	if _active and _state != State.DEAD:
		_clamp_to_screen()


func _screen_limits() -> Rect2:
	var screen := get_viewport().get_visible_rect()
	var canvas := get_viewport().get_canvas_transform()
	var origin := canvas * global_position
	var bounds: Rect2 = sprite.get_global_transform_with_canvas() * sprite.get_rect()
	var collider_bounds: Rect2 = $CollisionShape2D.get_global_transform_with_canvas() * $CollisionShape2D.shape.get_rect()
	bounds = bounds.merge(collider_bounds)
	var start := Vector2(screen.position.x + screen.size.x * 0.5, screen.position.y)
	start += Vector2.ONE * screen_margin - (bounds.position - origin)
	var finish := screen.end - Vector2.ONE * screen_margin - (bounds.end - origin)
	# Si una ventana es muy pequena, centrar en el espacio disponible.
	finish = finish.max(start)
	return Rect2(start, finish - start)


func _clamp_to_screen() -> void:
	var canvas := get_viewport().get_canvas_transform()
	var limits := _screen_limits()
	var point := canvas * global_position
	point = point.clamp(limits.position, limits.end)
	global_position = canvas.affine_inverse() * point


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
		animation_player.play(&"destroy")
		GameState.notify_boss_defeated()
	else:
		_hurt_timer = 0.3
		sprite.self_modulate = Color(1.0, 0.35, 0.35)
		create_tween().tween_property(sprite, "self_modulate", Color.WHITE, 0.25)
