extends CanvasLayer
## Non-blocking paper reveal. It survives level changes through the autoload.

func present(recipe_id: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 180
	var entry := RecipeCollection.recipe(recipe_id)
	var card := PanelContainer.new()
	card.position = Vector2(0, -150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff0ce")
	style.border_color = Color("af793c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(340, 115)
	card.theme = Theme.new()
	card.theme.default_font = preload("res://gui/fonts/DejaVuSans.ttf")
	card.theme.default_font_size = 14
	add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(48, 64)
	var paper_style := style.duplicate() as StyleBoxFlat
	paper_style.bg_color = Color("fffbed")
	paper_style.set_corner_radius_all(2)
	paper_style.content_margin_left = 5
	paper_style.content_margin_right = 5
	paper.add_theme_stylebox_override("panel", paper_style)
	row.add_child(paper)
	if not recipe_id.is_empty():
		paper.custom_minimum_size = Vector2(72, 64)
		var illustration := TextureRect.new()
		illustration.name = "RecipeRewardIllustration"
		illustration.texture = load(str(entry.get("illustration", ""))) as Texture2D
		illustration.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		paper.add_child(illustration)
	var number := Label.new()
	number.text = "N"
	number.add_theme_color_override("font_color", Color("805b35"))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if recipe_id.is_empty():
		paper.add_child(number)
	else:
		number.free()
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var heading := Label.new()
	heading.text = "¡RECETA RECUPERADA!" if not recipe_id.is_empty() else "¡RECIBISTE LA LIBRETA!"
	heading.add_theme_color_override("font_color", Color("427257"))
	heading.add_theme_font_size_override("font_size", 12)
	col.add_child(heading)
	var title := Label.new()
	title.text = str(entry.get("title", "La libreta de Nopalio"))
	title.add_theme_color_override("font_color", Color("402e22"))
	title.add_theme_font_size_override("font_size", 16)
	col.add_child(title)
	var open := Button.new()
	open.text = "Ver receta" if not recipe_id.is_empty() else "Abrir libreta"
	open.custom_minimum_size.y = 32
	open.pressed.connect(func() -> void: RecipeCollection.open_notebook(RecipeCollection, recipe_id))
	col.add_child(open)
	if RecipeCollection.last_save_error != OK:
		var warning := Label.new()
		warning.text = "No se pudo guardar; disponible en esta sesión."
		warning.add_theme_color_override("font_color", Color("954731"))
		warning.add_theme_font_size_override("font_size", 10)
		col.add_child(warning)
	# Position after the container has calculated its actual size.
	await get_tree().process_frame
	var width := get_viewport().get_visible_rect().size.x
	card.position.x = maxf(10.0, (width - card.size.x) * 0.5)
	paper.pivot_offset = paper.size * 0.5
	paper.scale = Vector2(0.1, 0.85)
	var entrance := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entrance.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.tween_property(card, "position:y", 14.0, 0.45)
	entrance.parallel().tween_property(paper, "scale", Vector2.ONE, 0.6)
	await entrance.finished
	await get_tree().create_timer(3.3, true).timeout
	var leave := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	leave.tween_property(card, "modulate:a", 0.0, 0.3)
	await leave.finished
