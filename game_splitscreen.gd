extends Game


func _ready() -> void:
	super._ready()
	resume_from_title()


func resume_from_title() -> void:
	var player_2 := %Player2 as Player
	var viewport_1 := %Viewport1 as SubViewport
	var viewport_2 := %Viewport2 as SubViewport
	viewport_2.world_2d = viewport_1.world_2d
	player_2.camera.custom_viewport = viewport_2
	(%Player1 as Player).camera.enabled = true
	player_2.camera.enabled = true
	(%Player1 as Player).camera.make_current()
	player_2.camera.make_current()


func prepare_for_title() -> void:
	# Separar los viewports antes de sacar la escena del árbol; al volver se
	# restablece el mundo compartido después de que ambos estén registrados.
	(%Player1 as Player).camera.enabled = false
	(%Player2 as Player).camera.enabled = false
	(%Player2 as Player).camera.custom_viewport = %Viewport1
	(%Viewport2 as SubViewport).world_2d = World2D.new()
