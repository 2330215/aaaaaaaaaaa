extends RefCounted
## Shared story text; JSON is included by the exporter through this resource.
const DATA = preload("res://story/dialogues.json")

static func lines(dialogue_id: String) -> Array:
	var data: Dictionary = DATA.data
	var result: Array = data.get(dialogue_id, [])
	return result.duplicate(true)

static func play(owner_node: Node, dialogue_id: String, speaker: String, portrait: Texture2D) -> void:
	var tree := owner_node.get_tree()
	var was_paused := tree.paused
	var box := preload("res://level/dialogue_box.tscn").instantiate() as DialogueBox
	owner_node.add_child(box)
	tree.paused = true
	box.start_dialogue(speaker, portrait, lines(dialogue_id))
	await box.dialogue_finished
	tree.paused = was_paused
	box.queue_free()
