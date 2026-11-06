extends LevelBackground

const LEVEL4_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/nivel4_1.png"),
	preload("res://level/background/nivel4_2.png"),
	preload("res://level/background/nivel4_3.png")
]


func _get_stage_textures() -> Array[Texture2D]:
	return LEVEL4_TEXTURES
