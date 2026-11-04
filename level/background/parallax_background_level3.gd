class_name LevelBackground3 extends LevelBackground

const LEVEL3_TEXTURES: Array[Texture2D] = [
	preload("res://level/background/level3_parte2.png"),
	preload("res://level/background/level3_parte2.png"),
	preload("res://level/background/level3_parte3.png")
]


func _get_stage_textures() -> Array[Texture2D]:
	return LEVEL3_TEXTURES


func set_cave_mode(enabled: bool) -> void:
	set_stage(1 if enabled else 0)
