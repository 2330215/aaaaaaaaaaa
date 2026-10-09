class_name Enemy extends CharacterBody2D


enum State {
	WALKING,
	DEAD,
}

const WALK_SPEED = 100.0      # Velocidad horizontal durante el salto
const JUMP_VELOCITY = -500.0   # Fuerza del salto

var _state := State.WALKING
var facing_direction: float = 1.0

@onready var gravity: int = ProjectSettings.get("physics/2d/default_gravity")
@onready var platform_detector := $PlatformDetector as RayCast2D
@onready var floor_detector_left := $FloorDetectorLeft as RayCast2D
@onready var floor_detector_right := $FloorDetectorRight as RayCast2D
@onready var sprite := $Sprite2D as Sprite2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer


func _physics_process(delta: float) -> void:
	# Aplicar gravedad
	velocity.y += gravity * delta

	if _state == State.WALKING:
		if is_on_floor():
			# Al tocar el suelo salta inmediatamente y avanza
			velocity.y = JUMP_VELOCITY
			velocity.x = WALK_SPEED * facing_direction
		else:
			# En el aire cambia de dirección si detecta bordes o límites
			if not floor_detector_left.is_colliding():
				facing_direction = 1.0
				velocity.x = WALK_SPEED
			elif not floor_detector_right.is_colliding():
				facing_direction = -1.0
				velocity.x = -WALK_SPEED

	if is_on_wall():
		facing_direction = -facing_direction
		velocity.x = WALK_SPEED * facing_direction

	move_and_slide()

	# Orientación del Sprite
	if velocity.x > 0.0:
		sprite.scale.x = 0.8
	elif velocity.x < 0.0:
		sprite.scale.x = -0.8

	# Reproducción limpia de animaciones
	var animation := get_new_animation()
	if animation != animation_player.current_animation:
		animation_player.play(animation)


func destroy() -> void:
	_state = State.DEAD
	velocity = Vector2.ZERO


func get_new_animation() -> StringName:
	var animation_new: StringName
	if _state == State.WALKING:
		if is_on_floor():
			animation_new = &"idle"
		else:
			# Si tienes una animación "jump" en tu AnimationPlayer usa &"jump", 
			# si no, usará &"idle" de forma fluida.
			if animation_player.has_animation(&"jump"):
				animation_new = &"jump"
			else:
				animation_new = &"idle"
	else:
		animation_new = &"destroy"
	return animation_new
