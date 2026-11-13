extends "res://level/pit_hazard.gd"
## Puntos seguros sobre barcos y plataformas, además de los suelos de tiles.

@export var safe_respawn_points: Array[Vector2] = []
## Región de agua local; permite cubrir el mar por encima de los escalones.
@export var water_bounds: Rect2 = Rect2()


func _ready() -> void:
	super._ready()
	if water_bounds.has_area():
		var collider := $CollisionShape2D as CollisionShape2D
		var rectangle := RectangleShape2D.new()
		rectangle.size = water_bounds.size
		collider.shape = rectangle
		collider.position = water_bounds.get_center()
		$PitGradient.hide()
		$PitSolidBottom.hide()


func _find_solid_respawn(player: Player) -> Vector2:
	if safe_respawn_points.is_empty():
		return super._find_solid_respawn(player)
	var level := get_parent() as Node2D
	var nearest := level.to_global(safe_respawn_points[0])
	var distance := nearest.distance_squared_to(player.global_position)
	for point in safe_respawn_points:
		var candidate := level.to_global(point)
		var candidate_distance := candidate.distance_squared_to(player.global_position)
		if candidate_distance < distance:
			nearest = candidate
			distance = candidate_distance
	return nearest
