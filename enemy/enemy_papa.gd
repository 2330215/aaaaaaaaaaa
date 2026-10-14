extends Enemy

const PAPA_SCENE = preload("res://enemy/papa_projectile.tscn")

@export var move_speed: float = 80.0
@export var stop_distance: float = 120.0
@export var attack_range: float = 300.0
@export var attack_cooldown: float = 2.0

@onready var lanzamiento: Marker2D = $LanzamientoPapa

var attack_timer: float = 0.0


func _ready() -> void:
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	attack_timer -= delta

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	var jugador := obtener_jugador()

	if animation_player.current_animation == &"ataque":
		velocity.x = 0.0

	elif jugador != null:
		var distancia_x := jugador.global_position.x - global_position.x

		if absf(distancia_x) > stop_distance:
			velocity.x = signf(distancia_x) * move_speed
			sprite.flip_h = velocity.x < 0.0

			if animation_player.current_animation != &"movimiento":
				animation_player.play("movimiento")
		else:
			velocity.x = 0.0

			if animation_player.current_animation != &"idle":
				animation_player.play("idle")

		if attack_timer <= 0.0 and obtener_jugador_cercano() != null:
			atacar()
			attack_timer = attack_cooldown

	else:
		velocity.x = 0.0

		if animation_player.current_animation != &"idle":
			animation_player.play("idle")

	move_and_slide()


func obtener_jugador() -> Player:
	var jugador_cercano: Player = null
	var distancia_minima := INF

	for nodo in get_tree().get_nodes_in_group("player"):
		if nodo is Player:
			var distancia := global_position.distance_to(nodo.global_position)

			if distancia < distancia_minima:
				distancia_minima = distancia
				jugador_cercano = nodo

	return jugador_cercano


func obtener_jugador_cercano() -> Player:
	var jugador := obtener_jugador()

	if jugador != null:
		if global_position.distance_to(jugador.global_position) <= attack_range:
			return jugador

	return null


func atacar() -> void:
	if obtener_jugador_cercano() != null:
		animation_player.play("ataque")


func lanzar_papa() -> void:
	var jugador := obtener_jugador_cercano()

	if jugador == null or lanzamiento == null:
		return

	var papa = PAPA_SCENE.instantiate()

	if papa == null:
		return

	papa.global_position = lanzamiento.global_position
	papa.direction = lanzamiento.global_position.direction_to(jugador.global_position)

	get_tree().current_scene.add_child(papa)


func destroy() -> void:
	if _state == State.DEAD:
		return

	_state = State.DEAD
	velocity = Vector2.ZERO

	if animation_player.has_animation(&"destroy"):
		animation_player.play("destroy")
	else:
		queue_free()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"ataque":
		animation_player.play("idle")
	elif animation_name == &"destroy":
		queue_free()
