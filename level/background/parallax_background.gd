class_name LevelBackground extends ParallaxBackground

@onready var sky_sprite1: Sprite2D = get_node_or_null(^"Sky/Sprite2D")
@onready var sky_sprite2: Sprite2D = get_node_or_null(^"Sky/Sprite2")
@onready var sky_sprite3: Sprite2D = get_node_or_null(^"Sky/Sprite3")

@onready var mountains1: ParallaxLayer = get_node_or_null(^"Mountains1")
@onready var mountains2: ParallaxLayer = get_node_or_null(^"Mountains2")

const STAGE_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/Sky.webp"),     # Nivel 0
	preload("res://level/background/sky1.webp"),   # Nivel 1
	preload("res://level/background/cueva_1.webp") # Nivel 2
]

const STAGE_Y_OFFSETS = [0.0, -1792.0, -3584.0]


func set_stage(stage_index: int) -> void:
	if stage_index < 0 or stage_index >= STAGE_TEXTURES.size():
		return

	var texture := STAGE_TEXTURES[stage_index]

	for sprite in [sky_sprite1, sky_sprite2, sky_sprite3]:
		if sprite:
			sprite.texture = texture

	if mountains1:
		mountains1.visible = stage_index != 2

	if mountains2:
		mountains2.visible = stage_index != 2


func align_to_stage(stage_index: int) -> void:
	if stage_index >= 0 and stage_index < STAGE_Y_OFFSETS.size():
		scroll_offset.y = STAGE_Y_OFFSETS[stage_index]
