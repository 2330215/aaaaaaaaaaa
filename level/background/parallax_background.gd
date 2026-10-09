class_name LevelBackground extends ParallaxBackground

@onready var sky_sprite1: Sprite2D = $Sky/Sprite2D
@onready var sky_sprite2: Sprite2D = $Sky/Sprite2
@onready var sky_sprite3: Sprite2D = $Sky/Sprite3
@onready var mountains1: ParallaxLayer = $Mountains1
@onready var mountains2: ParallaxLayer = $Mountains2

const SKY_TEXTURE = preload("res://level/background/Sky.webp")
const CAVE_TEXTURE = preload("res://level/background/cueva_1.webp")

# Base vertical offsets for aligning background to each stage height
const STAGE_Y_OFFSETS = [0.0, -1792.0, -3584.0]


func set_cave_mode(enabled: bool) -> void:
	var tex = CAVE_TEXTURE if enabled else SKY_TEXTURE
	if sky_sprite1:
		sky_sprite1.texture = tex
	if sky_sprite2:
		sky_sprite2.texture = tex
	if sky_sprite3:
		sky_sprite3.texture = tex

	if mountains1:
		mountains1.visible = not enabled
	if mountains2:
		mountains2.visible = not enabled


func align_to_stage(stage_index: int) -> void:
	if stage_index >= 0 and stage_index < STAGE_Y_OFFSETS.size():
		scroll_offset.y = STAGE_Y_OFFSETS[stage_index]
