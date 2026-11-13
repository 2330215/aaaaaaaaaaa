extends Node
## Collection is independent of lives, checkpoints and level selection.
signal recipe_unlocked(recipe_id: String)
signal collection_changed()

const CATALOG = preload("res://story/recipes.json")
var save_path: String = "user://recipe_collection.cfg"
var notebook_owned := false
var unlocked: Dictionary = {}
var last_save_error: Error = OK
var _notebook: CanvasLayer
var _notifications: Array[String] = []
var _notification_running := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()


func recipes() -> Array:
	return CATALOG.data.duplicate(true)


func recipe(recipe_id: String) -> Dictionary:
	for entry: Dictionary in CATALOG.data:
		if str(entry["id"]) == recipe_id:
			return entry.duplicate(true)
	return {}


func is_unlocked(recipe_id: String) -> bool:
	return unlocked.has(recipe_id)


func complete_dialogue(dialogue_id: String) -> bool:
	if dialogue_id == "nopalio" and not notebook_owned:
		notebook_owned = true
		save_progress()
		collection_changed.emit()
		_queue_notification("")
		return true
	for entry: Dictionary in CATALOG.data:
		if str(entry["dialogue"]) == dialogue_id:
			return unlock_recipe(str(entry["id"]))
	return false


func unlock_recipe(recipe_id: String) -> bool:
	if is_unlocked(recipe_id) or recipe(recipe_id).is_empty():
		return false
	# Level selection may reach another NPC before Nopalio.
	notebook_owned = true
	unlocked[recipe_id] = true
	save_progress()
	recipe_unlocked.emit(recipe_id)
	collection_changed.emit()
	_queue_notification(recipe_id)
	return true


func save_progress() -> Error:
	var config := ConfigFile.new()
	config.set_value("collection", "notebook_owned", notebook_owned)
	config.set_value("collection", "recipes", unlocked.keys())
	var temporary := save_path + ".tmp"
	last_save_error = config.save(temporary)
	if last_save_error == OK:
		last_save_error = DirAccess.rename_absolute(temporary, save_path)
	if last_save_error != OK:
		push_warning("No se pudo guardar la libreta: %s" % error_string(last_save_error))
	return last_save_error


func load_progress() -> void:
	unlocked.clear()
	notebook_owned = false
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	notebook_owned = bool(config.get_value("collection", "notebook_owned", false))
	var saved: Variant = config.get_value("collection", "recipes", [])
	if saved is Array or saved is PackedStringArray:
		for id in saved:
			if not recipe(str(id)).is_empty():
				unlocked[str(id)] = true
	if not unlocked.is_empty():
		notebook_owned = true


func open_notebook(owner_node: Node, selected_id: String = "") -> void:
	if is_instance_valid(_notebook):
		if not selected_id.is_empty():
			_notebook.select_recipe(selected_id)
		return
	_notebook = load("res://gui/recipe_notebook.gd").new() as CanvasLayer
	owner_node.add_child(_notebook)
	if not selected_id.is_empty():
		_notebook.select_recipe(selected_id)


func _queue_notification(recipe_id: String) -> void:
	_notifications.append(recipe_id)
	if not _notification_running:
		_show_notifications.call_deferred()


func _show_notifications() -> void:
	if _notification_running:
		return
	_notification_running = true
	while not _notifications.is_empty():
		var id: String = _notifications.pop_front()
		var toast = load("res://gui/recipe_toast.gd").new()
		add_child(toast)
		await toast.present(id)
		toast.queue_free()
	_notification_running = false
