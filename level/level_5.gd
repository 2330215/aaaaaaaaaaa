extends "res://level/level.gd"
## Copas de la selva, limpieza del poblado y arena de Dona con fosos.

const STAGE_WIDTHS: Array[float] = [3840.0, 3840.0, 2560.0]
const CAMERA_OFFSET := Vector2(0, -90)
const FLOOR_HEIGHTS: Array[float] = [494.0, 2542.0, 4334.0]
const PLAYER_SPAWNS: Array[Vector2] = [Vector2(3660, 450), Vector2(160, 2490), Vector2(160, 4280)]

var _village_cleared: bool = false
var _enemy_total: int = 0
var _status: Label
@onready var _village_enemies: Node2D = $VillageEnemies
@onready var _village_exit: StageGateway = $StageGateway2


func _ready() -> void:
	super._ready()
	_enemy_total = _village_enemies.get_child_count()
	_village_exit.set_enabled(false)
	var hud := CanvasLayer.new()
	hud.name = "VillageStatus"
	hud.layer = 10
	add_child(hud)
	_status = Label.new()
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status.offset_left = -300
	_status.offset_right = 300
	_status.offset_top = 52
	_status.offset_bottom = 118
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 5)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_status)
	_status.hide()


func _process(_delta: float) -> void:
	_setup_camera()
	var in_boss_stage := false
	var in_village := false
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.get_world_2d() == get_world_2d():
			var height := to_local(node.global_position).y
			in_boss_stage = in_boss_stage or height >= 3584.0
			in_village = in_village or (height >= 1792.0 and height < 3584.0)
	_update_village(in_village)
	var boss := get_node_or_null("DonutBoss") as Enemy
	if boss and boss._state != Enemy.State.DEAD:
		boss.visible = in_boss_stage
		boss.process_mode = Node.PROCESS_MODE_INHERIT if in_boss_stage else Node.PROCESS_MODE_DISABLED
		boss.collision_layer = 2 if in_boss_stage else 0


func _update_village(active: bool) -> void:
	_village_enemies.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_status.visible = active
	var remaining := 0
	for node in _village_enemies.get_children():
		var enemy := node as Enemy
		if enemy and enemy._state != Enemy.State.DEAD:
			remaining += 1
	if remaining == 0 and not _village_cleared:
		_village_cleared = true
		_village_exit.set_enabled(true)
	_status.text = "POBLADO · Enemigos: %d/%d\nDerrota a todos para abrir la salida →" % [remaining, _enemy_total]
	if _village_cleared:
		_status.text = "¡Poblado despejado!\nSalida abierta hacia el jefe →"


func _setup_camera() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player.get_world_2d() != get_world_2d():
			continue
		var height := to_local(player.global_position).y
		var stage := 2 if height >= 3584.0 else (1 if height >= 1792.0 else 0)
		var bounds := Rect2(0, FLOOR_HEIGHTS[stage] - 640.0, STAGE_WIDTHS[stage], 960)
		var viewport_size := player.get_viewport_rect().size
		var zoom := maxf(0.7, maxf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y))
		player.camera.zoom = Vector2.ONE * zoom
		player.camera.offset = CAMERA_OFFSET
		player.camera.limit_left = roundi(to_global(bounds.position).x - player.camera.offset.x)
		player.camera.limit_top = roundi(to_global(bounds.position).y - player.camera.offset.y)
		player.camera.limit_right = roundi(to_global(bounds.end).x - player.camera.offset.x)
		player.camera.limit_bottom = roundi(to_global(bounds.end).y - player.camera.offset.y)


func get_stage_destinations() -> Array:
	return [
		{"pos": to_global(PLAYER_SPAWNS[0]), "stage_index": 0, "cave": false, "sky": true, "label": "Copas de la selva"},
		{"pos": to_global(PLAYER_SPAWNS[1]), "stage_index": 1, "cave": false, "sky": true, "label": "Poblado"},
		{"pos": to_global(PLAYER_SPAWNS[2]), "stage_index": 2, "cave": false, "sky": true, "label": "Jefe Dona"}
	]
