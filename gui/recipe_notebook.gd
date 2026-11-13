extends CanvasLayer
## An open notebook with a recoverable-page index and scrollable recipe.

const INK = Color("49382b")
const MUTED = Color("887357")
var _was_paused := false
var _tree: SceneTree
var _progress: Label
var _index: VBoxContainer
var _page: VBoxContainer
var _page_scroll: ScrollContainer
var _selected_id: String = ""
var _return_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 170
	_tree = get_tree()
	_was_paused = _tree.paused
	_tree.paused = true
	_return_focus = get_viewport().gui_get_focus_owner()
	_build()
	RecipeCollection.collection_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if _tree:
		_tree.paused = _was_paused
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_pause"):
		get_viewport().set_input_as_handled()
		queue_free()


func _paper(color: Color, margin: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("ad8655")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


func _label(text: String, size: int = 15, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _build() -> void:
	var surface := Control.new()
	surface.theme = Theme.new()
	surface.theme.default_font = preload("res://gui/fonts/DejaVuSans.ttf")
	surface.theme.default_font_size = 14
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.07, 0.06, 0.94)
	surface.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	surface.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var toolbar := HBoxContainer.new()
	layout.add_child(toolbar)
	var title := _label("LA LIBRETA DE NOPALIO", 21, Color("f2dfb9"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	var close := Button.new()
	close.text = "Volver"
	close.name = "CloseNotebook"
	close.custom_minimum_size = Vector2(90, 38)
	close.pressed.connect(queue_free)
	toolbar.add_child(close)
	close.grab_focus()
	_progress = _label("", 13, Color("c8b690"))
	layout.add_child(_progress)
	var cover := PanelContainer.new()
	cover.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cover.add_theme_stylebox_override("panel", _paper(Color("69482e"), 7))
	layout.add_child(cover)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 4)
	cover.add_child(spread)
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 220
	left.add_theme_stylebox_override("panel", _paper(Color("e9d7b4"), 12))
	spread.add_child(left)
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left.add_child(left_col)
	left_col.add_child(_label("RECETAS DEL CAMINO", 13, MUTED))
	left_col.add_child(HSeparator.new())
	var index_scroll := ScrollContainer.new()
	index_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	index_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(index_scroll)
	_index = VBoxContainer.new()
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index.add_theme_constant_override("separation", 5)
	index_scroll.add_child(_index)
	var spine := ColorRect.new()
	spine.color = Color("af8b60")
	spine.custom_minimum_size.x = 8
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spread.add_child(spine)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", _paper(Color("fff2d8"), 18))
	spread.add_child(right)
	_page_scroll = ScrollContainer.new()
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_page_scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 9)
	_page_scroll.add_child(_page)
	layout.add_child(_label("7 hojas · 5 regiones · Muchas historias por recuperar", 12, Color("b3aa94")))
	cover.modulate.a = 0.0
	var opening := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	opening.tween_property(cover, "modulate:a", 1.0, 0.25)


func _refresh() -> void:
	_progress.text = "%d de 7 recetas recuperadas" % RecipeCollection.unlocked.size()
	for child in _index.get_children():
		_index.remove_child(child)
		child.queue_free()
	var recipes: Array = RecipeCollection.recipes()
	for i in recipes.size():
		var entry: Dictionary = recipes[i]
		var id: String = entry["id"]
		var known := RecipeCollection.is_unlocked(id)
		var button := Button.new()
		button.text = "%02d  %s\n%s" % [i + 1, str(entry["title"]) if known else "Hoja por descubrir", entry["region"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", INK if known else MUTED)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
		button.add_theme_stylebox_override("normal", _paper(Color("fff6e1") if known else Color("ddc9a7"), 6))
		button.add_theme_stylebox_override("hover", _paper(Color("fffbed"), 6))
		button.add_theme_stylebox_override("pressed", _paper(Color("ecd398"), 6))
		button.pressed.connect(select_recipe.bind(id))
		_index.add_child(button)
	if _selected_id.is_empty():
		for entry: Dictionary in recipes:
			if RecipeCollection.is_unlocked(str(entry["id"])):
				_selected_id = str(entry["id"])
				break
	select_recipe(_selected_id if not _selected_id.is_empty() else str(recipes[0]["id"]))


func select_recipe(recipe_id: String) -> void:
	_selected_id = recipe_id
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	_page_scroll.scroll_vertical = 0
	var entry := RecipeCollection.recipe(recipe_id)
	if entry.is_empty():
		return
	var known := RecipeCollection.is_unlocked(recipe_id)
	var color := Color(str(entry["color"]))
	_page.add_child(_label(str(entry["region"]).to_upper(), 12, color.darkened(0.2)))
	if not known:
		_page.add_child(_label("Esta hoja aún falta", 25))
		_page.add_child(HSeparator.new())
		_page.add_child(_label("Aquí hay espacio para una receta… y para el nombre de quien la preparó.", 16))
		_page.add_child(_label(str(entry["hint"]), 15, MUTED))
		if not RecipeCollection.notebook_owned:
			_page.add_child(_label("Habla con Nopalio para recibir su libreta y empezar la aventura.", 14, MUTED))
		return
	_page.add_child(_label(str(entry["title"]), 25))
	_page.add_child(_label("Una receta de " + str(entry["author"]), 12, MUTED))
	var illustration_path: String = str(entry.get("illustration", ""))
	if not illustration_path.is_empty() and ResourceLoader.exists(illustration_path):
		var illustration := TextureRect.new()
		illustration.name = "DishIllustration"
		illustration.texture = load(illustration_path) as Texture2D
		illustration.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		illustration.custom_minimum_size = Vector2(0, 148)
		illustration.tooltip_text = str(entry["title"])
		illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_page.add_child(illustration)
	_page.add_child(HSeparator.new())
	_page.add_child(_label("INGREDIENTES", 13, color.darkened(0.2)))
	for ingredient in entry["ingredients"]:
		_page.add_child(_label("• " + str(ingredient)))
	_page.add_child(_label("PREPARACIÓN", 13, color.darkened(0.2)))
	var steps: Array = entry["steps"]
	for i in steps.size():
		_page.add_child(_label("%d. %s" % [i + 1, steps[i]]))
	_page.add_child(HSeparator.new())
	_page.add_child(_label("EN EL MARGEN…", 12, MUTED))
	_page.add_child(_label(str(entry["note"]), 14, MUTED))
	_page.add_child(_label("Prepara esta receta en compañía de una persona adulta. Cuiden la higiene y revisen los ingredientes si hay alergias.", 11, MUTED))
