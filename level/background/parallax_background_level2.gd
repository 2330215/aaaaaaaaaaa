class_name LevelBackground2 extends LevelBackground

const LEVEL2_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/level2_parte1.png"),
	preload("res://level/background/level2_parte2.png"),
	preload("res://level/background/level2_parte3.png")
]


func _get_stage_textures() -> Array[Texture2D]:
	return LEVEL2_TEXTURES


func set_cave_mode(enabled: bool) -> void:
	set_stage(1 if enabled else 0)
