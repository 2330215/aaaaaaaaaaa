extends Node
## Do not pause the world for dialogue until every screen fade has finished.
## Weak references release abandoned transitions when a level is unloaded.
var _transitions: Dictionary = {}
var _next_transition := 0
var _dialogue_owner: WeakRef
var _dialogue_scene: WeakRef


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func begin_transition(owner_node: Node) -> int:
	_next_transition += 1
	_transitions[_next_transition] = weakref(owner_node)
	return _next_transition


func end_transition(token: int) -> void:
	_transitions.erase(token)


func is_transitioning() -> bool:
	for token in _transitions.keys():
		var owner_node = (_transitions[token] as WeakRef).get_ref()
		if not is_instance_valid(owner_node) or not owner_node.is_inside_tree():
			_transitions.erase(token)
	return not _transitions.is_empty()


func has_active_dialogue() -> bool:
	if _dialogue_owner == null:
		return false
	var owner_node = _dialogue_owner.get_ref()
	var scene = _dialogue_scene.get_ref() if _dialogue_scene else null
	if not is_instance_valid(owner_node) or not owner_node.is_inside_tree() or scene != get_tree().current_scene:
		_dialogue_owner = null
		_dialogue_scene = null
		return false
	return true


func wait_for_dialogue(owner_node: Node, allow_paused: bool = false) -> bool:
	var owner_ref: WeakRef = weakref(owner_node)
	var scene := get_tree().current_scene
	var scene_ref: WeakRef = weakref(scene) if scene else null
	var stable_frames := 0
	while true:
		await get_tree().process_frame
		var waiting_owner = owner_ref.get_ref()
		var expected_scene = scene_ref.get_ref() if scene_ref else null
		if not is_instance_valid(waiting_owner) or not waiting_owner.is_inside_tree() or waiting_owner.is_queued_for_deletion():
			return false
		if get_tree().current_scene != expected_scene:
			return false
		if is_transitioning() or has_active_dialogue() or (get_tree().paused and not allow_paused):
			stable_frames = 0
			continue
		# A complete update/render cycle after the fade lets the new camera,
		# background and skin become visible before the dialogue pauses them.
		stable_frames += 1
		if stable_frames >= 2:
			_dialogue_owner = owner_ref
			_dialogue_scene = scene_ref
			return true
	return false


func release_dialogue(owner_node: Node) -> void:
	if _dialogue_owner and _dialogue_owner.get_ref() == owner_node:
		_dialogue_owner = null
		_dialogue_scene = null
