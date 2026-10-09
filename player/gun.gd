class_name Gun extends Marker2D
## Represents a weapon that spawns and shoots bullets.
## The Cooldown timer controls the cooldown duration between shots.


const BULLET_VELOCITY = 850.0
const BULLET_SCENE = preload("res://player/bullet.tscn")

@onready var sound_shoot := $Shoot as AudioStreamPlayer2D
@onready var timer := $Cooldown as Timer


# This method is only called by Player.gd.
func shoot(direction: float = 1.0) -> bool:
	if not timer.is_stopped():
		return false
	var bullet := BULLET_SCENE.instantiate() as Bullet
	bullet.global_position = global_position
	bullet.linear_velocity = Vector2(direction * BULLET_VELOCITY, 0.0)

	bullet.set_as_top_level(true)
	add_child(bullet)
	sound_shoot.play()
	timer.start()
	return true


func shoot_special(direction: float = 1.0, count: int = 5) -> bool:
	for i in range(count):
		if not is_inside_tree():
			break
		var bullet := BULLET_SCENE.instantiate() as Bullet
		bullet.global_position = global_position + Vector2(0, randf_range(-4, 4))
		bullet.linear_velocity = Vector2(direction * (BULLET_VELOCITY + randf_range(-30, 50)), randf_range(-25, 25))
		bullet.set_as_top_level(true)
		add_child(bullet)
		sound_shoot.play()
		await get_tree().create_timer(0.06).timeout
	return true

