extends CanvasLayer
## HUD de vidas estilo contador: icono - x - número de vidas.
## Se conecta a GameState.life_lost y GameState.life_gained para actualizarse.

@onready var lives_label := $Container/LivesLabel as Label
@onready var icon_texture := $Container/IconTexture as TextureRect

var _player: Player
var _portrait := AtlasTexture.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	icon_texture.texture = _portrait
	call_deferred("_bind_player")

	GameState.life_lost.connect(_on_lives_changed)
	GameState.life_gained.connect(_on_lives_changed)

	_refresh(GameState.lives)


func _on_lives_changed(lives_remaining: int) -> void:
	_refresh(lives_remaining)


func _refresh(lives_remaining: int) -> void:
	lives_label.text = "x%d" % lives_remaining
	# Pequeña animación de pulso al cambiar
	var tween := lives_label.create_tween()
	tween.tween_property(lives_label, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(lives_label, "scale", Vector2(1.0, 1.0), 0.12)


func _process(_delta: float) -> void:
	# Volver a enlazar si el jugador se reemplaza durante la partida.
	if not is_instance_valid(_player):
		_bind_player()


func _bind_player() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.get_parent() is Player:
		_player = camera.get_parent() as Player
	else:
		for node in get_tree().get_nodes_in_group("player"):
			if node is Player and node.get_viewport() == get_viewport():
				_player = node
				break
	if not is_instance_valid(_player):
		return
	if not _player.skin_changed.is_connected(_on_skin_changed):
		_player.skin_changed.connect(_on_skin_changed)
	_on_skin_changed(_player.get_skin_name())


func _on_skin_changed(_skin_name: String) -> void:
	# Recortar un solo cuadro de la misma imagen que usa el jugador.
	var character_sprite := _player.get_node("Sprite2D") as Sprite2D
	if not character_sprite.texture:
		return
	var frame_size := character_sprite.texture.get_size() / Vector2(character_sprite.hframes, character_sprite.vframes)
	_portrait.atlas = character_sprite.texture
	_portrait.region = Rect2(Vector2.ZERO, frame_size)
	_portrait.filter_clip = true