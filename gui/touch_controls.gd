extends CanvasLayer

# ─── Nodos de HUD ────────────────────────────────────────────────────────────
@onready var special_button := $TextureButtonAttack2 as TextureButton
@onready var charge_bar     := $ChargeBar            as ProgressBar
@onready var charge_label   := $ChargeBar/Label      as Label
@onready var trucos_button  := $TrucosButton         as Button

# ─── Jugador ─────────────────────────────────────────────────────────────────
var _player: Node = null

# ─── Escenarios ──────────────────────────────────────────────────────────────
const STAGES: Array = [
	{"pos": Vector2(128, 448),  "stage_index": 0, "cave": false, "sky": false, "label": "Inicio"},
	{"pos": Vector2(128, 2208), "stage_index": 1, "cave": false, "sky": false, "label": "Escenario 2"},
	{"pos": Vector2(128, 3990), "stage_index": 2, "cave": true,  "sky": false, "label": "Cueva"},
	{"pos": Vector2(128, 5300), "stage_index": 1, "cave": false, "sky": true,  "label": "Boss"},
]
var _next_stage_idx: int = 1
var _teleporting: bool   = false

# ─── Estado de trucos ─────────────────────────────────────────────────────────
var _speed_cheat: bool = false
var _jump_cheat:  bool = false

# ─── Panel ───────────────────────────────────────────────────────────────────
var _panel_open: bool  = false
var _panel:      PanelContainer
var _skin_btn:   Button
var _limon_btn:  Button
var _stage_btn:  Button
var _speed_btn:  Button
var _jump_btn:   Button

# ─── Fade de teletransporte ───────────────────────────────────────────────────
var _fade_rect: ColorRect


func _ready() -> void:
	if special_button:
		if "action" in special_button:
			special_button.action = "special_attack"
		set_special_ready(false)

	if charge_bar:
		charge_bar.min_value = 0
		charge_bar.max_value = 5
		charge_bar.value     = 0

	if trucos_button:
		trucos_button.pressed.connect(_toggle_panel)

	_build_cheat_panel()
	_build_fade_rect()
	call_deferred("_connect_to_player")


# ─────────────────────────────────────────────────────────────────────────────
#  PANEL DE TRUCOS
# ─────────────────────────────────────────────────────────────────────────────
func _build_cheat_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "CheatPanel"

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.35, 0.35, 1.0)
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_right    = 4
	_panel.add_theme_stylebox_override("panel", style)

	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(8, 42)
	_panel.custom_minimum_size = Vector2(200, 0)
	_panel.visible = false

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Titulo
	var title := Label.new()
	title.text = "TRUCOS"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_skin_btn  = _make_btn("Personaje: Robot")
	_skin_btn.pressed.connect(_on_skin_pressed)
	vbox.add_child(_skin_btn)

	_limon_btn = _make_btn("Personaje: Limón")
	_limon_btn.pressed.connect(_on_limon_pressed)
	vbox.add_child(_limon_btn)

	_stage_btn = _make_btn("Ir a: Inicio")
	_stage_btn.pressed.connect(_on_stage_pressed)
	_update_stage_label()
	vbox.add_child(_stage_btn)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	_speed_btn = _make_btn("Velocidad: Normal")
	_speed_btn.pressed.connect(_on_speed_pressed)
	vbox.add_child(_speed_btn)

	_jump_btn  = _make_btn("Salto: Normal")
	_jump_btn.pressed.connect(_on_jump_pressed)
	vbox.add_child(_jump_btn)

	add_child(_panel)


func _make_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_font_size_override("font_size", 12)

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	sn.corner_radius_bottom_left  = 3
	sn.corner_radius_bottom_right = 3
	sn.corner_radius_top_left     = 3
	sn.corner_radius_top_right    = 3
	b.add_theme_stylebox_override("normal", sn)

	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.28, 0.28, 0.28, 1.0)
	sh.corner_radius_bottom_left  = 3
	sh.corner_radius_bottom_right = 3
	sh.corner_radius_top_left     = 3
	sh.corner_radius_top_right    = 3
	b.add_theme_stylebox_override("hover", sh)

	var sp := StyleBoxFlat.new()
	sp.bg_color = Color(0.22, 0.22, 0.22, 1.0)
	sp.corner_radius_bottom_left  = 3
	sp.corner_radius_bottom_right = 3
	sp.corner_radius_top_left     = 3
	sp.corner_radius_top_right    = 3
	b.add_theme_stylebox_override("pressed", sp)

	return b


func _build_fade_rect() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 200
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.visible = false
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade_rect)
	add_child(fade_layer)


# ─────────────────────────────────────────────────────────────────────────────
#  TOGGLE DEL PANEL
# ─────────────────────────────────────────────────────────────────────────────
func _toggle_panel() -> void:
	_panel_open = not _panel_open
	if _panel_open:
		_panel.modulate.a = 0.0
		_panel.visible    = true
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
		trucos_button.text = "Cerrar"
	else:
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 0.0, 0.12)
		await tw.finished
		_panel.visible     = false
		trucos_button.text = "Trucos"


# ─────────────────────────────────────────────────────────────────────────────
#  ACCIONES
# ─────────────────────────────────────────────────────────────────────────────
func _on_skin_pressed() -> void:
	if _player and _player.has_method("toggle_skin"):
		_player.toggle_skin()


func _on_limon_pressed() -> void:
	if _player and _player.has_method("toggle_limon_skin"):
		_player.toggle_limon_skin()


func _update_skin_label(skin_name: String) -> void:
	if _skin_btn:
		# El botón de Robot/Aguacate solo muestra esas skins
		if skin_name in ["Robot", "Aguacate"]:
			_skin_btn.text = "Personaje: " + skin_name
			_skin_btn.remove_theme_color_override("font_color")
		else:
			_skin_btn.text = "Personaje: Robot"
			_skin_btn.remove_theme_color_override("font_color")
	if _limon_btn:
		if skin_name == "Limón":
			_limon_btn.text = "Personaje: Limón"
			_limon_btn.remove_theme_color_override("font_color")
		elif skin_name == "Globo 🎈":
			_limon_btn.text = "Personaje: Limón  [GLOBO 🎈]"
			_limon_btn.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		else:
			_limon_btn.text = "Personaje: Limón"
			_limon_btn.remove_theme_color_override("font_color")


func _update_stage_label() -> void:
	if _stage_btn:
		var dest := STAGES[_next_stage_idx] as Dictionary
		if dest:
			_stage_btn.text = "Ir a: " + str(dest["label"])


func _on_stage_pressed() -> void:
	if _teleporting:
		return
	_teleporting = true
	_stage_btn.disabled = true

	var dest := STAGES[_next_stage_idx] as Dictionary
	if not dest:
		_teleporting        = false
		_stage_btn.disabled = false
		return

	_next_stage_idx = (_next_stage_idx + 1) % STAGES.size()
	_update_stage_label()

	_fade_rect.color   = Color(0, 0, 0, 0)
	_fade_rect.visible = true
	var tw_out := create_tween()
	tw_out.tween_property(_fade_rect, "color:a", 1.0, 0.3)
	await tw_out.finished

	var scene = get_tree().current_scene
	if scene:
		var bg = scene.find_child("ParallaxBackground", true, false)
		if bg:
			if bg.has_method("set_cave_mode"):
				bg.set_cave_mode(dest["cave"])
			if bg.has_method("align_to_stage"):
				bg.align_to_stage(dest["stage_index"])

	if _player and is_instance_valid(_player):
		_player.global_position = dest["pos"]
		_player.velocity        = Vector2.ZERO
		if _player.get_parent():
			for sib in _player.get_parent().get_children():
				if sib != _player and sib.has_method("die"):
					sib.global_position = dest["pos"] + Vector2(32, 0)
					if "velocity" in sib:
						sib.velocity = Vector2.ZERO

	await get_tree().process_frame

	var tw_in := create_tween()
	tw_in.tween_property(_fade_rect, "color:a", 0.0, 0.3)
	await tw_in.finished
	_fade_rect.visible  = false
	_stage_btn.disabled = false
	_teleporting        = false


func _on_speed_pressed() -> void:
	_speed_cheat = not _speed_cheat
	_apply_cheats()
	if _speed_cheat:
		_speed_btn.text = "Velocidad: Rapida  [ON]"
		_speed_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		_speed_btn.text = "Velocidad: Normal"
		_speed_btn.remove_theme_color_override("font_color")


func _on_jump_pressed() -> void:
	_jump_cheat = not _jump_cheat
	_apply_cheats()
	if _jump_cheat:
		_jump_btn.text = "Salto: Alto  [ON]"
		_jump_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		_jump_btn.text = "Salto: Normal"
		_jump_btn.remove_theme_color_override("font_color")


func _apply_cheats() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "speed_mult" in p:
			p.speed_mult = 2.2  if _speed_cheat else 1.0
		if "jump_mult" in p:
			p.jump_mult  = 1.55 if _jump_cheat  else 1.0


# ─────────────────────────────────────────────────────────────────────────────
#  CONEXIÓN CON EL JUGADOR
# ─────────────────────────────────────────────────────────────────────────────
func _connect_to_player() -> void:
	var parent := get_parent()
	if not parent:
		return
	var player := parent.find_child("Player", true, false)
	if not player:
		player = parent.find_child("Player1", true, false)
	if not player:
		return
	_player = player
	if player.has_signal("special_charge_changed"):
		player.special_charge_changed.connect(_on_special_charge_changed)
	if player.has_signal("special_attack_ready"):
		player.special_attack_ready.connect(set_special_ready)
	if player.has_signal("skin_changed"):
		player.skin_changed.connect(_update_skin_label)
	if player.has_method("get_skin_name"):
		_update_skin_label(player.get_skin_name())
	if "special_charge" in player and "MAX_SPECIAL_CHARGE" in player:
		_on_special_charge_changed(player.special_charge, player.MAX_SPECIAL_CHARGE)
		set_special_ready(player.special_charge >= player.MAX_SPECIAL_CHARGE)


# ─────────────────────────────────────────────────────────────────────────────
#  BARRA DE CARGA ESPECIAL
# ─────────────────────────────────────────────────────────────────────────────
func _on_special_charge_changed(current: int, max_charge: int) -> void:
	if charge_bar:
		charge_bar.max_value = max_charge
		charge_bar.value     = current
	if charge_label:
		if current >= max_charge:
			charge_label.text = "ATAQUE ESPECIAL LISTO"
			charge_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		else:
			charge_label.text = "CARGA: %d/%d" % [current, max_charge]
			charge_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))


func set_special_ready(is_ready: bool) -> void:
	if special_button:
		special_button.disabled = not is_ready
		if is_ready:
			special_button.modulate = Color(1.5, 1.3, 0.4, 1.0)
		else:
			special_button.modulate = Color(0.4, 0.4, 0.4, 0.5)
