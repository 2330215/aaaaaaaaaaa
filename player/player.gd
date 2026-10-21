class_name Player extends CharacterBody2D


signal coin_collected()
signal special_charge_changed(current: int, max_charge: int)
signal special_attack_ready(is_ready: bool)
signal skin_changed(skin_name: String)

const TEXTURE_ROBOT = preload("res://player/robot.png")
const TEXTURE_AGUACATE = preload("res://player/aguacate.png")

enum CharacterSkin { ROBOT, AGUACATE }
var current_skin: CharacterSkin = CharacterSkin.ROBOT

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
var _double_jump_charged := false


func _ready() -> void:
	add_to_group("player")
	coin_collected.connect(_on_coin_collected_internal)


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

	# Morir al tocar cualquier enemigo
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is Enemy:
			die()
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


func die() -> void:
	var pits := get_tree().get_nodes_in_group("pit_hazard")
	if pits.size() > 0:
		(pits[0] as PitHazard).trigger(self)
	else:
		GameState.record_death()
		get_tree().reload_current_scene()


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


func set_skin(new_skin: CharacterSkin) -> void:
	current_skin = new_skin
	if sprite:
		match current_skin:
			CharacterSkin.ROBOT:
				sprite.texture = TEXTURE_ROBOT
			CharacterSkin.AGUACATE:
				sprite.texture = TEXTURE_AGUACATE
	skin_changed.emit(get_skin_name())


func get_skin_name() -> String:
	match current_skin:
		CharacterSkin.ROBOT:
			return "Robot"
		CharacterSkin.AGUACATE:
			return "Aguacate"
		_:
			return "Robot"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			toggle_skin()
