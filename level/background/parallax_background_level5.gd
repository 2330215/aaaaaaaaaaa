extends LevelBackground

const LEVEL5_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/nivel5_1.png"),
	preload("res://level/background/nivel5_2.png"),
	preload("res://level/background/nivel5_3.png")
]


func _get_stage_textures() -> Array[Texture2D]:
	return LEVEL5_TEXTURES
