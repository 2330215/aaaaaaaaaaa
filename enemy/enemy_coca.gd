extends Enemy

## Enemy Coca: persigue al jugador y lanza proyectiles de refresco.
## Cuando el jugador está fuera de rango, patrulla de un lado al otro.

const PAPA_SCENE = preload("res://enemy/coca_projectile.tscn")

@export var move_speed: float = 80.0
@export var stop_distance: float = 120.0
@export var attack_range: float = 300.0
@export var attack_cooldown: float = 2.0
@export var detection_range: float = 400.0

@onready var lanzamiento: Marker2D = $LanzamientoPapa

var attack_timer: float = 0.0
var _patrol_dir: float = 1.0


func _ready() -> void:
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	attack_timer -= delta

	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
		move_and_slide()
		return
	else:
		velocity.y = 0.0

	# Durante animación de ataque quedarse quieto
	if animation_player.current_animation == &"ataque":
		velocity.x = 0.0
		move_and_slide()
		return

	var jugador := _obtener_jugador_en_rango()

	if jugador != null:
		# ── Modo persecución ─────────────────────────────────────────────
		var distancia_x := jugador.global_position.x - global_position.x
		var dir := signf(distancia_x)

		if absf(distancia_x) > stop_distance:
			velocity.x = dir * move_speed
			sprite.flip_h = velocity.x < 0.0
			_play_anim(&"walk")
		else:
			velocity.x = 0.0
			_play_anim(&"idle")

		# Atacar si está dentro del rango
		if attack_timer <= 0.0 and global_position.distance_to(jugador.global_position) <= attack_range:
			_atacar()
			attack_timer = attack_cooldown
	else:
		# ── Modo patrulla ─────────────────────────────────────────────────
		if is_on_wall():
			_patrol_dir = -_patrol_dir

		velocity.x = _patrol_dir * (move_speed * 0.6)
		sprite.flip_h = velocity.x < 0.0
		_play_anim(&"walk")

	move_and_slide()


func _obtener_jugador_en_rango() -> Player:
	var mas_cercano: Player = null
	var dist_min := detection_range
	for nodo in get_tree().get_nodes_in_group("player"):
		if nodo is Player:
			var dist := global_position.distance_to(nodo.global_position)
			if dist < dist_min:
				dist_min = dist
				mas_cercano = nodo
	return mas_cercano


func _atacar() -> void:
	animation_player.play(&"ataque")


func lanzar_papa() -> void:
	var jugador := _obtener_jugador_en_rango()
	if jugador == null or lanzamiento == null:
		return
	var papa = PAPA_SCENE.instantiate()
	if papa == null:
		return
	papa.global_position = lanzamiento.global_position
	papa.direction = lanzamiento.global_position.direction_to(jugador.global_position)
	get_tree().current_scene.add_child(papa)


func _play_anim(anim: StringName) -> void:
	if animation_player.current_animation != anim:
		animation_player.play(anim)


func destroy() -> void:
	if _state == State.DEAD:
		return
	super.destroy()
	if animation_player.has_animation(&"destroy"):
		animation_player.play(&"destroy")
	else:
		queue_free()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"ataque":
		animation_player.play(&"idle")
	elif animation_name == &"destroy":
		queue_free()
