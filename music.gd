extends AudioStreamPlayer


func _ready() -> void:
	if not playing:
		play()
	finished.connect(_on_finished)


func _on_finished() -> void:
	play()
