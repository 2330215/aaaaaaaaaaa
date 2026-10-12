extends CanvasLayer

@onready var special_button := $TextureButtonAttack2 as TextureButton
@onready var charge_bar := $ChargeBar as ProgressBar
@onready var label := $ChargeBar/Label as Label
@onready var skin_button := $SkinButton as Button

var _player: Node = null


func _ready() -> void:
	if special_button:
		if "action" in special_button:
			special_button.action = "special_attack"
		set_special_ready(false)

	if charge_bar:
		charge_bar.min_value = 0
		charge_bar.max_value = 5
		charge_bar.value = 0

	if skin_button:
		skin_button.pressed.connect(_on_skin_button_pressed)
		_update_skin_button_text("Robot")

	call_deferred("_connect_to_player")


func _connect_to_player() -> void:
	var parent := get_parent()
	if not parent:
		return
	var player := parent.find_child("Player", true, false)
	if not player:
		player = parent.find_child("Player1", true, false)
	if player:
		_player = player
		if player.has_signal("special_charge_changed"):
			player.special_charge_changed.connect(_on_special_charge_changed)
		if player.has_signal("special_attack_ready"):
			player.special_attack_ready.connect(set_special_ready)
		if player.has_signal("skin_changed"):
			player.skin_changed.connect(_update_skin_button_text)
		if player.has_method("get_skin_name"):
			_update_skin_button_text(player.get_skin_name())
		if "special_charge" in player and "MAX_SPECIAL_CHARGE" in player:
			_on_special_charge_changed(player.special_charge, player.MAX_SPECIAL_CHARGE)
			set_special_ready(player.special_charge >= player.MAX_SPECIAL_CHARGE)


func _on_skin_button_pressed() -> void:
	if _player and _player.has_method("toggle_skin"):
		_player.toggle_skin()


func _update_skin_button_text(skin_name: String) -> void:
	if skin_button:
		skin_button.text = "Personaje: " + skin_name


func _on_special_charge_changed(current: int, max_charge: int) -> void:
	if charge_bar:
		charge_bar.max_value = max_charge
		charge_bar.value = current
	if label:
		if current >= max_charge:
			label.text = "¡ATAQUE ESPECIAL LISTO!"
			label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		else:
			label.text = "CARGA: %d/%d" % [current, max_charge]
			label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))


func set_special_ready(is_ready: bool) -> void:
	if special_button:
		special_button.disabled = not is_ready
		if is_ready:
			special_button.modulate = Color(1.5, 1.3, 0.4, 1.0)
		else:
			special_button.modulate = Color(0.4, 0.4, 0.4, 0.5)
